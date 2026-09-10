---
hostname: "Border-Leaf1"
router_id: "10.0.2.4"
bgp_local_asn: 65031
mgmt_ip: "172.16.2.31/24"
device_type: "LeafRouter"
hwsku: "Arista-7050-QX-32S"
platform: "x86_64-arista_7050_qx32s"
loopback_ip: "10.0.2.4/32"
# 7050-QX-32S: fabric on last QSFP+ (Ethernet124=idx36, Ethernet120=idx35)
# Breakout: Ethernet0 (idx5) → 4x10G (all 4 children used)
switch_ports:
  Ethernet124: { speed: "40000", role: "fabric", alias: "Ethernet36", lanes: "5,6,7,8", index: "36", neighbor: "Spine-S1", rem_port: "Ethernet16", neighbor_asn: 65000 }
  Ethernet120: { speed: "40000", role: "fabric", alias: "Ethernet35", lanes: "1,2,3,4", index: "35", neighbor: "Spine-S2", rem_port: "Ethernet16", neighbor_asn: 65000 }

access_ports:
  Ethernet0:
    breakout: "4x10G"
    role: "access"
    children:
      - { name: "Ethernet0", alias: "Ethernet5/1", lanes: "9", index: "5", speed: "10000", neighbor: "Exit-Router1", rem_port: "enp2s0", neighbor_asn: 65251 }
      - { name: "Ethernet1", alias: "Ethernet5/2", lanes: "10", index: "5", speed: "10000", neighbor: "Exit-Router2", rem_port: "enp2s0", neighbor_asn: 65252 }
      - { name: "Ethernet2", alias: "Ethernet5/3", lanes: "11", index: "5", speed: "10000", neighbor: "k8s-master-03", rem_port: "cephport", neighbor_asn: 65231 }
      - { name: "Ethernet3", alias: "Ethernet5/4", lanes: "12", index: "5", speed: "10000", neighbor: "k8s-db-03", rem_port: "cephport", neighbor_asn: 65232 }
  Ethernet4:
    breakout: "4x10G"
    role: "access"
    children:
      - { name: "Ethernet4", alias: "Ethernet6/1", lanes: "16", index: "6", speed: "10000", neighbor: "osh-ctrl-03", rem_port: "enp2s0", neighbor_asn: 65233 }
      - { name: "Ethernet5", alias: "Ethernet6/2", lanes: "17", index: "7", speed: "10000", neighbor: "MonSrv", rem_port: "enp2s0", neighbor_asn: 65234 }
      - { name: "Ethernet6", alias: "Ethernet6/3", lanes: "21", index: "8", speed: "10000", neighbor: "osh-comp-03", rem_port: "cephport", neighbor_asn: 65235 }
      - { name: "Ethernet7", alias: "Ethernet6/4", lanes: "29", index: "9", speed: "10000", neighbor: "none" }

  # Legacy flat access model retained for reference:
  # access_ports:
  #   Ethernet0: { speed: "10000", role: "isp_uplink", alias: "Ethernet5/1", lanes: "9", index: "5", peer: "Exit-Router1", neighbor_asn: 65251 }
  #   Ethernet1: { speed: "10000", role: "isp_uplink", alias: "Ethernet5/2", lanes: "10", index: "5", peer: "Exit-Router2", neighbor_asn: 65252 }
  #   Ethernet2: { speed: "10000", role: "server_access", alias: "Ethernet5/3", lanes: "11", index: "5", peer: "k8s-master-03", neighbor_asn: 65231 }
  #   Ethernet3: { speed: "10000", role: "server_access", alias: "Ethernet5/4", lanes: "12", index: "5", peer: "k8s-db-03", neighbor_asn: 65232 }
  #   Ethernet4: { speed: "10000", role: "server_access", alias: "Ethernet6/1", lanes: "13", index: "6", peer: "osh-ctrl-03", neighbor_asn: 65233 }
  #   Ethernet5: { speed: "10000", role: "server_access", alias: "Ethernet6/2", lanes: "14", index: "6", peer: "MonSrv", neighbor_asn: 65234 }
  #   Ethernet6: { speed: "10000", role: "server_access", alias: "Ethernet6/3", lanes: "15", index: "6", peer: "osh-comp-03", neighbor_asn: 65235 }

