#!/usr/bin/env bash
set -euo pipefail

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

SONIC_PASS="amolla01"
UBUNTU_PASS="amolla01"
UBUNTU_ALT_PASS="ubuntu"
LAB_KEY_PATH="${HOME}/id_dc_lab"
VIRSH="virsh"
CHR_PASS="amolla01"

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

declare -A VM_BRIDGES VM_MGMT_IP VM_KIND SONIC_STARTUP_PORTS
declare -A SERVER_LOOPBACK_IP SERVER_ROUTER_ID SERVER_BGP_ASN
declare -A SERVER_PEER1_ASN SERVER_PEER2_ASN SERVER_PEER1_DESC SERVER_PEER2_DESC

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
VM_BRIDGES[Border_Leaf1]="br-BL1-ER1,@4,br-HB-BL1,br-HB2-BL1,br-MS-BL1,@22,br-BL1-S2,br-BL1-S1"
VM_BRIDGES[Border_Leaf2]="br-BL2-ER2,@4,br-HB-BL2,br-HB2-BL2,br-MS-BL2,@22,br-BL2-S2,br-BL2-S1"
VM_BRIDGES[Exit_Router1]="br-BL1-ER1"
VM_BRIDGES[Exit_Router2]="br-BL2-ER2"

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
VM_KIND[Border_Leaf1]="sonic"
VM_KIND[Border_Leaf2]="sonic"
VM_KIND[Host12_1]="ubuntu"
VM_KIND[Host12_2]="ubuntu"
VM_KIND[Host12_3]="ubuntu"
VM_KIND[Host34_1]="ubuntu"
VM_KIND[Host34_2]="ubuntu"
VM_KIND[Exit_Router1]="chr"
VM_KIND[Exit_Router2]="chr"

SONIC_STARTUP_PORTS[Spine_S1]="Ethernet0 Ethernet4 Ethernet8 Ethernet12 Ethernet16 Ethernet20"
SONIC_STARTUP_PORTS[Spine_S2]="Ethernet0 Ethernet4 Ethernet8 Ethernet12 Ethernet16 Ethernet20"
SONIC_STARTUP_PORTS[Leaf_L1]="Ethernet0 Ethernet1 Ethernet2 Ethernet64 Ethernet68"
SONIC_STARTUP_PORTS[Leaf_L2]="Ethernet0 Ethernet1 Ethernet2 Ethernet64 Ethernet68"
SONIC_STARTUP_PORTS[Leaf_L3]="Ethernet0 Ethernet4 Ethernet120 Ethernet124"
SONIC_STARTUP_PORTS[Leaf_L4]="Ethernet0 Ethernet4 Ethernet120 Ethernet124"

SERVER_LOOPBACK_IP[Host12_1]="10.10.255.1/32"
SERVER_LOOPBACK_IP[Host12_2]="10.10.255.2/32"
SERVER_LOOPBACK_IP[Host12_3]="10.10.255.3/32"
SERVER_LOOPBACK_IP[Host34_1]="10.10.255.11/32"
SERVER_LOOPBACK_IP[Host34_2]="10.10.255.12/32"
SERVER_ROUTER_ID[Host12_1]="10.10.255.1"
SERVER_ROUTER_ID[Host12_2]="10.10.255.2"
SERVER_ROUTER_ID[Host12_3]="10.10.255.3"
SERVER_ROUTER_ID[Host34_1]="10.10.255.11"
SERVER_ROUTER_ID[Host34_2]="10.10.255.12"
for vm in Host12_1 Host12_2 Host12_3 Host34_1 Host34_2; do
    SERVER_BGP_ASN[$vm]=65200
done
SERVER_PEER1_ASN[Host12_1]=65011; SERVER_PEER2_ASN[Host12_1]=65012
SERVER_PEER1_ASN[Host12_2]=65011; SERVER_PEER2_ASN[Host12_2]=65012
SERVER_PEER1_ASN[Host12_3]=65011; SERVER_PEER2_ASN[Host12_3]=65012
SERVER_PEER1_ASN[Host34_1]=65013; SERVER_PEER2_ASN[Host34_1]=65014
SERVER_PEER1_ASN[Host34_2]=65013; SERVER_PEER2_ASN[Host34_2]=65014
SERVER_PEER1_DESC[Host12_1]="Leaf_L1"; SERVER_PEER2_DESC[Host12_1]="Leaf_L2"
SERVER_PEER1_DESC[Host12_2]="Leaf_L1"; SERVER_PEER2_DESC[Host12_2]="Leaf_L2"
SERVER_PEER1_DESC[Host12_3]="Leaf_L1"; SERVER_PEER2_DESC[Host12_3]="Leaf_L2"
SERVER_PEER1_DESC[Host34_1]="Leaf_L3"; SERVER_PEER2_DESC[Host34_1]="Leaf_L4"
SERVER_PEER1_DESC[Host34_2]="Leaf_L3"; SERVER_PEER2_DESC[Host34_2]="Leaf_L4"

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

if len(bridge_ifaces) > len(expected):
    bridge_ifaces = bridge_ifaces[-len(expected):]

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

