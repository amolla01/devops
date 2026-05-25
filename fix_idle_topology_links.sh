#!/usr/bin/env bash
set -euo pipefail

SSH_OPTS=(
    -o StrictHostKeyChecking=no
    -o UserKnownHostsFile=/dev/null
    -o ConnectTimeout=8
)

SONIC_PASS="amolla01"
UBUNTU_PASS="amolla01"
VIRSH="virsh"

info() { printf '  ▸  %s\n' "$*"; }
ok() { printf '  ✓  %s\n' "$*"; }
warn() { printf '  △  %s\n' "$*"; }
err() { printf '  ✗  %s\n' "$*" >&2; }
phase() {
    printf '\n══════════════════════════════════════════════════\n'
    printf '  %s\n' "$*"
    printf '══════════════════════════════════════════════════\n'
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        err "Missing required command: $1"
        exit 1
    }
}

sonic_cmd() {
    local ip="$1"
    local cmd="$2"
    sshpass -p "$SONIC_PASS" ssh "${SSH_OPTS[@]}" "admin@${ip}" "$cmd"
}

ubuntu_cmd() {
    local ip="$1"
    local cmd="$2"
    sshpass -p "$UBUNTU_PASS" ssh "${SSH_OPTS[@]}" "ubuntu@${ip}" "$cmd"
}

declare -A VM_BRIDGES VM_MGMT_IP VM_KIND SONIC_STARTUP_PORTS

VM_BRIDGES[Spine_S1]="br-L1-S1,br-L2-S1,br-L3-S1,br-L4-S1,br-BL1-S1,br-BL2-S1"
VM_BRIDGES[Spine_S2]="br-L1-S2,br-L2-S2,br-L3-S2,br-L4-S2,br-BL1-S2,br-BL2-S2"
VM_BRIDGES[Leaf_L1]="br-H121-L1,br-H122-L1,br-H123-L1,@61,br-L1-S2,@3,br-L1-S1,@3"
VM_BRIDGES[Leaf_L2]="br-H121-L2,br-H122-L2,br-H123-L2,@61,br-L2-S2,@3,br-L2-S1,@3"
VM_BRIDGES[Leaf_L3]="br-H341-L3,br-H342-L3,@28,br-L3-S2,br-L3-S1"
VM_BRIDGES[Leaf_L4]="br-H341-L4,br-H342-L4,@28,br-L4-S2,br-L4-S1"
VM_BRIDGES[Host12_1]="br-H121-L1,br-H121-L2"
VM_BRIDGES[Host12_2]="br-H122-L1,br-H122-L2"
VM_BRIDGES[Host12_3]="br-H123-L1,br-H123-L2"
VM_BRIDGES[Host34_1]="br-H341-L3,br-H341-L4"
VM_BRIDGES[Host34_2]="br-H342-L3,br-H342-L4"

VM_MGMT_IP[Spine_S1]="172.16.2.11"
VM_MGMT_IP[Spine_S2]="172.16.2.12"
VM_MGMT_IP[Leaf_L1]="172.16.2.21"
VM_MGMT_IP[Leaf_L2]="172.16.2.22"
VM_MGMT_IP[Leaf_L3]="172.16.2.23"
VM_MGMT_IP[Leaf_L4]="172.16.2.24"
VM_MGMT_IP[Border_Leaf1]="172.16.2.31"
VM_MGMT_IP[Border_Leaf2]="172.16.2.32"
VM_MGMT_IP[Host12_1]="172.16.2.40"
VM_MGMT_IP[Host12_2]="172.16.2.41"
VM_MGMT_IP[Host12_3]="172.16.2.42"
VM_MGMT_IP[Host34_1]="172.16.2.43"
VM_MGMT_IP[Host34_2]="172.16.2.44"

VM_KIND[Spine_S1]="sonic"
VM_KIND[Spine_S2]="sonic"
VM_KIND[Leaf_L1]="sonic"
VM_KIND[Leaf_L2]="sonic"
VM_KIND[Leaf_L3]="sonic"
VM_KIND[Leaf_L4]="sonic"
VM_KIND[Host12_1]="ubuntu"
VM_KIND[Host12_2]="ubuntu"
VM_KIND[Host12_3]="ubuntu"
VM_KIND[Host34_1]="ubuntu"
VM_KIND[Host34_2]="ubuntu"

SONIC_STARTUP_PORTS[Spine_S1]="Ethernet0 Ethernet4 Ethernet8 Ethernet12 Ethernet16 Ethernet20"
SONIC_STARTUP_PORTS[Spine_S2]="Ethernet0 Ethernet4 Ethernet8 Ethernet12 Ethernet16 Ethernet20"
SONIC_STARTUP_PORTS[Leaf_L1]="Ethernet0 Ethernet1 Ethernet2 Ethernet64 Ethernet68"
SONIC_STARTUP_PORTS[Leaf_L2]="Ethernet0 Ethernet1 Ethernet2 Ethernet64 Ethernet68"
SONIC_STARTUP_PORTS[Leaf_L3]="Ethernet0 Ethernet4 Ethernet120 Ethernet124"
SONIC_STARTUP_PORTS[Leaf_L4]="Ethernet0 Ethernet4 Ethernet120 Ethernet124"