# Ports that carry the isolated Ceph replication VLAN (Vrf-storage over VLAN 100)
storage_ports:
  - { port: "Ethernet2",   neighbor_asn: 65231, neighbor: "k8s-master-03" }
  - { port: "Ethernet3",   neighbor_asn: 65232, neighbor: "k8s-db-03" }
  - { port: "Ethernet4",   neighbor_asn: 65233, neighbor: "osh-ctrl-03" }
  - { port: "Ethernet5",   neighbor_asn: 65223, neighbor: "MonSrv" }
  - { port: "Ethernet6",   neighbor_asn: 65235, neighbor: "osh-comp-03" }
  - { port: "Ethernet124", neighbor_asn: 65000, neighbor: "Spine-S1" }
  - { port: "Ethernet120", neighbor_asn: 65000, neighbor: "Spine-S2" }

  # --- Perimeter Access Breakouts (Channel Splits handling Router Transit & Ceph Storage) ---
  # Ethernet0:
  #   breakout: "4x10G"
  #   role: "access"
  #   children:
  #     # Northbound Internet Transit Gateways connecting to Ubuntu Nodes
  #     - { name: "Ethernet0", alias: "Ethernet5/1", lanes: "9",  index: "5", speed: "10000", neighbor: "Exit_Router1", rem_port: "enp2s0", neighbor_asn: 65101 }
  #     - { name: "Ethernet1", alias: "Ethernet5/2", lanes: "10", index: "5", speed: "10000", neighbor: "Exit_Router2", rem_port: "enp2s0", neighbor_asn: 65102 }
  #     # High-Performance Ceph Storage Cluster Replication Interfaces
  #     - { name: "Ethernet2", alias: "Ethernet5/3", lanes: "11", index: "5", speed: "10000", neighbor: "HostB12_1",    rem_port: "cephport", neighbor_asn: 65250 }
  #     - { name: "Ethernet3", alias: "Ethernet5/4", lanes: "12", index: "5", speed: "10000", neighbor: "HostB12_2",    rem_port: "cephport", neighbor_asn: 65251 }


---
hostname: "Border-Leaf2"
router_id: "10.0.2.5"
bgp_local_asn: 65032
mgmt_ip: "172.16.2.32/24"
device_type: "LeafRouter"
hwsku: "Arista-7050-QX-32S"
platform: "x86_64-arista_7050_qx32s"
loopback_ip: "10.0.2.5/32"
# 7050-QX-32S: fabric on last QSFP+ (Ethernet124=idx36, Ethernet120=idx35)
# Breakout: Ethernet0 (idx5) → 4x10G (all 4 children used)
switch_ports:
  Ethernet124: { speed: "40000", role: "fabric", alias: "Ethernet36", lanes: "5,6,7,8", index: "36", neighbor: "Spine-S1", rem_port: "Ethernet20", neighbor_asn: 65000 }
  Ethernet120: { speed: "40000", role: "fabric", alias: "Ethernet35", lanes: "1,2,3,4", index: "35", neighbor: "Spine-S2", rem_port: "Ethernet20", neighbor_asn: 65000 }

access_ports:
  Ethernet0:
    breakout: "4x10G"
    role: "access"
    children:
      - { name: "Ethernet0", alias: "Ethernet5/1", lanes: "9", index: "5", speed: "10000", neighbor: "Exit-Router2", rem_port: "enp3s0", neighbor_asn: 65252 }
      - { name: "Ethernet1", alias: "Ethernet5/2", lanes: "10", index: "5", speed: "10000", neighbor: "Exit-Router1", rem_port: "enp3s0", neighbor_asn: 65251 }
      - { name: "Ethernet2", alias: "Ethernet5/3", lanes: "11", index: "5", speed: "10000", neighbor: "k8s-master-03", rem_port: "enp3s0", neighbor_asn: 65231 }
      - { name: "Ethernet3", alias: "Ethernet5/4", lanes: "12", index: "5", speed: "10000", neighbor: "k8s-db-03", rem_port: "enp3s0", neighbor_asn: 65232 }
  Ethernet4:
    breakout: "4x10G"
    role: "access"
    children:
      - { name: "Ethernet4", alias: "Ethernet6/1", lanes: "13", index: "6", speed: "10000", neighbor: "osh-ctrl-03", rem_port: "enp3s0", neighbor_asn: 65233 }
      - { name: "Ethernet5", alias: "Ethernet6/2", lanes: "14", index: "6", speed: "10000", neighbor: "MonSrv", rem_port: "enp3s0", neighbor_asn: 65234 }
      - { name: "Ethernet6", alias: "Ethernet6/3", lanes: "15", index: "6", speed: "10000", neighbor: "osh-comp-03", rem_port: "enp3s0", neighbor_asn: 65235 }
      - { name: "Ethernet7", alias: "Ethernet6/4", lanes: "16", index: "6", speed: "10000", neighbor: "none" }

  # Legacy flat access model retained for reference:
  # access_ports:
  #   Ethernet0: { speed: "10000", role: "edge_uplink", alias: "Ethernet5/1", lanes: "9", index: "5", peer: "Exit-Router2", neighbor_asn: 65252 }
  #   Ethernet1: { speed: "10000", role: "edge_uplink", alias: "Ethernet5/2", lanes: "10", index: "5", peer: "Exit-Router1", neighbor_asn: 65251 }
  #   Ethernet2: { speed: "10000", role: "server_access", alias: "Ethernet5/3", lanes: "11", index: "5", peer: "k8s-master-03", neighbor_asn: 65231 }
  #   Ethernet3: { speed: "10000", role: "server_access", alias: "Ethernet5/4", lanes: "12", index: "5", peer: "k8s-db-03", neighbor_asn: 65232 }
  #   Ethernet4: { speed: "10000", role: "server_access", alias: "Ethernet6/1", lanes: "13", index: "6", peer: "osh-ctrl-03", neighbor_asn: 65233 }
  #   Ethernet5: { speed: "10000", role: "server_access", alias: "Ethernet6/2", lanes: "14", index: "6", peer: "MonSrv", neighbor_asn: 65234 }
  #   Ethernet6: { speed: "10000", role: "server_access", alias: "Ethernet6/3", lanes: "15", index: "6", peer: "osh-comp-03", neighbor_asn: 65235 }

