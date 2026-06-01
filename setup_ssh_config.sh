#!/usr/bin/env bash
# =============================================================================
# setup_ssh_config.sh  —  Patch ~/.ssh/config for dynamic ProxyJump to lab VMs
# =============================================================================
# Usage:
#   chmod +x setup_ssh_config.sh && ./setup_ssh_config.sh
#
# What it does:
#   1. Adds/updates Host entries for R810 and R620 hypervisors
#   2. Adds dynamic Match blocks so that:
#        AUTOMATION_PROFILE=ubuntu_r620_kvm  → SSH jumps through R620
#        AUTOMATION_PROFILE=ubuntu_r810_kvm  → SSH jumps through R810 (default)
#   3. The same AUTOMATION_PROFILE env var drives Ansible's ProxyJump
#
# After running, set in your .bashrc / .zshrc:
#   export AUTOMATION_PROFILE=ubuntu_r810_kvm   # default
#
# Then:
#   ssh Host12_1          # jumps through R810
#   AUTOMATION_PROFILE=ubuntu_r620_kvm ssh Host12_1   # jumps through R620
#
# Safe to re-run — removes previous managed block before re-inserting.
# =============================================================================

set -euo pipefail

# ─── Configuration ─────────────────────────────────────────────────────────────
SSH_CONFIG="${HOME}/.ssh/config"
MARKER_BEGIN="# >>> MANAGED BY setup_ssh_config.sh — DO NOT EDIT MANUALLY <<<"
MARKER_END="# >>> END MANAGED BLOCK <<<"

R810_IP="${R810_HOST:-192.168.9.198}"
R620_IP="${R620_HOST:-192.168.9.200}"
SSH_USER="${KVM_HYPERVISOR_USER:-nh1221}"
SSH_KEY="${SSH_KEY_PATH:-~/.ssh/id_dc_lab}"

# VM host patterns (must cover all inventory hostnames and IPs)
VM_PATTERNS="172.16.2.*,Spine_*,spine-*,Leaf_*,leaf-*,Host*,Border_*,border_*,MonitorSrv,Exit_Router*,exit_router*"

# ─── Functions ─────────────────────────────────────────────────────────────────
info()  { printf '\033[1;34m[INFO]\033[0m  %s\n' "$1"; }
warn()  { printf '\033[1;33m[WARN]\033[0m  %s\n' "$1"; }
ok()    { printf '\033[1;32m[ OK ]\033[0m  %s\n' "$1"; }

backup_config() {
    if [[ -f "$SSH_CONFIG" ]]; then
        local bak="${SSH_CONFIG}.bak.$(date +%Y%m%d_%H%M%S)"
        cp "$SSH_CONFIG" "$bak"
        info "Backup: $bak"
    fi
}

remove_managed_block() {
    if [[ -f "$SSH_CONFIG" ]] && grep -qF "$MARKER_BEGIN" "$SSH_CONFIG"; then
        warn "Removing previous managed block..."
        sed -i "/${MARKER_BEGIN//\//\\/}/,/${MARKER_END//\//\\/}/d" "$SSH_CONFIG"
    fi
}

generate_block() {
    cat <<EOF
${MARKER_BEGIN}

# ─── Lab Hypervisors ───────────────────────────────────────────────────────────
Host R810
    HostName ${R810_IP}
    User ${SSH_USER}
    IdentityFile ${SSH_KEY}
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host R620 dc-hypervisor
    HostName ${R620_IP}
    User ${SSH_USER}
    IdentityFile ${SSH_KEY}
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

# ─── Lab VMs: dynamic ProxyJump via AUTOMATION_PROFILE ─────────────────────────
# If AUTOMATION_PROFILE=ubuntu_r620_kvm → jump through R620
Match host ${VM_PATTERNS} exec "[ \"\${AUTOMATION_PROFILE:-ubuntu_r810_kvm}\" = 'ubuntu_r620_kvm' ]"
    ProxyJump R620
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ConnectTimeout 30
    ServerAliveInterval 30
    ServerAliveCountMax 3

# Default (AUTOMATION_PROFILE unset or ubuntu_r810_kvm) → jump through R810
Match host ${VM_PATTERNS}
    ProxyJump R810
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ConnectTimeout 30
    ServerAliveInterval 30
    ServerAliveCountMax 3

${MARKER_END}
EOF
}

# ─── Main ──────────────────────────────────────────────────────────────────────
main() {
    info "Setting up dynamic ProxyJump in ${SSH_CONFIG}"

    # Ensure .ssh directory exists with correct permissions
    mkdir -p "$(dirname "$SSH_CONFIG")"
    chmod 700 "$(dirname "$SSH_CONFIG")"

    # Backup existing config
    backup_config

    # Remove any previous managed block
    remove_managed_block

    # Append the new managed block at the TOP of the config
    # (SSH uses first-match, so our Match blocks must come before any
    #  wildcard Host blocks the user may have below)
    local tmp
    tmp=$(mktemp)
    generate_block > "$tmp"

    if [[ -f "$SSH_CONFIG" ]]; then
        echo "" >> "$tmp"
        cat "$SSH_CONFIG" >> "$tmp"
    fi

    mv "$tmp" "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"

    ok "SSH config updated."
    echo ""
    info "Profile-based routing:"
    echo "  export AUTOMATION_PROFILE=ubuntu_r810_kvm  →  VMs via R810 (${R810_IP})"
    echo "  export AUTOMATION_PROFILE=ubuntu_r620_kvm  →  VMs via R620 (${R620_IP})"
    echo ""
    info "Test with:"
    echo "  ssh -v Host12_1 2>&1 | grep -i 'proxy\\|jump'"
    echo ""

    # Remove old-style Host wildcard blocks that conflict
    if grep -qE '^\s*Host.*(172\.16\.2\.\*|Spine_|Leaf_|Host|Border_)' "$SSH_CONFIG" 2>/dev/null; then
        warn "Found existing Host wildcard lines outside the managed block."
        warn "These may conflict. Review and remove any duplicate entries below the managed block."
    fi
}

main "$@"
