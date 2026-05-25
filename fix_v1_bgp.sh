#!/usr/bin/env bash
# =============================================================================
# fix_v1_bgp.sh  —  _v1 CLOS Fabric BGP Recovery Script
# =============================================================================
# Run this ON the R620 host (as your normal user with sudo).
#   scp fix_v1_bgp.sh nh1221@R620:~/
#   ssh nh1221@R620
#   chmod +x fix_v1_bgp.sh && ./fix_v1_bgp.sh
#
# Fixes applied (in order):
#   1. BL1/BL2 — all fabric/server interfaces stuck admin-down (BGP = Idle)
#   2. br-BL2-ER2 — Exit_Router2 NIC missing from bridge (BL2→ER2 = Active)
#   3. Exit_Router1 — MikroTik ether2 down + verify BGP config (BL1→ER1 = Connect)
#   4. Exit_Router2 — MikroTik ether2 down + verify BGP config (BL2→ER2 = Active)
#
# Expected end-state:
#   BL1: Ethernet20/22/24/28/120/124 oper-up → BGP Established with S1/S2/servers/ER1
#   BL2: same                                 → BGP Established with S1/S2/servers/ER2
# =============================================================================

set -uo pipefail

# ─── Tunables ─────────────────────────────────────────────────────────────────
BL1_IP="172.16.2.31"
BL2_IP="172.16.2.32"
ER1_IP="172.16.2.98"
ER2_IP="172.16.2.99"

SONIC_USER="admin"
SONIC_PASS="amolla01"
CHR_USER="admin"          # No password on CHR by default

# Fabric + server ports that must be admin-up on both border leaves
# (Ethernet22 is also present in the _v1 BGP frr.conf as a physical sub-port
#  alias for MonitorSrv — include it so config interface startup attempts it;
#  SONiC will silently skip non-existent ports on KVM VS)
BL_PORTS="Ethernet20 Ethernet22 Ethernet24 Ethernet28 Ethernet120 Ethernet124"

# Exit-router /31 point-to-point links
BL1_EXIT_IP="10.0.253.0/31"
ER1_EXIT_IP="10.0.253.1/31"
BL1_EXIT_PEER="10.0.253.1"     # ER1 address seen by BL1
ER1_PEER_ADDR="10.0.253.0"     # BL1 address seen by ER1
BL1_ASN="65021"
ER1_ASN="65253"

BL2_EXIT_IP="10.0.253.2/31"
ER2_EXIT_IP="10.0.253.3/31"
BL2_EXIT_PEER="10.0.253.3"     # ER2 address seen by BL2
ER2_PEER_ADDR="10.0.253.2"     # BL2 address seen by ER2
BL2_ASN="65022"
ER2_ASN="65254"

BGP_WAIT=30   # seconds to wait for BGP to converge after fixes
# ─── End Tunables ──────────────────────────────────────────────────────────────

# ─── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'
CYN='\033[0;36m'; WHT='\033[1;37m'; DIM='\033[2m'; NC='\033[0m'

phase()   { echo -e "\n${WHT}══════════════════════════════════════════════════════${NC}"; \
            echo -e "${CYN}  $1${NC}"; \
            echo -e "${WHT}══════════════════════════════════════════════════════${NC}"; }
ok()      { echo -e "  ${GRN}✓  $*${NC}"; }
warn()    { echo -e "  ${YLW}△  $*${NC}"; }
err()     { echo -e "  ${RED}✗  $*${NC}"; }
info()    { echo -e "  ${DIM}▸  $*${NC}"; }
banner()  { echo -e "\n${DIM}─────  $*  ─────${NC}"; }

# ─── SSH helpers ───────────────────────────────────────────────────────────────
# SONiC switches — password auth via sshpass
sonic_cmd() {
    local host="$1"; shift
    sshpass -p "${SONIC_PASS}" \
        ssh -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o ConnectTimeout=10 \
            -o LogLevel=ERROR \
            "${SONIC_USER}@${host}" "$@" 2>&1
}

