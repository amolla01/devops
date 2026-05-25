#!/usr/bin/env bash
# =============================================================================
# fix_v1_bgp_v2.sh  —  _v1 CLOS Fabric Complete BGP Recovery (v2)
# =============================================================================
# Run ON the R620 host:
#   scp fix_v1_bgp_v2.sh nh1221@R620:~/
#   ssh nh1221@R620
#   chmod +x fix_v1_bgp_v2.sh && ./fix_v1_bgp_v2.sh
#
# Fixes over v1:
#   ✦ SSH key (id_dc_lab.pub) injected into MikroTik via virsh serial console
#   ✦ ER2 OVS NIC: virsh destroy+start (not just reboot) so new NIC appears in OVS
#   ✦ MonitorSrv: checked / started if down → br-MS-BL1/BL2 get both ports
#   ✦ Ethernet22 phantom removed from FRR BGP config on BL1/BL2
#   ✦ MikroTik full config: ether2 enable + /31 IP + BGP template + connection
#   ✦ All phases idempotent (safe to re-run)
# =============================================================================

set -uo pipefail

# ─── Config ────────────────────────────────────────────────────────────────────
BL1_IP="172.16.2.31";    BL2_IP="172.16.2.32"
ER1_IP="172.16.2.98";    ER2_IP="172.16.2.99"
SONIC_USER="admin";      SONIC_PASS="amolla01"
CHR_USER="admin"

# Fabric ports that must be admin-up on both border leaves
# (Ethernet22 is intentionally excluded — it doesn't exist on KVM VS)
BL_PORTS="Ethernet20 Ethernet24 Ethernet28 Ethernet120 Ethernet124"

# Exit router /31 point-to-point addressing
ER1_IP_CIDR="10.0.253.1/31";  ER1_ROUTER_ID="10.0.253.1"
ER1_PEER_IP="10.0.253.0";     ER1_PEER_ASN="65021";  ER1_ASN="65253"

ER2_IP_CIDR="10.0.253.3/31";  ER2_ROUTER_ID="10.0.253.3"
ER2_PEER_IP="10.0.253.2";     ER2_PEER_ASN="65022";  ER2_ASN="65254"

BGP_WAIT=35          # seconds to wait for convergence after all fixes

# ─── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'
CYN='\033[0;36m'; WHT='\033[1;37m'; DIM='\033[2m'; NC='\033[0m'

phase() { echo -e "\n${WHT}══════════════════════════════════════════════════${NC}";
          echo -e "${CYN}  $*${NC}";
          echo -e "${WHT}══════════════════════════════════════════════════${NC}"; }
ok()    { echo -e "  ${GRN}✓  $*${NC}"; }
warn()  { echo -e "  ${YLW}△  $*${NC}"; }
err()   { echo -e "  ${RED}✗  $*${NC}"; }
info()  { echo -e "  ${DIM}▸  $*${NC}"; }
hdr()   { echo -e "\n${DIM}─────  $*  ─────${NC}"; }

# ─── SSH helpers ───────────────────────────────────────────────────────────────
sonic_cmd() {
    local host="$1"; shift
    sshpass -p "${SONIC_PASS}" \
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            -o ConnectTimeout=10 -o LogLevel=ERROR \
            "${SONIC_USER}@${host}" "$@" 2>&1
}

chr_ssh() {
    local host="$1"; shift
    ssh -i "${CHR_PRIVKEY}" \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=10 -o LogLevel=ERROR \
        -o IdentitiesOnly=yes \
        "${CHR_USER}@${host}" "$@" 2>&1
}

# ─── Wait for ping helper ──────────────────────────────────────────────────────
wait_ping() {
    local host="$1"; local label="${2:-$1}"; local max=24; local i=0
    while ! ping -c1 -W2 "${host}" &>/dev/null; do
        i=$((i+1))
        [[ $i -ge $max ]] && { warn "${label} unreachable after $((max*5))s"; return 1; }
        info "Waiting for ${label} (${i}/${max})..."
        sleep 5
    done
    ok "${label} (${host}) is reachable"
}