# Ports that carry the isolated Ceph replication VLAN (Vrf-storage over VLAN 100)
storage_ports:
  - { port: "Ethernet2",   neighbor_asn: 65231, neighbor: "k8s-master-03" }
  - { port: "Ethernet3",   neighbor_asn: 65232, neighbor: "k8s-db-03" }
  - { port: "Ethernet4",   neighbor_asn: 65233, neighbor: "osh-ctrl-03" }
  - { port: "Ethernet5",   neighbor_asn: 65223, neighbor: "MonSrv" }
  - { port: "Ethernet6",   neighbor_asn: 65235, neighbor: "osh-comp-03" }
  - { port: "Ethernet124", neighbor_asn: 65000, neighbor: "Spine-S1" }
  - { port: "Ethernet120", neighbor_asn: 65000, neighbor: "Spine-S2" }


  # Perimeter Access Breakouts handling Exit Infrastructure and High-Sec Host Nodes
  # Ethernet0:
  #   breakout: "4x10G"
  #   role: "access"
  #   children:
  #     - { name: "Ethernet0", alias: "Ethernet5/1", lanes: "9",  index: "5", speed: "10000", neighbor: "Exit_Router1", rem_port: "enp3s0", neighbor_asn: 65101 }
  #     - { name: "Ethernet1", alias: "Ethernet5/2", lanes: "10", index: "5", speed: "10000", neighbor: "Exit_Router2", rem_port: "enp3s0", neighbor_asn: 65102 }
  #     - { name: "Ethernet2", alias: "Ethernet5/3", lanes: "11", index: "5", speed: "10000", neighbor: "HostB12_1",    rem_port: "enp3s0", neighbor_asn: 65250 }
  #     - { name: "Ethernet3", alias: "Ethernet5/4", lanes: "12", index: "5", speed: "10000", neighbor: "HostB12_2",    rem_port: "enp3s0", neighbor_asn: 65251 }

---
hostname: "Leaf-L3"
router_id: "10.0.2.3"
bgp_local_asn: 65021
mgmt_ip: "172.16.2.23/24"
device_type: "LeafRouter"
hwsku: "Arista-7050-QX32"
platform: "x86_64-arista_7050_qx32"
loopback_ip: "10.0.2.3/32"
# 7050-QX32: fabric on last QSFP+ (Ethernet124=idx32, Ethernet120=idx31)
# Access on the first three native QSFP+ front-panel ports. In vrnetlab each
# container ethN maps to ONE front-panel QSFP (Ethernet(4*(N-1))); a single
# 40G port has only one backing vNIC, so a 4x10G breakout cannot fan one port
# out to three hosts. eth1->Ethernet0, eth2->Ethernet4, eth3->Ethernet8.
switch_ports:
  Ethernet124: { speed: "40000", role: "fabric", alias: "Ethernet32", lanes: "1,2,3,4", index: "32", neighbor: "Spine-S1", rem_port: "Ethernet8", neighbor_asn: 65000 }
  Ethernet120: { speed: "40000", role: "fabric", alias: "Ethernet31", lanes: "5,6,7,8", index: "31", neighbor: "Spine-S2", rem_port: "Ethernet8", neighbor_asn: 65000 }

