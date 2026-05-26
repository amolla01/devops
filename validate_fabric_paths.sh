#!/usr/bin/env bash
set -euo pipefail

SSH_OPTS=()
SSH_OPTS_BATCH=()

SONIC_PASS="${SONIC_PASS:-amolla01}"
UBUNTU_PASS="${UBUNTU_PASS:-amolla01}"
UBUNTU_ALT_PASS="${UBUNTU_ALT_PASS:-ubuntu}"
CHR_PASS="${CHR_PASS:-amolla01}"
LAB_KEY_PATH="${LAB_KEY_PATH:-${HOME}/id_dc_lab}"
EXTERNAL_IP="${EXTERNAL_IP:-1.1.1.1}"
EXTERNAL_HOST="${EXTERNAL_HOST:-bbc.com}"
PING_COUNT="${PING_COUNT:-1}"
REPORT_DIR=""
INVENTORY_DIR=""
PROXY_JUMP_HOST="${PROXY_JUMP_HOST:-}"
DEPLOY_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/deploy_lab_v13.sh"

declare -A DEVICE_ROLE DEVICE_IP DEVICE_LOOPBACK DEVICE_SEEN DEVICE_BGP_UP DEVICE_BGP_TOTAL
declare -a DEVICES SERVER_DEVICES SWITCH_DEVICES EXIT_DEVICES

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info() { printf '  [INFO] %s\n' "$*"; }
ok() { printf '  [ OK ] %s\n' "$*"; }
warn() { printf '  [WARN] %s\n' "$*"; }
err() { printf '  [FAIL] %s\n' "$*" >&2; }
phase() {
    printf '\n==================================================\n'
    printf '  %s\n' "$*"
    printf '==================================================\n'
}

