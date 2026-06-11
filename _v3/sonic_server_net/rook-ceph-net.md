The failure to spawn rook-ceph-osd-prepare pods on your virsh VMs is primarily caused by Ceph's strict drive sanitization requirements and virtual disk signatures, compounded by underlying MTU mismatches across your virtual L3 CLOS Fabric or routing loop conflicts between Kubespray Calico and host-level FRRouting (FRR).
------------------------------
## 1. Fix the Ceph OSD-Prepare Failure [1] 
Rook will completely skip creating osd-prepare jobs if the target virtual drives (/dev/vdb and /dev/vdc) contain existing file systems, partition tables, LVM metadata, or incorrect drive geometry signatures from virsh.
## Wipe the Virtual Disks [2] 
Log directly into the six affected worker VMs and completely wipe the drives: [3] 

# Install sgdisk if missing
sudo apt-get install gdisk -y || sudo yum install gdisk -y
# Zap the virtual disks to clear GPT/MBRfor disk in vdb vdc; do
  sudo sgdisk --zap-all /dev/$disk
  sudo dd if=/dev/zero of=/dev/$disk bs=1M count=100 oflag=direct
  sudo blkid /dev/$diskdone

Note: The blkid command must return absolutely no output for both disks.
## Verify virsh Disk Configurations [4] 
Ensure your KVM/virsh XML configuration exposes these disks as raw unformatted block devices without caching conflicts. They should look like this in your domain XML:

<disk type='file' device='disk'>
  <driver name='qemu' type='raw' cache='none' io='native'/>
  <source file='/var/lib/libvirt/images/vm_osd_b.img'/>
  <target dev='vdb' bus='virtio'/>
</disk>

## Restart the Operator to Force Discovery
Once wiped, force the rook-ceph-operator to re-scan the node hardware:

kubectl -n rook-ceph rollout restart deployment rook-ceph-operator

------------------------------
## 2. MTU Setup Across Virtual L3 CLOS Fabric
A common reason Rook Mon pods form a quorum but OSDs fail to initialize is packet fragmentation during large Ceph peering payloads. Standard Ceph traffic requires flawless end-to-end MTU matching.

+-------------------+      +-------------------+      +-------------------+

|    Worker VM      |      |   KVM Host Br/VTEP|      |  L3 CLOS Spine    |
|  (MTU 9000/8500)  | ---> |    (MTU 9000)     | ---> |    (MTU 9000)     |
+-------------------+      +-------------------+      +-------------------+

## Fabric/Spine/Leaf Switches

* Configure all physical and virtual switches in the CLOS fabric to Jumbo Frames (MTU 9000).

## KVM Hypervisor (Host Level)

* Match the hypervisor physical NICs, Linux bridges, or OVS bonds to MTU 9000.
* If you use VXLAN/GENEVE overlays at the host level, set the host interfaces to 9050 to account for encapsulation overhead.

## Guest virsh VMs

* Set the VM's primary network interfaces to MTU 9000 (if the underlying fabric is purely routed) or MTU 8500 (if an unmanaged overlay tunnel adds encapsulation overhead).

------------------------------
## 3. BGP Conflicts: Kubespray Calico vs. Host FRR
Even if Calico is "turned off" or globally disabled in Kubespray, its underlying components or legacy configurations can severely conflict with a host-level FRR daemon running on your virsh hypervisors.
## The Port 179 Socket Conflict
Both Calico (bird or native GoBGP engine) and host-level FRR default to binding to TCP Port 179 for BGP peering. If Calico is partially active or restarting, it will fight FRR for this port, causing BGP sessions to flap and dropping network pathways between Ceph nodes.
## Route Leaking & Symmetric Routing Asymmetry
When Calico is active on the node, it injects /32 container routes into the kernel routing table (Table 254). If host FRR is simultaneously advertising the VM's subnet to the L3 CLOS fabric, it creates an asymmetric routing loop. Packets enter via FRR rules but attempt to exit via Calico's virtual interfaces (cali+), resulting in dropped Ceph traffic.
## How to Properly Disable Calico in Kubespray
To ensure Calico is completely removed from the equation so it does not interfere with your FRR architecture, modify your Kubespray inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml configuration:

# Set network plugin to none if managing routing entirely via Host FRRkube_network_plugin: allow-pods-to-communicatekube_network_plugin_multus: false
# Or ensure Calico is explicitly stripped outcalico_bgp_daemon_enabled: false

## Ensure Host FRR Configuration is Isolate-Safe
If your worker nodes must leverage host-level FRR to peer with your L3 Leaf switches, use explicit prefix lists to prevent the host from accidentally consuming or re-advertising internal Kubernetes pod/service networks:

! frr.conf snippet
router bgp 65001
 bgp router-id 10.0.0.11
 neighbor 10.0.0.1 remote-as 65000
 !
 address-family ipv4 unicast
  network 10.0.0.11/32
  ! Do NOT redistribute connected or kernel unless filtered strictly
  distribute-list FILTER_K8S out
 exit-address-family
!
access-list FILTER_K8S permit 10.0.0.0/24

------------------------------
## ✅ Summary of Resolution Steps
Below is the definitive verification of actions required to bring up your Ceph OSD pods:

   1. Wipe disk signatures completely using sgdisk --zap-all on every single /dev/vdb and /dev/vdc drive across all 6 VMs.
   2. Standardize your CLOS fabric MTU to 9000 across switches, KVM bridges, and VM interfaces to prevent Ceph packet truncation.
   3. Purge the TCP 179 binding conflict by ensuring Kubespray has completely deactivated Calico's BGP daemon, leaving host-level FRR as the sole routing authority.

To help narrow down any remaining edge cases, what operating system are your virsh VMs running, and what error message does kubectl -n rook-ceph logs show for the operator pod?