access_ports:
  Ethernet0:
    breakout: "4x10G"
    role: "access"
    children:
      - { name: "Ethernet0", alias: "Ethernet1/1", lanes: "128", index: "1", speed: "10000", neighbor: "k8s-master-02", rem_port: "enp2s0", neighbor_asn: 65221 }
      - { name: "Ethernet1", alias: "Ethernet1/2", lanes: "124", index: "2", speed: "10000", neighbor: "k8s-db-02", rem_port: "enp2s0", neighbor_asn: 65222 }
      - { name: "Ethernet2", alias: "Ethernet1/3", lanes: "13", index: "3", speed: "10000", neighbor: "osh-ctrl-02", rem_port: "enp2s0", neighbor_asn: 65223 }
      - { name: "Ethernet3", alias: "Ethernet1/4", lanes: "9", index: "4", speed: "10000", neighbor: "osh-net-02", rem_port: "enp2s0", neighbor_asn: 65224 }
  Ethernet4:
    breakout: "4x10G"
    role: "access"
    children:
      - { name: "Ethernet4", alias: "Ethernet2/1", lanes: "17", index: "5", speed: "10000", neighbor: "osh-comp-02", rem_port: "enp2s0", neighbor_asn: 65225 }
      - { name: "Ethernet5", alias: "Ethernet2/2", lanes: "21", index: "6", speed: "10000", neighbor: "none" }
      - { name: "Ethernet6", alias: "Ethernet2/3", lanes: "25", index: "7", speed: "10000", neighbor: "none" }
      - { name: "Ethernet7", alias: "Ethernet2/4", lanes: "29", index: "8", speed: "10000", neighbor: "none" }

  # Ethernet8:
  #   breakout: "4x10G"
  #   role: "access"
  #   children:
  #     - { name: "Ethernet0", alias: "Ethernet1/1", lanes: "125", index: "1", speed: "10000", neighbor: "k8s-master-02", rem_port: "enp2s0", neighbor_asn: 65221 }
  #     - { name: "Ethernet1", alias: "Ethernet1/2", lanes: "126", index: "1", speed: "10000", neighbor: "k8s-db-02", rem_port: "enp2s0", neighbor_asn: 65222 }
  #     - { name: "Ethernet2", alias: "Ethernet1/3", lanes: "127", index: "1", speed: "10000", neighbor: "osh-ctrl-02", rem_port: "enp2s0", neighbor_asn: 65223 }
  #     - { name: "Ethernet3", alias: "Ethernet1/4", lanes: "128", index: "1", speed: "10000", neighbor: "osh-net-02", rem_port: "enp2s0", neighbor_asn: 65224 }
  # Ethernet12:
  #   breakout: "4x10G"
  #   role: "access"
  #   children:
  #     - { name: "Ethernet4", alias: "Ethernet2/1", lanes: "121", index: "2", speed: "10000", neighbor: "osh-comp-02", rem_port: "enp2s0", neighbor_asn: 65225 }
  #     - { name: "Ethernet5", alias: "Ethernet2/2", lanes: "122", index: "2", speed: "10000", neighbor: "none" }
  #     - { name: "Ethernet6", alias: "Ethernet2/3", lanes: "123", index: "2", speed: "10000", neighbor: "none" }
  #     - { name: "Ethernet7", alias: "Ethernet2/4", lanes: "124", index: "2", speed: "10000", neighbor: "none" }
  # Ethernet16:
  #   breakout: "4x10G"
  #   role: "access"
  #   children:
  #     - { name: "Ethernet4", alias: "Ethernet2/1", lanes: "121", index: "2", speed: "10000", neighbor: "osh-comp-02", rem_port: "enp2s0", neighbor_asn: 65225 }
  #     - { name: "Ethernet5", alias: "Ethernet2/2", lanes: "122", index: "2", speed: "10000", neighbor: "none" }
  #     - { name: "Ethernet6", alias: "Ethernet2/3", lanes: "123", index: "2", speed: "10000", neighbor: "none" }
  #     - { name: "Ethernet7", alias: "Ethernet2/4", lanes: "124", index: "2", speed: "10000", neighbor: "none" }


  # Legacy flat access model retained for reference:
  # access_ports:
  #   Ethernet0: { speed: "10000", role: "server_access", alias: "Ethernet1/1", lanes: "125", index: "1", peer: "k8s-master-02", neighbor_asn: 65221 }
  #   Ethernet1: { speed: "10000", role: "server_access", alias: "Ethernet1/2", lanes: "126", index: "1", peer: "k8s-db-02", neighbor_asn: 65222 }
  #   Ethernet2: { speed: "10000", role: "server_access", alias: "Ethernet1/3", lanes: "127", index: "1", peer: "osh-ctrl-02", neighbor_asn: 65223 }
  #   Ethernet3: { speed: "10000", role: "server_access", alias: "Ethernet1/4", lanes: "128", index: "1", peer: "osh-net-02", neighbor_asn: 65224 }
  #   Ethernet4: { speed: "10000", role: "server_access", alias: "Ethernet2/1", lanes: "121", index: "2", peer: "osh-comp-02", neighbor_asn: 65225 }