init_ssh_opts() {
    SSH_OPTS=(
        -o StrictHostKeyChecking=no
        -o UserKnownHostsFile=/dev/null
        -o ConnectTimeout=8
    )
    SSH_OPTS_BATCH=(
        -o StrictHostKeyChecking=no
        -o UserKnownHostsFile=/dev/null
        -o ConnectTimeout=8
        -o BatchMode=yes
    )

    if [[ -n "$PROXY_JUMP_HOST" ]]; then
        SSH_OPTS+=( -o "ProxyJump=${PROXY_JUMP_HOST}" )
        SSH_OPTS_BATCH+=( -o "ProxyJump=${PROXY_JUMP_HOST}" )
    fi
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --inventory DIR     Inventory directory (for example: data-center/_v2/iteration-2/inventory)
  --report-dir DIR    Output directory for reports (default: data-center/validation-reports/<timestamp>)
    --proxy-jump HOST   SSH ProxyJump host, for example: admin@192.168.1.50
  --external-ip IP    External IP to validate north-south reachability (default: ${EXTERNAL_IP})
  --external-host H   External hostname to validate DNS-backed north-south reachability (default: ${EXTERNAL_HOST})
  --ping-count N      Ping count per test (default: ${PING_COUNT})
  --help              Show this help

Behavior:
  - Without --inventory, the script falls back to the current root topology mappings in deploy_lab_v13.sh
  - With --inventory, the script parses hosts.yml, group_vars/all.yml, and host_vars/*.yml
    - Set PROXY_JUMP_HOST or pass --proxy-jump when running from laptop/WSL through R620/R810
  - Generates a Markdown summary, TSV details, and per-device raw snapshots
EOF
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        err "Missing required command: $1"
        exit 1
    }
}

classify_role() {
    local name="$1"
    case "$name" in
        Spine_*) printf 'spine' ;;
        Leaf_*) printf 'leaf' ;;
        Border_Leaf*) printf 'border_leaf' ;;
        Exit_Router*) printf 'exit_router' ;;
        Host*|MonitorSrv) printf 'server' ;;
        *) printf 'unknown' ;;
    esac
}

add_device() {
    local name="$1"
    local ip="$2"
    local loopback="$3"
    local role="$4"
    [[ -z "$name" || -z "$ip" ]] && return 0

    DEVICE_IP["$name"]="$ip"
    DEVICE_LOOPBACK["$name"]="$loopback"
    DEVICE_ROLE["$name"]="$role"

    if [[ -z "${DEVICE_SEEN[$name]:-}" ]]; then
        DEVICES+=("$name")
        DEVICE_SEEN["$name"]=1
    fi
}

build_role_lists() {
    SERVER_DEVICES=()
    SWITCH_DEVICES=()
    EXIT_DEVICES=()

    local device role
    for device in "${DEVICES[@]}"; do
        role="${DEVICE_ROLE[$device]}"
        case "$role" in
            spine|leaf|border_leaf) SWITCH_DEVICES+=("$device") ;;
            server) SERVER_DEVICES+=("$device") ;;
            exit_router) EXIT_DEVICES+=("$device") ;;
        esac
    done
}

load_from_deploy_script() {
    local deploy_path="$1"
    [[ -f "$deploy_path" ]] || {
        err "Deploy script not found: $deploy_path"
        exit 1
    }

    local parsed line name ip loopback role
    parsed=$(python3 - "$deploy_path" <<'PY'
import re
import sys

path = sys.argv[1]
mgmt = {}
loop = {}
for raw_line in open(path, encoding='utf-8'):
    for name, ip in re.findall(r'VM_MGMT_IP\[([A-Za-z0-9_]+)\]="([0-9.]+)"', raw_line):
        mgmt[name] = ip
    for name, ip in re.findall(r'SERVER_LOOPBACK_IP\[([A-Za-z0-9_]+)\]="([0-9.]+)/\d+"', raw_line):
        loop[name] = ip

for name in sorted(mgmt):
    print(name, mgmt[name], loop.get(name, ''), sep='\t')
PY
)

    while IFS=$'\t' read -r name ip loopback; do
        [[ -z "$name" ]] && continue
        role="$(classify_role "$name")"
        add_device "$name" "$ip" "$loopback" "$role"
    done <<< "$parsed"
}

load_from_inventory() {
    local inventory_path="$1"
    [[ -d "$inventory_path" ]] || {
        err "Inventory directory not found: $inventory_path"
        exit 1
    }

    local parsed line name ip loopback role
    parsed=$(python3 - "$inventory_path" <<'PY'
import pathlib
import re
import sys

inventory = pathlib.Path(sys.argv[1])
hosts_yml = inventory / 'hosts.yml'
all_yml = inventory / 'group_vars' / 'all.yml'
host_vars_dir = inventory / 'host_vars'

host_ips = {}
if hosts_yml.exists():
    current = None
    current_indent = None
    for line in hosts_yml.read_text(encoding='utf-8').splitlines():
        match = re.match(r'^(\s*)([A-Za-z0-9_]+):\s*$', line)
        if match:
            current = match.group(2)
            current_indent = len(match.group(1))
            continue
        if current is None:
            continue
        match = re.match(r'^\s*ansible_host:\s*([0-9.]+)\s*$', line)
        if match:
            host_ips[current] = match.group(1)
            current = None
            current_indent = None
            continue
        stripped = line.strip()
        if stripped and (len(line) - len(line.lstrip(' '))) <= (current_indent or 0):
            current = None
            current_indent = None

server_loopbacks = {}
if all_yml.exists():
    in_map = False
    for line in all_yml.read_text(encoding='utf-8').splitlines():
        if re.match(r'^server_loopback_map:\s*$', line):
            in_map = True
            continue
        if in_map and re.match(r'^\S', line):
            in_map = False
        if not in_map:
            continue
        match = re.match(r'^\s+([A-Za-z0-9_]+):\s*"([0-9.]+)"\s*$', line)
        if match:
            server_loopbacks[match.group(1)] = match.group(2)

patterns = [
    re.compile(r'mgmt_ip:\s*"([0-9.]+)/\d+"'),
    re.compile(r'loopback_ip:\s*"([0-9.]+)/\d+"'),
    re.compile(r'server_loopback_ip:\s*"([0-9.]+)/\d+"'),
    re.compile(r'router_id:\s*"([0-9.]+)"'),
    re.compile(r'exit_router_id:\s*"([0-9.]+)"'),
]

for path in sorted(host_vars_dir.glob('*.yml')):
    name = path.stem
    mgmt = host_ips.get(name, '')
    loopback = ''
    for line in path.read_text(encoding='utf-8').splitlines():
        if not mgmt:
            match = patterns[0].search(line)
            if match:
                mgmt = match.group(1)
                continue
        if not loopback:
            for pattern in patterns[1:]:
                match = pattern.search(line)
                if match:
                    loopback = match.group(1)
                    break
    if not loopback:
        loopback = server_loopbacks.get(name, '')
    print(name, mgmt, loopback, sep='\t')
PY
)

    while IFS=$'\t' read -r name ip loopback; do
        [[ -z "$name" || -z "$ip" ]] && continue
        role="$(classify_role "$name")"
        add_device "$name" "$ip" "$loopback" "$role"
    done <<< "$parsed"
}

sonic_cmd() {
    local ip="$1"
    local cmd="$2"
    sshpass -p "$SONIC_PASS" ssh "${SSH_OPTS[@]}" "admin@${ip}" "$cmd"
}

ubuntu_cmd() {
    local ip="$1"
    local cmd="$2"

    if [[ -f "$LAB_KEY_PATH" ]] && ssh -i "$LAB_KEY_PATH" "${SSH_OPTS_BATCH[@]}" "ubuntu@${ip}" "true" >/dev/null 2>&1; then
        ssh -i "$LAB_KEY_PATH" "${SSH_OPTS[@]}" "ubuntu@${ip}" "$cmd"
        return
    fi

    if sshpass -p "$UBUNTU_PASS" ssh "${SSH_OPTS[@]}" "ubuntu@${ip}" "true" >/dev/null 2>&1; then
        sshpass -p "$UBUNTU_PASS" ssh "${SSH_OPTS[@]}" "ubuntu@${ip}" "$cmd"
        return
    fi

    sshpass -p "$UBUNTU_ALT_PASS" ssh "${SSH_OPTS[@]}" "ubuntu@${ip}" "$cmd"
}

routeros_cmd() {
    local ip="$1"
    local cmd="$2"

    if [[ -f "$LAB_KEY_PATH" ]] && ssh -i "$LAB_KEY_PATH" "${SSH_OPTS_BATCH[@]}" "admin@${ip}" ":put ok" >/dev/null 2>&1; then
        ssh -i "$LAB_KEY_PATH" "${SSH_OPTS[@]}" "admin@${ip}" "$cmd"
        return
    fi

    sshpass -p "$CHR_PASS" ssh "${SSH_OPTS[@]}" "admin@${ip}" "$cmd"
}

capture_remote() {
    local role="$1"
    local ip="$2"
    local cmd="$3"
    case "$role" in
        spine|leaf|border_leaf) sonic_cmd "$ip" "$cmd" ;;
        server) ubuntu_cmd "$ip" "$cmd" ;;
        exit_router) routeros_cmd "$ip" "$cmd" ;;
        *) return 1 ;;
    esac
}

sanitize_detail() {
    local detail="$1"
    detail="${detail//$'\t'/ }"
    detail="${detail//$'\r'/ }"
    detail="${detail//$'\n'/ | }"
    printf '%s' "$detail"
}

record_result() {
    local src="$1"
    local role="$2"
    local category="$3"
    local target="$4"
    local status="$5"
    local detail
    detail="$(sanitize_detail "${6:-}")"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$src" "$role" "$category" "$target" "$status" "$detail" >> "$RESULTS_TSV"
}

save_snapshot() {
    local name="$1"
    local suffix="$2"
    local content="$3"
    printf '%s\n' "$content" > "$RAW_DIR/${name}.${suffix}.txt"
}

collect_bgp_snapshot() {
    local name="$1"
    local role="${DEVICE_ROLE[$name]}"
    local ip="${DEVICE_IP[$name]}"
    local cmd output rc up total
    up=0
    total=0

    case "$role" in
        spine|leaf|border_leaf)
            cmd="docker exec bgp vtysh -c 'show bgp summary'"
            ;;
        server)
            cmd="sudo vtysh -c 'show bgp summary'"
            ;;
        exit_router)
            cmd=":put [/routing/bgp/session/print terse]"
            ;;
        *)
            return 0
            ;;
    esac

    set +e
    output="$(capture_remote "$role" "$ip" "$cmd" 2>&1)"
    rc=$?
    set -e

    save_snapshot "$name" bgp "$output"

    if [[ $rc -ne 0 ]]; then
        record_result "$name" "$role" bgp summary FAIL "$output"
        DEVICE_BGP_UP["$name"]=0
        DEVICE_BGP_TOTAL["$name"]=0
        return 0
    fi

    if [[ "$role" == "exit_router" ]]; then
        record_result "$name" "$role" bgp summary INFO "$output"
        DEVICE_BGP_UP["$name"]=0
        DEVICE_BGP_TOTAL["$name"]=0
        return 0
    fi

    read -r up total <<< "$(printf '%s\n' "$output" | awk '
        /^Neighbor/ {in_table=1; next}
        /^Total number of neighbors/ {if (in_table) {exit}}
        in_table && NF >= 10 {
            state = $(NF-1)
            total++
            if (state ~ /^[0-9]+$/) up++
        }
        END {print (up+0), (total+0)}
    ')"
    DEVICE_BGP_UP["$name"]="$up"
    DEVICE_BGP_TOTAL["$name"]="$total"
    if [[ "$total" -gt 0 && "$up" -gt 0 ]]; then
        record_result "$name" "$role" bgp summary PASS "${up}/${total} neighbors established"
    else
        record_result "$name" "$role" bgp summary FAIL "${up}/${total} neighbors established"
    fi
}

linux_ping_test() {
    local name="$1"
    local target="$2"
    local source_ip="$3"
    local role="${DEVICE_ROLE[$name]}"
    local ip="${DEVICE_IP[$name]}"
    local route_cmd ping_cmd route_out ping_out rc status

    route_cmd="ip route get ${target} 2>/dev/null | head -n1"
    ping_cmd="ping -c ${PING_COUNT} -W 2 ${source_ip:+-I ${source_ip}} ${target} >/dev/null 2>&1"

    set +e
    route_out="$(capture_remote "$role" "$ip" "$route_cmd" 2>&1)"
    ping_out="$(capture_remote "$role" "$ip" "$ping_cmd" 2>&1)"
    rc=$?
    set -e

    if [[ $rc -eq 0 ]]; then
        status="PASS"
    else
        status="FAIL"
    fi
    printf '%s\t%s' "$status" "$(sanitize_detail "${route_out:-${ping_out:-no output}}")"
}

sonic_ping_test() {
    local name="$1"
    local target="$2"
    local source_ip="$3"
    local ip="${DEVICE_IP[$name]}"
    local route_cmd ping_cmd route_out ping_out rc status

    if [[ "$target" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        route_cmd="docker exec bgp vtysh -c 'show ip route ${target}/32'"
    else
        route_cmd="docker exec bgp vtysh -c 'show ip route 0.0.0.0/0'"
    fi
    ping_cmd="ping -c ${PING_COUNT} -W 2 ${source_ip:+-I ${source_ip}} ${target} >/dev/null 2>&1"

    set +e
    route_out="$(sonic_cmd "$ip" "$route_cmd" 2>&1)"
    ping_out="$(sonic_cmd "$ip" "$ping_cmd" 2>&1)"
    rc=$?
    set -e

    if [[ $rc -eq 0 ]]; then
        status="PASS"
    else
        status="FAIL"
    fi
    printf '%s\t%s' "$status" "$(sanitize_detail "${route_out:-${ping_out:-no output}}")"
}

routeros_ping_test() {
    local name="$1"
    local target="$2"
    local ip="${DEVICE_IP[$name]}"
    local output rc status detail

    set +e
    output="$(routeros_cmd "$ip" ":put ([/ping address=${target} count=${PING_COUNT}] > 0)" 2>&1 | tr -d '\r' | tail -n1)"
    rc=$?
    set -e

    if [[ $rc -eq 0 && "$output" == "true" ]]; then
        status="PASS"
        detail="reachable"
    else
        status="FAIL"
        detail="${output:-unreachable}"
    fi
    printf '%s\t%s' "$status" "$detail"
}

validate_server_mesh() {
    phase "Phase 2 - East-West Server Mesh"
    local src dst source_ip result status detail
    for src in "${SERVER_DEVICES[@]}"; do
        source_ip="${DEVICE_LOOPBACK[$src]:-}"
        for dst in "${SERVER_DEVICES[@]}"; do
            [[ "$src" == "$dst" ]] && continue
            [[ -z "${DEVICE_LOOPBACK[$dst]:-}" ]] && continue
            read -r status detail <<< "$(linux_ping_test "$src" "${DEVICE_LOOPBACK[$dst]}" "$source_ip")"
            record_result "$src" server east_west "$dst:${DEVICE_LOOPBACK[$dst]}" "$status" "$detail"
        done
    done
}

validate_switch_to_server_loopbacks() {
    phase "Phase 3 - Switch to Server Loopbacks"
    local src dst source_ip status detail
    for src in "${SWITCH_DEVICES[@]}"; do
        source_ip="${DEVICE_LOOPBACK[$src]:-}"
        for dst in "${SERVER_DEVICES[@]}"; do
            [[ -z "${DEVICE_LOOPBACK[$dst]:-}" ]] && continue
            read -r status detail <<< "$(sonic_ping_test "$src" "${DEVICE_LOOPBACK[$dst]}" "$source_ip")"
            record_result "$src" "${DEVICE_ROLE[$src]}" east_west "$dst:${DEVICE_LOOPBACK[$dst]}" "$status" "$detail"
        done
    done
}

validate_exit_to_internal_and_external() {
    phase "Phase 4 - Exit Router Validation"
    local src dst target status detail
    for src in "${EXIT_DEVICES[@]}"; do
        for dst in Border_Leaf1 Border_Leaf2; do
            [[ -z "${DEVICE_IP[$dst]:-}" ]] && continue
            target="${DEVICE_LOOPBACK[$dst]:-}"
            if [[ -z "$target" ]]; then
                record_result "$src" exit_router adjacency "$dst" INFO "no discovered border-leaf fabric loopback; skipped adjacency ping"
                continue
            fi
            read -r status detail <<< "$(routeros_ping_test "$src" "$target")"
            record_result "$src" exit_router adjacency "$dst:$target" "$status" "$detail"
        done
        read -r status detail <<< "$(routeros_ping_test "$src" "$EXTERNAL_IP")"
        record_result "$src" exit_router north_south "$EXTERNAL_IP" "$status" "$detail"
        read -r status detail <<< "$(routeros_ping_test "$src" "$EXTERNAL_HOST")"
        record_result "$src" exit_router north_south "$EXTERNAL_HOST" "$status" "$detail"
    done
}

validate_north_south() {
    phase "Phase 5 - North-South Reachability"
    local src source_ip status detail
    for src in "${SERVER_DEVICES[@]}"; do
        source_ip="${DEVICE_LOOPBACK[$src]:-}"
        read -r status detail <<< "$(linux_ping_test "$src" "$EXTERNAL_IP" "$source_ip")"
        record_result "$src" server north_south "$EXTERNAL_IP" "$status" "$detail"
        read -r status detail <<< "$(linux_ping_test "$src" "$EXTERNAL_HOST" "$source_ip")"
        record_result "$src" server north_south "$EXTERNAL_HOST" "$status" "$detail"
    done

    for src in "${SWITCH_DEVICES[@]}"; do
        source_ip="${DEVICE_LOOPBACK[$src]:-}"
        read -r status detail <<< "$(sonic_ping_test "$src" "$EXTERNAL_IP" "$source_ip")"
        record_result "$src" "${DEVICE_ROLE[$src]}" north_south "$EXTERNAL_IP" "$status" "$detail"
        read -r status detail <<< "$(sonic_ping_test "$src" "$EXTERNAL_HOST" "$source_ip")"
        record_result "$src" "${DEVICE_ROLE[$src]}" north_south "$EXTERNAL_HOST" "$status" "$detail"
    done
}

generate_report() {
    local report_md="$REPORT_DIR/summary.md"
    local summary_tsv="$REPORT_DIR/device-summary.tsv"

    python3 - "$RESULTS_TSV" "$summary_tsv" "$report_md" <<'PY'
import collections
import csv
import pathlib
import sys

results_path = pathlib.Path(sys.argv[1])
summary_path = pathlib.Path(sys.argv[2])
report_path = pathlib.Path(sys.argv[3])

rows = []
with results_path.open(encoding='utf-8') as handle:
    for line in handle:
        parts = line.rstrip('\n').split('\t')
        if len(parts) != 6:
            continue
        rows.append(parts)

device_summary = collections.OrderedDict()
for src, role, category, target, status, detail in rows:
    device_summary.setdefault(src, {'role': role, 'categories': collections.defaultdict(list)})
    device_summary[src]['categories'][category].append(status)

def grade(statuses):
    if not statuses:
        return 'NA'
    if all(status == 'PASS' or status == 'INFO' for status in statuses):
        return 'PASS'
    if any(status == 'PASS' for status in statuses):
        return 'WARN'
    return 'FAIL'

with summary_path.open('w', encoding='utf-8', newline='') as handle:
    writer = csv.writer(handle, delimiter='\t')
    writer.writerow(['device', 'role', 'bgp', 'east_west', 'adjacency', 'north_south'])
    for device, data in device_summary.items():
        writer.writerow([
            device,
            data['role'],
            grade(data['categories'].get('bgp', [])),
            grade(data['categories'].get('east_west', [])),
            grade(data['categories'].get('adjacency', [])),
            grade(data['categories'].get('north_south', [])),
        ])

lines = []
lines.append('# Fabric Validation Report')
lines.append('')
lines.append('## Summary')
lines.append('')
lines.append('| Device | Role | BGP | East-West | Adjacency | North-South |')
lines.append('| --- | --- | --- | --- | --- | --- |')
for device, data in device_summary.items():
    lines.append(
        f"| {device} | {data['role']} | {grade(data['categories'].get('bgp', []))} | "
        f"{grade(data['categories'].get('east_west', []))} | {grade(data['categories'].get('adjacency', []))} | "
        f"{grade(data['categories'].get('north_south', []))} |"
    )

lines.append('')
lines.append('## Detailed Results')
lines.append('')
lines.append('| Source | Role | Category | Target | Status | Detail |')
lines.append('| --- | --- | --- | --- | --- | --- |')
for src, role, category, target, status, detail in rows:
    lines.append(f'| {src} | {role} | {category} | {target} | {status} | {detail} |')

report_path.write_text('\n'.join(lines) + '\n', encoding='utf-8')
PY

    ok "Report written to ${report_md}"
    ok "Detailed results written to ${RESULTS_TSV}"
    ok "Summary matrix written to ${summary_tsv}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --inventory)
            INVENTORY_DIR="$2"
            shift 2
            ;;
        --report-dir)
            REPORT_DIR="$2"
            shift 2
            ;;
        --proxy-jump)
            PROXY_JUMP_HOST="$2"
            shift 2
            ;;
        --external-ip)
            EXTERNAL_IP="$2"
            shift 2
            ;;
        --external-host)
            EXTERNAL_HOST="$2"
            shift 2
            ;;
        --ping-count)
            PING_COUNT="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            err "Unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

STAMP="$(date +%Y%m%d_%H%M%S)"
if [[ -z "$REPORT_DIR" ]]; then
    REPORT_DIR="$SCRIPT_DIR/validation-reports/${STAMP}"
fi
RAW_DIR="$REPORT_DIR/raw"
RESULTS_TSV="$REPORT_DIR/results.tsv"

phase "Phase 0 - Prerequisites"
need_cmd python3
need_cmd ssh
need_cmd sshpass
init_ssh_opts
mkdir -p "$RAW_DIR"
: > "$RESULTS_TSV"
ok "Output directory ready: ${REPORT_DIR}"
if [[ -n "$PROXY_JUMP_HOST" ]]; then
    ok "Using ProxyJump host: ${PROXY_JUMP_HOST}"
else
    warn "No ProxyJump configured; this only works if the lab management IPs are directly reachable from this machine"
fi

phase "Phase 1 - Topology Discovery"
if [[ -n "$INVENTORY_DIR" ]]; then
    load_from_inventory "$INVENTORY_DIR"
    ok "Loaded topology from inventory: ${INVENTORY_DIR}"
else
    load_from_deploy_script "$DEPLOY_SCRIPT"
    ok "Loaded topology from deploy script: ${DEPLOY_SCRIPT}"
fi
build_role_lists
ok "Discovered ${#DEVICES[@]} devices (${#SERVER_DEVICES[@]} servers, ${#SWITCH_DEVICES[@]} switches, ${#EXIT_DEVICES[@]} exit routers)"

phase "Phase 1.5 - BGP Snapshots"
for device in "${DEVICES[@]}"; do
    collect_bgp_snapshot "$device"
done

validate_server_mesh
validate_switch_to_server_loopbacks
validate_exit_to_internal_and_external
validate_north_south

phase "Phase 6 - Report Generation"
generate_report

phase "Done"
ok "Fabric validation complete"