# =============================================================================
phase "Phase 0 — Prerequisites"
# =============================================================================

# sshpass
command -v sshpass &>/dev/null \
    && ok "sshpass present" \
    || { warn "Installing sshpass..."; sudo apt-get install -y -qq sshpass && ok "sshpass installed"; }

# expect (needed for virsh console automation)
command -v expect &>/dev/null \
    && ok "expect present" \
    || { warn "Installing expect..."; sudo apt-get install -y -qq expect && ok "expect installed"; }

# virsh + ovs-vsctl
command -v virsh &>/dev/null     && ok "virsh present"     || { err "virsh not found — run this ON the R620 hypervisor"; exit 1; }
command -v ovs-vsctl &>/dev/null && ok "ovs-vsctl present" || { err "ovs-vsctl not found"; exit 1; }

# ─── Find SSH key ──────────────────────────────────────────────────────────────
CHR_PUBKEY_FILE=""
for candidate in "$HOME/.ssh/id_dc_lab.pub" "$HOME/id_dc_lab.pub"; do
    if [[ -f "$candidate" ]]; then
        CHR_PUBKEY_FILE="$candidate"
        break
    fi
done

[[ -z "${CHR_PUBKEY_FILE}" ]] && { err "id_dc_lab.pub not found in ~/.ssh/ or ~/"; exit 1; }

CHR_PRIVKEY="${CHR_PUBKEY_FILE%.pub}"   # strip .pub  → id_dc_lab
[[ -f "${CHR_PRIVKEY}" ]] && ok "Key pair: ${CHR_PRIVKEY} / ${CHR_PUBKEY_FILE}" \
    || { err "Private key ${CHR_PRIVKEY} not found (need the pair for post-injection SSH)"; exit 1; }

export CHR_PUBKEY
CHR_PUBKEY="$(cat "${CHR_PUBKEY_FILE}")"
info "Public key: ${CHR_PUBKEY:0:60}..."

# Write the reusable expect script to a temp file
EXPECT_SCRIPT=$(mktemp /tmp/ros_configure_XXXXXX.exp)
trap 'rm -f "${EXPECT_SCRIPT}"' EXIT

cat > "${EXPECT_SCRIPT}" << 'EXPECT_EOF'
#!/usr/bin/expect -f
# ─── Args ─────────────────────────────────────────────────────────────────────
# $argv: vm_name er_ip_cidr er_router_id peer_ip peer_asn local_asn peer_name
set vm        [lindex $argv 0]
set er_cidr   [lindex $argv 1]
set routerid  [lindex $argv 2]
set peer_ip   [lindex $argv 3]
set peer_asn  [lindex $argv 4]
set local_asn [lindex $argv 5]
set peername  [lindex $argv 6]
# Public key injected via environment variable CHR_PUBKEY
set pubkey    $env(CHR_PUBKEY)

set timeout 45
log_user 1

# ─── Helper: wait for RouterOS prompt ─────────────────────────────────────────
proc waitprompt {} {
    expect {
        -re {> $}   { return 0 }
        timeout     { send "\r"; exp_continue }
    }
}

# ─── Connect via virsh serial console ─────────────────────────────────────────
spawn sudo virsh console $vm

# Consume the "Connected to domain / Escape character" banner
expect "Escape character"
after 800
send "\r"

# Handle RouterOS login (no password) or direct prompt
expect {
    -re {\] > $}     { }
    -re {[>%\$] $}   { }
    -nocase "login:" {
        send "admin\r"
        expect -nocase "password"
        send "\r"
        waitprompt
    }
    timeout {
        send "\r"
        waitprompt
    }
}

# ── 1. Enable ether2 ──────────────────────────────────────────────────────────
send "/interface enable ether2\r"
waitprompt
send ":put \"[/interface get ether2 disabled] [/interface get ether2 running]\"\r"
waitprompt