# MikroTik CHR — no password, or key-based
# Uses a here-doc piped to SSH so RouterOS CLI gets all commands in one session
chr_cmd() {
    local host="$1"; shift
    ssh -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=10 \
        -o LogLevel=ERROR \
        -o PasswordAuthentication=no \
        "${CHR_USER}@${host}" "$@" 2>&1 || \
    # fallback: try with sshpass empty password
    sshpass -p "" \
        ssh -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o ConnectTimeout=10 \
            -o LogLevel=ERROR \
            "${CHR_USER}@${host}" "$@" 2>&1
}

# ─── Prerequisite checks ───────────────────────────────────────────────────────
phase "Phase 0 — Prerequisites"

# sshpass
if ! command -v sshpass &>/dev/null; then
    warn "sshpass not found — installing..."
    sudo apt-get install -y -qq sshpass && ok "sshpass installed" || { err "Cannot install sshpass. Aborting."; exit 1; }
else
    ok "sshpass available"
fi

# virsh
if ! command -v virsh &>/dev/null; then
    err "virsh not found. Run this script ON the R620 hypervisor host."; exit 1
fi
ok "virsh available"

# ovs-vsctl
if ! command -v ovs-vsctl &>/dev/null; then
    err "ovs-vsctl not found. OVS must be installed."; exit 1
fi
ok "ovs-vsctl available"

# ─────────────────────────────────────────────────────────────────────────────
phase "Phase 1 — Pre-flight Diagnostics"
# ─────────────────────────────────────────────────────────────────────────────

banner "BL1 (${BL1_IP}) — interface status"
sonic_cmd "${BL1_IP}" \
    "sudo show interfaces status 2>/dev/null | grep -E 'Ethernet(20|22|24|28|120|124)' || docker exec syncd ip link show 2>/dev/null | grep -E 'Ethernet(20|22|24|28|120|124)'" \
    || warn "Could not reach BL1 — may already be down"

banner "BL2 (${BL2_IP}) — interface status"
sonic_cmd "${BL2_IP}" \
    "sudo show interfaces status 2>/dev/null | grep -E 'Ethernet(20|22|24|28|120|124)' || true" \
    || warn "Could not reach BL2"

