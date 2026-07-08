---
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