# ── 2. Add /31 IP (idempotent) ────────────────────────────────────────────────
send ":if ([/ip address find where address=\"$er_cidr\"] = \"\") do={ /ip address add address=$er_cidr interface=ether2; :put \"IP $er_cidr added\" } else={ :put \"IP $er_cidr already present\" }\r"
waitprompt

# ── 3. Inject SSH public key (idempotent — ignore duplicate error) ─────────────
send ":do { /user ssh-keys add key=\"$pubkey\" user=admin } on-error={ :put \"key already present or ignored\" }\r"
waitprompt

# ── 4. BGP template (create if absent, update if present) ────────────────────
send ":if ([/routing bgp template find where name=default] = \"\") do={ /routing bgp template add name=default as=$local_asn router-id=$routerid; :put \"BGP template created\" } else={ /routing bgp template set [find name=default] as=$local_asn router-id=$routerid; :put \"BGP template updated\" }\r"
waitprompt

# ── 5. BGP connection (idempotent) ────────────────────────────────────────────
send ":if ([/routing bgp connection find where remote.address=$peer_ip] = \"\") do={ /routing bgp connection add name=$peername as=$local_asn remote.address=$peer_ip remote.as=$peer_asn router-id=$routerid local.role=ebgp; :put \"BGP connection to $peername created\" } else={ :put \"BGP connection to $peername already exists\" }\r"
waitprompt

# ── 6. Verify ─────────────────────────────────────────────────────────────────
send "/interface print where name=ether2\r"
waitprompt
send "/ip address print where interface=ether2\r"
waitprompt
send "/user ssh-keys print\r"
waitprompt
send "/routing bgp connection print\r"
waitprompt

# ── Exit console (Ctrl+]) ─────────────────────────────────────────────────────
send "\x1d"
set timeout 5
expect {
    eof     { }
    timeout { }
}
exit 0
EXPECT_EOF

chmod +x "${EXPECT_SCRIPT}"

# =============================================================================
phase "Phase 1 — Pre-flight Diagnostics"
# =============================================================================

hdr "BL1 (${BL1_IP}) — interface oper state"
sonic_cmd "${BL1_IP}" \
    "sudo show interfaces status 2>/dev/null | awk 'NR==1 || /^[[:space:]]*Ethernet(20|24|28|120|124)[[:space:]]/' | head -8" || warn "Cannot reach BL1"

hdr "BL2 (${BL2_IP}) — interface oper state"
sonic_cmd "${BL2_IP}" \
    "sudo show interfaces status 2>/dev/null | awk 'NR==1 || /^[[:space:]]*Ethernet(20|24|28|120|124)[[:space:]]/' | head -8" || warn "Cannot reach BL2"

hdr "BL1 BGP current state (before fixes)"
sonic_cmd "${BL1_IP}" "docker exec bgp vtysh -c 'show bgp summary' 2>/dev/null | tail -15" || true

hdr "OVS br-BL2-ER2 ports (expect 2)"
PORTS_BR_ER2=$(sudo ovs-vsctl list-ports br-BL2-ER2 2>/dev/null | grep -v "^br-BL2-ER2$" || true)
PORT_COUNT_ER2=$(echo "${PORTS_BR_ER2}" | grep -c "vnet" || true)
echo "  Ports: ${PORTS_BR_ER2:-none} (count=${PORT_COUNT_ER2})"

hdr "OVS br-MS-BL1 / br-MS-BL2 ports (expect 2 each)"
sudo ovs-vsctl list-ports br-MS-BL1 2>/dev/null | grep -c "vnet" \
    | xargs -I{} echo "  br-MS-BL1: {} port(s)"
sudo ovs-vsctl list-ports br-MS-BL2 2>/dev/null | grep -c "vnet" \
    | xargs -I{} echo "  br-MS-BL2: {} port(s)"