banner "OVS bridge br-BL2-ER2 — port count (expect 2, currently 1)"
sudo ovs-vsctl list-ports br-BL2-ER2 2>/dev/null | { \
    readarray -t ports; \
    echo "  Ports on br-BL2-ER2: ${#ports[@]} — ${ports[*]:-none}"; \
    [[ ${#ports[@]} -ge 2 ]] && ok "Bridge already has 2 ports" || warn "Only ${#ports[@]} port(s) — Exit_Router2 NIC missing"; \
}

banner "Exit_Router2 — current NIC wiring"
sudo virsh domiflist Exit_Router2 2>/dev/null || warn "Exit_Router2 VM not found or not running"

banner "Exit_Router1 — current NIC wiring"
sudo virsh domiflist Exit_Router1 2>/dev/null || warn "Exit_Router1 VM not found"

# ─────────────────────────────────────────────────────────────────────────────
phase "Phase 2 — Fix Border_Leaf1: Admin-up all fabric/server ports"
# ─────────────────────────────────────────────────────────────────────────────
# Root cause: Ethernet20/22/24/28/120/124 are admin-down in SONiC PORT table.
# FRR BGP refuses to use an admin-down interface → all neighbors stuck in Idle.

info "Bringing up fabric/server ports on BL1 (${BL1_IP})..."
for IFACE in ${BL_PORTS}; do
    RESULT=$(sonic_cmd "${BL1_IP}" "sudo config interface startup ${IFACE} 2>&1; echo __RC__\$?" || true)
    RC=$(echo "${RESULT}" | grep '__RC__' | sed 's/__RC__//')
    if [[ "${RC}" == "0" ]]; then
        ok "BL1 ${IFACE} started"
    else
        MSG=$(echo "${RESULT}" | grep -v '__RC__')
        warn "BL1 ${IFACE}: ${MSG:-no output} (may not exist on KVM VS — expected for Ethernet22)"
    fi
done

info "Saving BL1 config..."
sonic_cmd "${BL1_IP}" "sudo config save -y" && ok "BL1 config saved"

# ─────────────────────────────────────────────────────────────────────────────
phase "Phase 3 — Fix Border_Leaf2: Admin-up all fabric/server ports"
# ─────────────────────────────────────────────────────────────────────────────

info "Bringing up fabric/server ports on BL2 (${BL2_IP})..."
for IFACE in ${BL_PORTS}; do
    RESULT=$(sonic_cmd "${BL2_IP}" "sudo config interface startup ${IFACE} 2>&1; echo __RC__\$?" || true)
    RC=$(echo "${RESULT}" | grep '__RC__' | sed 's/__RC__//')
    if [[ "${RC}" == "0" ]]; then
        ok "BL2 ${IFACE} started"
    else
        MSG=$(echo "${RESULT}" | grep -v '__RC__')
        warn "BL2 ${IFACE}: ${MSG:-no output} (may not exist on KVM VS)"
    fi
done

info "Saving BL2 config..."
sonic_cmd "${BL2_IP}" "sudo config save -y" && ok "BL2 config saved"

# ─────────────────────────────────────────────────────────────────────────────
phase "Phase 4 — Fix br-BL2-ER2: Reattach Exit_Router2 NIC"
# ─────────────────────────────────────────────────────────────────────────────
# br-BL2-ER2 has only 1 port (Border_Leaf2's NIC).
# Exit_Router2's ether2 (NIC1) must also be on this bridge.
# Per VM_BRIDGES map: Exit_Router2 = "br-BL2-ER2" (its sole fabric NIC).

BRIDGE="br-BL2-ER2"
VM="Exit_Router2"

# Count current non-internal ports on the bridge
PORT_COUNT=$(sudo ovs-vsctl list-ports "${BRIDGE}" 2>/dev/null | grep -v "^${BRIDGE}$" | wc -l)
info "Current ports on ${BRIDGE}: ${PORT_COUNT}"

if [[ "${PORT_COUNT}" -ge 2 ]]; then
    ok "${VM} NIC already attached to ${BRIDGE} — skipping"
else
    # Check if VM is running
    VM_STATE=$(sudo virsh domstate "${VM}" 2>/dev/null || echo "not-found")
    info "${VM} state: ${VM_STATE}"

    if [[ "${VM_STATE}" == "not-found" ]]; then
        err "${VM} VM does not exist — cannot attach NIC"
    else
        # Check what fabric NICs ER2 currently has (exclude mgmt/dc-mgmt)
        CURRENT_FABRIC_BRIDGE=$(sudo virsh domiflist "${VM}" 2>/dev/null \
            | awk 'NR>2 && $3 != "dc-mgmt" && $3 != "" {print $3}' \
            | head -1)

        if [[ -n "${CURRENT_FABRIC_BRIDGE}" && "${CURRENT_FABRIC_BRIDGE}" != "${BRIDGE}" ]]; then
            warn "${VM} NIC is on wrong bridge '${CURRENT_FABRIC_BRIDGE}' — detaching..."
            # Get the MAC of the misplaced NIC
            WRONG_MAC=$(sudo virsh domiflist "${VM}" 2>/dev/null \
                | awk -v br="${CURRENT_FABRIC_BRIDGE}" '$3==br {print $5}' | head -1)
            if [[ -n "${WRONG_MAC}" ]]; then
                sudo virsh detach-interface "${VM}" bridge --mac "${WRONG_MAC}" --current 2>&1 \
                    && ok "Detached NIC (${WRONG_MAC}) from ${CURRENT_FABRIC_BRIDGE}" \
                    || warn "Detach may have failed — check manually"
                sleep 2
            fi
        fi

        info "Attaching ${VM} NIC to ${BRIDGE}..."
        if [[ "${VM_STATE}" == "running" ]]; then
            # Live attach (hot-plug) + persist to config
            sudo virsh attach-interface "${VM}" \
                --type bridge \
                --source "${BRIDGE}" \
                --model virtio \
                --config \
                --live 2>&1 && ok "${VM} NIC hot-attached to ${BRIDGE} (live + persistent)" \
                || { err "Live attach failed — trying config-only + reboot"; \
                     sudo virsh attach-interface "${VM}" --type bridge --source "${BRIDGE}" \
                         --model virtio --config 2>&1 \
                         && { info "Config-only attach succeeded. Rebooting ${VM}..."; \
                              sudo virsh reboot "${VM}" && ok "${VM} reboot triggered"; }; }
        else
            # VM is shut off — attach to config only, then start
            sudo virsh attach-interface "${VM}" \
                --type bridge \
                --source "${BRIDGE}" \
                --model virtio \
                --config 2>&1 && ok "${VM} NIC attached to config (VM was off)" \
                || err "Attach failed — see output above"
            info "Starting ${VM}..."
            sudo virsh start "${VM}" && ok "${VM} started"
        fi

        # Give it a moment and verify
        sleep 5
        NEW_PORT_COUNT=$(sudo ovs-vsctl list-ports "${BRIDGE}" 2>/dev/null \
            | grep -v "^${BRIDGE}$" | wc -l)
        if [[ "${NEW_PORT_COUNT}" -ge 2 ]]; then
            ok "Verified: ${BRIDGE} now has ${NEW_PORT_COUNT} ports"
        else
            warn "${BRIDGE} still has only ${NEW_PORT_COUNT} port(s) — manual intervention may be needed"
            info "Run:  sudo virsh domiflist ${VM}"
            info "      sudo ovs-vsctl list-ports ${BRIDGE}"
        fi
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
phase "Phase 5 — Fix Exit_Router1: Enable ether2 + Verify BGP (MikroTik RouterOS 7)"
# ─────────────────────────────────────────────────────────────────────────────
# BL1→ER1 is in 'Connect' state: bridge wiring is OK but ether2 is admin-down
# on the MikroTik. We need to:
#   a) Enable ether2
#   b) Confirm IP 10.0.253.1/31 is on ether2  (add if missing)
#   c) Confirm BGP connection to BL1 (10.0.253.0, AS 65021) exists

info "Connecting to Exit_Router1 (${ER1_IP})..."

chr_cmd "${ER1_IP}" << MIKROTIK_ER1
# ── a) Enable ether2 ──────────────────────────────────────────────────────────
:if ([/interface get [find name=ether2] disabled] = true) do={
    /interface enable ether2
    :log info "fix_v1_bgp: ether2 enabled"
    :put "ether2 was DISABLED — now enabled"
} else={
    :put "ether2 already enabled"
}
/interface print where name=ether2

# ── b) Ensure IP 10.0.253.1/31 on ether2 ─────────────────────────────────────
:local er1ip "${ER1_EXIT_IP}"
:if ([/ip address find where address=\$er1ip] = "") do={
    /ip address add address=\$er1ip interface=ether2
    :put "IP \$er1ip added to ether2"
} else={
    :put "IP \$er1ip already present on ether2"
}
/ip address print where interface=ether2

# ── c) Ensure BGP connection to BL1 exists (RouterOS 7 syntax) ───────────────
:local peerAddr "${ER1_PEER_ADDR}"
:local peerAs   ${BL1_ASN}
:local localAs  ${ER1_ASN}

# Check if BGP template 'default' has our AS
:if ([/routing bgp template find where as=\$localAs] = "") do={
    /routing bgp template add name=default as=\$localAs router-id=10.0.253.1
    :put "BGP template created with AS \$localAs"
} else={
    :put "BGP template already has AS \$localAs"
}

# Check if BGP connection to BL1 already exists
:if ([/routing bgp connection find where remote.address=\$peerAddr] = "") do={
    /routing bgp connection add \\
        name=to-BL1 \\
        as=\$localAs \\
        remote.address=\$peerAddr \\
        remote.as=\$peerAs \\
        router-id=10.0.253.1 \\
        local.role=ebgp
    :put "BGP connection to BL1 (\$peerAddr AS\$peerAs) created"
} else={
    :put "BGP connection to BL1 already configured"
}

/routing bgp connection print
/routing bgp session print
MIKROTIK_ER1

if [[ $? -eq 0 ]]; then
    ok "Exit_Router1 configuration applied"
else
    warn "Exit_Router1 SSH had errors — may need manual intervention"
    info "Manual steps on ER1:"
    info "  ssh admin@${ER1_IP}"
    info "  /interface enable ether2"
    info "  /ip address add address=${ER1_EXIT_IP} interface=ether2"
    info "  /routing bgp template set default as=${ER1_ASN}"
    info "  /routing bgp connection add name=to-BL1 as=${ER1_ASN} remote.address=${ER1_PEER_ADDR} remote.as=${BL1_ASN} router-id=10.0.253.1 local.role=ebgp"
fi

# ─────────────────────────────────────────────────────────────────────────────
phase "Phase 6 — Fix Exit_Router2: Enable ether2 + Verify BGP (MikroTik RouterOS 7)"
# ─────────────────────────────────────────────────────────────────────────────
# ER2 was unreachable because its NIC was missing from br-BL2-ER2 (fixed in Phase 4).
# Wait for VM to get its management IP, then apply the same config.

# ER2 may have just rebooted — give it time to come up
info "Waiting 20 s for Exit_Router2 to finish booting..."
sleep 20

# Ping test before SSH
if ping -c 2 -W 3 "${ER2_IP}" &>/dev/null; then
    ok "Exit_Router2 (${ER2_IP}) is reachable"
else
    warn "Exit_Router2 not yet pingable — waiting another 30 s..."
    sleep 30
    ping -c 2 -W 3 "${ER2_IP}" &>/dev/null \
        && ok "Exit_Router2 reachable now" \
        || { err "Exit_Router2 still unreachable at ${ER2_IP}. Check: sudo virsh domstate Exit_Router2"; \
             warn "Skipping ER2 config — re-run script after ER2 boots"; }
fi

if ping -c 1 -W 2 "${ER2_IP}" &>/dev/null; then

chr_cmd "${ER2_IP}" << MIKROTIK_ER2
# ── a) Enable ether2 ──────────────────────────────────────────────────────────
:if ([/interface get [find name=ether2] disabled] = true) do={
    /interface enable ether2
    :put "ether2 was DISABLED — now enabled"
} else={
    :put "ether2 already enabled"
}
/interface print where name=ether2

# ── b) Ensure IP 10.0.253.3/31 on ether2 ─────────────────────────────────────
:local er2ip "${ER2_EXIT_IP}"
:if ([/ip address find where address=\$er2ip] = "") do={
    /ip address add address=\$er2ip interface=ether2
    :put "IP \$er2ip added to ether2"
} else={
    :put "IP \$er2ip already present on ether2"
}
/ip address print where interface=ether2

# ── c) Ensure BGP connection to BL2 exists ───────────────────────────────────
:local peerAddr "${ER2_PEER_ADDR}"
:local peerAs   ${BL2_ASN}
:local localAs  ${ER2_ASN}

:if ([/routing bgp template find where as=\$localAs] = "") do={
    /routing bgp template add name=default as=\$localAs router-id=10.0.253.3
    :put "BGP template created with AS \$localAs"
} else={
    :put "BGP template already has AS \$localAs"
}

:if ([/routing bgp connection find where remote.address=\$peerAddr] = "") do={
    /routing bgp connection add \\
        name=to-BL2 \\
        as=\$localAs \\
        remote.address=\$peerAddr \\
        remote.as=\$peerAs \\
        router-id=10.0.253.3 \\
        local.role=ebgp
    :put "BGP connection to BL2 (\$peerAddr AS\$peerAs) created"
} else={
    :put "BGP connection to BL2 already configured"
}

/routing bgp connection print
/routing bgp session print
MIKROTIK_ER2

    [[ $? -eq 0 ]] && ok "Exit_Router2 configuration applied" \
        || warn "Exit_Router2 SSH had errors"
else
    warn "Skipping Exit_Router2 MikroTik config — not reachable"
    info "Re-run this script once ER2 has booted, or SSH manually:"
    info "  ssh admin@${ER2_IP}"
    info "  /interface enable ether2"
    info "  /ip address add address=${ER2_EXIT_IP} interface=ether2"
    info "  /routing bgp template set default as=${ER2_ASN}"
    info "  /routing bgp connection add name=to-BL2 as=${ER2_ASN} remote.address=${ER2_PEER_ADDR} remote.as=${BL2_ASN} router-id=10.0.253.3 local.role=ebgp"
fi

# ─────────────────────────────────────────────────────────────────────────────
phase "Phase 7 — Waiting ${BGP_WAIT}s for BGP to converge..."
# ─────────────────────────────────────────────────────────────────────────────
sleep "${BGP_WAIT}"

# ─────────────────────────────────────────────────────────────────────────────
phase "Phase 8 — Post-fix Verification"
# ─────────────────────────────────────────────────────────────────────────────

banner "BL1 interface oper state"
sonic_cmd "${BL1_IP}" \
    "sudo show interfaces status 2>/dev/null | grep -E 'Ethernet(20|22|24|28|120|124)'" \
    || warn "Cannot reach BL1 for verification"

banner "BL2 interface oper state"
sonic_cmd "${BL2_IP}" \
    "sudo show interfaces status 2>/dev/null | grep -E 'Ethernet(20|22|24|28|120|124)'" \
    || warn "Cannot reach BL2 for verification"

banner "BL1 BGP summary (expect Established on all neighbors)"
sonic_cmd "${BL1_IP}" \
    "docker exec bgp vtysh -c 'show bgp summary' 2>/dev/null | tail -30" \
    || warn "Cannot reach BL1 for BGP check"

banner "BL2 BGP summary"
sonic_cmd "${BL2_IP}" \
    "docker exec bgp vtysh -c 'show bgp summary' 2>/dev/null | tail -30" \
    || warn "Cannot reach BL2 for BGP check"

banner "Exit_Router1 BGP sessions"
chr_cmd "${ER1_IP}" "/routing bgp session print" 2>/dev/null \
    || warn "Cannot reach ER1"

banner "Exit_Router2 BGP sessions"
chr_cmd "${ER2_IP}" "/routing bgp session print" 2>/dev/null \
    || warn "Cannot reach ER2"

banner "br-BL2-ER2 OVS bridge ports (expect 2)"
sudo ovs-vsctl list-ports br-BL2-ER2 2>/dev/null

# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n${WHT}══════════════════════════════════════════════════════${NC}"
echo -e "${CYN}  Fix script complete.${NC}"
echo -e "${WHT}══════════════════════════════════════════════════════${NC}"
echo -e ""
echo -e "  Expected outcomes:"
echo -e "  ${GRN}✓${NC}  BL1/BL2 Ethernet120/124 → Spine_S1/S2  : Established"
echo -e "  ${GRN}✓${NC}  BL1/BL2 Ethernet20/24/28 → servers      : Established"
echo -e "  ${GRN}✓${NC}  BL1 10.0.253.1 → Exit_Router1           : Established"
echo -e "  ${GRN}✓${NC}  BL2 10.0.253.3 → Exit_Router2           : Established"
echo -e ""
echo -e "  If any sessions are still ${YLW}Active${NC} after ${BGP_WAIT}s:"
echo -e "    • Check interface oper state: ${DIM}show interfaces status${NC}"
echo -e "    • Check IP assignment: ${DIM}show ip interface${NC}"
echo -e "    • Check OVS carrier: ${DIM}sudo ovs-vsctl show | grep -A3 <bridge>${NC}"
echo -e "    • Force BGP restart: ${DIM}sudo systemctl restart bgp${NC} (on SONiC)"
echo -e ""
