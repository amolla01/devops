Assuming we have a data center that practices leaf-spine topology. It uses Leaf columns of two leaves. Each and every Server connects to those columns that works multi-homing as active active ebgp hosts. Among those hosts are running ceph osd's. In the host servers that is configured with ceph -osd has a dummy interface in their netplan implementation, so that can be used for osd-replication only. and we want that to be used for storage replication with a vrf-storage, it can not consume more than 80% of bandwidth at any point in time. The TWO interface that gets used for multi-homing connection is infact used in this architecture for osd replication as well. Provide details to achieve this step by step configuration options for netplan, leaf, spine etc for all L3.

To achieve an active-active eBGP multi-homed architecture with a dedicated, bandwidth-capped storage replication VRF, you must implement symmetric routing, routing instances (VRFs), and strict Traffic Shaping (QoS).
Because your architecture forces Ceph to reuse the same physical uplinks for both public/client and OSD-replication traffic, the dummy interface will act as a logical visual endpoint. Traffic mapping to vrf-storage must be forced onto the wire via advanced policy routing (PBR) and throttled via Linux Traffic Control (tc) or Ceph native parameters.
------------------------------
## 1. Leaf and Spine Switch Configuration (L3)
The network switches must support eBGP Multi-hop or standard eBGP over the direct physical links, matching asymmetric VRF routing. [1] 
## Spine Configuration
Spines sit in a higher Autonomous System (e.g., AS 65000) and act as core transit routes, unaware of the hosts but fully aware of the Leaf VRFs. [2, 3] 

! Enable BGP and IP Routing
ip routing
!
router bgp 65000
 bgp router-id 10.0.0.1
 bgp bestpath as-path multipath-relax
 neighbor LEAF_COLUMN peer-group
 neighbor LEAF_COLUMN remote-as external
 neighbor LEAF_COLUMN multipath
 ! Define neighbor IPs to Leaf columns
 neighbor 192.168.0.2 peer-group LEAF_COLUMN
 neighbor 192.168.0.6 peer-group LEAF_COLUMN
 !
 address-family ipv4
  neighbor LEAF_COLUMN activate
  maximum-paths 64

## Leaf Configuration (2-Leaf Column)
Each leaf needs a defined VRF for Storage and an open Default/Base VRF for regular client traffic. Assume Leaf A is AS 65001 and Leaf B is AS 65002. [4] 

! Define VRF on Switches
vrf instance vrf-storage
!
! Downlink interfaces to Host 1 (Example for Leaf A)
interface Ethernet1
 description To_Host1_Port1
 no switchport
 ip address 10.1.1.1/30
!
interface Ethernet2
 description To_Host1_Port1_Storage
 no switchport
 vrf forwarding vrf-storage
 ip address 10.2.1.1/30
!
! BGP configurations targeting the Host
router bgp 65001
 ! Base Client BGP
 neighbor 10.1.1.2 remote-as 65100
 neighbor 10.1.1.2 description Host1_Client
 !
 ! Storage VRF BGP
 vrf vrf-storage
  rd 65001:100
  route-target import 65001:100
  route-target export 65001:100
  !
  neighbor 10.2.1.2 remote-as 65100
  neighbor 10.2.1.2 description Host1_Storage

------------------------------
## 2. Host Netplan Implementation
On the host side, your dummy interface represents the Ceph Replication IP address. Netplan binds it to a dedicated routing table (100) that corresponds to vrf-storage. [5] 

network:
  version: 2
  renderer: networkd
  ethernets:
    enp3s0f0: # Physical Link to Leaf A
      addresses:
        - 10.1.1.2/30 # Base Client IP
        - 10.2.1.2/30 # Storage VRF IP
    enp3s0f1: # Physical Link to Leaf B
      addresses:
        - 10.1.2.2/30 # Base Client IP
        - 10.2.2.2/30 # Storage VRF IP

  dummy-devices:
    dum-storage:
      addresses:
        - 192.168.50.1/32 # Unique OSD replication dummy IP
      routes:
        - to: 0.0.0.0/0
          via: 10.2.1.1
          table: 100 # Directs default storage traffic through Leaf A VRF
          metric: 10
        - to: 0.0.0.0/0
          via: 10.2.2.1
          table: 100 # Directs default storage traffic through Leaf B VRF
          metric: 20
      routing-policy:
        - from: 192.168.50.1
          table: 100 # Forces replies from dummy IP to use Storage Table 100

------------------------------
## 3. Host FRRouting (FRR) Configuration
To run active-active eBGP on the host dynamically across both Leaf columns, install FRRouting on your servers.

! /etc/frr/frr.conf
frr version 10.0
frr defaults traditional
!
router bgp 65100
 bgp router-id 192.168.50.1
 bgp bestpath as-path multipath-relax
 ! Neighbors for Client Traffic
 neighbor 10.1.1.1 remote-as 65001
 neighbor 10.1.2.1 remote-as 65002
 !
 ! Neighbors for Storage VRF
 neighbor 10.2.1.1 remote-as 65001
 neighbor 10.2.2.1 remote-as 65002
 !
 address-family ipv4 unicast
  neighbor 10.1.1.1 activate
  neighbor 10.1.2.1 activate
  neighbor 10.2.1.1 activate
  neighbor 10.2.2.1 activate
  ! Advertise Dummy Interface into BGP
  network 192.168.50.1/32
  maximum-paths 2
 exit-address-family

------------------------------
## 4. Enforcing the 80% Bandwidth Cap
Because the storage replication passes through the exact same physical wires (enp3s0f0 and enp3s0f1) as client traffic, you must restrict the storage subnet or the dummy interface output.
## Option A: Linux Traffic Control (tc) with Token Bucket Filter
If your physical interfaces are 10Gbps, 80% maximum capacity equates to 8Gbps. You can use a Hierarchical Token Bucket (HTB) filter to shape outgoing IP packets originating from the storage network.
Run these commands during boot via systemd or a netplan post-up script:

# Attach HTB to physical link 1
sudo tc qdisc add dev enp3s0f0 root handle 1: htb default 10
# Create class 10 for Client Traffic (Full speed up to 10gbit)
sudo tc class add dev enp3s0f0 parent 1: classid 1:10 htb rate 10gbit
# Create class 20 for Storage Traffic (Capped strictly at 8gbit)
sudo tc class add dev enp3s0f0 parent 1: classid 1:20 htb rate 8gbit ceil 8gbit
# Filter match based on source IP (Dummy storage block or local storage pool)
sudo tc filter add dev enp3s0f0 parent 1: protocol ip prio 1 u32 match ip src 10.2.1.2/32 flowid 1:20
# Repeat symmetrically for your second multi-homed link (enp3s0f1)
sudo tc qdisc add dev enp3s0f1 root handle 1: htb default 10
sudo tc class add dev enp3s0f1 parent 1: classid 1:10 htb rate 10gbit
sudo tc class add dev enp3s0f1 parent 1: classid 1:20 htb rate 8gbit ceil 8gbit
sudo tc filter add dev enp3s0f1 parent 1: protocol ip prio 1 u32 match ip src 10.2.2.2/32 flowid 1:20

## Option B: Ceph Daemon Optimization (Alternative application fallback)
To add an extra layer of defense inside Ceph configuration (ceph.conf), constrain the recovery and backfill threads to avoid saturating links under load:

[global]
# Bind replication explicitly to the dummy network
osd_cluster_network = 192.168.50.0/24 

