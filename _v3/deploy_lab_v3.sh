#!/usr/bin/env bash
set -euo pipefail

# _v3 lab orchestrator for initial QEMU/KVM setup + day0 onward service deployment.
# This wrapper uses the vendored _v3/deploy_lab_v13.sh snapshot for KVM topology
# lifecycle, then uses _v3 inventory/playbooks for hardened architecture operations.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
V13_SCRIPT="$SCRIPT_DIR/deploy_lab_v13.sh"
INV_FILE="$SCRIPT_DIR/inventory/hosts.yml"

PROFILE="${AUTOMATION_PROFILE:-ubuntu_r620_kvm}"
PROXY_FLAGS=()
EXTRA_ANSIBLE_ARGS=()
SSH_OPTS=()
PREFLIGHT_DONE=false
ACTION_ARGS=()
ALLOW_PASSWORD_AUTH="${ALLOW_PASSWORD_AUTH:-false}"

# Optional remote execution for deploy_lab_v13.sh (recommended when laptop is controller
# and R620/R810 are hypervisors running libvirt/qemu-kvm).
REMOTE_V13_HOST="${REMOTE_V13_HOST:-}"
REMOTE_V13_USER="${REMOTE_V13_USER:-${USER:-$(whoami)}}"
REMOTE_V13_PATH="${REMOTE_V13_PATH:-}"  # Empty = auto-detect (~/deploy_lab_v13.sh on remote)
REMOTE_V13_PATH_EXPLICIT=false          # Track if user provided --remote-v13-path

# Laptop -> hypervisor connectivity preflight parameters.
SSH_KEY_PATH="${SSH_KEY_PATH:-}"
PROXY_JUMP_HOST="${PROXY_JUMP_HOST:-}"
R620_HOST="${R620_HOST:-}"
R810_HOST="${R810_HOST:-}"
R620_V13_PATH="${R620_V13_PATH:-$REMOTE_V13_PATH}"
R810_V13_PATH="${R810_V13_PATH:-$REMOTE_V13_PATH}"

# Phased deployment defaults.
R620_LIMIT="${R620_LIMIT:-Spine_S1,Spine_S2,Leaf_L1,Leaf_L2,Border_Leaf1,Border_Leaf2,Exit_Router1,Exit_Router2,Host12_1,Host12_2,Host12_3,HostB12_1,HostB12_2,MonitorSrv}"
R810_LIMIT="${R810_LIMIT:-Leaf_L3,Leaf_L4,Host34_1,Host34_2}"

log() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; }
err() { printf '[FAIL] %s\n' "$*" >&2; }

die() {
  err "$*"
  exit 1
}