[1] [https://www.juniper.net](https://www.juniper.net/documentation/us/en/software/paragon-automation22.1/paragon-automation-troubleshooting-guide/topics/topic-map/tg-troubleshoot-ceph-rook.html)
[2] [https://github.com](https://github.com/rook/rook/issues/13825)
[3] [https://oneuptime.com](https://oneuptime.com/blog/post/2026-01-07-ceph-rook-bare-metal-kubernetes/view)
[4] [https://www.cisco.com](https://www.cisco.com/c/en/us/td/docs/unified_computing/ucs/ucs-director/troubleshooting-guide/cisco-ucs-director-troubleshooting/issues_and_solutions.html)



## Clarification on the 10.0.0.0/24 Subnet
The 10.0.0.0/24 block in the previous example was a generic placeholder representing a local host subnet. Because your topology utilizes BGP Unnumbered across an L3 CLOS fabric, you do not use traditional IP subnets for peering.
Instead, your interfaces use IPv6 Link-Local addresses for BGP neighbor discovery, and Extended Next Hop Encoding (RFC 8950) allows your IPv4 prefixes (like host /32 loopbacks) to route over those unnumbered IPv6 links. [1] 
------------------------------
## Step 1: Completely Strip Calico Interfaces from Kubespray
To ensure that Calico is entirely removed from the VMs and never provisions virtual interfaces (like cali* or tunl0), you must switch Kubespray to use no CNI plugin, or switch to a provider that does not manage host routing tables.
Since you are running OpenStack for tenant isolation, the typical architectural design is to let OpenStack Neutron handle encapsulation/CNI plumbing (e.g., via the Kuryr CNI or native OpenStack ML2/OVN orchestration), rather than layering a separate Calico mesh on top.
## Modify Kubespray Inventory Variables
Update your inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml:

# Disable Calico completelykube_network_plugin: allow-pods-to-communicatekube_network_plugin_multus: false
# Remove all Calico deployment declarationscalico_network_backend: nonecalico_bgp_daemon_enabled: false

## Purge Leftover Calico Interfaces on Existing VMs
If Kubespray has already run and left behind legacy configurations, log into your VMs and manually destroy the Calico artifacts:

# Bring down and delete the Calico tunnel interface if present
sudo ip link set dev tunl0 down 2>/dev/null
sudo ip link delete dev tunl0 2>/dev/null
# Remove any remaining cali* virtual veth pairsfor intf in $(ip link show | grep -o 'cali[a-f0-9]*'); do
    sudo ip link set dev $intf down
    sudo ip link delete dev $intfdone
# Flush iptables chains that Calico commonly leaves behind
sudo iptables -F
sudo iptables -X

------------------------------
## Step 2: Netplan Configuration for VRF-Storage and VRF-Default
To map your explicit VM interfaces directly to separate Routing Tables/VRFs for Ceph (vrf-storage) and tenant communications (vrf-default), you must configure Netplan explicitly. This isolation prevents Ceph's high-throughput replication traffic from bleeding into tenant networks.
## Example Netplan Configuration (/etc/netplan/01-netcfg.yaml)

network:
  version: 2
  renderer: networkd
  ethernets:
    # Interface connected to your L3 CLOS for general tenant traffic
    ens3:
      dhcp4: no
      addresses:
        - 192.168.10.15/24

    # Interface dedicated exclusively to Rook-Ceph storage traffic
    ens4:
      dhcp4: no
      addresses:
        - 172.16.50.15/24

  vrfs:
    # Tenant VRF
    vrf-default:
      table: 100
      interfaces:
        - ens3

    # Ceph Storage VRF
    vrf-storage:
      table: 200
      interfaces:
        - ens4

Apply the changes:

sudo netplan generate
sudo netplan apply

------------------------------
## Step 3: FRR Configuration for BGP Unnumbered with VRFs
Because FRR on the host needs to advertise endpoints inside specific VRFs over BGP Unnumbered interfaces, you must bind your BGP instances to those VRFs. [2] 
Below is the corresponding frr.conf configuration. It leverages BGP Unnumbered on the underlying physical interfaces while segregating the IPv4 addresses into their respective VRF address families.

! /etc/frr/frr.conf

! Enable VRF routing capabilities
vrf vrf-default
 vrf-routing-backend linux
exit
!
vrf vrf-storage
 vrf-routing-backend linux
exit

! ----------------------------------------------------
! BGP Instance for Tenant Communications (vrf-default)
! ----------------------------------------------------
router bgp 65501 vrf vrf-default
 bgp router-id 192.168.10.15
 
 ! Peer over the BGP Unnumbered interface
 neighbor ens3 interface remote-as external
 
 address-family ipv4 unicast
  ! Advertise the local tenant interface IP to the CLOS fabric
  network 192.168.10.15/32
  neighbor ens3 activate
 exit-address-family

! ----------------------------------------------------
! BGP Instance for Ceph Storage (vrf-storage)
! ----------------------------------------------------
router bgp 65501 vrf vrf-storage
 bgp router-id 172.16.50.15
 
 ! Peer over the BGP Unnumbered interface
 neighbor ens4 interface remote-as external
 
 address-family ipv4 unicast
  ! Advertise the local Ceph storage IP to the CLOS fabric
  network 172.16.50.15/32
  neighbor ens4 activate
 exit-address-family

------------------------------
## Step 4: Bind Rook-Ceph to the Storage Network
With Calico out of the picture and your network segmented, you must force Rook to bind exclusively to the interfaces inside vrf-storage.
Update your cluster.yaml deployment file for Rook-Ceph to use the host network directly, explicitly telling Ceph which subnets belong to the public (client) and cluster (replication) pathways: [3] 

spec:
  # Instruct Rook to use the host's networking stack directly
  network:
    provider: host
    selectors:
      # Targets the explicit subnet configured in vrf-storage
      public: 172.16.50.0/24
      cluster: 172.16.50.0/24

Apply the updated configuration to trigger the OSD preparation framework on the newly isolated interfaces:

kubectl apply -f cluster.yaml

If you apply this configuration, let me know:

* What OpenStack CNI/mechanism driver (like OVN, Kuryr, or LinuxBridge) you intend to deploy for your tenant networking.
* Whether your CLOS fabric leaf switches are already configured to accept these specific VRF BGP EVPN/L3VPN strings.


[1] [https://netlab.tools](https://netlab.tools/module/vrf/)
[2] [https://community.cisco.com](https://community.cisco.com/t5/routing/need-some-help-to-understand-vrf-feature/td-p/2459188)
[3] [https://www.ibm.com](https://www.ibm.com/docs/en/tncm-p/1.4.4?topic=oitncmpo-setting-up-rook-ceph-operator-in-network-restricted-airgap-environment)



When multi-homing your virsh VMs to a SONiC Leaf pair using BGP Unnumbered, you are building a highly resilient, active-active or active-standby Layer 3 boundary directly at the virtual host level.
Because SONiC relies heavily on FRR internally, aligning your host-level FRR configurations to interface seamlessly over these unnumbered connections requires strict attention to LACP/MCLAG visibility, IPv6 Link-Local peering, and Linux Kernel VRF packet handling. [1] 
------------------------------
## 1. Updated Netplan Configuration for Multi-Homing
In a multi-homed SONiC Leaf architecture, your interfaces (ens3 and ens4) connect to two distinct physical switches or separate ports on an MC-LAG pair. [2, 3] 
Instead of configuring BGP unnumbered directly on raw physical interfaces, it is best practice to attach them to Linux VRF devices. This allows FRR to cleanly bind the unnumbered IPv6 Link-Local neighbor discovery to the correct routing tables.

# /etc/netplan/01-netcfg.yamlnetwork:
  version: 2
  renderer: networkd
  ethernets:
    # --- Tenant Network Path (Multi-homed to SONiC Leaf Pair) ---
    ens3:
      dhcp4: no
      ipv6-privacy: off
      accept-ra: false
    
    # --- Ceph Storage Network Path (Multi-homed to SONiC Leaf Pair) ---
    ens4:
      dhcp4: no
      ipv6-privacy: off
      accept-ra: false

  vrfs:
    vrf-default:
      table: 100
      interfaces:
        - ens3

    vrf-storage:
      table: 200
      interfaces:
        - ens4

Note on IPv6: BGP Unnumbered requires an IPv6 Link-Local address (fe80::/10) to automatically generate on ens3 and ens4. Ensure your VM kernel does not disable IPv6 on these interfaces (sysctl -w net.ipv6.conf.all.disable_ipv6=0).
------------------------------
## 2. Multi-Homed FRR BGP Unnumbered Configuration
SONiC Leafs expect an IPv6 neighbor relationship over the link, which they will use to exchange your IPv4 /32 loopbacks via RFC 8950 (Extended Next Hop Encoding). [4] 
To ensure optimal pathing across your multi-homed setup, you must enable Multipath in FRR so that the host can balance traffic across both links or react immediately if a SONiC leaf fails.

! /etc/frr/frr.conf

! Enable the necessary Linux routing table bindings
vrf vrf-default
 vrf-routing-backend linux
exit
!
vrf vrf-storage
 vrf-routing-backend linux
exit

! ----------------------------------------------------
! VRF-DEFAULT: Tenant Path to SONiC
! ----------------------------------------------------
router bgp 65501 vrf vrf-default
 bgp router-id 192.168.10.15
 ! Enable Equal-Cost Multi-Pathing (ECMP) across the leaf pair
 maximum-paths 64
 
 ! Setup BGP Unnumbered Peer Template
 neighbor SONIC_LEAF_TENANT peer-group
 neighbor SONIC_LEAF_TENANT remote-as external
 neighbor SONIC_LEAF_TENANT capability extended-nexthop
 
 ! Bind the unnumbered interface
 neighbor ens3 interface peer-group SONIC_LEAF_TENANT
 
 address-family ipv4 unicast
  ! Advertise this specific VM host tenant IP
  network 192.168.10.15/32
  neighbor SONIC_LEAF_TENANT activate
 exit-address-family

! ----------------------------------------------------
! VRF-STORAGE: Rook-Ceph Path to SONiC
! ----------------------------------------------------
router bgp 65501 vrf vrf-storage
 bgp router-id 172.16.50.15
 maximum-paths 64
 
 ! Setup BGP Unnumbered Peer Template
 neighbor SONIC_LEAF_STORAGE peer-group
 neighbor SONIC_LEAF_STORAGE remote-as external
 neighbor SONIC_LEAF_STORAGE capability extended-nexthop
 
 ! Bind the unnumbered interface
 neighbor ens4 interface peer-group SONIC_LEAF_STORAGE
 
 address-family ipv4 unicast
  ! Advertise this specific VM host storage IP
  network 172.16.50.15/32
  neighbor SONIC_LEAF_STORAGE activate
 exit-address-family

------------------------------
## 3. Critical Linux Kernel Sysctls for VRF + Ceph
Because Rook-Ceph and Kubernetes pods will run inside the network namespace of the host, the Linux kernel needs specific instructions to look past the VRF boundaries when resolving paths, or BGP Unnumbered next-hops will fail to resolve.
Create or update /etc/sysctl.d/99-ceph-vrf.conf:

# Allow BGP Unnumbered next-hops to be looked up across VRF tables
net.ipv4.tcp_l3mdev_accept = 1
net.ipv4.udp_l3mdev_accept = 1

# Ensure the system processes standard routing before VRF rules
net.ipv4.ip_forward = 1

Apply the parameters: sudo sysctl --system
------------------------------
## 4. Verifying Connectivity on the Host [5] 
Before you re-trigger the Rook deployment, verify that the unnumbered peerings have successfully formed with your SONiC switches and the routes are properly injected into the correct Linux kernel tables.

   1. Check FRR BGP Summaries per VRF:
   
   sudo vtysh -c "show bgp vrf vrf-default summary"
   sudo vtysh -c "show bgp vrf vrf-storage summary"
   
   You should see ens3 and ens4 showing established states with their respective IPv6 Link-Local neighbors.
   2. Verify Kernel Table Injection:
   
   ip route show table 200
   
   This must show paths to your other 5 Ceph nodes via nhid or dev ens4 using the unnumbered next-hop.
   3. Verify Ceph OSD Allocation:
   Now that the storage network layer is fully isolated via vrf-storage, restart your rook-ceph-operator. It will cleanly map the wiped /dev/vdb and /dev/vdc drives over the 172.16.50.15/32 bound network context without any Calico interference.

If your host-level BGP sessions remain stuck in an Active or Connect state, let me know:

* Are your SONiC leaf switches configured with capability extended-nexthop on their respective interface peer-groups?
* Are you using IPv4-anycast gateways on the SONiC side, or is it a strict point-to-point unnumbered leaf architecture?


[1] [https://www.ciscolive.com](https://www.ciscolive.com/c/dam/r/ciscolive/global-event/docs/2025/pdf/DEVNET-2990.pdf)
[2] [https://www.cisco.com](https://www.cisco.com/c/en/us/td/docs/dcn/nx-os/nexus9000/106x/configuration/vxlan/cisco-nexus-9000-series-nx-os-vxlan-configuration-guide-release-106x/configuring-esi-tx.html)
[3] [https://infohub.delltechnologies.com](https://infohub.delltechnologies.com/en-ca/l/dell-enterprise-sonic-deployment-for-vxrail-with-lacp-deployment-guide/single-leaf-pair-deployment-2/4/)
[4] [https://infohub.delltechnologies.com](https://infohub.delltechnologies.com/l/dell-enterprise-sonic-deployment-for-vxrail/spine-switch-configuration-39/)
[5] [https://www.virtualizationhowto.com](https://www.virtualizationhowto.com/2026/01/i-tried-lacp-in-my-proxmox-home-lab-and-heres-what-actually-happened/)