# Ports that carry the isolated Ceph replication VLAN (Vrf-storage over VLAN 100)
storage_ports:
  - { port: "Ethernet8",   neighbor_asn: 65223, neighbor: "osh-ctrl-02" }
  - { port: "Ethernet12",  neighbor_asn: 65224, neighbor: "osh-net-02" }
  - { port: "Ethernet16",  neighbor_asn: 65225, neighbor: "osh-comp-02" }
  - { port: "Ethernet124", neighbor_asn: 65000, neighbor: "Spine-S1" }
  - { port: "Ethernet120", neighbor_asn: 65000, neighbor: "Spine-S2" }
---
hostname: "Leaf-L4"
router_id: "10.0.2.4"
bgp_local_asn: 65022
mgmt_ip: "172.16.2.24/24"
device_type: "LeafRouter"
hwsku: "Arista-7050-QX32"
platform: "x86_64-arista_7050_qx32"
loopback_ip: "10.0.2.4/32"
# 7050-QX32: fabric on last QSFP+ (Ethernet124=idx32, Ethernet120=idx31)
# Access on the first three native QSFP+ front-panel ports. In vrnetlab each
# container ethN maps to ONE front-panel QSFP (Ethernet(4*(N-1))); a single
# 40G port has only one backing vNIC, so a 4x10G breakout cannot fan one port
# out to three hosts. eth1->Ethernet0, eth2->Ethernet4, eth3->Ethernet8.
switch_ports:
  Ethernet124: { speed: "40000", role: "fabric", alias: "Ethernet32", lanes: "1,2,3,4", index: "32", neighbor: "Spine-S1", rem_port: "Ethernet12", neighbor_asn: 65000 }
  Ethernet120: { speed: "40000", role: "fabric", alias: "Ethernet31", lanes: "5,6,7,8", index: "31", neighbor: "Spine-S2", rem_port: "Ethernet12", neighbor_asn: 65000 }

access_ports:
  Ethernet0:
    breakout: "4x10G"
    role: "access"
    children:
      - { name: "Ethernet0", alias: "Ethernet1/1", lanes: "128", index: "1", speed: "10000", neighbor: "k8s-master-02", rem_port: "enp3s0", neighbor_asn: 65221 }
      - { name: "Ethernet1", alias: "Ethernet1/2", lanes: "124", index: "2", speed: "10000", neighbor: "k8s-db-02", rem_port: "enp3s0", neighbor_asn: 65222 }
      - { name: "Ethernet2", alias: "Ethernet1/3", lanes: "13", index: "3", speed: "10000", neighbor: "osh-ctrl-02", rem_port: "enp3s0", neighbor_asn: 65223 }
      - { name: "Ethernet3", alias: "Ethernet1/4", lanes: "9", index: "4", speed: "10000", neighbor: "osh-net-02", rem_port: "enp3s0", neighbor_asn: 65224 }
  Ethernet4:
    breakout: "4x10G"
    role: "access"
    children:
      - { name: "Ethernet4", alias: "Ethernet2/1", lanes: "17", index: "5", speed: "10000", neighbor: "osh-comp-02", rem_port: "enp3s0", neighbor_asn: 65225 }
      - { name: "Ethernet5", alias: "Ethernet2/2", lanes: "21", index: "6", speed: "10000", neighbor: "none" }
      - { name: "Ethernet6", alias: "Ethernet2/3", lanes: "25", index: "7", speed: "10000", neighbor: "none" }
      - { name: "Ethernet7", alias: "Ethernet2/4", lanes: "29", index: "8", speed: "10000", neighbor: "none" }

  # Legacy flat access model retained for reference:
  # access_ports:
  #   Ethernet0: { speed: "10000", role: "server_access", alias: "Ethernet1/1", lanes: "125", index: "1", peer: "k8s-master-02", neighbor_asn: 65221 }
  #   Ethernet1: { speed: "10000", role: "server_access", alias: "Ethernet1/2", lanes: "126", index: "1", peer: "k8s-db-02", neighbor_asn: 65222 }
  #   Ethernet2: { speed: "10000", role: "server_access", alias: "Ethernet1/3", lanes: "127", index: "1", peer: "osh-ctrl-02", neighbor_asn: 65223 }
  #   Ethernet3: { speed: "10000", role: "server_access", alias: "Ethernet1/4", lanes: "128", index: "1", peer: "osh-net-02", neighbor_asn: 65224 }
  #   Ethernet4: { speed: "10000", role: "server_access", alias: "Ethernet2/1", lanes: "121", index: "2", peer: "osh-comp-02", neighbor_asn: 65225 }