repair_host_frr() {
    local vm="$1"
    local ip="${VM_MGMT_IP[$vm]}"
    local loopback_ip="${SERVER_LOOPBACK_IP[$vm]}"
    local router_id="${SERVER_ROUTER_ID[$vm]}"
    local bgp_asn="${SERVER_BGP_ASN[$vm]}"
    local peer1_asn="${SERVER_PEER1_ASN[$vm]}"
    local peer2_asn="${SERVER_PEER2_ASN[$vm]}"
    local peer1_desc="${SERVER_PEER1_DESC[$vm]}"
    local peer2_desc="${SERVER_PEER2_DESC[$vm]}"

    local fab0_name fab1_name
    fab0_name=$(ubuntu_cmd "$ip" "ip -o link show | grep -v lo | grep -v enp1s0 | awk -F': ' 'NR==1{print \$2}'" 2>/dev/null || true)
    fab1_name=$(ubuntu_cmd "$ip" "ip -o link show | grep -v lo | grep -v enp1s0 | awk -F': ' 'NR==2{print \$2}'" 2>/dev/null || true)
    [[ -z "$fab0_name" ]] && fab0_name="enp2s0"
    [[ -z "$fab1_name" ]] && fab1_name="enp3s0"

    local frr_conf="frr version 8.4
frr defaults traditional
hostname ${vm}
log syslog informational
no ipv6 forwarding
!
router bgp ${bgp_asn}
 bgp router-id ${router_id}
 bgp bestpath as-path multipath-relax
 no bgp ebgp-requires-policy
 neighbor ${fab0_name} interface remote-as ${peer1_asn}
 neighbor ${fab0_name} description ${peer1_desc}
 neighbor ${fab1_name} interface remote-as ${peer2_asn}
 neighbor ${fab1_name} description ${peer2_desc}
 !
 address-family ipv4 unicast
  redistribute connected
  neighbor ${fab0_name} activate
  neighbor ${fab0_name} soft-reconfiguration inbound
  neighbor ${fab1_name} activate
  neighbor ${fab1_name} soft-reconfiguration inbound
 exit-address-family
!
line vty
!"

    ubuntu_cmd "$ip" "
        sudo ip link set ${fab0_name} up 2>/dev/null || true
        sudo ip link set ${fab1_name} up 2>/dev/null || true
        sudo ip addr replace ${loopback_ip} dev lo
        sudo ip addr replace 169.254.0.1/32 dev ${fab0_name}
        sudo ip addr replace 169.254.0.1/32 dev ${fab1_name}
        sudo mkdir -p /etc/netplan
        sudo tee /etc/netplan/10-loopback.yaml > /dev/null <<'LOEOF'
network:
  version: 2
  ethernets:
    lo:
      addresses:
        - ${loopback_ip}
LOEOF
        sudo tee /etc/netplan/20-fabric.yaml > /dev/null <<'FABEOF'
network:
  version: 2
  ethernets:
    ${fab0_name}:
      dhcp4: false
      link-local: [ipv6]
      mtu: 9000
    ${fab1_name}:
      dhcp4: false
      link-local: [ipv6]
      mtu: 9000
FABEOF
        sudo sed -i 's/^bgpd=no/bgpd=yes/' /etc/frr/daemons 2>/dev/null || true
        sudo sed -i 's/^zebra=no/zebra=yes/' /etc/frr/daemons 2>/dev/null || true
        echo '${frr_conf}' | sudo tee /etc/frr/frr.conf > /dev/null
        sudo chown frr:frr /etc/frr/frr.conf
        sudo chmod 640 /etc/frr/frr.conf
        sudo netplan apply 2>/dev/null || true
        sudo systemctl restart frr
    " >/dev/null 2>&1 \
        && ok "$vm FRR configuration reconciled" \
        || warn "$vm FRR reconciliation failed"
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

repair_mikrotik_peer() {
    local vm="$1"
    local ip="$2"
    local bridge="$3"
    local local_ip="$4"
    local remote_ip="$5"
    local local_as="$6"
    local remote_as="$7"
    local conn_name="$8"

    local data_mac data_if ros_cmd
    data_mac=$(${VIRSH} domiflist "$vm" 2>/dev/null | awk -v br="$bridge" '$3==br {print toupper($5); exit}')
    if [[ -z "$data_mac" ]]; then
        warn "$vm: could not determine data MAC for $bridge"
        return 1
    fi

    data_if=$(routeros_cmd "$ip" ":put [/interface/get [find where mac-address=\"$data_mac\"] name]" 2>/dev/null | tr -d '\r' | tail -n1)
    if [[ -z "$data_if" ]]; then
        warn "$vm: could not map MAC $data_mac to RouterOS interface"
        return 1
    fi

    ros_cmd="
        /interface enable ${data_if};
        /ip address remove [find where address=\"${local_ip}/31\"];
        /ip address add address=${local_ip}/31 interface=${data_if};
        /routing bgp session reset [find];
        /routing bgp connection remove [find];
        /routing bgp template set default as=${local_as} router-id=${local_ip} hold-time=3m keepalive-time=1m afi=ip;
        /routing bgp instance set default as=${local_as} router-id=${local_ip};
        /routing bgp connection add name=${conn_name} templates=default local.address=${local_ip} local.role=ebgp remote.address=${remote_ip}/32 remote.as=${remote_as} connect=yes listen=yes;
        /ip firewall filter remove [find where comment~\"accept-bgp-fabric\"];
        /ip firewall filter add chain=input action=accept protocol=tcp src-address=10.0.253.0/24 dst-port=179 comment=accept-bgp-fabric;
        /ip firewall filter add chain=input action=accept protocol=udp src-address=10.0.253.0/24 dst-port=3784,3785 comment=accept-bfd;
    "

    routeros_cmd "$ip" "$ros_cmd" >/dev/null 2>&1 \
        && ok "$vm RouterOS peer reconciled on ${data_if}" \
        || warn "$vm RouterOS reconciliation failed"
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
    repair_host_frr "$vm"
done

phase "Phase 2.5 - MikroTik edge cleanup"
repair_mikrotik_peer Exit_Router1 172.16.2.98 br-BL1-ER1 10.0.253.1 10.0.253.0 65253 65021 to-BL1
repair_mikrotik_peer Exit_Router2 172.16.2.99 br-BL2-ER2 10.0.253.3 10.0.253.2 65254 65022 to-BL2

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