hdr "Exit_Router1 NIC list"
sudo virsh domiflist Exit_Router1 2>/dev/null || warn "ER1 not found"

hdr "Exit_Router2 NIC list"
sudo virsh domiflist Exit_Router2 2>/dev/null || warn "ER2 not found"

# =============================================================================
phase "Phase 2 — BL1/BL2: Admin-up fabric/server ports (idempotent)"
# =============================================================================
# Ethernet22 is intentionally omitted — it doesn't exist in the KVM VS
# port_config.ini (it was a physical breakout sub-port alias from real hardware).

for BL_NAME in "BL1:${BL1_IP}" "BL2:${BL2_IP}"; do
    BL_LABEL="${BL_NAME%%:*}"; BL_HOST="${BL_NAME##*:}"
    info "Processing ${BL_LABEL} (${BL_HOST})..."
    for IFACE in ${BL_PORTS}; do
        RESULT=$(sonic_cmd "${BL_HOST}" \
            "STATE=\$(sudo show interfaces status ${IFACE} 2>/dev/null | awk '/^[[:space:]]*${IFACE}[[:space:]]/{print \$8}');
             if [[ \"\$STATE\" == \"up\" ]]; then
                 echo \"ALREADY_UP\";
             else
                 sudo config interface startup ${IFACE} 2>&1 && echo \"STARTED\" || echo \"FAILED\";
             fi")
        case "${RESULT}" in
            *ALREADY_UP*) ok "${BL_LABEL} ${IFACE}: already up" ;;
            *STARTED*)    ok "${BL_LABEL} ${IFACE}: brought up" ;;
            *FAILED*)     warn "${BL_LABEL} ${IFACE}: failed — ${RESULT}" ;;
            *)            warn "${BL_LABEL} ${IFACE}: ${RESULT}" ;;
        esac
    done
    sonic_cmd "${BL_HOST}" "sudo config save -y" &>/dev/null && ok "${BL_LABEL} config saved"
done

# =============================================================================
phase "Phase 3 — Remove Ethernet22 phantom from FRR BGP (BL1 + BL2)"
# =============================================================================
# Ethernet22 (physical breakout sub-port alias) does not exist on KVM VS.
# It will always be Idle and adds noise to 'show bgp summary'.

for BL_NAME in "BL1:${BL1_IP}" "BL2:${BL2_IP}"; do
    BL_LABEL="${BL_NAME%%:*}"; BL_HOST="${BL_NAME##*:}"
    RESULT=$(sonic_cmd "${BL_HOST}" \
        "docker exec bgp vtysh \
            -c 'configure terminal' \
            -c 'router bgp' \
            -c 'no neighbor Ethernet22' \
            -c 'end' \
            -c 'write memory' 2>&1")
    if echo "${RESULT}" | grep -qi "error\|unknown"; then
        warn "${BL_LABEL}: Ethernet22 removal — ${RESULT}"
    else
        ok "${BL_LABEL}: Ethernet22 removed from FRR config"
    fi
done

# =============================================================================
phase "Phase 4 — Fix br-BL2-ER2: Hard destroy+start Exit_Router2"
# =============================================================================
# 'virsh reboot' keeps the QEMU process running — new NIC XML only takes effect
# when the domain is stopped (destroy) and freshly started.

ER2_BRIDGE_PORTS=$(sudo ovs-vsctl list-ports br-BL2-ER2 2>/dev/null \
    | grep -c "vnet" || echo "0")

if [[ "${ER2_BRIDGE_PORTS}" -ge 2 ]]; then
    ok "br-BL2-ER2 already has ${ER2_BRIDGE_PORTS} ports — skipping ER2 restart"