# Ports that carry the isolated Ceph replication VLAN (Vrf-storage over VLAN 100)
storage_ports:
  - { port: "Ethernet8",   neighbor_asn: 65223, neighbor: "osh-ctrl-02" }
  - { port: "Ethernet12",  neighbor_asn: 65224, neighbor: "osh-net-02" }
  - { port: "Ethernet16",  neighbor_asn: 65225, neighbor: "osh-comp-02" }
  - { port: "Ethernet124", neighbor_asn: 65000, neighbor: "Spine-S1" }
  - { port: "Ethernet120", neighbor_asn: 65000, neighbor: "Spine-S2" }

    XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

    # name          lanes             alias         index   speed
Ethernet0       128               Ethernet1/1   1       10000
Ethernet1       124               Ethernet1/2   2       10000
Ethernet2       13                Ethernet1/3   3       10000
Ethernet3       9                 Ethernet1/4   4       10000
Ethernet4       17                Ethernet2/1   5       10000
Ethernet5       21                Ethernet2/2   6       10000
Ethernet6       25                Ethernet2/3   7       10000
Ethernet7       29                Ethernet2/4   8       10000
Ethernet8       13,14,15,16       Ethernet3/1   3       40000
Ethernet12      9,10,11,12        Ethernet4/1   4       40000
Ethernet16      17,18,19,20       Ethernet5/1   5       40000
Ethernet20      21,22,23,24       Ethernet6/1   6       40000
Ethernet24      25,26,27,28       Ethernet7/1   7       40000
Ethernet28      29,30,31,32       Ethernet8/1   8       40000
Ethernet32      37,38,39,40       Ethernet9/1   9       40000
Ethernet36      33,34,35,36       Ethernet10/1  10      40000
Ethernet40      45,46,47,48       Ethernet11/1  11      40000
Ethernet44      41,42,43,44       Ethernet12/1  12      40000
Ethernet48      53,54,55,56       Ethernet13/1  13      40000
Ethernet52      49,50,51,52       Ethernet14/1  14      40000
Ethernet56      69,70,71,72       Ethernet15/1  15      40000
Ethernet60      65,66,67,68       Ethernet16/1  16      40000
Ethernet64      77,78,79,80       Ethernet17/1  17      40000
Ethernet68      73,74,75,76       Ethernet18/1  18      40000
Ethernet72      93,94,95,96       Ethernet19/1  19      40000
Ethernet76      89,90,91,92       Ethernet20/1  20      40000
Ethernet80      101,102,103,104   Ethernet21/1  21      40000
Ethernet84      97,98,99,100      Ethernet22/1  22      40000
Ethernet88      109,110,111,112   Ethernet23/1  23      40000
Ethernet92      105,106,107,108   Ethernet24/1  24      40000
Ethernet96      61,62,63,64       Ethernet25    25      40000
Ethernet100     57,58,59,60       Ethernet26    26      40000
Ethernet104     81,82,83,84       Ethernet27    27      40000
Ethernet108     85,86,87,88       Ethernet28    28      40000
Ethernet112     117,118,119,120   Ethernet29    29      40000
Ethernet116     113,114,115,116   Ethernet30    30      40000
Ethernet120     5,6,7,8           Ethernet31    31      40000
Ethernet124     1,2,3,4           Ethernet32    32      40000
XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
# Arista DCS-7050QX-32S — SONiC port_config.ini
# hwsku: Arista-7050-QX-32S
# platform: x86_64-arista_7050_qx32s
#
# 32x QSFP+ 40G ports (Ethernet0–Ethernet124)
# Indices 5–36 — indices 1–4 are reserved for the 4 front-panel SFP+ ports
# (sfp1–sfp4) that share ASIC lanes with QSFP+5 (Ethernet0). The SFP+ ports
# are MUTUALLY EXCLUSIVE with Ethernet0 breakout sub-ports:
#   - Default 1x40G[10G] mode → Ethernet5/1 (QSFP+5) active, sfp1-4 dead
#   - After 4x10G breakout    → Ethernet5/1–5/4 each 10G, sfp1-4 dead
#   - After 3x10G+1x1G mode   → sfp1-4 (Ethernet1–4) active, QSFP+5 dead
#
# KEY DIFFERENCE from 7050-QX32 (no 'S'):
#   7050-QX32:  QSFP+ starts at index 1 (Ethernet0 = lanes 125-128)
#   7050QX-32S: QSFP+ starts at index 5 (Ethernet0 = lanes 9-12) ← THIS FILE
#
# KVM VS NIC-to-port formula: ethN = index - 4
#   Ethernet0 (index 5)   → eth1  = NIC1
#   Ethernet124 (index 36) → eth32 = NIC32
#
# Source: Verified against running SONiC 202405 VS on KVM (show interfaces status)
#
# name          lanes             alias         index   speed
Ethernet0       9                 Ethernet5/1   5       10000
Ethernet1       10                Ethernet5/2   5       10000
Ethernet2       11                Ethernet5/3   5       10000
Ethernet3       12                Ethernet5/4   5       10000
Ethernet4       16                Ethernet6/1   6       10000
Ethernet5       17                Ethernet6/2   7       10000
Ethernet6       21                Ethernet6/3   8       10000
Ethernet7       29                Ethernet6/4   9       10000
Ethernet8       17,18,19,20       Ethernet7/1   7       40000
Ethernet12      21,22,23,24       Ethernet8/1   8       40000
Ethernet16      29,30,31,32       Ethernet9/1   9       40000
Ethernet20      25,26,27,28       Ethernet10/1  10      40000
Ethernet24      33,34,35,36       Ethernet11/1  11      40000
Ethernet28      37,38,39,40       Ethernet12/1  12      40000
Ethernet32      45,46,47,48       Ethernet13/1  13      40000
Ethernet36      41,42,43,44       Ethernet14/1  14      40000
Ethernet40      49,50,51,52       Ethernet15/1  15      40000
Ethernet44      53,54,55,56       Ethernet16/1  16      40000
Ethernet48      69,70,71,72       Ethernet17/1  17      40000
Ethernet52      65,66,67,68       Ethernet18/1  18      40000
Ethernet56      73,74,75,76       Ethernet19/1  19      40000
Ethernet60      77,78,79,80       Ethernet20/1  20      40000
Ethernet64      93,94,95,96       Ethernet21/1  21      40000
Ethernet68      89,90,91,92       Ethernet22/1  22      40000
Ethernet72      97,98,99,100      Ethernet23/1  23      40000
Ethernet76      101,102,103,104   Ethernet24/1  24      40000
Ethernet80      109,110,111,112   Ethernet25/1  25      40000
Ethernet84      105,106,107,108   Ethernet26/1  26      40000
Ethernet88      121,122,123,124   Ethernet27/1  27      40000
Ethernet92      125,126,127,128   Ethernet28/1  28      40000
Ethernet96      61,62,63,64       Ethernet29    29      40000
Ethernet100     57,58,59,60       Ethernet30    30      40000
Ethernet104     81,82,83,84       Ethernet31    31      40000
Ethernet108     85,86,87,88       Ethernet32    32      40000
Ethernet112     117,118,119,120   Ethernet33    33      40000
Ethernet116     113,114,115,116   Ethernet34    34      40000
Ethernet120     1,2,3,4           Ethernet35    35      40000
Ethernet124     5,6,7,8           Ethernet36    36      40000
XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
#!/usr/bin/env python3
"""Surgical post-processor for raw_config_db.json.

Enhancements:
  - Step 1: Ingests port_data.json and raw_config_db.json inputs.
  - Step 2: Updates DEVICE_METADATA, purges template sections, and inserts
    "admin_status": "up" strictly for keys defined in port_data.json.
"""
import json