TARGET_VMS=(
    Spine_S1 Spine_S2
    Leaf_L1 Leaf_L2 Leaf_L3 Leaf_L4
    Host12_1 Host12_2 Host12_3 Host34_1 Host34_2
)

expand_bridge_spec() {
    local spec="$1"
    local token
    local -a tokens=()
    IFS=',' read -r -a tokens <<< "$spec"
    for token in "${tokens[@]}"; do
        if [[ "$token" =~ ^@([0-9]+)$ ]]; then
            local count="${BASH_REMATCH[1]}"
            local pad
            for ((pad=0; pad<count; pad++)); do
                printf '%s\n' "br-pad"
            done
        else
            printf '%s\n' "$token"
        fi
    done
}

OVS_XML_PATCHER=$(mktemp /tmp/idle_topology_xml_XXXXXX.py)
trap 'rm -f "${OVS_XML_PATCHER}"' EXIT

cat > "${OVS_XML_PATCHER}" << 'PYEOF'
import sys
import xml.etree.ElementTree as ET

path = sys.argv[1]
expected = sys.argv[2:]

tree = ET.parse(path)
root = tree.getroot()
devices = root.find('devices')
bridge_ifaces = []
for iface in devices.findall('interface'):
    source = iface.find('source')
    if source is not None and 'bridge' in source.attrib:
        bridge_ifaces.append(iface)

if len(bridge_ifaces) < len(expected):
    print(f'ERROR: only {len(bridge_ifaces)} bridge NICs, expected {len(expected)}')
    sys.exit(3)

changed = False
for idx, wanted in enumerate(expected):
    iface = bridge_ifaces[idx]
    source = iface.find('source')
    current = source.attrib.get('bridge', '')
    if current != wanted:
        source.set('bridge', wanted)
        changed = True
        print(f'NIC{idx + 1}: {current} -> {wanted}')
    if wanted != 'br-pad':
        vp = iface.find('virtualport')
        if vp is None:
            vp = ET.SubElement(iface, 'virtualport')
            vp.set('type', 'openvswitch')
            changed = True
            print(f'NIC{idx + 1}: add virtualport openvswitch')
        elif vp.attrib.get('type') != 'openvswitch':
            vp.set('type', 'openvswitch')
            changed = True
            print(f'NIC{idx + 1}: force virtualport openvswitch')

if changed:
    tree.write(path, encoding='unicode')
    sys.exit(0)

print('UNCHANGED')
sys.exit(2)
PYEOF

patch_vm_xml() {
    local vm="$1"
    shift
    local tmpxml
    tmpxml=$(mktemp /tmp/idle_vm_xml_XXXXXX.xml)
    "${VIRSH}" dumpxml "$vm" > "$tmpxml" || {
        warn "$vm: failed to dump libvirt XML"
        rm -f "$tmpxml"
        return 1
    }

    local rc=0
    set +e
    python3 "$OVS_XML_PATCHER" "$tmpxml" "$@"
    rc=$?
    set -e
    if [[ $rc -eq 0 ]]; then
        "${VIRSH}" define "$tmpxml" >/dev/null && ok "$vm XML patched"
    elif [[ $rc -eq 2 ]]; then
        ok "$vm XML already aligned"
    else
        warn "$vm XML patch failed (rc=$rc)"
    fi
    rm -f "$tmpxml"
}

