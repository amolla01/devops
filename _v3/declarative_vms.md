---
inventory/hosts.yml
---
# =============================================================================
# L3 CLOS Fabric Inventory (MERGED SSOT)
# =============================================================================
# Topology: 2 Spines → 4 Leaves + 2 Border Leaves → Exit Router
#           6 Multi-Homed Ubuntu Host Servers (dual-connected to leaf pairs)
#           4 Dedicated Ceph Storage Servers (HDD + SSD tiers)
#           1 Monitoring Server
#
# Switch Hardware:
#   Spine:        Celestica DX010 (Seastone)   - 32x100G QSFP28, Broadcom Tomahawk
#   Leaf_L1/L2:  Edgecore/Accton AS5712-54X   - 48x10G SFP+ + 6x40G QSFP+, Trident II
#   Leaf_L3/L4:  Arista 7050QX-32S            - 32x40G QSFP+, Broadcom Trident II
#   Border-Leaf: Arista 7050QX-32S            - 32x40G QSFP+, Broadcom Trident II
#
# Networks:
#   Management:   172.16.2.0/24  (libvirt NAT in KVM, reachable from hypervisor)
#   iDRAC / PXE:  192.168.255.0/25  (OOB server management)
#   Loopback (switches): 10.0.0.0/24 (spines), 10.0.1.0/24 (leaves), 10.0.2.0/24 (border)
#   Loopback (servers):  10.10.255.0/24 (announced via FRR BGP)
#   Fabric P2P:          IPv6 link-local with BGP unnumbered
# =============================================================================
all:
  # 🧠 THE DEFINITIVE INVENTORY OVERRIDE:
  vars:
    ansible_ssh_private_key_file: "/mnt/c/Users/nh1221/.ssh/id_dc_lab"
    ansible_ssh_common_args: "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
  children:
    # =================================================================
    # Management / Observability (service-tier groups)
    # =================================================================
    management_services:
      hosts:
        HostB12_1:

    observability:
      hosts:
        MonitorSrv:

    # =================================================================
    # SONiC Network Switches
    # =================================================================
    spines:
      hosts:
        Spine_S1: { ansible_host: 10.10.1.48 }
        Spine_S2: { ansible_host: 10.10.1.47 }

    accton_leaves:
      hosts:
        Leaf_L1:  { ansible_host: 10.10.1.46 }
        Leaf_L2:  { ansible_host: 10.10.1.45 }

    # Group 1 for standard 7050QX-32 platform profiles
    arista_qx32_leaves:
      hosts:
        Leaf_L3:  { ansible_host: 10.10.1.44 }
        Leaf_L4:  { ansible_host: 10.10.1.43 }

    # Group 2 for specialized 7050QX-32S border platforms
    arista_qx32s_borders:
      hosts:
        Border_Leaf1: { ansible_host: 10.10.1.42 }
        Border_Leaf2: { ansible_host: 10.10.1.41 }

    exit_routers:
      hosts:
        Exit_Router1: { ansible_host: 10.10.1.40 }
        Exit_Router2: { ansible_host: 10.10.1.39 }

    # sonic_switches:
    #   children:
    #     spines:
    #       hosts:
    #         Spine_S1:
    #           ansible_host: 10.10.1.48
    #         Spine_S2:
    #           ansible_host: 10.10.1.47
    #     leaves:
    #       children:
    #         leaf_accton:       # Accton/Edgecore AS5712-54X — serves host pair 12
    #           hosts:
    #             Leaf_L1:
    #               ansible_host: 10.10.1.46
    #             Leaf_L2:
    #               ansible_host: 10.10.1.45
    #         leaf_arista:       # Arista 7050QX-32S — serves host pair 34
    #           hosts:
    #             Leaf_L3:
    #               ansible_host: 10.10.1.44
    #             Leaf_L4:
    #               ansible_host: 10.10.1.43
    #     border_leaves:
    #       hosts:
    #         Border_Leaf1:
    #           ansible_host: 10.10.1.42
    #         Border_Leaf2:
    #           ansible_host: 10.10.1.41

    # =================================================================
    # Exit Routers (Now Ubuntu VMs - not SONiC/Mikrotik managed)
    # =================================================================
    # exit_routers:
    #   hosts:
    #     Exit_Router1:
    #       ansible_host: 10.10.1.40
    #       # 🧠 FORCE HIGH-PRECEDENCE HOST VARIABLE PINNING:
    #       # ansible_user: ubuntu
    #     Exit_Router2:
    #       ansible_host: 10.10.1.39
    #       # ansible_user: ubuntu

    # =================================================================
    # Ubuntu Host Servers (bare-metal, MaaS-commissioned)
    # =================================================================
    servers:
      vars:
        ansible_user: ubuntu
        ansible_password: "{{ vault_ansible_password | default('Welcome0!') }}"
        ansible_become: true
      children:
        servers_leaf_pair_12:
          hosts:
            Host12_1:
              ansible_host: 10.10.1.30
              idrac_pxe_ip: 192.168.255.11
            Host12_2:
              ansible_host: 10.10.1.29
              idrac_pxe_ip: 192.168.255.12
            Host12_3:
              ansible_host: 10.10.1.28
              idrac_pxe_ip: 192.168.255.13
        servers_leaf_pair_34:
          hosts:
            Host34_1:
              ansible_host: 10.10.1.27
              idrac_pxe_ip: 192.168.255.21
            Host34_2:
              ansible_host: 10.10.1.26
              idrac_pxe_ip: 192.168.255.22
            MonitorSrv:
              ansible_host: 10.10.1.10
              idrac_pxe_ip: 192.168.255.33              
        servers_border:
          hosts:
            HostB12_1:
              ansible_host: 10.10.1.25
              idrac_pxe_ip: 192.168.255.31
            HostB12_2:
              ansible_host: 10.10.1.24
              idrac_pxe_ip: 192.168.255.32

    # =================================================================
    # Kubernetes Roles
    # =================================================================
    kube_controllers:
      hosts:
        Host12_1:
          kube_node_name: "host12-1"
          etcd_member_name: "host12-1"
        Host34_1:
          kube_node_name: "host34-1"
          etcd_member_name: "host34-1"
        HostB12_1:
          kube_node_name: "hostb12-1"
          etcd_member_name: "hostb12-1"
    kube_workers:
      hosts:
        Host12_2:
          kube_node_name: "host12-2"
        Host12_3:
          kube_node_name: "host12-3"
        Host34_2:
          kube_node_name: "host34-2"

    # Parent group: all Kubernetes nodes (controllers + workers)
    kube_nodes:
      children:
        kube_controllers:
        kube_workers:

    # Aliases — some playbooks use k8_ prefix
    k8_controllers:
      children:
        kube_controllers:
    k8_workers:
      children:
        kube_workers:
    k8_nodes:
      children:
        kube_nodes:

    # =================================================================
    # Ceph Storage Roles
    # =================================================================
    ceph_mon:
      hosts:
        Host12_1:
          monitor_address: "10.10.1.30"
        Host34_1:
          monitor_address: "10.10.1.27"
        HostB12_1:
          monitor_address: "10.10.1.25"        
    ceph_osd:
      hosts:
        Host12_1:
          ceph_osd_devices: ["/dev/vdb", "/dev/vdc"]
        Host12_2:
          ceph_osd_devices: ["/dev/vdb", "/dev/vdc"]
        Host12_3:
          ceph_osd_devices: ["/dev/vdb", "/dev/vdc"]
        Host34_1:
          ceph_osd_devices: ["/dev/vdb", "/dev/vdc"]
        Host34_2:
          ceph_osd_devices: ["/dev/vdb", "/dev/vdc"]
        HostB12_1:
          ceph_osd_devices: ["/dev/vdb"]
        # -----------------------------------------------------------
        # Real-hardware storage servers (commented out for KVM lab)
        # Uncomment when deploying on real_hardware profile
        # -----------------------------------------------------------
        # Storage_Server_HDD_01:
        #   ceph_osd_devices: ["/dev/sda", "/dev/sdb", "/dev/sdc", "/dev/sdd"]
        #   ceph_crush_device_class: "hdd"
        # Storage_Server_HDD_02:
        #   ceph_osd_devices: ["/dev/sda", "/dev/sdb", "/dev/sdc", "/dev/sdd"]
        #   ceph_crush_device_class: "hdd"
        # Storage_Server_SSD_01:
        #   ceph_osd_devices: ["/dev/nvme0n1", "/dev/nvme1n1", "/dev/nvme2n1", "/dev/nvme3n1"]
        #   ceph_crush_device_class: "ssd"
        # Storage_Server_SSD_02:
        #   ceph_osd_devices: ["/dev/nvme0n1", "/dev/nvme1n1", "/dev/nvme2n1", "/dev/nvme3n1"]
        #   ceph_crush_device_class: "ssd"

    # Convenience aliases used in _v3 playbooks
    ceph_controllers:
      children:
        ceph_mon:
    ceph_storage:
      children:
        ceph_osd:

    # =================================================================
    # OpenStack Roles
    # =================================================================
    openstack_controllers:
      hosts:
        Host12_1:
          os_controller_priority: 100
        Host34_1:
          os_controller_priority: 90
    openstack_computes:
      hosts:
        Host12_2:
          os_availability_zone: "az-pod12"
        Host12_3:
          os_availability_zone: "az-pod12"
        Host34_2:
          os_availability_zone: "az-pod34"
    openstack_gateways:
      hosts:
        HostB12_1:
          os_gateway_role: "primary"
        HostB12_2:
          os_gateway_role: "secondary"

    # Parent group: all OpenStack nodes (controllers + computes + gateways)
    openstack_nodes:
      children:
        openstack_controllers:
        openstack_computes:
        openstack_gateways:

    # Aliases — some playbooks use singular
    openstack_compute:
      children:
        openstack_computes:

    premium_firewall_nodes:
      hosts:
        HostB12_1:
        HostB12_2:

    # =================================================================
    # EVPN Hypervisors (BGP/EVPN-to-the-Host)
    # =================================================================
    # Servers participating in EVPN overlay (FRR + VXLAN + VRF).
    # Phase 1: Static VRF/VNI provisioned by Ansible
    # Phase 2: Dynamic route advertisement via OVN BGP Agent
    # =================================================================
    evpn_hypervisors:
      hosts:
        Host12_1:
          evpn_vtep_ip: "10.10.255.1"
          evpn_server_id: 1
        Host12_2:
          evpn_vtep_ip: "10.10.255.2"
          evpn_server_id: 2
        Host12_3:
          evpn_vtep_ip: "10.10.255.3"
          evpn_server_id: 3
        Host34_1:
          evpn_vtep_ip: "10.10.255.11"
          evpn_server_id: 4
        Host34_2:
          evpn_vtep_ip: "10.10.255.12"
          evpn_server_id: 5
        HostB12_1:
          evpn_vtep_ip: "10.10.255.100"
          evpn_server_id: 6

    # =================================================================
    # Centralized Monitoring & Syslog Server
    # =================================================================
    monitoring_servers:
      hosts:
        MonitorSrv:
          syslog_listen_ip: "10.10.255.102"
          grafana_port: 3000
          loki_port: 3100
          prometheus_port: 9090
          alertmanager_port: 9093