# =========================================================================
# STEP 1: Ingest input configuration files
# =========================================================================
with open('/tmp/port_data.json') as f:
    data = json.load(f)

switch_ports = data['switch_ports']
access_ports = data['access_ports']
meta = data['metadata']
target_hwsku = meta.get('hwsku', '')


def flatten_access_ports(raw_access_ports):
    """Normalize both legacy and breakout-aware access Ports into a list of child port definitions."""
    entries = []
    for port_name, cfg in raw_access_ports.items():
        if isinstance(cfg, dict) and 'children' in cfg and isinstance(cfg.get('children'), list):
            for child in cfg.get('children', []):
                child_cfg = dict(child)
                child_cfg.setdefault('name', child.get('name', port_name))
                entries.append(child_cfg)
        else:
            cfg_dict = dict(cfg) if isinstance(cfg, dict) else {}
            cfg_dict.setdefault('name', port_name)
            entries.append(cfg_dict)
    return entries


access_port_entries = flatten_access_ports(access_ports)

with open('/tmp/raw_config_db.json') as f:
    db = json.load(f)

# =========================================================================
# STEP 2: Core configuration update and key-based port activation
# =========================================================================

# 2a. Update metadata attributes for virtual environment execution compatibility
db['DEVICE_METADATA']['localhost'].update({
    'hostname': meta['hostname'],
    'type': meta['type'],
    'router_id': meta['router_id'],
    'bgp_asn': meta['bgp_asn'],
    'platform': 'x86_64-kvm_x86_64-r0',
    'frr_mgmt_framework_config': 'true',
    'docker_routing_config_mode': 'unified'
})