live_fix_vm_ports() {
    local vm="$1"
    shift
    local -a expected=("$@")
    local domif
    domif=$("${VIRSH}" domiflist "$vm" 2>/dev/null) || {
        warn "$vm: domiflist failed"
        return 1
    }

    local -a ifaces=()
    local -a bridges=()
    while read -r iface type source _; do
        [[ -z "$iface" || "$iface" == "Interface" || "$iface" == "-" ]] && continue
        [[ "$type" != "bridge" ]] && continue
        ifaces+=("$iface")
        bridges+=("$source")
    done < <(printf '%s\n' "$domif" | awk 'NR>2 {print $1, $2, $3, $4}')

    local count=${#expected[@]}
    if [[ ${#ifaces[@]} -lt $count ]]; then
        warn "$vm: only ${#ifaces[@]} bridge NICs live, expected $count"
        count=${#ifaces[@]}
    fi

    local idx iface current target
    for ((idx=0; idx<count; idx++)); do
        iface="${ifaces[$idx]}"
        current="${bridges[$idx]}"
        target="${expected[$idx]}"
        [[ "$target" == "br-pad" ]] && continue

        if [[ -n "$current" ]] && sudo ovs-vsctl br-exists "$current" 2>/dev/null; then
            if sudo ovs-vsctl list-ports "$current" 2>/dev/null | grep -qx "$iface" && [[ "$current" != "$target" ]]; then
                sudo ovs-vsctl del-port "$current" "$iface" >/dev/null 2>&1 || true
                info "$vm $iface removed from $current"
            fi
        fi

        if sudo ovs-vsctl list-ports "$target" 2>/dev/null | grep -qx "$iface"; then
            ok "$vm $iface already on $target"
        else
            sudo ovs-vsctl add-port "$target" "$iface" >/dev/null 2>&1 \
                && ok "$vm $iface added to $target" \
                || warn "$vm $iface failed to add to $target"
        fi
    done
}

fix_vm_attachment() {
    local vm="$1"
    local spec="${VM_BRIDGES[$vm]}"
    local -a expected=()
    while IFS= read -r bridge; do
        expected+=("$bridge")
    done < <(expand_bridge_spec "$spec")

    info "$vm: patching XML to expected bridge order"
    patch_vm_xml "$vm" "${expected[@]}"
    info "$vm: live-fixing OVS port membership"
    live_fix_vm_ports "$vm" "${expected[@]}"
}

bring_up_sonic_ports() {
    local vm="$1"
    local ip="${VM_MGMT_IP[$vm]}"
    local ports="${SONIC_STARTUP_PORTS[$vm]:-}"
    [[ -z "$ports" ]] && return 0
    local cmd=""
    local port
    for port in $ports; do
        cmd+="sudo config interface startup ${port}; "
    done
    cmd+="docker exec bgp vtysh -c 'clear bgp * soft out' >/dev/null 2>&1 || true"
    sonic_cmd "$ip" "$cmd" >/dev/null 2>&1 \
        && ok "$vm SONiC ports brought up" \
        || warn "$vm SONiC port startup command failed"
}

restart_host_frr() {
    local vm="$1"
    local ip="${VM_MGMT_IP[$vm]}"
    ubuntu_cmd "$ip" "sudo ip link set enp2s0 up; sudo ip link set enp3s0 up; sudo systemctl restart frr" >/dev/null 2>&1 \
        && ok "$vm interfaces up + FRR restarted" \
        || warn "$vm host recovery command failed"
}

show_bridge_counts() {
    local -A seen=()
    local vm spec bridge
    for vm in "${TARGET_VMS[@]}"; do
        spec="${VM_BRIDGES[$vm]}"
        while IFS= read -r bridge; do
            [[ "$bridge" == "br-pad" ]] && continue
            seen["$bridge"]=1
        done < <(expand_bridge_spec "$spec")
    done

    local br
    for br in "${!seen[@]}"; do
        local count
        count=$(sudo ovs-vsctl list-ports "$br" 2>/dev/null | grep -c '^vnet' || echo 0)
        if [[ "$count" -ge 2 ]]; then
            ok "$br: ${count} ports"
        else
            warn "$br: only ${count} port(s)"
        fi
    done | sort
}

show_bgp_summary() {
    local vm="$1"
    local ip="${VM_MGMT_IP[$vm]}"
    if [[ "${VM_KIND[$vm]}" == "sonic" ]]; then
        printf '\n---- %s ----\n' "$vm"
        sonic_cmd "$ip" "docker exec bgp vtysh -c 'show bgp summary'" || warn "$vm BGP summary failed"
    else
        printf '\n---- %s ----\n' "$vm"
        ubuntu_cmd "$ip" "sudo vtysh -c 'show bgp summary'" || warn "$vm BGP summary failed"
    fi
}

phase "Phase 0 - Prerequisites"
need_cmd virsh
need_cmd ovs-vsctl
need_cmd sshpass
need_cmd python3
ok "Required commands available"

phase "Phase 1 - Patch XML and live-fix OVS ports"
for vm in "${TARGET_VMS[@]}"; do
    fix_vm_attachment "$vm"
done

phase "Phase 2 - Bring interfaces and daemons up"
for vm in Spine_S1 Spine_S2 Leaf_L1 Leaf_L2 Leaf_L3 Leaf_L4; do
    bring_up_sonic_ports "$vm"
done
for vm in Host12_1 Host12_2 Host12_3 Host34_1 Host34_2; do
    restart_host_frr "$vm"
done

phase "Phase 3 - OVS bridge counts"
show_bridge_counts

phase "Phase 4 - BGP verification"
for vm in Host12_1 Host12_2 Host12_3 Host34_1 Host34_2 Leaf_L1 Leaf_L2 Leaf_L3 Leaf_L4 Spine_S1 Spine_S2 Border_Leaf1 Border_Leaf2; do
    if [[ -n "${VM_MGMT_IP[$vm]:-}" ]]; then
        show_bgp_summary "$vm"
    fi
done

phase "Done"
ok "Topology idle-link repair complete. Re-run safely if any bridge still shows only one vnet."