else
    warn "br-BL2-ER2 has only ${ER2_BRIDGE_PORTS} port(s) — hard restarting Exit_Router2"

    ER2_STATE=$(sudo virsh domstate Exit_Router2 2>/dev/null || echo "not-found")
    info "Exit_Router2 state: ${ER2_STATE}"

    if [[ "${ER2_STATE}" == "not-found" ]]; then
        err "Exit_Router2 VM not found — cannot fix"
    else
        if [[ "${ER2_STATE}" == "running" ]]; then
            info "Destroying Exit_Router2..."
            sudo virsh destroy Exit_Router2 2>&1 && ok "Exit_Router2 destroyed (hard stop)"
            sleep 3
        fi

        info "Starting Exit_Router2..."
        sudo virsh start Exit_Router2 2>&1 && ok "Exit_Router2 started"

        info "Waiting 10s for OVS to register new NIC..."
        sleep 10

        NEW_COUNT=$(sudo ovs-vsctl list-ports br-BL2-ER2 2>/dev/null \
            | grep -c "vnet" || echo "0")
        if [[ "${NEW_COUNT}" -ge 2 ]]; then
            ok "br-BL2-ER2 now has ${NEW_COUNT} ports: $(sudo ovs-vsctl list-ports br-BL2-ER2 | tr '\n' ' ')"
        else
            warn "br-BL2-ER2 still shows only ${NEW_COUNT} port(s) after start"
            info "Current ports: $(sudo ovs-vsctl list-ports br-BL2-ER2 2>/dev/null | tr '\n' ' ')"
            info "Verify with: sudo virsh domiflist Exit_Router2"
        fi
    fi
fi

# =============================================================================
phase "Phase 5 — Fix MonitorSrv: Ensure VM is running (br-MS-BL1/BL2)"
# =============================================================================

MS_STATE=$(sudo virsh domstate MonitorSrv 2>/dev/null || echo "not-found")
info "MonitorSrv state: ${MS_STATE}"

if [[ "${MS_STATE}" == "not-found" ]]; then
    warn "MonitorSrv VM not found in libvirt — skipping"
elif [[ "${MS_STATE}" == "running" ]]; then
    MS_PORTS_BL1=$(sudo ovs-vsctl list-ports br-MS-BL1 2>/dev/null | grep -c "vnet" || echo "0")
    MS_PORTS_BL2=$(sudo ovs-vsctl list-ports br-MS-BL2 2>/dev/null | grep -c "vnet" || echo "0")

    if [[ "${MS_PORTS_BL1}" -ge 2 && "${MS_PORTS_BL2}" -ge 2 ]]; then
        ok "MonitorSrv running and both OVS bridges have 2 ports — no action needed"
    else
        warn "MonitorSrv running but bridges are incomplete (br-MS-BL1=${MS_PORTS_BL1}, br-MS-BL2=${MS_PORTS_BL2})"
        info "Hard-restarting MonitorSrv to re-bind NICs to OVS..."
        sudo virsh destroy MonitorSrv 2>&1 && sleep 3
        sudo virsh start  MonitorSrv 2>&1 && ok "MonitorSrv restarted"
        sleep 8
        MS_NEW_1=$(sudo ovs-vsctl list-ports br-MS-BL1 2>/dev/null | grep -c "vnet" || echo "0")
        MS_NEW_2=$(sudo ovs-vsctl list-ports br-MS-BL2 2>/dev/null | grep -c "vnet" || echo "0")
        ok "br-MS-BL1: ${MS_NEW_1} port(s), br-MS-BL2: ${MS_NEW_2} port(s)"
    fi
elif [[ "${MS_STATE}" == "shut off" ]]; then
    info "Starting MonitorSrv..."
    sudo virsh start MonitorSrv 2>&1 && ok "MonitorSrv started"
    sleep 8
    ok "br-MS-BL1: $(sudo ovs-vsctl list-ports br-MS-BL1 2>/dev/null | grep -c "vnet" || echo 0) port(s)"
    ok "br-MS-BL2: $(sudo ovs-vsctl list-ports br-MS-BL2 2>/dev/null | grep -c "vnet" || echo 0) port(s)"
fi

# =============================================================================
phase "Phase 6 — Exit_Router1: SSH key inject + ether2 + BGP (virsh console)"
# =============================================================================