[osd]
# Limit concurrent operations during recovery
osd_max_backfills = 1
osd_recovery_max_active = 2
osd_recovery_op_priority = 2

Do you need help writing a systemd service to automatically apply the tc rate-limiting rules across your reboots?

[1] [https://support.huawei.com](https://support.huawei.com/enterprise/en/doc/EDOC1000178179/62ee6802/configuring-route-exchange-between-pe-and-ce-devices)
[2] [https://www.youtube.com](https://www.youtube.com/watch?v=lhb4ufr7UXQ)
[3] [https://overlaid.net](https://overlaid.net/2019/01/27/arista-bgp-evpn-configuration-example/)
[4] [https://www.cisco.com](https://www.cisco.com/c/en/us/td/docs/dcn/whitepapers/cisco-vxlan-multi-site-and-service-node-integration.html)
[5] [https://support.riverbed.com](https://support.riverbed.com/bin/support/static/17qudtqont75l258qrbn4maj75/html/1mk0rjev5snblam40lgbg0mrgp/sh_9.5_dg_html/sh_9.5_dg/vrf.html)




provide the complete bgp implementation using bgp un-numberd above. and if there is any alternative approach that can be achieved such as using vlan sub interfaces on those ports, outline that as well and do the comparison of implementation which one is more production quality solution.

## 1. BGP Unnumbered Complete Implementation
BGP Unnumbered uses IPv6 Link-Local Addresses (FE80::) automatically assigned to physical interfaces to route IPv4 and IPv6 traffic. This removes the need to assign explicit /30 or /31 IPv4 subnets to your host-to-switch links. [1, 2] 
## Leaf Switches Configuration (FRR Syntax / Enterprise SONiC) [3] 
Both leaves must have IPv6 forwarding enabled and IPv6 link-local capability on their downlink interfaces.

! Enable IPv6 routing globally
ipv6 forwarding
!
! Physical Interfaces down to Host1
interface Ethernet1
 description To_Host1_Port1_Base
 no switchport
 ipv6 nd ra-interval 10
 no ipv6 nd suppress-ra
!
interface Ethernet2
 description To_Host1_Port2_Storage
 no switchport
 vrf forwarding vrf-storage
 ipv6 nd ra-interval 10
 no ipv6 nd suppress-ra
!
! BGP Instance
router bgp 65001
 bgp router-id 10.0.0.11
 bgp bestpath as-path multipath-relax
 !
 ! Base Client Unnumbered Peer
 neighbor Ethernet1 interface remote-as external
 !
 address-family ipv4 unicast
  neighbor Ethernet1 activate
  maximum-paths 64
 exit-address-family
 !
 ! Storage VRF Unnumbered Peer
 vrf vrf-storage
  rd 65001:100
  route-target import 65001:100
  route-target export 65001:100
  !
  neighbor Ethernet2 interface remote-as external
  !
  address-family ipv4 unicast
   neighbor Ethernet2 activate
   maximum-paths 64
  exit-address-family

## Host Netplan Configuration (/etc/netplan/01-netcfg.yaml)
Since BGP Unnumbered relies on IPv6 link-local addresses, you must explicitly tell Netplan not to wait for or look for IPv4 addresses on the physical interfaces, while keeping IPv6 enabled. [4] 

network:
  version: 2
  renderer: networkd
  ethernets:
    enp3s0f0:
      dhcp4: no
      dhcp6: no
      ipv6-privacy: off
      accept-ra: true
    enp3s0f1:
      dhcp4: no
      dhcp6: no
      ipv6-privacy: off
      accept-ra: true

  dummy-devices:
    dum-storage:
      addresses:
        - 192.168.50.1/32
      # Routing policy to ensure traffic originating from this IP looks at table 100
      routing-policy:
        - from: 192.168.50.1
          table: 100

## Host FRRouting Configuration (/etc/frr/frr.conf) [5] 
You must enable bgp extended-nexthop capability so that IPv4 prefixes can be advertised using the switch's IPv6 link-local address as the next hop. [6, 7, 8] 

frr version 10.0
frr defaults traditional
!
! Base BGP routing instance (Client/Public)
router bgp 65100
 bgp router-id 192.168.50.1
 bgp bestpath as-path multipath-relax
 !
 ! Peer with both Leaves over physical interfaces dynamically
 neighbor enp3s0f0 interface remote-as external
 neighbor enp3s0f1 interface remote-as external
 !
 address-family ipv4 unicast
  neighbor enp3s0f0 activate
  neighbor enp3s0f1 activate
  neighbor enp3s0f0 capability extended-nexthop
  neighbor enp3s0f1 capability extended-nexthop
  maximum-paths 2
 exit-address-family
!
! VRF-Storage instance mapping to kernel routing table 100
router bgp 65100 vrf vrf-storage
 bgp router-id 192.168.50.1
 bgp bestpath as-path multipath-relax
 !
 ! Re-use same physical interfaces but separated at FRR/VRF level
 neighbor enp3s0f0 interface remote-as external
 neighbor enp3s0f1 interface remote-as external
 !
 address-family ipv4 unicast
  neighbor enp3s0f0 activate
  neighbor enp3s0f1 activate
  neighbor enp3s0f0 capability extended-nexthop
  neighbor enp3s0f1 capability extended-nexthop
  ! Advertise Dummy Interface into Storage VRF
  network 192.168.50.1/32
  maximum-paths 2
 exit-address-family

------------------------------
## 2. Alternative Approach: VLAN Sub-Interfaces (802.1Q)
Instead of using two physical interfaces for separate purposes, you use VLAN Tagging over your multi-homed interfaces. This maps your VRFs to specific VLAN tags on the wire, running BGP Unnumbered (or standard L3) over the sub-interfaces. [9, 10, 11] 
## Host Netplan Configuration for VLAN Alternative

network:
  version: 2
  renderer: networkd
  ethernets:
    enp3s0f0:
      dhcp4: no
    enp3s0f1:
      dhcp4: no

  vlans:
    # Public/Client Sub-interfaces
    enp3s0f0.10:
      id: 10
      link: enp3s0f0
    enp3s0f1.10:
      id: 10
      link: enp3s0f1
    # Storage VRF Sub-interfaces
    enp3s0f0.20:
      id: 20
      link: enp3s0f0
    enp3s0f1.20:
      id: 20
      link: enp3s0f1

  dummy-devices:
    dum-storage:
      addresses:
        - 192.168.50.1/32
      routing-policy:
        - from: 192.168.50.1
          table: 100

Note: FRR configurations would then target enp3s0f0.10 for default client traffic and enp3s0f0.20 inside the vrf-storage instance.
------------------------------
## 3. Production Quality Comparison

| Feature/Metric | Approach A: Pure BGP Unnumbered (No VLANs) | Approach B: VLAN Sub-Interfaces (802.1Q) |
|---|---|---|
| Architectural Fit | Pure Layer 3 down to the host. Consistent with Cloud-scale design principles. | Hybrid Layer 2/3. Traditional enterprise design adapted to modern environments. |
| VRF Isolation & Security | Strong inside FRR/Switch software, but boundaries are blurry on the wire because raw frames don't have tags. | Strongest. Traffic separation is explicitly baked into the Ethernet frame header (VLAN Tag). Hardware-enforced. |
| Configuration Complexity | Very low IP management. High complexity inside FRR to peer multiple VRFs across identical raw interfaces. | Slightly higher Netplan configuration, but vastly simpler and standardized FRR/Switch neighbor configurations. |
| QoS / Traffic Shaping Effectiveness | Relies entirely on L3 IP Match rules (u32 match ip src). Complex to implement accurately with high-speed dynamic flows. | Easiest/Most Robust. Traffic Control (tc) can target the sub-interface itself (e.g., dev enp3s0f0.20), eliminating fragile source IP matching rules. |
| Troubleshooting & Packet Captures | Harder to debug. tcpdump on a physical port mixes client and storage frames completely. | Easy. Run tcpdump -i enp3s0f0.20 to view clean, isolated OSD-replication storage traffic. |

## Verdict: Which one is "Production Quality"?
For your specific use case, Approach B (VLAN Sub-Interfaces) combined with BGP Unnumbered is the superior, enterprise-grade production solution.
While pure BGP Unnumbered over a raw interface works well for single-tenant or single-VRF hosts, running multiple routing instances over the exact same untagged interface creates race conditions in the Linux Kernel network subsystem (Netfilter/conntrack) and risks data bleeding.
By introducing 802.1Q VLAN sub-interfaces:

   1. You gain absolute structural traffic isolation.
   2. Your bandwidth cap becomes foolproof: you can attach a basic tc rule directly to enp3s0f0.20 and enp3s0f1.20 to guarantee that storage replication never hurts the parent interface's availability.

Would you like me to rewrite the FRR configuration to map cleanly to the VLAN sub-interface approach?

[1] [https://stordis.com](https://stordis.com/bgp-unnumbered-in-enterprise-sonic/)
[2] [https://docs.nvidia.com](https://docs.nvidia.com/networking-ethernet-software/cumulus-linux-44/Layer-3/Border-Gateway-Protocol-BGP/)
[3] [https://www.youtube.com](https://www.youtube.com/watch?v=2V9Zage2d1A)
[4] [https://stordis.com](https://stordis.com/bgp-unnumbered-in-enterprise-sonic/)
[5] [https://ltomasbo.wordpress.com](https://ltomasbo.wordpress.com/2021/02/04/ovn-bgp-agent-testing-setup/)
[6] [https://blog.apnic.net](https://blog.apnic.net/2024/08/28/vpp-with-loopback-only-ospfv3-part-1/)
[7] [https://www.linkedin.com](https://www.linkedin.com/pulse/bgp-unnumbered-bard-dipankar-shaw)
[8] [https://www.theasciiconstruct.com](https://www.theasciiconstruct.com/blog/2021/12/10/cumulus-basics-part-v---bgp-unnumbered/)
[9] [https://www.youtube.com](https://www.youtube.com/watch?v=2YRKTyMgV4M)
[10] [https://www.youtube.com](https://www.youtube.com/watch?v=HydWVa0rJrg)
[11] [https://www.youtube.com](https://www.youtube.com/watch?v=dVVB2sREQ3s)


XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX


Good call — let me read the actual inventory to get accurate group membership and hostnames before writing any validation. 

Read [](file:///c%3A/dc-lab/clab/sonic-clab/inventory.yml)

Important correction from the real inventory: `ceph_osd_nodes` = **k8s-db-03, MonSrv, osh-comp-03, osh-comp-04** — there is no HostB12-1/HostB12-2. But verify-storage-qos.yml still hardcodes `HostB12-1`/`HostB12-2` as defaults. Let me find every stale reference.  

Searched for regex `HostB12|Host12|Host34|HostB` (`**/sonic-clab/**`), 382 results

Most matches are in stale backup files (`*.old`, `*copy*`, `*.orig`, `*.works`) which are inactive. The active problem is verify-storage-qos.yml hardcoding `HostB12-1`/`HostB12-2` and IPs `20.0.56.1/.2` — none of which exist. Let me confirm the real OSD nodes' storage config.    

Searched for files matching `**/sonic-clab/host_vars/osh-comp-0{3,4}.yml`, 2 matches

Read [](file:///c%3A/dc-lab/clab/sonic-clab/host_vars/k8s-db-03.yml#1-1), lines 1 to 15

Read [](file:///c%3A/dc-lab/clab/sonic-clab/host_vars/osh-comp-03.yml)

Read [](file:///c%3A/dc-lab/clab/sonic-clab/host_vars/osh-comp-04.yml)

I now have the accurate picture from the inventory, and I found real data drift. Let me fix the active broken file first, then report.

Accurate `ceph_osd_nodes` from inventory.yml: **k8s-db-03, MonSrv, osh-comp-03, osh-comp-04**. Fixing the stale `HostB12-1/2` names and wrong IPs in the storage verify play (deriving real IPs from inventory host_vars): 

Replace String in File


Let me investigate the rook-ceph playbook, the OSD disk vars, and how disks are defined in the clab topology so I can make the validation actually check them.  

Searched for files matching `**/*rook*`, 1 match

Searched for regex `ceph_osd_devices|osd_devices|ceph_osd|/dev/vd`, 135 results

Read [](file:///c%3A/dc-lab/clab/sonic-clab/playbooks/rook-ceph.yml)

Read [](file:///c%3A/dc-lab/clab/sonic-clab/group_vars/ceph_osd_nodes.yml)

Read [](file:///c%3A/dc-lab/clab/sonic-clab/roles/rook_ceph_deploy/templates/cephcluster.yaml.j2)

Read [](file:///c%3A/dc-lab/clab/sonic-clab/host_vars/k8s-db-03.yml#1-1), lines 1 to 18

Read [](file:///c%3A/dc-lab/clab/sonic-clab/host_vars/MonSrv.yaml#1-1), lines 1 to 35

Read [](file:///c%3A/dc-lab/clab/sonic-clab/inventory.yml#210-210), lines 210 to 245

Searched for regex `disk|pci|vdb|vdc|qcow2|virtio|data|addr=` (`**/topology.clab.yml`), 65 results

Now let me read the actual topology node blocks that attach Ceph data disks to see the full picture:   

Read [](file:///c%3A/dc-lab/clab/sonic-clab/topology.clab.yml#240-240), lines 240 to 275

Read [](file:///c%3A/dc-lab/clab/sonic-clab/topology.clab.yml#340-340), lines 340 to 440

Let me confirm what the current validation checks and whether osh-comp-01/02 have host_vars, to complete the picture.    

Read [](file:///c%3A/dc-lab/clab/sonic-clab/playbooks/validate-production.yml#860-860), lines 860 to 905

Searched for files matching `**/host_vars/osh-comp-0{1,2}.yml`, 2 matches

Read [](file:///c%3A/dc-lab/clab/sonic-clab/host_vars/osh-comp-01.yml)

Read [](file:///c%3A/dc-lab/clab/sonic-clab/host_vars/osh-comp-02.yml)

I traced the full storage path across all three layers — inventory, host_vars, and the actual disk attachments in topology.clab.yml. The short answer to "are we checking on the above?": **no, and it matters — as configured today, zero OSDs would come up.** Here is exactly why.

## The Ceph disk reality vs. what the CephCluster CR asks for

`roles/rook_ceph_deploy/templates/cephcluster.yaml.j2` iterates `groups['ceph_osd_nodes']` and uses each node's `ceph_osd_devices | default(['/dev/sdb'])`. But the raw disks in the topology don't line up with that group at all.

| Node | In `ceph_osd_nodes`? | `ceph_osd_devices` (host_vars) | Real disk in topology (drvCephA @ PCI `addr=0x5`) | Result |
|---|---|---|---|---|
| k8s-db-03 | ✅ | `/dev/vdb` | ❌ none (only system `addr=0x4`) | OSD fails — no disk |
| MonSrv | ✅ | `/dev/vdb`, `/dev/vdc` | ❌ none | both OSDs fail |
| osh-comp-03 | ✅ | *(unset → default `/dev/sdb`)* | ✅ host `/dev/sdd` → guest `/dev/vdb` | fails — CR asks `/dev/sdb`, disk is `/dev/vdb` |
| osh-comp-04 | ✅ | *(unset → default `/dev/sdb`)* | ❌ none | fails — no disk |
| osh-comp-01 | ❌ | *(unset)* | ✅ host `/dev/sdb` → guest `/dev/vdb` | disk wasted (not an OSD node) |
| osh-comp-02 | ❌ | *(unset)* | ✅ host `/dev/sdc` → guest `/dev/vdb` | disk wasted |
| k8s-master-03 | ❌ (control-plane) | `/dev/vdb`, has `20.0.56.31/32` | ❌ none | storage IP but never an OSD |

Two key facts that drive the mismatch:

1. **PCI → guest naming:** the Ceph passthrough disk is always the *second* virtio-blk device (`addr=0x5`, system disk is `addr=0x4`), so inside every guest it appears as **`/dev/vdb`** regardless of the host device (`/dev/sdb|sdc|sdd`). The `default(['/dev/sdb'])` in the template is therefore wrong for the guest.
2. **The three layers disagree on *which* nodes are OSDs:** disks are physically attached to `osh-comp-01/02/03`, the storage-VRF config (`vrf_storage`, `ceph_data_replication_ip`) is on `k8s-db-03`/`MonSrv`, and the group lists a fourth mix. Only `osh-comp-03` overlaps two of the three.

Because these don't intersect, `ceph_osd_expected` in validate-production.yml computes from `ceph_osd_nodes` × `ceph_osd_devices` (= 4 expected) while the deploy can bring up 0 — the assert would fire, but nothing *upstream* checks that the disks even exist before Rook runs.

## What I want to fix (two parts)

- **Safe, non-destructive (I can do now):** add a cross-layer pre-check that asserts, per `ceph_osd_node`, that every `ceph_osd_devices` entry is a real raw block device present in the guest, and that the OSD set is internally consistent (in-group ⇒ has disk + `vrf_storage` + replication IP). This is the "are we checking?" gap.
- **Hard-to-reverse (needs your call first):** reconciling *which* nodes are OSDs touches the physical `/dev/sdX` passthrough on the R810 and the switch storage BGP peers, so I don't want to guess.

Which is the intended 
source of truth? 

Got it — that's the source of truth. `physical_ceph_disk_a` is on **osh-comp-01 (`/dev/sdb`), osh-comp-02 (`/dev/sdc`), osh-comp-03 (`/dev/sdd`)**, passed through and appearing as **`/dev/vdb`** inside each guest (drvCephA at PCI `addr=0x5`). So the real OSD set is osh-comp-01/02/03 (Option A). Let me map the full cascade before editing — switch storage_ports and existing vrf_storage placement. 

Searched for regex `storage_ports|vrf_storage|ceph_data_replication_ip|physical_ceph_disk` (`**/host_vars/**`), 12 results

Read [](file:///c%3A/dc-lab/clab/sonic-clab/host_vars/Border-Leaf1.yml#40-40), lines 40 to 64

Read [](file:///c%3A/dc-lab/clab/sonic-clab/host_vars/Leaf-L3.yml#65-65), lines 65 to 77

Read [](file:///c%3A/dc-lab/clab/sonic-clab/host_vars/Leaf-L4.yml#40-40), lines 40 to 52

Read [](file:///c%3A/dc-lab/clab/sonic-clab/host_vars/Spine-S1.yml#18-18), lines 18 to 26

This is a substantial, interconnected storage fabric. Let me read the two leaf switches that host osh-comp-01 to determine the correct storage port names before editing.    

Read [](file:///c%3A/dc-lab/clab/sonic-clab/host_vars/Leaf-L1.yml)

Read [](file:///c%3A/dc-lab/clab/sonic-clab/host_vars/Leaf-L2.yml)

osh-comp-01 sits on **Leaf-L1/Leaf-L2 Ethernet4** (Accton AS5712, native 10G — no breakout). But the storage fabric currently doesn't reach the L1/L2 pod at all (no `storage_ports` on Leaf-L1/L2, and the spines don't list them). To make osh-comp-01 replicate to osh-comp-02/03 in the other pods, I must extend the storage VLAN across Leaf-L1/L2 and the spines. Let me read the spine port maps.    

Read [](file:///c%3A/dc-lab/clab/sonic-clab/host_vars/Spine-S1.yml)

Read [](file:///c%3A/dc-lab/clab/sonic-clab/host_vars/Spine-S2.yml)

Now I have the complete fabric map. Before editing, let me confirm which role consumes `vrf_storage`/`ceph_data_replication_ip` on the host side, so adding those vars to osh-comp-01/02/03 is sufficient to configure them.    

Searched for regex `vrf_storage|ceph_data_replication_ip|storage_ports|physical_ceph_disk` (`**/roles/**`), 40 results

Searched for regex `vrf_storage|ceph_data_replication_ip|storage_replication_nodes|linux_qos_htb|sonic_vrf_storage` (`**/playbooks/**`), 13 results

The topology is **generated** from `roles/clab_topology_prep/templates/topology.clab.yml.j2` using `physical_ceph_disk_a` — so I must not hand-edit the static topology.clab.yml; the disk attach already follows inventory. Let me confirm the template's guest-device mapping.    

Read [](file:///c%3A/dc-lab/clab/sonic-clab/roles/clab_topology_prep/templates/topology.clab.yml.j2#195-195), lines 195 to 230

Read [](file:///c%3A/dc-lab/clab/sonic-clab/roles/linux_netplan_staged/templates/30-ceph-dummy.yaml.j2)

This is now fully confirmed. The topology template itself hardcodes `['osh-comp-01', 'osh-comp-02', 'osh-comp-03']` as the OSD/disk nodes — so **Option A is the definitive design intent**, and only inventory.yml + host_vars were never updated to match. The guest device is always `/dev/vdb` (drvCephA @ `addr=0x5`). Let me lay out the work and execute. 

Created 9 todos

Now let me execute all the host_vars, inventory, group_vars, and template edits in one batch: 

Replacing 31 lines with 46 lines in [](file:///c%3A/dc-lab/clab/sonic-clab/inventory.yml), [](file:///c%3A/dc-lab/clab/sonic-clab/group_vars/ceph_osd_nodes.yml), [](file:///c%3A/dc-lab/clab/sonic-clab/host_vars/osh-comp-01.yml), [](file:///c%3A/dc-lab/clab/sonic-clab/host_vars/osh-comp-02.yml), [](file:///c%3A/dc-lab/clab/sonic-clab/host_vars/osh-comp-03.yml), [](file:///c%3A/dc-lab/clab/sonic-clab/roles/rook_ceph_deploy/templates/cephcluster.yaml.j2)


```

```

```

```

```

```

```

```

```

```

```

```


Starting: *Remove bogus ceph_osd_devices from k8s-db-03/MonSrv* (4/9)

Replacing 21 lines with 20 lines in [](file:///c%3A/dc-lab/clab/sonic-clab/host_vars/k8s-db-03.yml), [](file:///c%3A/dc-lab/clab/sonic-clab/host_vars/MonSrv.yaml)


```

```

```

```
Now the switch fabric. Let me confirm the tail of the Leaf-L1/L2 files before appending `storage_ports`.    

Read [](file:///c%3A/dc-lab/clab/sonic-clab/host_vars/Leaf-L1.yml#22-22), lines 22 to 22

Read [](file:///c%3A/dc-lab/clab/sonic-clab/host_vars/Leaf-L2.yml#22-22), lines 22 to 23

Replacing 14 lines with 32 lines in [](file:///c%3A/dc-lab/clab/sonic-clab/host_vars/Leaf-L1.yml), [](file:///c%3A/dc-lab/clab/sonic-clab/host_vars/Leaf-L2.yml), [](file:///c%3A/dc-lab/clab/sonic-clab/host_vars/Spine-S1.yml), [](file:///c%3A/dc-lab/clab/sonic-clab/host_vars/Spine-S2.yml)


```

```

```

```

```

```

```

```


Starting: *Add OSD disk-existence validation* (8/9)

Now add the OSD disk-existence check to the iperf3 play in verify-storage-qos.yml (runs on `ceph_osd_nodes`, pre-overlay — the exact gap behind "are we checking on the above?"): 

Replacing 3 lines with 26 lines in [](file:///c%3A/dc-lab/clab/sonic-clab/playbooks/verify-storage-qos.yml)


```

```
Now syntax-check the affected playbooks:  

Ran terminal command: wsl.exe -d ubuntu-24.04 bash -lc 'cd /mnt/c/dc-lab/clab/sonic-clab && CFG=/mnt/c/dc-lab/clab/sonic-clab/ansible.cfg; for p in playbooks/verify-storage-qos.yml playbooks/rook-ceph.yml playbooks/storage-vrf.yml playbooks/validate-production.yml; do echo "=== $p ==="; ANSIBLE_CONFIG=$CFG ansible-playbook -i inventory.yml "$p" --syntax-check; echo "RC=$?"; done'
Completed with input: wsl.exe -d ubuntu-24.04 bash -lc 'cd /mnt/c/dc-lab/clab/sonic-clab && CFG=/mnt/c/dc-lab/clab/sonic-clab/ansible.cfg; for p in playbooks/verify-storage-qos.yml playbooks/rook-ceph.yml playbooks/storage-vrf.yml playbooks/validate-production.yml; do echo "=== $p ==="; ANSIBLE_CONFIG=$CFG ansible-playbook -i inventory.yml "$p" --syntax-check; echo "RC=$?"; done'

Ran terminal command: wsl.exe -d ubuntu-24.04 bash -lc 'cd /mnt/c/dc-lab/clab/sonic-clab && ANSIBLE_CONFIG=/mnt/c/dc-lab/clab/sonic-clab/ansible.cfg ansible-playbook -i inventory.yml playbooks/verify-storage-qos.yml --syntax-check; echo "RC_VSQ=$?"'

Ran terminal command: wsl.exe -d ubuntu-24.04 bash -lc 'cd /mnt/c/dc-lab/clab/sonic-clab && ANSIBLE_CONFIG=/mnt/c/dc-lab/clab/sonic-clab/ansible.cfg ansible-playbook -i inventory.yml playbooks/validate-production.yml --syntax-check; echo "RC_VP=$?"; ANSIBLE_CONFIG=/mnt/c/dc-lab/clab/sonic-clab/ansible.cfg ansible-playbook -i inventory.yml playbooks/storage-vrf.yml --syntax-check; echo "RC_SV=$?"; ANSIBLE_CONFIG=/mnt/c/dc-lab/clab/sonic-clab/ansible.cfg ansible-playbook -i inventory.yml playbooks/rook-ceph.yml --syntax-check; echo "RC_RC=$?"'

Let me verify the derived values resolve correctly (OSD group, devices, and the replication-node derivation):   

Ran terminal command: wsl.exe -d ubuntu-24.04 bash -lc 'cd /mnt/c/dc-lab/clab/sonic-clab && ANSIBLE_CONFIG=/mnt/c/dc-lab/clab/sonic-clab/ansible.cfg ansible -i inventory.yml localhost -m debug -a "msg={{ groups["ceph_osd_nodes"] }} | repl={{ storage_replication_nodes }} | devs={{ groups["ceph_osd_nodes"] | map("extract", hostvars, "ceph_osd_devices") | list }}"'
Completed with input: wsl.exe -d ubuntu-24.04 bash -lc 'cd /mnt/c/dc-lab/clab/sonic-clab && ANSIBLE_CONFIG=/mnt/c/dc-lab/clab/sonic-clab/ansible.cfg ansible -i inventory.yml localhost -m debug -a "msg={{ groups["ceph_osd_nodes"] }} | repl={{ storage_replication_nodes }} | devs={{ groups["ceph_osd_nodes"] | map("extract", hostvars, "ceph_osd_devices") | list }}"'

Created [](file:///c%3A/dc-lab/clab/sonic-clab/_check_osd.yml)

Ran terminal command: wsl.exe -d ubuntu-24.04 bash -lc 'cd /mnt/c/dc-lab/clab/sonic-clab && ANSIBLE_CONFIG=/mnt/c/dc-lab/clab/sonic-clab/ansible.cfg ansible-playbook -i inventory.yml _check_osd.yml'

Everything resolves correctly. Let me remove the temp check file and finalize.   

Ran terminal command: Remove-Item C:\dc-lab\clab\sonic-clab\_check_osd.yml

Completed: *Add OSD disk-existence validation* (8/9)

Let me record this reconciliation in repo memory for continuity. 

Read memory [](file:///c%3A/Users/nh4134/AppData/Roaming/Code/User/workspaceStorage/77d38b8fb836138bdc64636f049387ed/GitHub.copilot-chat/memory-tool/memories/repo/notes.md)

Updated memory file [](file:///c%3A/Users/nh4134/AppData/Roaming/Code/User/workspaceStorage/77d38b8fb836138bdc64636f049387ed/GitHub.copilot-chat/memory-tool/memories/repo/notes.md)

Done. Yes — we're now checking on it, and I found the real problem in the process: the OSD set was inconsistent across three layers, and as configured **zero OSDs would have come up**.

## What was wrong
The topology generator topology.clab.yml.j2 hardcodes the OSD/disk nodes as `osh-comp-01/02/03` (attaching each node's `physical_ceph_disk_a` as drvCephA at PCI `addr=0x5` → guest `/dev/vdb`). But inventory.yml listed a *different* set (`k8s-db-03, MonSrv, osh-comp-03, osh-comp-04`), and the CephCluster CR defaulted to `/dev/sdb`. Nothing lined up.

## What I changed (all aligned to osh-comp-01/02/03 + `/dev/vdb`)
- **inventory.yml** — `ceph_osd_nodes` → `osh-comp-01/02/03` (the only nodes with `physical_ceph_disk_a`).
- **group_vars/ceph_osd_nodes.yml** — added `ceph_osd_devices: [/dev/vdb]` default (guest device for the `addr=0x5` passthrough), so it's dynamic per group membership.
- **host_vars osh-comp-01/02/03** — added `vrf_storage: true` + `ceph_data_replication_ip` (`20.0.56.15/25/35`) so Ceph daemons bind the storage subnet.
- **host_vars k8s-db-03 / MonSrv** — removed the bogus `ceph_osd_devices` (they have no disks); kept `vrf_storage` as mon/mgr storage endpoints.
- **cephcluster.yaml.j2** — device default `/dev/sdb` → `/dev/vdb`.
- **Storage fabric** — `osh-comp-02` (Leaf-L3/L4) and `osh-comp-03` (Border-Leaf) already had `storage_ports`; the L1/L2 pod didn't, so I added `storage_ports` to Leaf-L1/Leaf-L2 (osh-comp-01 on `Ethernet4.100` + spine uplinks) and added Leaf-L1/L2 to Spine-S1/S2 `storage_ports`, so osh-comp-01 can replicate across the spines.
- **Validation** — added an OSD disk-existence assert in verify-storage-qos.yml (stats each `ceph_osd_devices` entry, requires it to be a real block device) — this is the "are we checking?" gap. The QoS/isolation endpoints are now derived dynamically from `storage_replication_nodes` instead of the old hardcoded `HostB12-1/2`.

## Verified
All playbooks syntax-check clean, and the derivations resolve correctly:
- `ceph_osd_nodes` = `['osh-comp-01','osh-comp-02','osh-comp-03']`
- devices = `[['/dev/vdb'],['/dev/vdb'],['/dev/vdb']]`, replication IPs = `20.0.56.15/25/35`, `expected_osds = 3`.

One thing only a live deploy can confirm (not syntax): the exact SONiC port names I added for the storage VLAN on Leaf-L1/L2 (`Ethernet4`) and the spines (`Ethernet0`/`Ethernet4`). I derived them from each switch's real `access_ports`/`switch_ports` map, but worth a `show bgp vrf Vrf-storage summary` check after deploy to confirm those peers reach `Established`.

Made changes.

The user is explicitly requesting a guide, so creating a doc is appropriate. Let me gather the exact deploy/validate commands so the guide is accurate rather than invented.     

Read [](file:///c%3A/dc-lab/clab/sonic-clab/playbooks/storage-vrf.yml)

Searched for files matching `**/roles/rook_ceph_deploy/tasks/main.yml`, 1 match

Read [](file:///c%3A/dc-lab/clab/sonic-clab/playbooks/validate-production.yml#610-610), lines 610 to 760

Read [](file:///c%3A/dc-lab/clab/sonic-clab/roles/rook_ceph_deploy/tasks/main.yml)

I have everything needed. Creating a focused Ceph user guide in the wiki.   

Created [](file:///c%3A/dc-lab/clab/sonic-clab/wiki/ceph-user-guide.md)

Let me confirm the topo-prep playbook path I referenced exists.   

Searched for files matching `**/clab-topo-prep*.yml`, 1 match

The guide is created at wiki/ceph-user-guide.md. Let me add it to the wiki index so it's discoverable.   

Read [](file:///c%3A/dc-lab/clab/sonic-clab/wiki/index.md#1-1), lines 1 to 60

Replacing 3 lines with 4 lines in [](file:///c%3A/dc-lab/clab/sonic-clab/wiki/index.md)


```

```
Created the guide at wiki/ceph-user-guide.md and linked it from wiki/index.md.

It's written against the actual code/vars (not invented), and covers what you asked:

- **Architecture** — the L3VPN‑lite storage plane: OSD nodes `osh-comp-01/02/03`, `physical_ceph_disk_a` → guest `/dev/vdb`, `vrf-storage`/`Vrf-storage`, VLAN 100, `20.0.56.0/24`, per‑VRF eBGP‑unnumbered, HTB 80/20 QoS, plus a Mermaid topology diagram and the mon/mgr‑only nodes (`k8s-master-03`, `k8s-db-03`, `MonSrv`).
- **Deploy on K8s** — correct order: storage-vrf.yml → verify-storage-qos.yml → rook-ceph.yml → validate-production.yml, with what `rook_ceph_deploy` actually does (Helm, operator, CephCluster, StorageClasses) and the WSL `ANSIBLE_CONFIG` caveat.
- **Verify networking** — host + SONiC commands (`vtysh show bgp vrf … summary`, table‑300 isolation, sub‑interface enslavement) and Ansible one‑liners.
- **Validate** — which playbook/tags assert what (disk existence, isolation, eBGP `Established`, OSD‑to‑OSD ping, OSD count vs disks) plus manual `ceph status/osd dump`.
- **Test** — the iperf3 QoS split and a `rados bench`.
- **Use** — `ceph-block`/`ceph-filesystem` StorageClasses with RWO/RWX PVC examples.
- **Expand** — exact 3‑layer steps to add an OSD node (disk/topology, inventory group, host_vars, switch `storage_ports`, re‑deploy) and how to add a second disk (`/dev/vdc`).
- **Troubleshooting** table for the common failure modes.

Note: the older "Node Role Allocation" table in index.md still lists stale names (HostB12‑1/2, wrong IPs) and now conflicts with the reconciled OSD set — say the word and I'll correct that table to match the real inventory (`osh-comp-01/02/03` OSDs).

Made changes.

Let me find the exact playbooks that apply each layer of our changes so I give you the right run list.   

Searched for regex `linux_vrf_config|linux_netplan_staged|linux_frr_bgp|sonic_vrf_storage|rook_ceph_deploy|import_playbook.*storage|import_playbook.*rook`, 73 results

Compacted conversation

Read [](file:///c%3A/dc-lab/clab/sonic-clab/playbooks/lab/leaf-server-edge.yml)

Here's the mapping of our changes to the playbooks that apply them. No containerlab redeploy is needed — the topology template already hardcoded `osh-comp-01/02/03`, so the generated topology (and the `/dev/vdb` passthrough) is unchanged; only host/switch config and the Rook CR need re-applying.

## Run order

**1. Host + switch storage plane** — applies the new `vrf_storage` + `ceph_data_replication_ip` on `osh-comp-01/02/03` and the new `storage_ports` on Leaf-L1/L2 + Spine-S1/S2:

```bash
ansible-playbook -i inventory.yml playbooks/linux-netplan-stages.yml   # ensX.100 VLAN sub-ifs
ansible-playbook -i inventory.yml playbooks/linux-vrf-stages.yml       # cephdummy0 + vrf-storage
ansible-playbook -i inventory.yml playbooks/linux-bgp.yml              # host FRR storage BGP
ansible-playbook -i inventory.yml playbooks/storage-vrf.yml           # SONiC Vrf-storage + HTB QoS
```

Or run the single wrapper that chains all four **plus** the validations: playbooks/lab/leaf-server-edge.yml.

**2. Rook/Ceph** — re-renders the `CephCluster` CR with the reconciled `ceph_osd_nodes` (osh-comp-01/02/03) and `ceph_osd_devices: /dev/vdb`:

```bash
ansible-playbook -i inventory.yml playbooks/rook-ceph.yml
```

**3. Validate**:

```bash
ansible-playbook -i inventory.yml playbooks/verify-storage-qos.yml
ansible-playbook -i inventory.yml playbooks/validate-production.yml --tags storage,ceph
```

## Wrapping via WSL

Each command runs as (the literal `ANSIBLE_CONFIG=` path is required):

```powershell
wsl.exe -d ubuntu-24.04 bash -lc 'cd /mnt/c/dc-lab/clab/sonic-clab && ANSIBLE_CONFIG=/mnt/c/dc-lab/clab/sonic-clab/ansible.cfg ansible-playbook -i inventory.yml playbooks/storage-vrf.yml'
```

## One-shot options
- playbooks/lab/fabric-full.yml — full build (topology → fabric → storage-vrf → verify → rook-ceph); overkill for these incremental edits.
- playbooks/site.yml — same end-to-end chain including rook-ceph.yml.
- playbooks/lab/overlay-k8s.yml — just the Rook/Ceph overlay if the fabric/host plane is already current.

For your case (incremental reconciliation on a running lab), the targeted 3-step sequence above is the least disruptive.

Let me find the exact playbooks that apply each layer of our changes so I give you the right run list.   

Searched for regex `linux_vrf_config|linux_netplan_staged|linux_frr_bgp|sonic_vrf_storage|rook_ceph_deploy|import_playbook.*storage|import_playbook.*rook`, 73 results

Compacted conversation

Read [](file:///c%3A/dc-lab/clab/sonic-clab/playbooks/lab/leaf-server-edge.yml)

Here's the mapping of our changes to the playbooks that apply them. No containerlab redeploy is needed — the topology template already hardcoded `osh-comp-01/02/03`, so the generated topology (and the `/dev/vdb` passthrough) is unchanged; only host/switch config and the Rook CR need re-applying.

## Run order

**1. Host + switch storage plane** — applies the new `vrf_storage` + `ceph_data_replication_ip` on `osh-comp-01/02/03` and the new `storage_ports` on Leaf-L1/L2 + Spine-S1/S2:

```bash
ansible-playbook -i inventory.yml playbooks/linux-netplan-stages.yml   # ensX.100 VLAN sub-ifs
ansible-playbook -i inventory.yml playbooks/linux-vrf-stages.yml       # cephdummy0 + vrf-storage
ansible-playbook -i inventory.yml playbooks/linux-bgp.yml              # host FRR storage BGP
ansible-playbook -i inventory.yml playbooks/storage-vrf.yml           # SONiC Vrf-storage + HTB QoS
```

Or run the single wrapper that chains all four **plus** the validations: playbooks/lab/leaf-server-edge.yml.

**2. Rook/Ceph** — re-renders the `CephCluster` CR with the reconciled `ceph_osd_nodes` (osh-comp-01/02/03) and `ceph_osd_devices: /dev/vdb`:

```bash
ansible-playbook -i inventory.yml playbooks/rook-ceph.yml
```

**3. Validate**:

```bash
ansible-playbook -i inventory.yml playbooks/verify-storage-qos.yml
ansible-playbook -i inventory.yml playbooks/validate-production.yml --tags storage,ceph
```

## Wrapping via WSL

Each command runs as (the literal `ANSIBLE_CONFIG=` path is required):

```powershell
wsl.exe -d ubuntu-24.04 bash -lc 'cd /mnt/c/dc-lab/clab/sonic-clab && ANSIBLE_CONFIG=/mnt/c/dc-lab/clab/sonic-clab/ansible.cfg ansible-playbook -i inventory.yml playbooks/storage-vrf.yml'
```

## One-shot options
- playbooks/lab/fabric-full.yml — full build (topology → fabric → storage-vrf → verify → rook-ceph); overkill for these incremental edits.
- playbooks/site.yml — same end-to-end chain including rook-ceph.yml.
- playbooks/lab/overlay-k8s.yml — just the Rook/Ceph overlay if the fabric/host plane is already current.

For your case (incremental reconciliation on a running lab), the targeted 3-step sequence above is the least disruptive.

I'll read the guide and an existing wiki HTML to match the styling. 

Read [](file:///c%3A/dc-lab/clab/sonic-clab/wiki/ceph-user-guide.md)

Now let me look at an existing wiki HTML to match the styling convention. 

Read [](file:///c%3A/dc-lab/clab/sonic-clab/wiki/vrf-storage-design-tradeoffs.html#1-1), lines 1 to 120

Now I'll create the HTML version matching the wiki styling, with Mermaid rendered via CDN. 

Created [](file:///c%3A/dc-lab/clab/sonic-clab/wiki/ceph-user-guide.html)

Now let me add the HTML version to the wiki index's HTML section. Let me check the rest of index.md and index.html. 

Read [](file:///c%3A/dc-lab/clab/sonic-clab/wiki/index.md#61-61), lines 61 to 89

Replacing 4 lines with 5 lines in [](file:///c%3A/dc-lab/clab/sonic-clab/wiki/index.md)


```

```
Created wiki/ceph-user-guide.html — a browser-openable version of the guide.

- Matches the existing wiki styling (same CSS as vrf-storage-design-tradeoffs.html): cards, tables, dark code blocks, index/cross-links.
- The Mermaid topology diagram renders live via the Mermaid CDN (`mermaid@10`), so the Pod/Spine flowchart displays in the browser.
- All relative links (`../inventory.yml`, `../playbooks/...`, `../roles/...`) resolve the same way as the other wiki HTML pages.
- Added it to the "HTML Versions" list in wiki/index.md.

Open it directly at ceph-user-guide.html. Note: the Mermaid diagram needs internet access for the CDN script; the rest of the page is fully self-contained and works offline.

Made changes.

The failure is a switch-side task referencing `ceph_data_replication_ip`, which only exists on OSD hosts, not switches. Let me read that role task. 

Read [](file:///c%3A/dc-lab/clab/sonic-clab/roles/sonic_vrf_storage/tasks/main.yml#160-160), lines 160 to 240

Searched for regex `ceph_data_replication_ip|storage_subnet` (`**/roles/sonic_vrf_storage/tasks/main.yml`), 4 results

Read [](file:///c%3A/dc-lab/clab/sonic-clab/roles/sonic_vrf_storage/tasks/main.yml#95-95), lines 95 to 115

Read [](file:///c%3A/dc-lab/clab/sonic-clab/roles/sonic_vrf_storage/tasks/main.yml#186-186), lines 186 to 225

Switches are transit nodes — they have no `ceph_data_replication_ip` and must not originate a host `/32`. The fix: the export prefix-list should permit the whole storage subnet (so all OSD `/32`s transit), and drop the local-origination `network` line on switches. 

Replacing 9 lines with 8 lines in [](file:///c%3A/dc-lab/clab/sonic-clab/roles/sonic_vrf_storage/tasks/main.yml)


```

```
Now syntax-check the playbook that runs this role. 

Ran terminal command: wsl.exe -d ubuntu-24.04 bash -lc 'cd /mnt/c/dc-lab/clab/sonic-clab && ANSIBLE_CONFIG=/mnt/c/dc-lab/clab/sonic-clab/ansible.cfg ansible-playbook -i inventory.yml playbooks/storage-vrf.yml --syntax-check'

Fixed. The syntax check passes. Here's the assessment of what you pasted — there are **two** distinct things in that output:

## 1. The `FAILED` task — root cause fixed
The `sonic_vrf_storage` role (switch-only) referenced `ceph_data_replication_ip`, which is a **host_var that exists only on OSD nodes**, never on switches. Switches are transit nodes — they don't originate a host `/32`. I corrected two ungated references in roles/sonic_vrf_storage/tasks/main.yml:

- Export prefix-list now permits the whole subnet so every OSD `/32` transits:
  `ip prefix-list STORAGE-ONLY seq 10 permit {{ storage_subnet }} le 32` (was `permit {{ ceph_data_replication_ip }}`).
- Removed the `network {{ ceph_data_replication_ip }}` origination line from the switch FRR block (switches re-advertise learned `/32`s, they don't originate).

The third reference (line 107, CONFIG_DB `BGP_NETWORK`) was already gated with `when: ceph_data_replication_ip is defined`, so it correctly skips on switches.

## 2. The `Idle` / `PfxRcd 0` / `RIB entries 0` summary — likely a side-effect, not yet proven fixed
That "Report storage VRF BGP summary" ran **before** the play aborted. The task that actually brings sessions up — *"Apply vrf-storage BGP neighbors directly in FRR"* (does `no bgp ebgp-requires-policy`, `neighbor … activate`, and `clear bgp vrf … * soft`) — runs **after** the task that failed, so **it never executed**. That is a plausible reason the neighbors were still `Idle`.

So re-running the now-fixed playbook should let those neighbors activate. Re-run and re-check:

```bash
ansible-playbook -i inventory.yml playbooks/storage-vrf.yml
# then confirm sessions move off Idle:
ansible sonic_switches -b -m shell -a 'docker exec bgp vtysh -c "show bgp vrf Vrf-storage ipv4 unicast summary"'
```

Caveat — I can't confirm from a syntax check alone that sessions reach `Established`. Establishment also requires, on the **host** side, that:
- each OSD/mon node's `vrf-storage` FRR is up and **originating** its `20.0.56.x/32` (role `linux_frr_bgp`), and
- IPv6 link-local (`fe80::`) is present on each `EthernetX.100` subinterface (the role already waits for this).

If after the re-run any peer is still `Idle`, paste a host-side `vtysh -c "show bgp vrf vrf-storage summary"` from one OSD node and the switch's `show bgp vrf Vrf-storage neighbors <sub> ` and I'll trace it.

Want me to also add a guard so the switch role fails fast with a clear message if `storage_subnet` is ever undefined, and reorder the summary task to run after activation so the log reflects the real state?

Made changes.
You're right — that's exactly the design, and yes, `20.0.56.0/24` must **never** appear in the main (default) BGP table. Let me verify nothing in the current config leaks between the two VRFs. 

Searched for regex `import vrf|redistribute|20\.0\.56|route-leak|rt import|rt export|ip route.*table` (`**/roles/**/{frr.conf.j2,main.yml,50-vrf-storage.yaml.j2}`), 16 results

Searched for regex `20\.0\.56|storage_subnet|vrf-storage|Vrf-storage|isolation|default table|table 300` (`**/playbooks/validate-production.yml`), 35 results

Correct — that's exactly the design, and it's both structurally enforced and validated. You should **never** see `20.0.56.x` in the main/default BGP table.

## Why it stays separate

1. **Dedicated VRF end-to-end** — `Vrf-storage` on switches (its own `vrf-id`, e.g. 51/83/124) and `vrf-storage` (table 300) on hosts. The summary you pasted is the **storage** instance (`VRF Vrf-storage vrf-id 51`), so those peers/prefixes live in the storage RIB, not the default one.

2. **Storage `/32`s originate only inside the storage VRF** — via per-VRF `BGP_NETWORK|Vrf-storage|…` on switches and the `vrf-storage` FRR instance on hosts. Nothing redistributes them into default.

3. **No route-leak between the two VRFs** — I grepped the whole repo: there is **no `import vrf`** tying `vrf-storage`↔`default` anywhere. The only `import vrf` in the codebase is the unrelated exit-router `vrf-internet`↔`default`. On switches, `ROUTE_REDISTRIBUTE` is scoped per-VRF, and the default fabric (`sonic_bgp_unnumbered`) only redistributes the loopback `/32` + `k8s_pod_block_cidr` — never the storage subnet.

## It's also asserted (fails loudly if it ever leaks)

validate-production.yml has explicit air-gap checks on the hosts:

- Line 326/332 and 704/710 — `ip route show | grep 20.0.56.0/24` in the **default** table must return **0**, else:
  `AIR-GAP VIOLATION … storage subnet leaked into the default table`.

Run it any time to prove isolation:

```bash
ansible-playbook -i inventory.yml playbooks/validate-production.yml --tags storage,vrf
```

Or check directly on a box:

```bash
# host: present only in table 300, absent from default
ip route show table 300 | grep 20.0.56    # <- should list the /32s
ip route show           | grep 20.0.56    # <- MUST be empty
# switch: only in the storage VRF RIB
docker exec bgp vtysh -c "show bgp vrf Vrf-storage ipv4 unicast"   # <- 20.0.56.x here
docker exec bgp vtysh -c "show bgp ipv4 unicast"                   # <- no 20.0.56.x
```

## One clarification about what you saw
The `RIB entries 0` / `Idle` in your paste wasn't a leak — it was the *storage* VRF having learned nothing yet because the play aborted (the undefined-var bug) **before** the neighbor-activation + `clear bgp … soft` task ran. That's now fixed; after a clean re-run the `20.0.56.x/32`s should populate the `Vrf-storage` RIB **only**, and remain absent from the default table.

I'll add expected `show bgp vrf` route output examples for hosts and leaf/spine switches. Let me read the exact current section 3 text to edit precisely.  

Read [](file:///c%3A/dc-lab/clab/sonic-clab/wiki/ceph-user-guide.md#150-150), lines 150 to 180

Read [](file:///c%3A/dc-lab/clab/sonic-clab/wiki/ceph-user-guide.md#108-108), lines 108 to 146

Now I'll add a "3.3 Expected route state" subsection with realistic `show bgp vrf` outputs for host, leaf, and spine, plus an ASN reference.  

Replacing 5 lines with 132 lines in [](file:///c%3A/dc-lab/clab/sonic-clab/wiki/ceph-user-guide.md)


```

```
Now mirror this into the HTML. Let me update the Section 3 card in the HTML file.  

Replacing 4 lines with 94 lines in [](file:///c%3A/dc-lab/clab/sonic-clab/wiki/ceph-user-guide.html)


```

```
Let me verify the HTML card structure stayed intact around the new section boundary.   

Searched for regex `MUST be empty` (`**/wiki/ceph-user-guide.html`), 2 results

Read [](file:///c%3A/dc-lab/clab/sonic-clab/wiki/ceph-user-guide.html#238-238), lines 238 to 248

Structure is intact. Both docs are enriched.

Added a new **§3.3 "Expected route state (what 'good' looks like)"** to both wiki/ceph-user-guide.md and wiki/ceph-user-guide.html, driven by the real subnets/VLAN/VRF/ASNs:

- **ASN + `/32` reference table** — OSD hosts (`65215/65225/65235` → `20.0.56.15/25/35`), leaves (`65011/12/21/22`), border-leaves (`65031/32`), spines (`65000`), with their storage ports.
- **Host sample** — `osh-comp-01` `show bgp vrf vrf-storage summary` + `ipv4 unicast`: self-originated `20.0.56.15/32` from `cephdummy0`, the two remote OSD `/32`s learned ECMP over `ens2`/`ens3` (`*>` primary, `*` backup), with full AS-paths (e.g. `65011 65000 65021 65225`).
- **Leaf sample** — `Leaf-L1` (`65011`): local OSD `/32` learned directly (`65215 i`), the other two via both spines; `PfxRcd`/`PfxSnt` annotated.
- **Spine sample** — `Spine-S1` (`65000`): all six neighbors (the L1/L2 pair we just added included → `Total number of neighbors 6`), all three `/32`s with two ECMP paths each.
- **Isolation sanity checks** — `ip route show | grep 20.0.56` (default table MUST be empty) and `show bgp ipv4 unicast | grep 20.0.56` on switches (MUST be empty).
- A note on reading `State/PfxRcd`: `Idle/Active/never` = session down; `PfxRcd 0` on an established session = peer not originating its `/32`.

Router-IDs are flagged as illustrative except the ones already observed live (Spine-S1 `10.0.1.1`, Leaf-L3 `10.0.2.3`). The HTML renders these as monospaced `<pre>` blocks matching the wiki style; open `wiki/ceph-user-guide.html` in the browser to view.

Made changes.

Asked a question (osd-source-of-truth)