# 2b. Cleanup preset-generated architectural template sections
for key in ['BGP_NEIGHBOR', 'DEVICE_NEIGHBOR', 'INTERFACE', 'LOOPBACK_INTERFACE']:
    db.pop(key, None)
# =========================================================================
# PLATFORM SPECIFIC: ACCTON SFP+ / QSFP+ FABRIC PRESERVATION
# =========================================================================
if "as5712" in target_hwsku.lower() or "accton" in target_hwsku.lower():
    # Force fabric ports back to original un-broken 40G bundling state
    # Overwrites the sonic-vs template which splits everything into 10G lines
    fabric_definitions = {
        "Ethernet64": {"lanes": "109,110,111,112", "index": "53", "speed": "40000"},
        "Ethernet68": {"lanes": "77,78,79,80",     "index": "54", "speed": "40000"}
    }

    # 1. Purge all child sub-interfaces generated by the native profile
    for i in range(64, 68):
        db['PORT'].pop(f"Ethernet{i}", None)
    for i in range(68, 72):
        db['PORT'].pop(f"Ethernet{i}", None)

    # 2. Inject clean, structured native 40G fabric interfaces
    for fname, fcfg in fabric_definitions.items():
        db['PORT'][fname] = {
            'lanes': fcfg['lanes'],
            'speed': fcfg['speed'],
            'index': fcfg['index'],
            'admin_status': 'up',
            'alias': fname,
            'mtu': '9100'
        }

# 2c. Consolidate port parameters from port_data.json
port_meta = {}
port_meta.update(switch_ports)
port_meta.update(access_ports)

# 2d. Apply structural admin states based purely on keys present in port_data.json
for pname, pcfg in db['PORT'].items():
    # Direct insertion: If the key exists in port_data.json, it goes UP. Otherwise, DOWN.
    pcfg['admin_status'] = 'up' if pname in port_meta else 'down'
    pcfg.setdefault('mtu', '9100')  # ensure jumbo frames match topology defaults
    
    # Inject user-defined interface aliases if present in port_data
    alias = port_meta.get(pname, {}).get('alias')
    if alias:
        pcfg['alias'] = alias

# 2e. Write out final clean database configuration payload
with open('/tmp/raw_config_db.json', 'w') as f:
    json.dump(db, f, indent=4)
XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
- name: Copy breakout port config from Control Node to SONiC Switch VMs
  ansible.builtin.copy:
    src: "{{ playbook_dir }}/../hwsku_port_configs/{{ platform }}/{{ hwsku }}/breakout_port_config.ini"
    dest: "/tmp/breakout_port_config.ini"
    mode: "0644"

# No -H: -H pulls the VM host's own profile (x86_64-kvm_x86_64-r0 / Force10-S6000)
# and shadows -p, collapsing every switch to the default 32x40G layout. Using -p
# alone renders the true vendor port panel; platform is re-pinned to kvm below.
# - name: Generate raw config_db from platform port_config.ini
#   ansible.builtin.shell: >
#     sonic-cfggen -k {{ hwsku }}
#     -p /usr/share/sonic/device/{{ platform }}/{{ hwsku }}/port_config.ini
#     --preset t1 > /tmp/raw_config_db.json
#   become: true
#   when: switch_ports is defined

- name: Generate raw config_db from platform bbreakout_port_config.ini
  ansible.builtin.shell: >
    sonic-cfggen -k {{ hwsku }}
    -p /tmp/breakout_port_config.ini
    --preset t1 > /tmp/raw_config_db.json
  become: true
  when: switch_ports is defined
  XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