info "Configuring Exit_Router1 (${ER1_IP}) via virsh serial console..."
info "Key: ${CHR_PUBKEY_FILE}"
echo ""

expect "${EXPECT_SCRIPT}" \
    "Exit_Router1" \
    "${ER1_IP_CIDR}" \
    "${ER1_ROUTER_ID}" \
    "${ER1_PEER_IP}" \
    "${ER1_PEER_ASN}" \
    "${ER1_ASN}" \
    "to-BL1"

ER1_EXPECT_RC=$?
echo ""

if [[ "${ER1_EXPECT_RC}" -eq 0 ]]; then
    ok "Exit_Router1 console session completed"
    info "Testing SSH key auth to ER1..."
    sleep 3
    if chr_ssh "${ER1_IP}" ":put ok" 2>/dev/null | grep -q "ok"; then
        ok "SSH key auth works for Exit_Router1"
    else
        warn "SSH key auth not yet working — ER1 BGP config was applied via console"
    fi
else
    warn "virsh console session for ER1 had non-zero exit — check output above"
    info "Manual fallback: sudo virsh console Exit_Router1"
    info "  /interface enable ether2"
    info "  /ip address add address=${ER1_IP_CIDR} interface=ether2"
    info "  /routing bgp template set [find name=default] as=${ER1_ASN} router-id=${ER1_ROUTER_ID}"
    info "  /routing bgp connection add name=to-BL1 as=${ER1_ASN} remote.address=${ER1_PEER_IP} remote.as=${ER1_PEER_ASN} router-id=${ER1_ROUTER_ID} local.role=ebgp"
fi

# =============================================================================
phase "Phase 7 — Exit_Router2: SSH key inject + ether2 + BGP (virsh console)"
# =============================================================================
# ER2 just had a hard restart (Phase 4) — wait for it to boot fully

info "Waiting for Exit_Router2 (${ER2_IP}) to be reachable..."
wait_ping "${ER2_IP}" "Exit_Router2" || true   # non-fatal, console works regardless
echo ""

info "Configuring Exit_Router2 (${ER2_IP}) via virsh serial console..."
echo ""

expect "${EXPECT_SCRIPT}" \
    "Exit_Router2" \
    "${ER2_IP_CIDR}" \
    "${ER2_ROUTER_ID}" \
    "${ER2_PEER_IP}" \
    "${ER2_PEER_ASN}" \
    "${ER2_ASN}" \
    "to-BL2"

ER2_EXPECT_RC=$?
echo ""

if [[ "${ER2_EXPECT_RC}" -eq 0 ]]; then
    ok "Exit_Router2 console session completed"
    info "Testing SSH key auth to ER2..."
    sleep 3
    if chr_ssh "${ER2_IP}" ":put ok" 2>/dev/null | grep -q "ok"; then
        ok "SSH key auth works for Exit_Router2"
    else
        warn "SSH key auth not yet working — ER2 BGP config was applied via console"
    fi
else
    warn "virsh console session for ER2 had non-zero exit — check output above"
    info "Manual fallback: sudo virsh console Exit_Router2"
    info "  /interface enable ether2"
    info "  /ip address add address=${ER2_IP_CIDR} interface=ether2"
    info "  /routing bgp template set [find name=default] as=${ER2_ASN} router-id=${ER2_ROUTER_ID}"
    info "  /routing bgp connection add name=to-BL2 as=${ER2_ASN} remote.address=${ER2_PEER_IP} remote.as=${ER2_PEER_ASN} router-id=${ER2_ROUTER_ID} local.role=ebgp"
fi

# =============================================================================
phase "Phase 8 — Waiting ${BGP_WAIT}s for BGP to converge..."
# =============================================================================
echo ""
for i in $(seq "${BGP_WAIT}" -5 5); do
    printf "\r  ${CYN}▸  T-%-3ds remaining...${NC}" "${i}"
    sleep 5