usage() {
  cat <<'EOF'
Usage: deploy_lab_v3.sh [options] <action>

Options:
  --profile <name>        Automation profile: win11_kvm|ubuntu_r620_kvm|ubuntu_r810_kvm|real_hardware
  --no-proxy              Pass --no-proxy to deploy_lab_v13.sh
  --proxy                 Pass --proxy to deploy_lab_v13.sh
  --proxy-url <url>       Pass custom proxy URL to deploy_lab_v13.sh
  --remote-v13-host <h>   Run deploy_lab_v13.sh on remote host (for laptop controller mode)
  --remote-v13-user <u>   SSH user for --remote-v13-host (default: current user)
  --remote-v13-path <p>   Path to deploy_lab_v13.sh on remote host
  --ssh-key <path>        SSH key path for laptop -> hypervisor auth checks
  --allow-password        Allow password-based SSH (prompts during operations)
  --proxy-jump-host <h>   SSH ProxyJump host for laptop -> hypervisor access
  --r620-host <h>         R620 SSH target for preflight (host or user@host)
  --r810-host <h>         R810 SSH target for preflight (host or user@host)
  --r620-limit <csv>      Host limit string for R620-first phase
  --r810-limit <csv>      Host limit string for R810-expansion phase
  --ansible-arg <arg>     Extra ansible-playbook argument (repeatable)

Actions:
  preflight               Verify laptop -> R620/R810 SSH/ProxyJump/key auth
  kvm-deploy              Initial KVM topology deployment using deploy_lab_v13.sh
  kvm-deploy-r620         Remote deploy on R620 (laptop-driven)
  kvm-deploy-r810         Remote deploy on R810 (laptop-driven)
  kvm-deploy-both         Remote deploy on R620 then R810
  kvm-redeploy            Force redeploy KVM topology using deploy_lab_v13.sh
  kvm-destroy             Destroy KVM topology using deploy_lab_v13.sh
  kvm-validate            Validate VM SSH/connectivity using deploy_lab_v13.sh
  remote-status           Show virsh list on R620 and R810 from laptop
  remote-virsh <h> <cmd>  Run virsh command remotely. h=r620|r810
  day0                    Run day-0 base provisioning
  day1                    Run day-1 fabric wiring
  infra-services          Run kubespray + postgresql + maas + ceph + openstack + monitoring
  phase-r620              R620-first phased deployment with predefined host limits
  phase-r810              R810 expansion phased deployment with predefined host limits
  phased-full             Run phase-r620 then phase-r810
  gateway                 Run _v3 gateway deployment
  premium-fw              Run _v3 premium firewall deployment
  full                    KVM deploy + full environment deploy
  teardown                Full environment teardown (guarded)
  status                  Show VM status from deploy_lab_v13.sh

Examples:
  ./deploy_lab_v3.sh --proxy-jump-host jump.example --ssh-key ~/.ssh/id_r620 --r620-host admin@10.1.1.20 --r810-host admin@10.1.1.21 preflight
  ./deploy_lab_v3.sh --remote-v13-host admin@10.1.1.20 --profile ubuntu_r620_kvm kvm-deploy
  ./deploy_lab_v3.sh --r620-host admin@10.1.1.20 kvm-deploy-r620
  ./deploy_lab_v3.sh --r810-host admin@10.1.1.21 kvm-deploy-r810
  ./deploy_lab_v3.sh --r620-host admin@10.1.1.20 --r810-host admin@10.1.1.21 kvm-deploy-both
  ./deploy_lab_v3.sh --r620-host admin@10.1.1.20 remote-virsh r620 start Spine_S1
  ./deploy_lab_v3.sh phase-r620
  ./deploy_lab_v3.sh phase-r810
  ./deploy_lab_v3.sh --profile ubuntu_r620_kvm kvm-deploy
  ./deploy_lab_v3.sh --profile ubuntu_r620_kvm full
  ./deploy_lab_v3.sh teardown --ansible-arg=-e --ansible-arg=allow_destructive_teardown=true --ansible-arg=-e --ansible-arg=teardown_confirmation_token=YES-TEARDOWN-ALL
EOF
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

build_ssh_opts() {
  SSH_OPTS=(
    -o ConnectTimeout=12
    -o StrictHostKeyChecking=no
    -o UserKnownHostsFile=/dev/null
  )

  # BatchMode=yes disables password prompts (key-only auth).
  # Skip it when --allow-password is set or no SSH key is configured.
  if [[ "${ALLOW_PASSWORD_AUTH:-false}" != "true" && -n "$SSH_KEY_PATH" ]]; then
    SSH_OPTS+=( -o BatchMode=yes )
  fi

  if [[ -n "$SSH_KEY_PATH" ]]; then
    SSH_OPTS+=( -i "$SSH_KEY_PATH" )
  fi

  if [[ -n "$PROXY_JUMP_HOST" ]]; then
    SSH_OPTS+=( -J "$PROXY_JUMP_HOST" )
  fi
}

normalize_target() {
  local target="$1"
  if [[ -z "$target" ]]; then
    echo ""
  elif [[ "$target" == *"@"* ]]; then
    echo "$target"
  else
    echo "$REMOTE_V13_USER@$target"
  fi
}

check_ssh_target() {
  local label="$1"
  local target="$2"
  [[ -n "$target" ]] || return 0

  # First try BatchMode (key auth, non-interactive)
  log "Preflight: checking SSH connectivity to $label ($target)"
  if ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
       ${SSH_KEY_PATH:+-i "$SSH_KEY_PATH"} ${PROXY_JUMP_HOST:+-J "$PROXY_JUMP_HOST"} \
       "$target" "echo ok" >/dev/null 2>&1; then
    log "Preflight: $label — key-based auth OK"
    return 0
  fi

  # Key auth failed — offer password fallback
  if [[ "${ALLOW_PASSWORD_AUTH:-false}" == "true" ]]; then
    warn "Key-based auth failed for $label ($target). Password auth allowed (--allow-password)."
    warn "You will be prompted for a password during remote operations."
    # Verify connectivity with password prompt
    ssh -o ConnectTimeout=8 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        ${PROXY_JUMP_HOST:+-J "$PROXY_JUMP_HOST"} \
        "$target" "echo ok" >/dev/null 2>&1 || \
      die "Preflight failed for $label ($target). Cannot connect even with password."
    return 0
  fi

  # No key, no --allow-password
  err "Preflight failed for $label ($target). Key-based SSH auth not working."
  err ""
  err "Options to fix:"
  err "  1. Set up SSH key:  ssh-copy-id $target"
  err "  2. Specify key:     --ssh-key ~/.ssh/id_ed25519"
  err "  3. Allow password:  --allow-password  (will prompt during operations)"
  err "  4. SSH in manually: ssh $target, then run deploy_lab_v13.sh directly"
  die "Aborting preflight."
}

preflight_access() {
  need_cmd ssh
  build_ssh_opts

  local r620_target
  local r810_target
  r620_target="$(normalize_target "$R620_HOST")"
  r810_target="$(normalize_target "$R810_HOST")"

  if [[ -z "$r620_target" && -z "$r810_target" && -z "$REMOTE_V13_HOST" ]]; then
    warn "No explicit hypervisor targets provided for preflight (--r620-host/--r810-host/--remote-v13-host)."
    warn "Skipping SSH preflight checks."
    PREFLIGHT_DONE=true
    return 0
  fi

  [[ -n "$r620_target" ]] && check_ssh_target "R620" "$r620_target"
  [[ -n "$r810_target" ]] && check_ssh_target "R810" "$r810_target"

  if [[ -n "$REMOTE_V13_HOST" ]]; then
    local remote_target
    remote_target="$(normalize_target "$REMOTE_V13_HOST")"
    check_ssh_target "REMOTE_V13_HOST" "$remote_target"

    # Resolve remote home directory (needed because printf '%q' escapes tildes)
    local remote_home
    remote_home="$(ssh "${SSH_OPTS[@]}" "$remote_target" 'echo $HOME' 2>/dev/null)" || remote_home=""
    if [[ -z "$remote_home" ]]; then
      warn "Could not resolve remote \$HOME, defaulting to /home/$REMOTE_V13_USER"
      remote_home="/home/$REMOTE_V13_USER"
    fi

    # Resolve REMOTE_V13_PATH: if not explicitly provided, use $HOME/deploy_lab_v13.sh
    if [[ -z "$REMOTE_V13_PATH" ]]; then
      REMOTE_V13_PATH="$remote_home/deploy_lab_v13.sh"
    elif [[ "$REMOTE_V13_PATH" == "~/"* ]]; then
      # Expand leading ~/ to resolved remote home
      REMOTE_V13_PATH="$remote_home/${REMOTE_V13_PATH#\~/}"
    fi

    log "Preflight: checking deploy_lab_v13.sh presence on remote ($REMOTE_V13_PATH)"
    if ! ssh "${SSH_OPTS[@]}" "$remote_target" "test -f '$REMOTE_V13_PATH'" >/dev/null 2>&1; then
      # Script not found on remote — auto-copy from local
      local local_v13="$SCRIPT_DIR/deploy_lab_v13.sh"
      if [[ -f "$local_v13" ]]; then
        warn "deploy_lab_v13.sh not found at $REMOTE_V13_PATH on $remote_target"
        log "Auto-copying deploy_lab_v13.sh to remote host..."
        scp "${SSH_OPTS[@]}" "$local_v13" "$remote_target:$remote_home/deploy_lab_v13.sh" || \
          die "Failed to scp deploy_lab_v13.sh to $remote_target"
        ssh "${SSH_OPTS[@]}" "$remote_target" "chmod +x '$remote_home/deploy_lab_v13.sh'" 2>/dev/null || true
        REMOTE_V13_PATH="$remote_home/deploy_lab_v13.sh"
        log "Copied successfully to $remote_target:$REMOTE_V13_PATH"
      else
        die "deploy_lab_v13.sh not found locally ($local_v13) or remotely ($REMOTE_V13_PATH on $remote_target)"
      fi
    fi
  fi

  PREFLIGHT_DONE=true
  log "Preflight completed successfully."
}

ensure_preflight() {
  if ! $PREFLIGHT_DONE; then
    preflight_access
  fi
}

run_v13() {
  [[ -x "$V13_SCRIPT" || -f "$V13_SCRIPT" ]] || die "deploy_lab_v13.sh not found at $V13_SCRIPT"
  local action="$1"
  shift || true

  if [[ -n "$REMOTE_V13_HOST" ]]; then
    need_cmd ssh
    build_ssh_opts
    local remote_target
    remote_target="$(normalize_target "$REMOTE_V13_HOST")"
    local cmd=(bash "$REMOTE_V13_PATH" --profile "$PROFILE" "${PROXY_FLAGS[@]}" "$action" "$@")
    local remote_cmd
    remote_cmd="$(printf '%q ' "${cmd[@]}")"
    log "Running remote deploy_lab_v13.sh action=$action profile=$PROFILE target=$remote_target"
    ssh -t "${SSH_OPTS[@]}" "$remote_target" "$remote_cmd"
  else
    # Guard: detect non-Linux environments where libvirt/KVM is not available.
    local os_type="${OSTYPE:-unknown}"
    if [[ "$os_type" == msys* || "$os_type" == mingw* || "$os_type" == cygwin* || "$os_type" == win* || "$os_type" == darwin* ]]; then
      err "Detected non-Linux environment (OSTYPE=$os_type)."
      err "KVM commands require a Linux hypervisor (R620/R810)."
      err ""
      err "Use --remote-v13-host to run on the remote hypervisor:"
      err "  ./deploy_lab_v3.sh --remote-v13-host <user@hypervisor> --profile $PROFILE $action"
      err ""
      err "Or SSH into the hypervisor and run deploy_lab_v13.sh directly."
      die "Aborting: cannot run KVM operations locally on $(uname -s)."
    fi
    if ! command -v virsh >/dev/null 2>&1; then
      warn "virsh not found on this machine. Are you sure this is the KVM hypervisor?"
      warn "If not, use --remote-v13-host <user@hypervisor> to target the correct host."
      printf 'Continue anyway? [y/N] '
      read -r confirm
      [[ "$confirm" == [yY]* ]] || die "Aborted by user."
    fi
    log "Running local deploy_lab_v13.sh action=$action profile=$PROFILE"
    bash "$V13_SCRIPT" --profile "$PROFILE" "${PROXY_FLAGS[@]}" "$action" "$@"
  fi
}

run_v13_targeted() {
  local target="$1"
  local target_profile="$2"
  local target_path="$3"
  local action="$4"
  shift 4 || true

  [[ -n "$target" ]] || die "Remote target host is required for targeted v13 action"
  need_cmd ssh
  build_ssh_opts

  local normalized
  normalized="$(normalize_target "$target")"
  local cmd=(bash "$target_path" --profile "$target_profile" "${PROXY_FLAGS[@]}" "$action" "$@")
  local remote_cmd
  remote_cmd="$(printf '%q ' "${cmd[@]}")"
  log "Running remote deploy_lab_v13.sh action=$action profile=$target_profile target=$normalized"
  ssh -t "${SSH_OPTS[@]}" "$normalized" "$remote_cmd"
}

run_remote_virsh_raw() {
  local target="$1"
  shift || true
  [[ -n "$target" ]] || die "Remote target host is required"
  [[ $# -gt 0 ]] || die "Remote virsh command is required"

  need_cmd ssh
  build_ssh_opts

  local normalized
  normalized="$(normalize_target "$target")"

  local cmd=("$@")
  local remote_cmd
  remote_cmd="$(printf '%q ' "${cmd[@]}")"

  ssh "${SSH_OPTS[@]}" "$normalized" "$remote_cmd"
}

run_remote_virsh() {
  local hypervisor="$1"
  shift || true

  local target=""
  case "$hypervisor" in
    r620) target="$R620_HOST" ;;
    r810) target="$R810_HOST" ;;
    *) die "Unsupported hypervisor '$hypervisor'. Use r620 or r810." ;;
  esac

  [[ -n "$target" ]] || die "Host for $hypervisor is not set. Use --${hypervisor}-host."

  if [[ $# -eq 0 ]]; then
    set -- list --all
  fi

  run_remote_virsh_raw "$target" virsh "$@"
}

run_remote_status() {
  [[ -n "$R620_HOST" || -n "$R810_HOST" ]] || die "Set --r620-host and/or --r810-host for remote-status"

  if [[ -n "$R620_HOST" ]]; then
    log "Remote virsh status: R620 ($R620_HOST)"
    run_remote_virsh r620 list --all || warn "Failed to get R620 virsh status"
  fi

  if [[ -n "$R810_HOST" ]]; then
    log "Remote virsh status: R810 ($R810_HOST)"
    run_remote_virsh r810 list --all || warn "Failed to get R810 virsh status"
  fi
}

run_ansible() {
  local playbook_rel="$1"
  shift || true
  local pb="$SCRIPT_DIR/$playbook_rel"
  [[ -f "$pb" ]] || die "Playbook not found: $pb"
  need_cmd ansible-playbook
  log "Running ansible-playbook $playbook_rel"
  ansible-playbook -i "$INV_FILE" "$pb" "${EXTRA_ANSIBLE_ARGS[@]}" "$@"
}

parse_args() {
  local positional=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile)
        PROFILE="$2"; shift 2 ;;
      --no-proxy)
        PROXY_FLAGS+=("--no-proxy"); shift ;;
      --proxy)
        PROXY_FLAGS+=("--proxy"); shift ;;
      --proxy-url)
        PROXY_FLAGS+=("--proxy-url" "$2"); shift 2 ;;
      --remote-v13-host)
        REMOTE_V13_HOST="$2"; shift 2 ;;
      --remote-v13-user)
        REMOTE_V13_USER="$2"; shift 2 ;;
      --remote-v13-path)
        REMOTE_V13_PATH="$2"; REMOTE_V13_PATH_EXPLICIT=true; shift 2 ;;
      --ssh-key)
        SSH_KEY_PATH="$2"; shift 2 ;;
      --allow-password)
        ALLOW_PASSWORD_AUTH=true; shift ;;
      --proxy-jump-host)
        PROXY_JUMP_HOST="$2"; shift 2 ;;
      --r620-host)
        R620_HOST="$2"; shift 2 ;;
      --r810-host)
        R810_HOST="$2"; shift 2 ;;
      --r620-v13-path)
        R620_V13_PATH="$2"; shift 2 ;;
      --r810-v13-path)
        R810_V13_PATH="$2"; shift 2 ;;
      --r620-limit)
        R620_LIMIT="$2"; shift 2 ;;
      --r810-limit)
        R810_LIMIT="$2"; shift 2 ;;
      --ansible-arg)
        EXTRA_ANSIBLE_ARGS+=("$2"); shift 2 ;;
      -h|--help)
        usage; exit 0 ;;
      *)
        positional+=("$1"); shift ;;
    esac
  done

  if [[ ${#positional[@]} -lt 1 ]]; then
    usage
    exit 1
  fi

  ACTION="${positional[0]}"
  if [[ ${#positional[@]} -gt 1 ]]; then
    ACTION_ARGS=("${positional[@]:1}")
  fi
}

run_day0() {
  local limit="${1:-}"
  if [[ -n "$limit" ]]; then
    run_ansible "playbooks/reused/deploy_day0.yml" --limit "$limit"
  else
    run_ansible "playbooks/reused/deploy_day0.yml"
  fi
}

run_day1() {
  local limit="${1:-}"
  if [[ -n "$limit" ]]; then
    run_ansible "playbooks/reused/deploy_day1.yml" --limit "$limit"
  else
    run_ansible "playbooks/reused/deploy_day1.yml"
  fi
}

run_infra_services() {
  run_ansible "playbooks/reused/deploy_kubespray.yml"
  run_ansible "playbooks/reused/deploy_postgresql.yml"
  run_ansible "playbooks/reused/deploy_maas.yml"
  run_ansible "playbooks/reused/deploy_ceph.yml"
  run_ansible "playbooks/reused/deploy_openstack_helm.yml"
  run_ansible "playbooks/reused/deploy_monitoring.yml"
}

run_phase_r620() {
  log "Starting R620-first phase with limit: $R620_LIMIT"
  run_day0 "$R620_LIMIT"
  run_day1 "$R620_LIMIT"
  run_ansible "playbooks/reused/deploy_kubespray.yml" --limit "Host12_1,Host12_2,Host12_3,HostB12_1"
  run_ansible "playbooks/reused/deploy_postgresql.yml" --limit "HostB12_1"
  run_ansible "playbooks/reused/deploy_maas.yml" --limit "HostB12_1"
  run_ansible "playbooks/reused/deploy_ceph.yml" --limit "Host12_1,Host12_2,Host12_3,HostB12_1"
  run_ansible "playbooks/reused/deploy_openstack_helm.yml" --limit "Host12_1,Host12_2,Host12_3"
  run_ansible "playbooks/deploy_openstack_gateways.yml" --limit "HostB12_1,HostB12_2"
  run_ansible "playbooks/deploy_premium_firewall.yml" --limit "HostB12_1,HostB12_2"
}

run_phase_r810() {
  log "Starting R810 expansion phase with limit: $R810_LIMIT"
  run_day0 "$R810_LIMIT"
  run_day1 "$R810_LIMIT"
  run_ansible "playbooks/reused/deploy_kubespray.yml" --limit "Host34_1,Host34_2"
  run_ansible "playbooks/reused/deploy_ceph.yml" --limit "Host34_1,Host34_2"
  run_ansible "playbooks/reused/deploy_openstack_helm.yml" --limit "Host34_1,Host34_2"
  run_ansible "playbooks/reused/deploy_monitoring.yml" --limit "MonitorSrv"
}

main() {
  parse_args "$@"

  case "$ACTION" in
    preflight)
      preflight_access
      ;;
    kvm-deploy)
      ensure_preflight
      run_v13 deploy
      ;;
    kvm-deploy-r620)
      ensure_preflight
      run_v13_targeted "$R620_HOST" "ubuntu_r620_kvm" "$R620_V13_PATH" deploy
      ;;
    kvm-deploy-r810)
      ensure_preflight
      run_v13_targeted "$R810_HOST" "ubuntu_r810_kvm" "$R810_V13_PATH" deploy
      ;;
    kvm-deploy-both)
      ensure_preflight
      run_v13_targeted "$R620_HOST" "ubuntu_r620_kvm" "$R620_V13_PATH" deploy
      run_v13_targeted "$R810_HOST" "ubuntu_r810_kvm" "$R810_V13_PATH" deploy
      ;;
    kvm-redeploy)
      ensure_preflight
      run_v13 redeploy
      ;;
    kvm-destroy)
      ensure_preflight
      run_v13 destroy
      ;;
    kvm-validate)
      ensure_preflight
      run_v13 validate
      ;;
    remote-status)
      ensure_preflight
      run_remote_status
      ;;
    remote-virsh)
      ensure_preflight
      [[ ${#ACTION_ARGS[@]} -ge 1 ]] || die "Usage: remote-virsh <r620|r810> <virsh args...>"
      run_remote_virsh "${ACTION_ARGS[0]}" "${ACTION_ARGS[@]:1}"
      ;;
    status)
      ensure_preflight
      run_v13 status
      ;;
    day0)
      ensure_preflight
      run_day0
      ;;
    day1)
      ensure_preflight
      run_day1
      ;;
    infra-services)
      ensure_preflight
      run_infra_services
      ;;
    phase-r620)
      ensure_preflight
      run_phase_r620
      ;;
    phase-r810)
      ensure_preflight
      run_phase_r810
      ;;
    phased-full)
      ensure_preflight
      run_phase_r620
      run_phase_r810
      ;;
    gateway)
      ensure_preflight
      run_ansible "playbooks/deploy_openstack_gateways.yml"
      ;;
    premium-fw)
      ensure_preflight
      run_ansible "playbooks/deploy_premium_firewall.yml"
      ;;
    full)
      ensure_preflight
      run_v13 deploy
      run_ansible "playbooks/deploy_full_environment.yml"
      ;;
    teardown)
      ensure_preflight
      run_ansible "playbooks/teardown_full_environment.yml"
      ;;
    *)
      usage
      die "Unsupported action: $ACTION"
      ;;
  esac

  log "Action '$ACTION' completed."
}

main "$@"
