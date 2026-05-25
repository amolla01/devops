#!/usr/bin/env bash
# =============================================================================
# push_key_to_r810.sh  —  Bootstrap passwordless SSH: WSL → R810 → all 18 VMs
# =============================================================================
# Run from WSL laptop:
#   chmod +x push_key_to_r810.sh && ./push_key_to_r810.sh
#
# PHASE 1 — WSL → R810:
#   Copies id_dc_lab.pub to R810 authorized_keys  (WSL→R810 passwordless)
#   Copies id_dc_lab keypair to R810 ~/.ssh/       (R810→VMs passwordless)
#
# PHASE 2 — R810 → all 18 _v2 topology VMs:
#   SONiC switches   (×8)  admin/amolla01  172.16.2.11-12, 21-24, 31-32
#   Ubuntu servers   (×8)  ubuntu/ubuntu   172.16.2.40-47
#   MikroTik CHR     (×2)  admin/""        172.16.2.98-99
#     └─ MikroTik key injection via virsh serial console (RouterOS /user ssh-keys)
#
# Result: id_dc_lab authorised on every node — no more passwords anywhere.
# =============================================================================

set -uo pipefail

# ─── Config ────────────────────────────────────────────────────────────────────
R810_IP="192.168.9.198"
R810_USER="nh1221"
R810_PASS="amolla01"
KEY_NAME="id_dc_lab"
SSH_DIR="${HOME}/.ssh"

# ─── VM inventory ──────────────────────────────────────────────────────────────
SONIC_HOSTS=(172.16.2.11 172.16.2.12       # Spine_S1, Spine_S2
             172.16.2.21 172.16.2.22       # Leaf_L1, Leaf_L2
             172.16.2.23 172.16.2.24       # Leaf_L3, Leaf_L4
             172.16.2.31 172.16.2.32)      # Border_Leaf1, Border_Leaf2
SONIC_USER="admin";  SONIC_PASS="amolla01"

UBUNTU_HOSTS=(172.16.2.40 172.16.2.41 172.16.2.42   # Host12_1/2/3
              172.16.2.43 172.16.2.44                # Host34_1/2
              172.16.2.45 172.16.2.46 172.16.2.47)   # HostB12_1/2, MonitorSrv
UBUNTU_USER="ubuntu"; UBUNTU_PASS="ubuntu"

# MikroTik: "IP:VmName" pairs (VM name needed for virsh console fallback)
MIKROTIK_VMS=("172.16.2.98:Exit_Router1"
              "172.16.2.99:Exit_Router2")
MIKROTIK_USER="admin"

# ─── Colours ───────────────────────────────────────────────────────────────────
GRN='\033[0;32m'; YLW='\033[1;33m'; RED='\033[0;31m'
CYN='\033[0;36m'; WHT='\033[1;37m'; DIM='\033[2m'; NC='\033[0m'
phase() { echo -e "\n${WHT}══════════════════════════════════════════════════${NC}";
          echo -e "${CYN}  $*${NC}";
          echo -e "${WHT}══════════════════════════════════════════════════${NC}"; }
ok()    { echo -e "  ${GRN}✓  $*${NC}"; }
warn()  { echo -e "  ${YLW}△  $*${NC}"; }
err()   { echo -e "  ${RED}✗  $*${NC}"; exit 1; }
info()  { echo -e "  ${DIM}▸  $*${NC}"; }

# ─── SSH option sets ───────────────────────────────────────────────────────────
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=10"
R810_SSH="sshpass -p ${R810_PASS} ssh ${SSH_OPTS} ${R810_USER}@${R810_IP}"
R810_SCP="sshpass -p ${R810_PASS} scp ${SSH_OPTS}"
R810_KEY_SSH="ssh ${SSH_OPTS} -i ${SSH_DIR}/${KEY_NAME} -o IdentitiesOnly=yes ${R810_USER}@${R810_IP}"

# =============================================================================
phase "Phase 1 — WSL → R810 (${R810_IP})"
# =============================================================================

# ── 1a. Verify key pair on WSL ────────────────────────────────────────────────
[[ -f "${SSH_DIR}/${KEY_NAME}" ]]     || err "Private key ${SSH_DIR}/${KEY_NAME} not found"
[[ -f "${SSH_DIR}/${KEY_NAME}.pub" ]] || err "Public key ${SSH_DIR}/${KEY_NAME}.pub not found"
ok "Key pair found: ${SSH_DIR}/${KEY_NAME}(.pub)"

# ── 1b. Ensure sshpass ────────────────────────────────────────────────────────
command -v sshpass &>/dev/null \
    && ok "sshpass present" \
    || { warn "Installing sshpass..."; sudo apt-get install -y -qq sshpass && ok "sshpass installed"; }