done
echo ""
echo ""

# =============================================================================
phase "Phase 9 — Final Verification"
# =============================================================================

hdr "BL1 interface oper state (Ethernet20/24/28/120/124)"
sonic_cmd "${BL1_IP}" \
    "sudo show interfaces status 2>/dev/null | awk '/^[[:space:]]*Ethernet(20|24|28|120|124)[[:space:]]/{print}'" \
    || warn "Cannot reach BL1"

hdr "BL2 interface oper state"
sonic_cmd "${BL2_IP}" \
    "sudo show interfaces status 2>/dev/null | awk '/^[[:space:]]*Ethernet(20|24|28|120|124)[[:space:]]/{print}'" \
    || warn "Cannot reach BL2"

hdr "BL1 BGP summary (IPv4)"
sonic_cmd "${BL1_IP}" \
    "docker exec bgp vtysh -c 'show bgp ipv4 unicast summary' 2>/dev/null" \
    || warn "Cannot reach BL1"

hdr "BL2 BGP summary (IPv4)"
sonic_cmd "${BL2_IP}" \
    "docker exec bgp vtysh -c 'show bgp ipv4 unicast summary' 2>/dev/null" \
    || warn "Cannot reach BL2"

hdr "Exit_Router1 BGP sessions (via SSH key)"
chr_ssh "${ER1_IP}" "/routing bgp session print" 2>/dev/null \
    || warn "ER1 SSH key auth not yet ready — check manually"

hdr "Exit_Router2 BGP sessions (via SSH key)"
chr_ssh "${ER2_IP}" "/routing bgp session print" 2>/dev/null \
    || warn "ER2 SSH key auth not yet ready — check manually"

hdr "OVS bridge port counts"
for BR in br-BL1-ER1 br-BL2-ER2 br-MS-BL1 br-MS-BL2; do
    CNT=$(sudo ovs-vsctl list-ports "${BR}" 2>/dev/null | grep -c "vnet" || echo "0")
    [[ "${CNT}" -ge 2 ]] \
        && ok "${BR}: ${CNT} ports" \
        || warn "${BR}: only ${CNT} port(s)"
done

# =============================================================================
echo -e "\n${WHT}══════════════════════════════════════════════════${NC}"
echo -e "${CYN}  Script complete.${NC}"
echo -e "${WHT}══════════════════════════════════════════════════${NC}"
cat << 'SUMMARY'

  Target BGP state after all fixes:
  ──────────────────────────────────────────────────────────
  BL1  Ethernet120  → Spine_S2   : Established  (was: ✓)
  BL1  Ethernet124  → Spine_S1   : Established  (was: ✓)
  BL1  Ethernet20   → HostB12_1  : Established  (was: Connect)
  BL1  Ethernet24   → HostB12_2  : Established  (was: OpenSent)
  BL1  Ethernet28   → MonitorSrv : Established  (Phase 5 fix)
  BL1  10.0.253.1   → Exit_Router1: Established (Phase 6 fix)

  BL2  Ethernet120  → Spine_S2   : Established  (was: ✓)
  BL2  Ethernet124  → Spine_S1   : Established  (was: ✓)
  BL2  Ethernet20   → HostB12_1  : Established  (was: ✓)
  BL2  Ethernet24   → HostB12_2  : Established  (was: Connect)
  BL2  Ethernet28   → MonitorSrv : Established  (Phase 5 fix)
  BL2  10.0.253.3   → Exit_Router2: Established (Phase 7 fix)

  Ethernet22 (phantom) removed from FRR on both BL1/BL2.

  If MikroTik SSH key auth is working, you can now use:
    ssh -i ~/.ssh/id_dc_lab admin@172.16.2.98
    ssh -i ~/.ssh/id_dc_lab admin@172.16.2.99

  If any session is still not Established, run:
    sudo virsh console Exit_Router1   (Ctrl+] to exit)
    sudo virsh console Exit_Router2
SUMMARY