# =================================================================
# QoS Performance Verification Meta-Group (Target Footprint)
# =================================================================
    qos_test_group:
      hosts:
        Host12_1:
          ansible_host: 10.10.1.30 # Your standard SSH management IP
          loopback_ip: "10.10.255.1"  # Maps to your 'lo' workload subnet identity
          ceph_data_replication_ip: "20.0.12.1" # Maps to your 'dummy ceph' subnet identity
          fabric_interfaces: [{name: "enp2s0"}, {name: "enp3s0"}] # The physical multi-homed interface where 'tc' shaping runs
        Host12_2:
          ansible_host: 10.10.1.29 # Your standard SSH management IP
          loopback_ip: "10.10.255.2"  # Maps to your 'lo' workload subnet identity
          ceph_data_replication_ip: "20.0.12.2" # Maps to your 'dummy ceph' subnet identity
          fabric_interfaces: [{name: "enp2s0"}, {name: "enp3s0"}] # The physical multi-homed interface where 'tc' shaping runs
        Host12_3:
          ansible_host: 10.10.1.28 # Your standard SSH management IP
          loopback_ip: "10.10.255.3"  # Maps to your 'lo' workload subnet identity
          ceph_data_replication_ip: "20.0.12.3" # Maps to your 'dummy ceph' subnet identity
          fabric_interfaces: [{name: "enp2s0"}, {name: "enp3s0"}] # The physical multi-homed interface where 'tc' shaping runs
        Host34_1:
          ansible_host: 10.10.1.27 # Your standard SSH management IP
          loopback_ip: "10.10.255.11"  # Maps to your 'lo' workload subnet identity
          ceph_data_replication_ip: "20.0.34.1" # Maps to your 'dummy ceph' subnet identity
          fabric_interfaces: [{name: "enp2s0"}, {name: "enp3s0"}] # The physical multi-homed interface where 'tc' shaping runs
        Host34_2:
          ansible_host: 10.10.1.26 # Your standard SSH management IP
          loopback_ip: "10.10.255.12"  # Maps to your 'lo' workload subnet identity
          ceph_data_replication_ip: "20.0.34.2" # Maps to your 'dummy ceph' subnet identity
          fabric_interfaces: [{name: "enp2s0"}, {name: "enp3s0"}] # The physical multi-homed interface where 'tc' shaping runs
        HostB12_1:
          ansible_host: 10.10.1.25 # Your standard SSH management IP
          loopback_ip: "10.10.255.100"  # Maps to your 'lo' workload subnet identity
          ceph_data_replication_ip: "20.0.56.1" # Maps to your 'dummy ceph' subnet identity
          fabric_interfaces: [{name: "enp2s0"}, {name: "enp3s0"}] # The physical multi-homed interface where 'tc' shaping runs
        HostB12_2:
          ansible_host: 10.10.1.24 # Your standard SSH management IP
          loopback_ip: "10.10.255.101"  # Maps to your 'lo' workload subnet identity
          ceph_data_replication_ip: "20.0.56.2" # Maps to your 'dummy ceph' subnet identity
          fabric_interfaces: [{name: "enp2s0"}, {name: "enp3s0"}] # The physical multi-homed interface where 'tc' shaping runs
        MonitorSrv:
          ansible_host: 10.10.1.10 # Your standard SSH management IP
          loopback_ip: "10.10.255.102"  # Maps to your 'lo' workload subnet identity
          ceph_data_replication_ip: "20.0.56.3" # Maps to your 'dummy ceph' subnet identity
          fabric_interfaces: [{name: "enp2s0"}, {name: "enp3s0"}] # The physical multi-homed interface where 'tc' shaping runs

    metallb_l2:
      children:
        servers:
        border_leaves:
        exit_routers:

---
group_vars/accton_leaves.yml
# Authoritative mapping structure for Accton flat string lists
all_ports: "{{ as5712_sfp_ports + as5712_qsfp_ports }}"
platform_speed_fallback: "10000"
---
group_vars/arista_qx32_leaves.yml
# Authoritative hardware profile mapping for the base Arista 7050QX-32
all_ports: "{{ qx32_all_ports | default({}) }}"
platform_speed_fallback: "40000"
---
group_vars/arista_qx32s_borders.yml
# Authoritative hardware profile mapping for the specialized Arista 7050QX-32S
all_ports: "{{ qx32s_all_ports | default({}) }}"
platform_speed_fallback: "40000"
---
group_vars/exit_routers.yml
wireguard_peers:
  - name: "Admin_Laptop_Primary"
    public_key: "PASTE_YOUR_LAPTOP_PUBLIC_KEY_HERE="
    allowed_ips: "192.168.100.10/32"

  - name: "Admin_Laptop_Backup"
    public_key: "PASTE_SECONDARY_LAPTOP_PUBLIC_KEY_HERE="
    allowed_ips: "192.168.100.11/32"
---
group_vars/spines.yml
# Authoritative mapping structure for Celestica Spine dict arrays
all_ports: "{{ dx010_all_ports | default({}) }}"
platform_speed_fallback: "100000"
```
hostname: "Spine_S1"
router_id: "10.0.0.1"
bgp_local_asn: 65000
hwsku: "Seastone-DX010"
platform: "x86_64-cel_seastone-r0"

switch_ports:
  # Downlinks to the standard Leaf Switch block
  Ethernet0:  { breakout: "none", speed: "40000", lanes: "65,66,67,68", index: "1", neighbor: "Leaf_L1", rem_port: "Ethernet68" }
  Ethernet4:  { breakout: "none", speed: "40000", lanes: "69,70,71,72", index: "2", neighbor: "Leaf_L2", rem_port: "Ethernet68" }
  Ethernet8:  { breakout: "none", speed: "40000", lanes: "73,74,75,76", index: "3", neighbor: "Leaf_L3", rem_port: "Ethernet124" }
  Ethernet12: { breakout: "none", speed: "40000", lanes: "77,78,79,80", index: "4", neighbor: "Leaf_L4", rem_port: "Ethernet124" }
  
  # Uplinks to the Border Leaf Edge blocks
  Ethernet16: { breakout: "none", speed: "40000", lanes: "33,34,35,36", index: "5", neighbor: "Border_Leaf1", rem_port: "Ethernet124" }
  Ethernet20: { breakout: "none", speed: "40000", lanes: "37,38,39,40", index: "6", neighbor: "Border_Leaf2", rem_port: "Ethernet124" }

# Safe empty array fallback to satisfy the template engine pipeline
breakout_configurations: {}

---

hostname: "Spine_S2"
router_id: "10.0.0.2"
bgp_local_asn: 65000
hwsku: "Seastone-DX010"
platform: "x86_64-cel_seastone-r0"
mac_address: "00:e0:ec:8a:1a:39"
mgmt_ip: "10.10.1.47"
mgmt_gateway: "10.10.1.1"

switch_ports:
  # Downlinks to the standard Leaf Switch block
  Ethernet0:  { breakout: "none", speed: "40000", lanes: "65,66,67,68", index: "1", neighbor: "Leaf_L1", rem_port: "Ethernet64" }
  Ethernet4:  { breakout: "none", speed: "40000", lanes: "69,70,71,72", index: "2", neighbor: "Leaf_L2", rem_port: "Ethernet64" }
  Ethernet8:  { breakout: "none", speed: "40000", lanes: "73,74,75,76", index: "3", neighbor: "Leaf_L3", rem_port: "Ethernet120" }
  Ethernet12: { breakout: "none", speed: "40000", lanes: "77,78,79,80", index: "4", neighbor: "Leaf_L4", rem_port: "Ethernet120" }
  
  # Uplinks to the Border Leaf Edge blocks
  Ethernet16: { breakout: "none", speed: "40000", lanes: "33,34,35,36", index: "5", neighbor: "Border_Leaf1", rem_port: "Ethernet120" }
  Ethernet20: { breakout: "none", speed: "40000", lanes: "37,38,39,40", index: "6", neighbor: "Border_Leaf2", rem_port: "Ethernet120" }

breakout_configurations: {}
```
---
```
hostname: "Leaf_L1"
router_id: "10.0.1.1"
bgp_local_asn: 65011
hwsku: "Accton-AS5712-54X"
platform: "x86_64-accton_as5712_54x-r0"
mac_address: "00:1c:73:a1:01:01"
mgmt_ip: "10.10.1.46"
mgmt_gateway: "10.10.1.1"

switch_ports:
  # --- Backbone Uplinks to Spines (Flat Naming via Breakout Sub-Ports) ---
  # KVM NIC54 maps to Spine_S1; KVM NIC53 maps to Spine_S2
  Ethernet68: { breakout: "none", speed: "10000", lanes: "77",  index: "54", neighbor: "Spine_S1", rem_port: "Ethernet0" }
  Ethernet64: { breakout: "none", speed: "10000", lanes: "109", index: "53", neighbor: "Spine_S2", rem_port: "Ethernet0" }

  # --- Access Downlinks to Compute Servers (Standard 10G SFP+ Interfaces) ---
  # KVM Data NICs 1, 2, and 3 wiring directly out to the host servers
  Ethernet0: { breakout: "none", speed: "10000", lanes: "13", index: "1", role: "access", neighbor: "Host12_1", rem_port: "enp2s0", neighbor_asn: 65234 }
  Ethernet1: { breakout: "none", speed: "10000", lanes: "14", index: "2", role: "access", neighbor: "Host12_2", rem_port: "enp2s0", neighbor_asn: 65235 }
  Ethernet2: { breakout: "none", speed: "10000", lanes: "15", index: "3", role: "access", neighbor: "Host12_3", rem_port: "enp2s0", neighbor_asn: 65236 }

# Tells Stage 4 to pull the flat string list configuration inherited via group_vars
breakout_configurations: {}
```
---
```
hostname: "Leaf_L2"
router_id: "10.0.1.2"
bgp_local_asn: 65012
hwsku: "Accton-AS5712-54X"
platform: "x86_64-accton_as5712_54x-r0"
mac_address: "00:1c:73:a1:01:02"
mgmt_ip: "10.10.1.45"
mgmt_gateway: "10.10.1.1"

switch_ports:
  # --- Backbone Uplinks to Spines (Flat Naming via Breakout Sub-Ports) ---
  Ethernet68: { breakout: "none", speed: "10000", lanes: "77",  index: "54", neighbor: "Spine_S1", rem_port: "Ethernet4" }
  Ethernet64: { breakout: "none", speed: "10000", lanes: "109", index: "53", neighbor: "Spine_S2", rem_port: "Ethernet4" }

  # --- Access Downlinks to Compute Servers (Standard 10G SFP+ Interfaces) ---
  Ethernet0: { breakout: "none", speed: "10000", lanes: "13", index: "1", role: "access", neighbor: "Host12_1", rem_port: "enp3s0", neighbor_asn: 65234 }
  Ethernet1: { breakout: "none", speed: "10000", lanes: "14", index: "2", role: "access", neighbor: "Host12_2", rem_port: "enp3s0", neighbor_asn: 65235 }
  Ethernet2: { breakout: "none", speed: "10000", lanes: "15", index: "3", role: "access", neighbor: "Host12_3", rem_port: "enp3s0", neighbor_asn: 65236 }

breakout_configurations: {}
```
---
```
hostname: "Leaf_L3"
router_id: "10.0.1.3"
bgp_local_asn: 65013
hwsku: "Arista-7050-QX32"
platform: "x86_64-arista_7050_qx32"

switch_ports:
  # Uplinks to Transit Spines (Non-Breakout 40G)
  Ethernet124: { breakout: "none", speed: "40000", role: "fabric", lanes: "1,2,3,4", index: "32", neighbor: "Spine_S1", rem_port: "Ethernet8" }
  Ethernet120: { breakout: "none", speed: "40000", role: "fabric", lanes: "5,6,7,8", index: "31", neighbor: "Spine_S2", rem_port: "Ethernet8" }
  
  # Downlinks to Compute Servers (4x10G Breakout Split)
  Ethernet0:
    breakout: "4x10G"
    role: "access"
    children:
      - { name: "Ethernet0", alias: "Ethernet1/1", lanes: "125", index: "1", speed: "10000", neighbor: "Host34_1",   rem_port: "enp2s0", neighbor_asn: 65234 }
      - { name: "Ethernet1", alias: "Ethernet1/2", lanes: "126", index: "1", speed: "10000", neighbor: "Host34_2",   rem_port: "enp2s0", neighbor_asn: 65235 }
      - { name: "Ethernet2", alias: "Ethernet1/3", lanes: "127", index: "1", speed: "10000", neighbor: "MonitorSrv", rem_port: "enp2s0", neighbor_asn: 65301 }
      - { name: "Ethernet3", alias: "Ethernet1/4", lanes: "128", index: "1", speed: "10000", admin: "down" } # Unused cage track

```
---
```
hostname: "Leaf_L4"
router_id: "10.0.1.4"
bgp_local_asn: 65014
hwsku: "Arista-7050-QX32"
platform: "x86_64-arista_7050_qx32"
mac_address: "00:1c:73:a1:03:02"
mgmt_ip: "10.10.1.43"
mgmt_gateway: "10.10.1.1"

switch_ports:
  # Uplinks to Transit Spines (Non-Breakout 40G)
  Ethernet124: { breakout: "none", speed: "40000", role: "fabric", lanes: "1,2,3,4", index: "32", neighbor: "Spine_S1", rem_port: "Ethernet12" }
  Ethernet120: { breakout: "none", speed: "40000", role: "fabric", lanes: "5,6,7,8", index: "31", neighbor: "Spine_S2", rem_port: "Ethernet12" }
  
  # Downlinks to Compute Servers (4x10G Breakout Split)
  Ethernet0:
    breakout: "4x10G"
    role: "access"
    children:
      - { name: "Ethernet0", alias: "Ethernet1/1", lanes: "125", index: "1", speed: "10000", neighbor: "Host34_1",   rem_port: "enp3s0", neighbor_asn: 65234 }
      - { name: "Ethernet1", alias: "Ethernet1/2", lanes: "126", index: "1", speed: "10000", neighbor: "Host34_2",   rem_port: "enp3s0", neighbor_asn: 65235 }
      - { name: "Ethernet2", alias: "Ethernet1/3", lanes: "127", index: "1", speed: "10000", neighbor: "MonitorSrv", rem_port: "enp3s0", neighbor_asn: 65301 }
      - { name: "Ethernet3", alias: "Ethernet1/4", lanes: "128", index: "1", speed: "10000", admin: "down" }
```
---
```
hostname: "Border_Leaf1"
router_id: "10.0.2.1"
bgp_local_asn: 65021
hwsku: "Arista-7050-QX32S"
platform: "x86_64-arista_7050_qx32s"
mac_address: "00:e0:ec:57:12:01"
mgmt_ip: "10.10.1.42"
mgmt_gateway: "10.10.1.1"

switch_ports:
  # --- Backbone Uplinks to Transit Spines (Native 40G QSFP+ Connections) ---
  Ethernet124: { breakout: "none", speed: "40000", lanes: "5,6,7,8", index: "36", neighbor: "Spine_S1", rem_port: "Ethernet16" }
  Ethernet120: { breakout: "none", speed: "40000", lanes: "1,2,3,4", index: "35", neighbor: "Spine_S2", rem_port: "Ethernet16" }

  # --- Perimeter Access Breakouts (Channel Splits handling Router Transit & Ceph Storage) ---
  Ethernet0:
    breakout: "4x10G"
    role: "access"
    children:
      # Northbound Internet Transit Gateways connecting to Ubuntu Nodes
      - { name: "Ethernet0", alias: "Ethernet5/1", lanes: "9",  index: "5", speed: "10000", neighbor: "Exit_Router1", rem_port: "enp2s0", neighbor_asn: 65101 }
      - { name: "Ethernet1", alias: "Ethernet5/2", lanes: "10", index: "5", speed: "10000", neighbor: "Exit_Router2", rem_port: "enp2s0", neighbor_asn: 65102 }
      # High-Performance Ceph Storage Cluster Replication Interfaces
      - { name: "Ethernet2", alias: "Ethernet5/3", lanes: "11", index: "5", speed: "10000", neighbor: "HostB12_1",    rem_port: "cephport", neighbor_asn: 65250 }
      - { name: "Ethernet3", alias: "Ethernet5/4", lanes: "12", index: "5", speed: "10000", neighbor: "HostB12_2",    rem_port: "cephport", neighbor_asn: 65251 }

# Virtual Overlay Definitions
fabric_vrfs:
  - { name: "vrf-transit", table_id: 102 }
  - { name: "vrf-storage", table_id: 101 }

fabric_vlans:
  - { id: 10, name: "Vlan10", vrf_binding: "vrf-transit" }
  - { id: 20, name: "Vlan20", vrf_binding: "vrf-storage" }
```
---
```
hostname: "Border_Leaf2"
router_id: "10.0.2.2"
bgp_local_asn: 65022
hwsku: "Arista-7050-QX32S"
platform: "x86_64-arista_7050_qx32s"
mac_address: "00:e0:ec:57:12:02"
mgmt_ip: "10.10.1.41"
mgmt_gateway: "10.10.1.1"

switch_ports:
  # Backbone Uplinks connecting to Spines
  Ethernet124: { breakout: "none", speed: "40000", lanes: "5,6,7,8", index: "36", neighbor: "Spine_S1", rem_port: "Ethernet20" }
  Ethernet120: { breakout: "none", speed: "40000", lanes: "1,2,3,4", index: "35", neighbor: "Spine_S2", rem_port: "Ethernet20" }
  
  # Perimeter Access Breakouts handling Exit Infrastructure and High-Sec Host Nodes
  Ethernet0:
    breakout: "4x10G"
    role: "access"
    children:
      - { name: "Ethernet0", alias: "Ethernet5/1", lanes: "9",  index: "5", speed: "10000", neighbor: "Exit_Router2", rem_port: "enp3s0", neighbor_asn: 65102 }
      - { name: "Ethernet1", alias: "Ethernet5/2", lanes: "10", index: "5", speed: "10000", neighbor: "Exit_Router1", rem_port: "enp3s0", neighbor_asn: 65101 }
      - { name: "Ethernet2", alias: "Ethernet5/3", lanes: "11", index: "5", speed: "10000", neighbor: "HostB12_1",    rem_port: "enp3s0", neighbor_asn: 65250 }
      - { name: "Ethernet3", alias: "Ethernet5/4", lanes: "12", index: "5", speed: "10000", neighbor: "HostB12_2",    rem_port: "enp3s0", neighbor_asn: 65251 }

# Authoritative VRF Multi-Instance Assignments
fabric_vrfs:
  - { name: "vrf-transit", table_id: 102 }
  - { name: "vrf-storage", table_id: 101 }

# Bind your transit networks and storage subnets securely to their respective VRFs
fabric_vlans:
  - { id: 10, name: "Vlan10", vrf_binding: "vrf-transit" }
  - { id: 20, name: "Vlan20", vrf_binding: "vrf-storage" }
```
---
```
hostname: "Exit_Router1"
mgmt_ip: "10.10.1.40"
mgmt_gateway: "10.10.1.1"
bgp_local_asn: 65101

# 🧠 TRANSPORT WIRING MATRIX — MULTI-HOMED TO EDGE BORDERS
server_interfaces:
  enp2s0:
    speed: "10000"
    connected_to: "Border_Leaf1"
    switch_port: "Ethernet0"
    breakout_channel: "0"          # Maps directly to Border_Leaf1's Ethernet5/1 sub-interface
    neighbor_asn: 65021
  enp3s0:
    speed: "10000"
    connected_to: "Border_Leaf2"
    switch_port: "Ethernet0"
    breakout_channel: "0"          # Maps directly to Border_Leaf2's Ethernet5/1 sub-interface
    neighbor_asn: 65022

```
---
```
hostname: "Exit_Router2"
mgmt_ip: "10.10.1.39"
bgp_local_asn: 65102

# Documents the server's local interfaces wiring back into the Border Leaf block
server_interfaces:
  enp2s0:
    speed: "10000"
    connected_to: "Border_Leaf1"
    switch_port: "Ethernet0"
    breakout_channel: "1"          # Maps directly to sub-interface Ethernet5/2 on Border 1
    neighbor_asn: 65021
  enp3s0:
    speed: "10000"
    connected_to: "Border_Leaf2"
    switch_port: "Ethernet0"
    breakout_channel: "1"          # Maps directly to sub-interface Ethernet5/2 on Border 2
    neighbor_asn: 65022
```
---
```
hostname: "Host12_1"
mgmt_ip: "10.10.1.31"
mgmt_gateway: "10.10.1.1"
bgp_local_asn: 65234

# 🧠 INTERFACE WIRING MATRIX — MULTI-HOMED TO ACCTON FABRICS
server_interfaces:
  enp2s0:
    speed: "10000"
    connected_to: "Leaf_L1"
    switch_port: "Ethernet0"        # Direct physical 10G SFP+ slot on Leaf_L1
    neighbor_asn: 65011
  enp3s0:
    speed: "10000"
    connected_to: "Leaf_L2"
    switch_port: "Ethernet0"        # Direct physical 10G SFP+ slot on Leaf_L2
    neighbor_asn: 65012

# 🧠 MULTI-VRF INTENT AND CORE WORKLOAD ADDRESS IDENTITIES
loopback_ip: "10.0.10.1/32"
ceph_storage_ip: "192.168.20.11/32"
```
---
```
hostname: "Host12_2"
mgmt_ip: "10.10.1.32"
mgmt_gateway: "10.10.1.1"
bgp_local_asn: 65235

# 🧠 INTERFACE WIRING MATRIX — MULTI-HOMED TO ACCTON FABRICS
server_interfaces:
  enp2s0:
    speed: "10000"
    connected_to: "Leaf_L1"
    switch_port: "Ethernet1"
    neighbor_asn: 65011
  enp3s0:
    speed: "10000"
    connected_to: "Leaf_L2"
    switch_port: "Ethernet1"
    neighbor_asn: 65012

# 🧠 MULTI-VRF INTENT AND CORE WORKLOAD ADDRESS IDENTITIES
loopback_ip: "10.0.10.2/32"
ceph_storage_ip: "192.168.20.12/32"
```
---
```
hostname: "Host12_3"
mgmt_ip: "10.10.1.33"
mgmt_gateway: "10.10.1.1"
bgp_local_asn: 65236

# 🧠 INTERFACE WIRING MATRIX — MULTI-HOMED TO ACCTON FABRICS
server_interfaces:
  enp2s0:
    speed: "10000"
    connected_to: "Leaf_L1"
    switch_port: "Ethernet2"
    neighbor_asn: 65011
  enp3s0:
    speed: "10000"
    connected_to: "Leaf_L2"
    switch_port: "Ethernet2"
    neighbor_asn: 65012

# 🧠 MULTI-VRF INTENT AND CORE WORKLOAD ADDRESS IDENTITIES
loopback_ip: "10.0.10.3/32"
ceph_storage_ip: "192.168.20.13/32"
```
---
```
hostname: "Host34_1"
mgmt_ip: "10.10.1.27"
mgmt_gateway: "10.10.1.1"
bgp_local_asn: 65237

# 🧠 INTERFACE WIRING MATRIX — MULTI-HOMED TO ARISTA LEAVES
server_interfaces:
  enp2s0:
    speed: "10000"
    connected_to: "Leaf_L3"
    switch_port: "Ethernet0"
    breakout_channel: "0"          # Maps to sub-interface key Ethernet1/1 on Leaf_L3
    neighbor_asn: 65013
  enp3s0:
    speed: "10000"
    connected_to: "Leaf_L4"
    switch_port: "Ethernet0"
    breakout_channel: "0"          # Maps to sub-interface key Ethernet1/1 on Leaf_L4
    neighbor_asn: 65014

loopback_ip: "10.0.20.1/32"
ceph_storage_ip: "192.168.20.21/32"

```
---
```
hostname: "Host34_2"
mgmt_ip: "10.10.1.28"
mgmt_gateway: "10.10.1.1"
bgp_local_asn: 65238

# 🧠 INTERFACE WIRING MATRIX — MULTI-HOMED TO ARISTA BREAKOUT FABRICS
server_interfaces:
  enp2s0:
    speed: "10000"
    connected_to: "Leaf_L3"
    switch_port: "Ethernet0"
    breakout_channel: "1"          # Maps cleanly to Arista sub-interface key Ethernet1/2
    neighbor_asn: 65013
  enp3s0:
    speed: "10000"
    connected_to: "Leaf_L4"
    switch_port: "Ethernet0"
    breakout_channel: "1"          # Maps cleanly to Arista sub-interface key Ethernet1/2
    neighbor_asn: 65014

# 🧠 MULTI-VRF INTENT AND CORE WORKLOAD ADDRESS IDENTITIES
loopback_ip: "10.0.20.2/32"
ceph_storage_ip: "192.168.20.22/32"
``
---
```
hostname: "MonitorSrv"
mgmt_ip: "10.10.1.10"
mgmt_gateway: "10.10.1.1"
bgp_local_asn: 65301