# ── 1c. Authorise key on R810 ─────────────────────────────────────────────────
info "Adding id_dc_lab.pub to R810 authorized_keys..."
PUBKEY_CONTENT="$(cat "${SSH_DIR}/${KEY_NAME}.pub")"
RESULT=$(${R810_SSH} "
    mkdir -p ~/.ssh && chmod 700 ~/.ssh
    if ! grep -qF '${PUBKEY_CONTENT}' ~/.ssh/authorized_keys 2>/dev/null; then
        printf '%s\n' '${PUBKEY_CONTENT}' >> ~/.ssh/authorized_keys
        echo ADDED
    else
        echo EXISTS
    fi
    chmod 600 ~/.ssh/authorized_keys")
[[ "${RESULT}" == *ADDED* ]] && ok "Public key added to R810 authorized_keys" \
                              || ok "Public key already in R810 authorized_keys"

# ── 1d. Copy keypair to R810 ~/.ssh/ ──────────────────────────────────────────
info "Copying keypair to R810 ~/.ssh/ ..."
${R810_SCP} "${SSH_DIR}/${KEY_NAME}"     "${R810_USER}@${R810_IP}:~/.ssh/${KEY_NAME}"
${R810_SCP} "${SSH_DIR}/${KEY_NAME}.pub" "${R810_USER}@${R810_IP}:~/.ssh/${KEY_NAME}.pub"
${R810_SSH} "chmod 600 ~/.ssh/${KEY_NAME}; chmod 644 ~/.ssh/${KEY_NAME}.pub"
ok "Keypair on R810: ~/.ssh/${KEY_NAME}(.pub) — perms 0600/0644"

# ── 1e. Smoke-test passwordless login ─────────────────────────────────────────
TEST=$(${R810_KEY_SSH} "echo OK" 2>&1)
[[ "${TEST}" == "OK" ]] \
    && ok "Passwordless SSH WSL → R810 confirmed" \
    || warn "Passwordless test returned: ${TEST} (continuing anyway)"

# =============================================================================
phase "Phase 2 — R810 → All 18 Topology VMs"
# =============================================================================
# Everything below executes ON R810 via a single SSH heredoc.
# R810 has virsh/ovs — used for MikroTik serial console fallback.

info "Connecting to R810 to distribute key to all VMs..."

${R810_KEY_SSH} bash << REMOTE
set +e   # non-fatal per-host errors

KEY_NAME="${KEY_NAME}"
PUBKEY="\$(cat ~/.ssh/\${KEY_NAME}.pub)"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=10"

GRN='\033[0;32m'; YLW='\033[1;33m'; DIM='\033[2m'; NC='\033[0m'
ok()   { echo -e "  \${GRN}✓  \$*\${NC}"; }
warn() { echo -e "  \${YLW}△  \$*\${NC}"; }
info() { echo -e "  \${DIM}▸  \$*\${NC}"; }

# ── Helper: copy key to a Linux host via sshpass ──────────────────────────────
push_linux_key() {
    local user="\$1" pass="\$2" host="\$3" label="\$4"
    local RESULT
    RESULT=\$(sshpass -p "\${pass}" ssh \${SSH_OPTS} "\${user}@\${host}" "
        mkdir -p ~/.ssh && chmod 700 ~/.ssh
        if ! grep -qF '\${PUBKEY}' ~/.ssh/authorized_keys 2>/dev/null; then
            printf '%s\n' '\${PUBKEY}' >> ~/.ssh/authorized_keys
            chmod 600 ~/.ssh/authorized_keys
            echo ADDED
        else
            echo EXISTS
        fi" 2>&1)
    if echo "\${RESULT}" | grep -q "ADDED";  then ok "\${label} (\${host}): key added"
    elif echo "\${RESULT}" | grep -q "EXISTS"; then ok "\${label} (\${host}): key already present"
    else warn "\${label} (\${host}): \${RESULT}"; fi
}

# ── Helper: inject key into MikroTik via virsh serial console ─────────────────
push_mikrotik_key() {
    local host="\$1" vm_name="\$2"
    # First try: empty-password SSH directly (RouterOS allows it if no password set)
    local ROS_RESULT
    ROS_RESULT=\$(sshpass -p "" ssh \${SSH_OPTS} \
        -o PreferredAuthentications=password \
        "\${MIKROTIK_USER}@\${host}" \
        ":do { /user ssh-keys add key=\"\${PUBKEY}\" user=admin } on-error={ :put EXISTS }" 2>&1)

    if echo "\${ROS_RESULT}" | grep -qiE "EXISTS|done|added"; then
        ok "MikroTik \${vm_name} (\${host}): key injected via SSH"
        return
    fi

    # Fallback: virsh serial console + expect
    if ! command -v expect &>/dev/null; then
        warn "MikroTik \${vm_name}: SSH failed and expect not installed — run: sudo apt-get install -y expect"
        return
    fi

    info "MikroTik \${vm_name} (\${host}): SSH auth failed — using virsh console..."
    local EXP_SCRIPT=\$(mktemp /tmp/ros_key_XXXXXX.exp)

    cat > "\${EXP_SCRIPT}" << 'EXPECT_EOF'
#!/usr/bin/expect -f
set vm     [lindex \$argv 0]
set pubkey \$env(ROS_PUBKEY)
set timeout 30
log_user 1

proc waitprompt {} {
    expect {
        -re {> \$} { return }
        timeout    { send "\r"; exp_continue }
    }
}

spawn sudo virsh console \$vm
expect "Escape character"
after 800
send "\r"
expect {
    -re {> \$}      { }
    -nocase "login" { send "admin\r"; expect -nocase "password"; send "\r"; waitprompt }
    timeout         { send "\r"; waitprompt }
}

send ":do { /user ssh-keys add key=\"\$pubkey\" user=admin } on-error={ :put \"key exists or error\" }\r"
waitprompt
send ":put done\r"
waitprompt
send "\x1d"
set timeout 5
expect { eof {} timeout {} }
exit 0
EXPECT_EOF

    chmod +x "\${EXP_SCRIPT}"
    export ROS_PUBKEY="\${PUBKEY}"
    expect "\${EXP_SCRIPT}" "\${vm_name}"
    local RC=\$?
    rm -f "\${EXP_SCRIPT}"
    [[ \$RC -eq 0 ]] && ok "MikroTik \${vm_name} (\${host}): key injected via virsh console" \
                      || warn "MikroTik \${vm_name} (\${host}): virsh console returned RC=\${RC}"
}

export MIKROTIK_USER="${MIKROTIK_USER}"

# ──────────────────────────────────────────────────────────────────────────────
echo -e "\n\${DIM}─────  SONiC Switches (admin/amolla01)  ─────\${NC}"
SONIC_HOSTS=(${SONIC_HOSTS[*]})
for H in "\${SONIC_HOSTS[@]}"; do
    push_linux_key "${SONIC_USER}" "${SONIC_PASS}" "\${H}" "SONiC"
done

echo -e "\n\${DIM}─────  Ubuntu Servers (ubuntu/ubuntu)  ─────\${NC}"
UBUNTU_HOSTS=(${UBUNTU_HOSTS[*]})
for H in "\${UBUNTU_HOSTS[@]}"; do
    push_linux_key "${UBUNTU_USER}" "${UBUNTU_PASS}" "\${H}" "Ubuntu"
done

echo -e "\n\${DIM}─────  MikroTik CHR (admin / virsh console)  ─────\${NC}"
MIKROTIK_VMS=(${MIKROTIK_VMS[*]})
for ENTRY in "\${MIKROTIK_VMS[@]}"; do
    MK_IP="\${ENTRY%%:*}"
    MK_VM="\${ENTRY##*:}"
    push_mikrotik_key "\${MK_IP}" "\${MK_VM}"
done

REMOTE

# =============================================================================
phase "Phase 3 — Smoke-test: WSL → R810 → VM key-based SSH"
# =============================================================================
info "Spot-checking a sample of VMs via ProxyJump (key only, no password)..."

check_key_auth() {
    local user="$1" host="$2" label="$3"
    local RESULT
    RESULT=$(ssh ${SSH_OPTS} \
        -i "${SSH_DIR}/${KEY_NAME}" -o IdentitiesOnly=yes \
        -J "${R810_USER}@${R810_IP}" \
        "${user}@${host}" "echo OK" 2>&1)
    [[ "${RESULT}" == "OK" ]] \
        && ok "${label} (${host}): key-only login works" \
        || warn "${label} (${host}): ${RESULT}"
}

check_key_auth "${SONIC_USER}"  "172.16.2.11" "Spine_S1"
check_key_auth "${SONIC_USER}"  "172.16.2.31" "Border_Leaf1"
check_key_auth "${UBUNTU_USER}" "172.16.2.40" "Host12_1"
check_key_auth "${UBUNTU_USER}" "172.16.2.47" "MonitorSrv"

echo -e "\n${WHT}══════════════════════════════════════════════════${NC}"
echo -e "${GRN}  All done.  Passwordless SSH matrix:${NC}"
echo -e "${WHT}══════════════════════════════════════════════════${NC}"
cat << 'SUMMARY'

  WSL  → R810              ssh -i ~/.ssh/id_dc_lab nh1221@192.168.9.198
  WSL  → any VM (via R810) ssh -i ~/.ssh/id_dc_lab -J nh1221@192.168.9.198 admin@172.16.2.11
  R810 → SONiC switches    ssh -i ~/.ssh/id_dc_lab admin@172.16.2.{11,12,21-24,31,32}
  R810 → Ubuntu servers    ssh -i ~/.ssh/id_dc_lab ubuntu@172.16.2.{40-47}
  R810 → MikroTik CHR      ssh -i ~/.ssh/id_dc_lab admin@172.16.2.{98,99}

SUMMARY
