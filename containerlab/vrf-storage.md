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