# 🧠 MONITORING WIRE MECHANICS — DUAL-HOMED TO FABRIC
server_interfaces:
  enp2s0:
    speed: "10000"
    connected_to: "Leaf_L3"
    switch_port: "Ethernet0"
    breakout_channel: "2"          # Target sub-port Ethernet1/3 on Leaf_L3
    neighbor_asn: 65013
  enp3s0:
    speed: "10000"
    connected_to: "Leaf_L4"
    switch_port: "Ethernet0"
    breakout_channel: "2"          # Target sub-port Ethernet1/3 on Leaf_L4
    neighbor_asn: 65014

loopback_ip: "10.0.30.1/32"

```
---
```
hostname: "HostB12_1"
mgmt_ip: "10.10.1.25"
mgmt_gateway: "10.10.1.1"
bgp_local_asn: 65250

# 🧠 STORAGE FABRIC ATTACHMENT TIER
server_interfaces:
  enp2s0:
    speed: "10000"
    connected_to: "Border_Leaf1"
    switch_port: "Ethernet0"
    breakout_channel: "2"          # Maps directly to sub-interface Ethernet5/3 on Border 1
    neighbor_asn: 65021
  enp3s0:
    speed: "10000"
    connected_to: "Border_Leaf2"
    switch_port: "Ethernet0"
    breakout_channel: "2"          # Maps directly to sub-interface Ethernet5/3 on Border 2
    neighbor_asn: 65022

loopback_ip: "10.0.40.1/32"
ceph_storage_ip: "192.168.20.51/32"

```
---
```
hostname: "HostB12_2"
mgmt_ip: "10.10.1.24"
mgmt_gateway: "10.10.1.1"
bgp_local_asn: 65251

# 🧠 STORAGE FABRIC ATTACHMENT TIER
server_interfaces:
  enp2s0:
    speed: "10000"
    connected_to: "Border_Leaf1"
    switch_port: "Ethernet0"
    breakout_channel: "3"          # Maps directly to sub-interface Ethernet5/4 on Border 1
    neighbor_asn: 65021
  enp3s0:
    speed: "10000"
    connected_to: "Border_Leaf2"
    switch_port: "Ethernet0"
    breakout_channel: "3"          # Maps directly to sub-interface Ethernet5/4 on Border 2
    neighbor_asn: 65022

loopback_ip: "10.0.40.2/32"
ceph_storage_ip: "192.168.20.52/32"

```
