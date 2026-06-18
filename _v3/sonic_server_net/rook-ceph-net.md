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



To configure networking for a production-ready Rook-Ceph cluster, you need to use a Custom Resource Definition (CRD) that separates your client traffic from your backend storage replication traffic. This configuration prevents heavy data recovery and synchronization operations from slowing down application workloads. [1, 2] 
The following guide details a production configuration utilizing Multus CNI to attach multiple dedicated network interfaces to your Ceph pods. [2] 
## Prerequisites
Before applying the cluster configuration, you must define your NetworkAttachmentDefinition resources via your Kubernetes network provider. This maps physical host interfaces or VLANs to the pods. [2, 3, 4] 

apiVersion: "k8s.cni.cncf.io/v1"kind: NetworkAttachmentDefinitionmetadata:
  name: ceph-public-net
  namespace: rook-cephspec:
  config: '{
      "cniVersion": "0.3.1",
      "type": "macvlan",
      "master": "eth1",
      "mode": "bridge",
      "ipam": {
        "type": "whereabouts",
        "range": "10.10.10.0/24"
      }
    }'
---apiVersion: "k8s.cni.cncf.io/v1"kind: NetworkAttachmentDefinitionmetadata:
  name: ceph-cluster-net
  namespace: rook-cephspec:
  config: '{
      "cniVersion": "0.3.1",
      "type": "macvlan",
      "master": "eth2",
      "mode": "bridge",
      "ipam": {
        "type": "whereabouts",
        "range": "10.20.20.0/24"
      }
    }'

## CephCluster CRD Example Configuration
This production-grade CephCluster configuration references the Multus networks defined above and targets specific raw local nvme drives. You can reference the standard [Rook Cluster Template on GitHub](https://github.com/rook/rook/blob/master/deploy/examples/cluster.yaml) for a full baseline schema. [2, 5, 6] 

apiVersion: ceph.rook.io/v1kind: CephClustermetadata:
  name: rook-ceph
  namespace: rook-cephspec:
  cephVersion:
    image: quay.io/ceph/ceph:v18.2.1
    allowUnsupported: false
  dataDirHostPath: /var/lib/rook
  
  # Network Configuration Section
  network:
    provider: multus
    selectors:
      public: rook-ceph/ceph-public-net   # Front-end client traffic, MONs, MGRs
      cluster: rook-ceph/ceph-cluster-net # Back-end replication, OSD heartbeats
    connections:
      requireMsgr2: true                  # Enforce modern secure messenger v2 protocol
      encryption:
        enabled: false                    # Set to true if in-transit wire encryption is needed
      compression:
        enabled: false

  mon:
    count: 3
    allowMultiplePerNode: false           # Enforce high availability across nodes
  mgr:
    count: 2
  
  # Storage Topology and Resource Allocation
  storage:
    useAllNodes: true
    useAllDevices: false
    deviceFilter: "^nvme[0-9]n1$"         # Matches raw nvme storage drives exclusively
    config:
      osd_memory_target: "4294967296"     # Pins OSD memory target to 4GB

  # Resource Management
  resources:
    mon:
      limits:
        cpu: "2"
        memory: "2Gi"
      requests:
        cpu: "1"
        memory: "1Gi"
    osd:
      limits:
        cpu: "4"
        memory: "6Gi"
      requests:
        cpu: "2"
        memory: "5Gi"                     # Ensures request is 1GB higher than target for stability

## Network Type Alternatives
If your environment does not support Multus CNI, you can modify the network block in your CephCluster file to use alternative setups: [2] 

* Host Networking: Bypasses the Kubernetes software-defined network for lower latency. This maps Ceph daemons directly to host interfaces.

network:
  provider: host

* Standard SDN: Routes all traffic over your default Kubernetes CNI (e.g., Cilium, Calico) on a single shared interface.

network:
  provider: kubernetes

[1, 2, 7, 8, 9] 

## Validating Your Configuration
Once your pods deploy, connect to the cluster via the [Rook Toolbox Container](https://rook.io/docs/rook/v1.20/Storage-Configuration/Advanced/ceph-configuration/) to verify that your networks bound properly: [10, 11] 

   1. Run ceph status to ensure all MONs, MGRs, and OSDs are healthy and communicating.
   2. Run ceph config dump to review active daemon address bindings and ensure your isolated subnets are applied correctly. [2, 12, 13, 14, 15] 

Would you like help setting up the StorageClasses for this configuration, or would you prefer guidance on provisioning a CephFS shared filesystem across these networks? [13, 16, 17, 18] 

[1] [https://stackoverflow.com](https://stackoverflow.com/questions/73195335/how-to-seperate-traffic-in-rook)
[2] [https://oneuptime.com](https://oneuptime.com/blog/post/2026-03-31-rook-network-configuration/view)
[3] [https://www.suse.com](https://www.suse.com/c/advanced-kubernetes-networking/)
[4] [https://docs.cloud.google.com](https://docs.cloud.google.com/kubernetes-engine/distributed-cloud/bare-metal/docs/how-to/multi-nic)
[5] [https://github.com](https://github.com/rook/rook/blob/master/deploy/examples/cluster.yaml)
[6] [https://rook.io](https://rook.io/docs/rook/latest/Getting-Started/Prerequisites/prerequisites/)
[7] [https://documentation.suse.com](https://documentation.suse.com/sbp/storage/pdf/SBP-rook-ceph-kubernetes_en.pdf)
[8] [https://oneuptime.com](https://oneuptime.com/blog/post/2026-03-31-rook-how-to-set-up-multus-cni-for-rook-ceph/view)
[9] [https://oneuptime.com](https://oneuptime.com/blog/post/2026-03-03-configure-rook-ceph-on-talos-linux/view)
[10] [https://rook.io](https://rook.io/docs/rook/v1.20/Storage-Configuration/Advanced/ceph-configuration/)
[11] [https://ceph.io](https://ceph.io/en/news/blog/2025/rook-on-mac-with-docker/)
[12] [https://rook.io](https://rook.io/docs/rook/latest-release/Troubleshooting/ceph-common-issues/)
[13] [https://rook.io](https://rook.io/docs/rook/latest/Storage-Configuration/Shared-Filesystem-CephFS/filesystem-storage/)
[14] [https://rook.io](https://rook.io/docs/rook/latest/Getting-Started/quickstart/)
[15] [https://blog.searce.com](https://blog.searce.com/setup-rook-to-manage-ceph-on-kubernetes-ecc4af01afe5)
[16] [https://rook.io](https://rook.io/docs/rook/latest-release/CRDs/Cluster/external-cluster/consumer-import/)
[17] [https://oneuptime.com](https://oneuptime.com/blog/post/2026-03-31-rook-external-storage-classes/view)
[18] [https://ceph.io](https://ceph.io/en/news/blog/2018/rook-automating-ceph-kubernetes/)



In a pure Layer 3 CLOS routed-to-host topology, the ultimate goal is to terminate BGP routing directly on the bare-metal storage node. This allows the host to announce its own IP addresses (such as loopbacks) over redundant uplinks, achieving equal-cost multi-path (ECMP) routing and instant sub-second failover.
When deciding whether to attach your Ceph network IPs to Ubuntu loopback interfaces via Netplan versus managing them completely as dummy/loopback interfaces inside Free Range Routing (FRR), you are choosing between a system-first or a routing-daemon-first design.
------------------------------
## Option 1: Configuring Secondary IPs on Loopback via Netplan
In this model, you configure a dummy interface (or multiple IP addresses on the standard lo loopback interface) permanently inside Ubuntu's system configuration using Netplan. FRR is then configured simply to redistribute these locally existing kernel interfaces.

# Netplan Example (/etc/netplan/01-netcfg.yaml)network:
  version: 2
  dummy-devices:
    lo-ceph:
      addresses:
        - 10.10.10.11/32  # Ceph Public IP
        - 10.20.20.11/32  # Ceph Cluster IP

## Why Choose Netplan?

* Decoupled Life Cycle: The Ceph storage IPs exist at the OS level completely independent of the BGP daemon. If the FRR service crashes, restarts, or misconfigures, the local Ceph daemons (OSDs, MONs) can still bind to their respective sockets and talk to local processes.
* Deterministic Binding: Rook/Ceph daemons start reliably during boot because the underlying network interfaces are guaranteed to be up and initialized by systemd-networkd long before the container runtime or network routing daemons initialize.
* Standard Linux Architecture: This follows standard Linux systems administration practices. The network configuration is held in the definitive OS network state engine, making it visible to standard monitoring tools.

------------------------------
## Option 2: Configuring Loopback/Dummy IPs Directly via FRR
In this model, the underlying operating system is kept as bare as possible. Netplan only configures the raw physical uplink interfaces. You log into the FRR routing engine (via vtysh) and define the dummy interfaces and IP networks directly inside the routing configuration file (/etc/frr/frr.conf). [1, 2] 

! FRR Example Configuration
interface dummy0
 ip address 10.10.10.11/32
!
interface dummy1
 ip address 10.20.20.11/32

## Why Choose FRR?

* Single Source of Truth: All Layer 3 architecture—including IP allocations, routing policies, BGP peerings, and loopback bindings—is contained in one singular file (frr.conf).
* Dynamic Lifecycle Infrastructure: Perfect for automated NetOps deployments (e.g., using Ansible or Terraform with FRR modules). You can provision, tear down, or re-IP an entire storage node’s routing and interface layout dynamically without triggering disruptive OS-level network restarts (netplan apply).
* Conditional Advertisement: If a dummy interface is tied strictly to the FRR daemon lifecycle, a failure of the routing engine immediately drops the interface link state, instantly pulling the route out of the upstream spine switches.

------------------------------
## Comparison Matrix

| Criteria [3, 4] | Netplan (System-Managed) | FRR (Routing-Managed) |
|---|---|---|
| Storage Stability | High. IPs persist even if BGP fails; local daemons remain up. | Medium. If FRR drops, the dummy IPs can vanish, breaking local sockets. |
| Boot Ordering | Safe. IPs exist before Kubernetes/Rook start up. | Risky. Ceph might try to bind before FRR initializes the IPs. |
| Automation Focus | SysOps / Standard Linux Infrastructure. | NetOps / Infrastructure-as-Code Networking. |
| State Visibility | Native (ip addr matches config perfectly). | Split (Interfaces depend on the routing daemon state). |

------------------------------
## Architectural Recommendation for Ceph Clos Topologies [5] 
For a Rook-Ceph Routed-to-Host CLOS topology, the Netplan (System-Managed) approach is highly recommended.
Ceph is highly sensitive to socket binding states. If an OSD or MON attempts to initialize or restart during a configuration change and the target IP address does not physically exist in the Linux kernel network stack (because FRR is reloading or initializing), the Ceph daemon will panic and crash-loop.
By using Netplan, you cement the network boundaries on the host machine. You then configure FRR simply to announce those anchors upstream to your leaf switches using the redistribute connected command:

router bgp 65001
 neighbor LEAF-SWITCHES peer-group
 !
 address-family ipv4 unicast
  redistribute connected route-map ALLOW-CEPH-IPS
 exit-address-family

Would you like an example of the FRR route-map configuration to safely restrict which Netplan loopback IPs get advertised to your leaf switches, or do you want to look at how Kubernetes BGP tools (like Metallb or Cilium) can layer on top of this host network?

[1] [https://medium.com](https://medium.com/sonic-nos/evpn-route-reflector-with-sonic-using-frr-mgmt-framework-db6d12b85ce7)
[2] [https://codingpackets.com](https://codingpackets.com/blog/linux-routing-on-the-host-with-frr/)
[3] [https://medium.com](https://medium.com/@bektiaw/netplan-the-key-to-understanding-and-controlling-ubuntu-networking-e9f5850da2b6)
[4] [https://createnetech.tistory.com](https://createnetech.tistory.com/54)
[5] [https://openmetal.io](https://openmetal.io/resources/blog/how-to-tune-ceph-for-block-storage-performance/)



Choosing between stacking multiple IPs on the core lo interface versus spinning up a dedicated dummy interface for your Ceph cluster traffic changes how your Linux kernel, routing daemon, and Maximum Transmission Unit (MTU) sizes behave. [1, 2] 
In an L3 CLOS routed-to-host topology, separating your workloads from your storage traffic using a dedicated dummy interface is the architecturally superior choice.
Here is the comparative understanding of both approaches.
------------------------------
## Option 1: Dual IPs Stacked on a Single lo Interface
In this design, you place both your OpenStack workload IP and your Ceph cluster replication IP as /32 aliases directly on the native loopback (lo) interface.
## Structural Characteristics

* Shared Network Stack: Both the workload traffic and the storage replication traffic share the exact same logical interface framework.
* Implicit MTU Handling: The native Linux loopback interface (lo) has a hardcoded, default MTU of 65536.

## Why Choose This?

* Simplicity: It minimizes the number of virtual network components you have to configure in Netplan. Every IP address lives under a single logical interface.
* Effortless Internal Performance: Because the loopback interface naturally uses a massive 65,536 MTU for local host-to-host process communication, any daemons communicating within the same machine encounter zero fragmentation or MTU bottlenecks internally.

## The Critical Downside (The Jumbo Frame Trap)
The native loopback interface is a pseudo-device. It does not map cleanly to the physical Layer 2 MTU constraints of your network interface cards (NICs).
When Ceph replicates data across hosts, the kernel must packetize those 65k-bound loopback buffers into the physical uplinks (e.g., eth0 and eth1). If you require a strict Jumbo Frame configuration (MTU 9000) end-to-end to optimize your switches and physical NICs, managing, tracking, and troubleshooting fragmentation boundaries across a single lo device becomes a nightmare.
------------------------------
## Option 2: Workload IP on lo + Ceph IP on Dedicated dummy Interface
In this design, your standard OpenStack workload network remains anchored to the native lo interface. You then create a brand new virtual dummy interface (e.g., dummy-ceph) explicitly for your Ceph cluster network.
## Structural Characteristics

* Explicit Network Isolation: You create a hard boundary at the Linux kernel layer between your primary application computing network and your storage backend fabric.
* Configurable MTU Boundaries: You can explicitly set the MTU of the dummy interface to match your physical fabric targets.

# Netplan Example for Option 2network:
  version: 2
  dummy-devices:
    dummy-ceph:
      addresses:
        - 10.20.20.11/32  # Dedicated Ceph Cluster IP
      mtu: 9000           # Explicitly matches your physical Jumbo Frame fabric

## Why Choose This?

* Deterministic MTU and Jumbo Frame Alignment: By explicitly setting the dummy interface to MTU 9000, you force the Linux kernel network stack to treat storage replication traffic as a Jumbo Frame payload right at the point of origin. This aligns your virtual boundaries perfectly with your physical leaf-spine switch configuration, eliminating unexpected CPU-heavy packet fragmentation. [3] 
* Granular FRR Routing Policies: In your FRR configuration, writing route maps becomes significantly easier and less prone to human error. You can filter and announce routes based on the originating interface rather than writing complex IP prefix lists.

! FRR can explicitly target the dummy interface for specific policies
route-map ROUTE-TO-LEAF permit 10
 match interface dummy-ceph

* Advanced Monitoring and Traffic Control (tc): If your OpenStack workloads saturate your host's network, you can easily attach Linux Traffic Control (tc) QoS policies or standard prometheus-node-exporter metrics to the dummy-ceph interface. This allows you to track and throttle storage replication throughput independently of your VM traffic.

------------------------------
## Comparison Matrix

| Architectural Feature [4] | Option 1: Dual IPs on lo | Option 2: Workload on lo + Ceph on dummy |
|---|---|---|
| Traffic Isolation | Logical Only. Differentiated purely by IP addresses in the kernel. | Interface Level. Differentiated by independent virtual network devices. |
| MTU / Jumbo Frame Control | Poor. Tied to the native loopback's unchangeable 65,536 MTU. | Excellent. You can explicitly pin the dummy device to MTU 9000. |
| FRR Configuration Safety | Medium. Requires strict IP prefix-lists to prevent route leaks. | High. Allows simple, bulletproof interface-based routing policies. |
| Observability | Difficult. ip -s link show lo aggregates all workload and storage stats together. | Easy. Clear, isolated bandwidth metrics per interface (dummy-ceph). |

------------------------------
## Architectural Verdict
Go with Option 2 (Dedicated Dummy Interface).
In a high-throughput architecture like a CLOS routed-to-host storage design, relying on the native loopback interface to multiplex both regular OpenStack compute traffic and heavy Ceph storage synchronization introduces a structural blind spot.
Using a dedicated dummy interface for your storage replication network gives you the precise control over Jumbo Frames (MTU 9000), metric tracking, and BGP redistribution safety rules required for an enterprise deployment. [5] 
Would you like to see how to write the FRR BGP configuration to cleanly handle this dedicated dummy interface layout, or should we look at how Netplan handles the physical bonding of your underlying uplink interfaces?

[1] [https://packetpushers.net](https://packetpushers.net/blog/proxmox-ceph-full-mesh-hci-cluster-w-dynamic-routing/)
[2] [https://www.cisco.com](https://www.cisco.com/c/en/us/td/docs/security/asa/asa91/configuration/general/asa_91_general_config/ha_cluster.html)
[3] [https://docs.redhat.com](https://docs.redhat.com/en/documentation/red_hat_openstack_platform/16.0/html-single/hyperconverged_infrastructure_guide/index)
[4] [https://www.linkedin.com](https://www.linkedin.com/pulse/best-practices-deploying-ceph-your-infrastructure-reza-bojnordi)
[5] [https://docs.redhat.com](https://docs.redhat.com/en/documentation/red_hat_openstack_platform/16.0/html-single/hyperconverged_infrastructure_guide/index)



In this pure L3 CLOS routed-to-host architecture, you do not use standard L2 bonding protocols (like LACP/802.3ad). Instead, you leverage BGP Unnumbered over independent physical interfaces (enp2s0 and enp3s0).
By treating each physical wire as an independent L3 point-to-point link directly to its respective SONiC Top-of-Rack (TOR) switch, the Linux kernel uses Equal-Cost Multi-Path (ECMP) to load balance and handle sub-second link failovers natively.
Below are the complete, production-ready configuration examples for both Netplan and FRR.
------------------------------
## Part 1: Netplan Configuration [1] 
This configuration leaves enp2s0 and enp3s0 bare without explicit IPv4 addresses to support BGP unnumbered (which uses IPv6 Link-Local auto-discovery). It binds your OpenStack workload address directly to the primary loopback (lo) and establishes your Jumbo-Frame ceph-dummy device. [2, 3, 4, 5] 
Save the following content to /etc/netplan/01-netcfg.yaml: [6] 

network:
  version: 2
  renderer: networkd
  
  ethernets:
    # Uplink interface to SONiC TOR 1 (L1)
    enp2s0:
      dhcp4: false
      dhcp6: false
      # IPv6 link-local is mandatory for BGP unnumbered to peer
      link-local: [ ipv6 ] 
      mtu: 9000

    # Uplink interface to SONiC TOR 2 (L2)
    enp3s0:
      dhcp4: false
      dhcp6: false
      link-local: [ ipv6 ]
      mtu: 9000

    # Primary native loopback interface for Workload IPs
    lo:
      match:
        name: lo
      addresses:
        - 10.10.10.11/32     # Regular OpenStack Workload IP

  dummy-devices:
    # Isolated interface specifically for Ceph replication
    ceph-dummy:
      addresses:
        - 10.20.20.11/32     # Ceph Cluster Network IP
      mtu: 9000              # Enforces physical MTU alignment at the kernel boundary

Apply the network configuration: [6, 7] 

sudo netplan apply

------------------------------
## Part 2: FRR Configuration [8] 
To make this function seamlessly, your daemons must be activated. First, ensure the BGP daemon is active by checking /etc/frr/daemons: [9, 10, 11, 12] 

bgpd=yes
zebra=yes

Now, implement the routing topology. This BGP architecture uses an eBGP-to-host setup. The server holds its own Autonomous System Number (ASN), peers unnumbered out of both physical interfaces, activates ECMP, and explicitly advertises both the workload and Ceph loopbacks upstream. [2] 
Save the following file to /etc/frr/frr.conf: [9] 

# Global defaults and hostname
frr defaults traditional
hostname compute-node-01
log syslog informational

# Enable kernel routing options for equal cost path balancing
ip nexthop groups max-paths 64

# ==========================================
# BGP Routing Instance Setup
# ==========================================
# Local host Private ASN (e.g., 65101)
router bgp 65101
  bgp router-id 10.10.10.11
  
  # Allow identical paths from different upstream TOR switches
  bgp bestpath as-path multipath-relax
  
  # Automatically peer with any SONiC router sending BGP messages on uplinks
  neighbor TOR-FABRIC peer-group
  neighbor TOR-FABRIC remote-as external
  neighbor TOR-FABRIC bfd
  
  # Apply BGP Unnumbered to physical ports via IPv6 link-local discovery
  neighbor enp2s0 interface peer-group TOR-FABRIC
  neighbor enp3s0 interface peer-group TOR-FABRIC

  # ------------------------------------------
  # Address Family Configuration (IPv4 Unicast)
  # ------------------------------------------
  address-family ipv4 unicast
    # Enable multi-path routing (ECMP) for up to 2 active uplinks
    maximum-paths 2
    
    # Inject our local host addresses into the BGP table
    network 10.10.10.11/32
    network 10.20.20.11/32
    
    # Apply outbound filtering to safely restrict what we tell the switches
    neighbor TOR-FABRIC route-map EXPORT-HOST-ROUTES out
  exit-address-family

# ==========================================
# Route Maps and Prefix Filtering
# ==========================================
# Explicitly define our host IP ranges to prevent accidental transit route leaks
ip prefix-list HOST-IP-RANGE permit 10.10.10.11/32
ip prefix-list HOST-IP-RANGE permit 10.20.20.11/32

route-map EXPORT-HOST-ROUTES permit 10
  match ip address prefix-list HOST-IP-RANGE

Restart the FRR routing daemon to begin processing the paths: [9] 

sudo systemctl restart frr

------------------------------
## Architectural Advantages of This Setup

* Asymmetric Failure Resilience: If enp2s0 drops or SONiC L1 reboots, FRR immediately pulls the dead route path. Upstream spine switches seamlessly redirect inbound workload and Ceph replication traffic to SONiC L2 over enp3s0 within milliseconds. [13] 
* Deterministic Storage Fabric: Because ceph-dummy is declared with MTU 9000, any packets originating from Ceph to another storage host bypass software-driven MTU fragmentation. [14] 
* IP Preservation: No IP subnets are wasted on point-to-point transit addresses between the compute host and the TOR switches. [2, 3] 

Would you like to examine how to verify the active routes using vtysh, or should we move on to configuring the SONiC TOR switch sides to establish the unnumbered peer bindings? [15] 

[1] [https://www.cisco.com](https://www.cisco.com/c/en/us/support/docs/servers-unified-computing/ucs-c885a-m8-rack-server/223235-configure-lacp-c885a-m8-nic-with.html)
[2] [https://netbergtw.com](https://netbergtw.com/top-support/netberg-sonic/bgp-unnumbered/)
[3] [https://stordis.com](https://stordis.com/overlay-configuration-examples-with-bgp-underlay/)
[4] [https://vincent.bernat.ch](https://vincent.bernat.ch/en/blog/2018-l3-routing-hypervisor)
[5] [https://resources.geant.org](https://resources.geant.org/wp-content/uploads/2022/02/GN4-3_White-Paper_White-Box-GRNET-Data-Centre-Use-Case.pdf)
[6] [https://canonical-netplan.readthedocs-hosted.com](https://canonical-netplan.readthedocs-hosted.com/en/0.105/examples.html)
[7] [https://oneuptime.com](https://oneuptime.com/blog/post/2026-01-07-ceph-network-segmentation-security/view)
[8] [https://oneuptime.com](https://oneuptime.com/blog/post/2026-03-20-vxlan-evpn-control-plane-linux/view)
[9] [https://codingpackets.com](https://codingpackets.com/blog/linux-routing-on-the-host-with-frr/)
[10] [https://docs.nvidia.com](https://docs.nvidia.com/networking-ethernet-software/cumulus-linux-43/Layer-3/FRRouting/Configure-FRRouting/)
[11] [https://www.watchguard.com](https://www.watchguard.com/help/docs/help-center/en-us/content/en-us/Fireware/dynamicrouting/rip_ng_sample_frr.html)
[12] [https://www.virtua.cloud](https://www.virtua.cloud/learn/en/tutorials/frr-bgp-configuration-linux-vps)
[13] [https://www.dnzydn.com](https://www.dnzydn.com/2025/11/19/cilium-bgp-and-using-frr-for-node-connectivity/)
[14] [https://www.linkedin.com](https://www.linkedin.com/pulse/deploying-ceph-storage-bgp-l3-network-satish-patel-gycne)
[15] [https://hardwarenation.com](https://hardwarenation.com/wp-content/uploads/2024/03/Guide-for-BGP-Unnumbered-between-SONiC-and-FRR-VM.pdf)



To complete your L3 CLOS routed-to-host topology, you must configure the upstream SONiC Top-of-Rack (TOR) switches to peer with your compute nodes using BGP Unnumbered.
Because BGP Unnumbered relies on IPv6 Link-Local Addresses (LLAs) to establish the underlying transport layer, a critical architectural decision emerges: Do you configure the rest of your fabric infrastructure (inter-switch links, spine-leaf paths, and overlays) using an IPv4-centric strategy or a Pure IPv6-centric strategy? [1] 
Below is the complete SONiC configuration followed by an in-depth strategic analysis of these two options.
------------------------------
## Part 1: SONiC TOR Switch Configuration
SONiC uses FRR as its underlying routing engine. On your SONiC TOR switches, the physical interfaces facing the servers (e.g., Ethernet0 connecting to the server's enp2s0) must be kept bare of IPv4 addresses and configured to listen for dynamic peerings. [2] 
Assuming SONiC L1 TOR uses ASN 65001 and your servers are dynamically assigned ASNs in a pool (or explicitly defined), add this to the FRR daemon config (/etc/sonic/frr/frr.conf or applied via SONiC CLI/Config DB):

! SONiC L1 TOR Switch Configuration
!
interface Ethernet0
 description Link-to-Compute-Node-01-enp2s0
 ipv6 nd send-ra
!
router bgp 65001
  bgp router-id 10.0.0.1
  bgp bestpath as-path multipath-relax
  
  # Define a dynamic peer group for servers to allow easy horizontal scale
  neighbor SERVERS peer-group
  neighbor SERVERS remote-as external
  neighbor SERVERS bfd
  
  # Automatically listen for and peer with any host on Ethernet0 sending BGP messages
  neighbor Ethernet0 interface peer-group SERVERS
  
  # Address Family to carry the actual server IPv4 storage/workload paths
  address-family ipv4 unicast
    maximum-paths 64
    neighbor SERVERS activate
    
    # RFC 5549 / RFC 8950: Allows IPv4 prefixes to be sent over the IPv6 peer
    neighbor SERVERS nexthop-local unchanged
  exit-address-family

------------------------------
## Part 2: IP Strategy Tradeoffs for BGP Unnumbered Fabrics
Even though BGP Unnumbered uses IPv6 Link-Local packets on the local wire, you still have to choose the primary network protocol for your wider fabric core. [3] 
## Option A: IPv4-Centric Strategy (IPv4 Prefixes over IPv6 Transport)
In this model (enabled by RFC 8950), the BGP peering sessions utilize IPv6 link-local addresses, but the switches exchange standard IPv4 routing updates (10.10.10.11/32 and 10.20.20.11/32). The next-hop for these IPv4 routes is an IPv6 address. The ASIC handles the translation automatically in hardware. [4] 
## Option B: Pure IPv6-Centric Strategy (Dual-Stack or IPv6-Only Fabric)
In this model, your workload and Ceph storage networks are natively allocated IPv6 blocks (e.g., 2001:db8:storage::11/128). The entire fabric, including the applications, operates natively on IPv6.
------------------------------
## In-Depth Strategic Comparison## 1. Support & Ecosystem Maturity

* IPv4-Centric (RFC 8950): High support in modern data center operating systems (SONiC, Cumulus, EOS, JunOS). However, older server NIC drivers or legacy container runtimes occasionally struggle with processing an IPv4 destination route that resolves to an IPv6 next-hop in the Linux kernel routing table. [5, 6] 
* Pure IPv6-Centric: Flawlessly supported by the Linux kernel natively for decades. It avoids the complexity of crossing protocol boundaries (IPv4-over-IPv6). The downside is that legacy enterprise applications, old OpenStack components, or specialized backup tools may lack native IPv6 support. [7] 

## 2. Troubleshooting & Learning Curve

* IPv4-Centric: Steep initial troubleshooting curve. When you type ip route show on the server, you see an IPv4 address pointing to an IPv6 link-local interface (e.g., 10.20.20.0/24 via inet6 fe80::... dev enp2s0). This can deeply confuse sysadmins accustomed to standard IPv4 gateways. Packet capture tools (tcpdump) must look for IPv6 transport frames to diagnose why an IPv4 application cannot connect.
* Pure IPv6-Centric: High conceptual learning curve for teams that have never managed IPv6 hex notation and subnetting rules (/64 vs /128). However, once mastered, troubleshooting is highly logical: an IPv6 address talks to an IPv6 address over an IPv6 interface.

## 3. Downtime & Migration Risk

* IPv4-Centric: Very Low. If you are transitioning an existing OpenStack/Ceph environment into an L3 CLOS topology, your applications and storage configurations do not have to change their IP schemes. You change the underlying routing mechanism while keeping your data plane addresses identical.
* Pure IPv6-Centric: High. Moving an existing Ceph cluster from IPv4 to IPv6 requires either building a brand new cluster from scratch or initiating a high-risk, multi-phase rolling daemon migration with a strong likelihood of temporary storage instability or cluster health warnings.

## 4. Scalability & Horizontal Expansion

* IPv4-Centric: Adequate for small-to-medium topologies, but eventually limited by Private IPv4 (RFC 1918) address exhaustion if you provision thousands of virtual machines, microservices, and unique storage endpoints per host.
* Pure IPv6-Centric: Infinite scaling. Every single pod, container, virtual machine, and Ceph daemon can have a globally unique or unique-local IPv6 address without ever risking overlapping IP space or exhausting subnets during massive horizontal fabric expansions.

------------------------------
## Tradeoff Summary Matrix

| Strategic Vector | Option A: IPv4-Centric (RFC 8950) | Option B: Pure IPv6-Centric |
|---|---|---|
| Learning Curve | Moderate (Weird routing tables, familiar IPs). | High (Unfamiliar hexadecimal network architecture). |
| Application Support | Universal. Works with legacy tools. | Limited by older enterprise software stacks. |
| Downtime Risk | Low. Fits into existing IPv4 environments easily. | High. Requires full IP restructuring of daemons. |
| Troubleshooting | Confusing mix of IPv4 routes via IPv6 next-hops. | Unified. Pure IPv6 tracing end-to-end. |
| Expandability | Bound by standard private IPv4 limits. | Practically limitless horizontal expansion. |

------------------------------
## Architectural Verdict
For an operational OpenStack + Rook-Ceph deployment on SONiC, the IPv4-Centric Strategy (Option A) is usually the most pragmatic choice if your team is new to L3-to-host architectures. It preserves standard application compatibility and minimizes migration downtime while still providing the configuration-free, cable-plug-and-play benefits of BGP Unnumbered at the physical layer.
However, if you are building a greenfield, next-generation infrastructure from scratch and your application stack fully validates against it, a Pure IPv6-Centric Strategy (Option B) eliminates the "protocol translation" layer entirely, yielding a cleaner network layout for long-term operations.
Would you like to review how the Linux kernel routing table looks under Option A to prepare your team for troubleshooting, or should we look at BFD (Bidirectional Forwarding Detection) tuning between SONiC and the host?

[1] [https://stordis.com](https://stordis.com/bgp-unnumbered-in-enterprise-sonic/)
[2] [https://learningnetwork.cisco.com](https://learningnetwork.cisco.com/s/article/software-for-open-networking-in-the-cloud-sonic)
[3] [https://doc.6wind.com](https://doc.6wind.com/new/vsr-3/latest/vsr-guide/user-guide/cli/routing/bgp/config-options.html)
[4] [https://medium.com](https://medium.com/@menu.sri13/practical-guide-to-transitioning-existing-ipv4-data-center-infrastructure-to-a-full-ipv6-underlay-99535556029a)
[5] [https://learningnetwork.cisco.com](https://learningnetwork.cisco.com/s/article/software-for-open-networking-in-the-cloud-sonic)
[6] [https://onvox.net](https://onvox.net/2024/02/01/srv6-vyos/)
[7] [https://www.cyberghostvpn.com](https://www.cyberghostvpn.com/privacyhub/ipv4-vs-ipv6/)



## Part 1: Anatomy of an RFC 8950 Linux Routing Table
When utilizing an IPv4-Centric BGP Unnumbered strategy (Option A), the Linux kernel maps IPv4 destination prefixes to IPv6 Link-Local next-hops. This breaks the traditional administrative assumption that an IPv4 packet must point to an IPv4 gateway address.
## Viewing Active BGP Paths
To inspect the routing table on the Ubuntu host, execute the native IP route command:

ip route show

The output will appear as follows:

default proto bgp src 10.10.10.11 
	nexthop via inet6 fe80::201:efff:fe00:1 dev enp2s0 weight 1
	nexthop via inet6 fe80::201:efff:fe00:2 dev enp3s0 weight 1
10.20.20.0/24 proto bgp src 10.20.20.11
	nexthop via inet6 fe80::201:efff:fe00:1 dev enp2s0 weight 1
	nexthop via inet6 fe80::201:efff:fe00:2 dev enp3s0 weight 1

## Key Elements for Troubleshooting:

* via inet6: This explicitly tells the Linux kernel that the next-hop router must be reached using an IPv6 Link-Local Address (LLA).
* weight 1: Because both physical links (enp2s0 and enp3s0) carry identical weights, the kernel automatically enables ECMP (Equal-Cost Multi-Path). Traffic is dynamically balanced per-flow using a hashing algorithm based on the Layer 3/4 header.
* src flag: This enforces deterministic source IP binding. Any packet originating from the host destined for the Ceph cluster network automatically binds to 10.20.20.11 as its source IP, ensuring it hits the proper dummy interface rules.

------------------------------
## Part 2: BFD (Bidirectional Forwarding Detection) Aggressive Tuning
Standard BGP relies on keepalive timers (typically 60–180 seconds) to determine if a peer is dead. In a high-throughput storage fabric, waiting minutes for a dead path to drop will cause Ceph OSD timeouts and freeze VM disk I/O.
By layering BFD on top of your BGP Unnumbered interfaces, the host and the SONiC switch exchange tiny, low-overhead hello packets at millisecond intervals. If a physical interface fails, a switch port flaps, or a SONiC line card freezes, BFD tears down the BGP session within milliseconds, shifting 100% of the traffic to the remaining healthy path seamlessly.

       +---------------------------------------------+

       |             Ubuntu Compute Host             |
       |  [lo: 10.10.10.11]   [ceph-dummy: 10.20.20.11]
       +---------------------------------------------+
                  /                           \
       enp2s0    /                             \    enp3s0
      Jumbo 9000/                               \Jumbo 9000
               /                                 \
  BFD: 3x100ms/                                   \BFD: 3x100ms
             /                                     \
            v                                       v
   +-----------------+                     +-----------------+

   | SONiC TOR L1    |                     | SONiC TOR L2    |
   | (ASN 65001)     |                     | (ASN 65002)     |
   +-----------------+                     +-----------------+

## 1. Host-Side Configuration Update (/etc/frr/frr.conf)
To implement aggressive sub-second failover on your Ubuntu storage node, append the explicit bfd profile definition block to your existing config file:

! Define a highly aggressive sub-second BFD profile
bfd
 profile CEPH-FABRIC-BFD
  detect-multiplier 3
  receive-interval 100
  transmit-interval 100
 !
!
interface enp2s0
 bfd profile CEPH-FABRIC-BFD
!
interface enp3s0
 bfd profile CEPH-FABRIC-BFD
!
router bgp 65101
  neighbor TOR-FABRIC peer-group
  neighbor TOR-FABRIC bfd  # Associates the neighbor group with the BFD subsystem

## 2. SONiC TOR L1/L2 Configuration Update (/etc/sonic/frr/frr.conf)
The upstream SONiC switches must match these aggressive timers to prevent timer negotiation down to slower default intervals.

! SONiC Switch Configuration
bfd
 profile SERVER-PORTS-BFD
  detect-multiplier 3
  receive-interval 100
  transmit-interval 100
 !
!
interface Ethernet0
 bfd profile SERVER-PORTS-BFD
!
router bgp 65001
  neighbor SERVERS peer-group
  neighbor SERVERS bfd

------------------------------
## Part 3: Operational Diagnostics Cheat Sheet
When troubleshooting an active eBGP-to-host setup, you must run commands across both systems to verify the control and data planes.
## 1. Verifying Peer Status (On Host or SONiC)
Drop into the FRR VTY shell by typing vtysh. Run the following command to check if BGP Unnumbered successfully discovered its neighbor over IPv6 link-local:

show bgp neighbors enp2s0

Look for: BGP state = Established. If it says Active or Connect, the interfaces cannot pass IPv6 link-local Multicast traffic, or Router Advertisements (RAs) are disabled on the switch side.
## 2. Verifying Sub-Second BFD States (On Host)
Inside vtysh, check the raw health of the BFD polling engine:

show bfd peers brief

Output validation:

SessionId  LocalAddress          PeerAddress           Interface  Status
=========  ============          ===========           =========  ======
1          fe80::201:efff:fe00:a fe80::201:efff:fe00:1 enp2s0     Up
2          fe80::201:efff:fe00:a fe80::201:efff:fe00:2 dev enp3s0  Up

If Status is Down but BGP is Up: Your CPU firewalls (iptables / nftables / UFW) on the host are likely dropping UDP ports 3784 or 4784. BFD traffic must be explicitly permitted.
## 3. Real-Time Data Path Validation
To confirm that your storage nodes are executing true Layer 3 multi-path routing without dropping or fragmenting large blocks of Ceph data, issue an explicit Jumbo-Frame packet check across the network:

ping -M do -s 8972 10.20.20.12


* -M do: Forbids local fragmentation at the OS layer.
* -s 8972: Sends a true 9000-byte frame (accounting for the 28-byte ICMP/IP header overhead).

If the ping fails or returns Packet bigger than maximum transmission unit, check that your physical interfaces, the netplan YAML configuration, and the SONiC physical port databases all explicitly mirror an identical mtu 9000 declaration.
Would you like to analyze how to verify these hardware routes using SONiC-specific CLI database commands (show ip route), or are you ready to configure Rook-Ceph to bind cleanly to these newly established paths?




## Part 1: Verifying Hardware Routes on the SONiC TOR Switches
SONiC manages its routing state using a Redis database infrastructure called the ConfigDB and ApplDB. When FRR learns routes via BGP Unnumbered, it injects them into the Linux kernel, which SONiC synchronizes into the switch ASIC hardware.
To verify that your server’s lo and ceph-dummy addresses have properly populated the switch fabric, execute these diagnostics from the native SONiC CLI.
## 1. View the Global IP Routing Table
Run this command to check the integrated routing state of the switch:

show ip route

Expected Output Analysis:

Codes: K - kernel route, C - connected, S - static, R - RIP,
       B - BGP, O - OSPF, IA - OSPF inter area,
       N1 - OSPF NSSA external type 1, N2 - OSPF NSSA external type 2,
       E1 - OSPF external type 1, E2 - OSPF external type 2
Total number of IPv4 routes: 4

B    10.10.10.11/32 [20/0] via fe80::201:efff:fe00:a%Ethernet0, 00:14:22
B    10.20.20.11/32 [20/0] via fe80::201:efff:fe00:a%Ethernet0, 00:14:22


* B: Confirms the route was dynamically injected via eBGP.
* via fe80::...%Ethernet0: Confirms RFC 8950 (IPv4 over IPv6 Next-Hop) is operating perfectly in hardware. The destination is an IPv4 /32, but the physical outbound path transits the IPv6 link-local address bound to front-panel port Ethernet0.

## 2. Confirm BGP Unnumbered Summary Data
Verify the routing protocol’s peering session health with:

show bgp ipv4 unicast summary

Expected Output Analysis:

BGP router identifier 10.0.0.1, local AS number 65001 vrf-id 0
BGP table version is 2
Local Type Addresses: 1

Neighbor        V         AS MsgRcvd MsgSent   TblVer  InQ OutQ  Up/Down  State/PfxRcd
Ethernet0       4      65101     842     849        0    0    0 00:14:25        2


* Neighbor Ethernet0: Confirms BGP Unnumbered is attached directly to the physical interface name rather than a static IP.
* State/PfxRcd = 2: Confirms that this specific switch port has successfully received exactly 2 prefixes from your compute host (10.10.10.11/32 and 10.20.20.11/32).

------------------------------
## Part 2: Configuring Rook-Ceph to Bind to Your Routed Network
Once your underlying L3 CLOS transport routing infrastructure is fully active, you must configure your Rook-Ceph operator to explicitly bind storage traffic to your custom ceph-dummy host interface.
By default, Rook attempts to discover interfaces or bind blindly to the default Kubernetes SDN. For a production L3 host-routed design, you must configure the CephCluster resource to utilize Host Networking, coupled with precise Ceph Core Network Configuration overrides.
## Update Your CephCluster Manifest
Modify your CephCluster custom resource deployment to enforce host network binding, specify your /32 subnets, and configure Ceph's internal subnets.

apiVersion: ceph.rook.io/v1kind: CephClustermetadata:
  name: rook-ceph
  namespace: rook-cephspec:
  cephVersion:
    image: quay.io/ceph/ceph:v18.2.1
    allowUnsupported: false
  dataDirHostPath: /var/lib/rook

  # ==========================================
  # Host-Routed L3 Network Binding Configuration
  # ==========================================
  network:
    # Directs Rook to run Ceph pods natively in the host's network namespace.
    # This allows MONs and OSDs to bind straight to your lo and ceph-dummy IPs.
    provider: host
    
    connections:
      requireMsgr2: true                  # Enforces modern, secure messenger v2 protocol
      encryption:
        enabled: false
      compression:
        enabled: false

  # Custom Ceph configuration to force routing restrictions across the host interfaces
  config:
    global:
      # Explicitly restricts public traffic (OpenStack clients, VMs, MON communication) 
      # to the L3 subnet space hosting your workload loopback addresses.
      public_network: "10.10.10.0/24"
      
      # Explicitly restricts high-throughput OSD storage replication, backfilling,
      # and heartbeat synchronization to your dedicated Jumbo Frame dummy interfaces.
      cluster_network: "10.20.20.0/24"

  # ==========================================
  # Storage Topology and Pod Placement
  # ==========================================
  mon:
    count: 3
    allowMultiplePerNode: false           # Guarantees High Availability across compute hosts
  mgr:
    count: 2

  storage:
    useAllNodes: true
    useAllDevices: false
    deviceFilter: "^nvme[0-9]n1$"         # Dynamically consumes matching raw host nvme storage
    config:
      osd_memory_target: "4294967296"     # Pins OSD baseline memory footprint to 4GB

  # Resource profiles to prevent host memory starvation during OSD recovery cycles
  resources:
    mon:
      limits:
        cpu: "2"
        memory: "2Gi"
      requests:
        cpu: "1"
        memory: "1Gi"
    osd:
      limits:
        cpu: "4"
        memory: "6Gi"
      requests:
        cpu: "2"
        memory: "5Gi"

## Why This Works

   1. provider: host: When Rook sets up the Ceph pods, it drops them out of the standard isolated Kubernetes overlay network (like Calico or Cilium) and places them directly into the host operating system's network stack. The Ceph daemons now see your lo and ceph-dummy interfaces natively.
   2. public_network / cluster_network: When an OSD starts up, it reads these parameters. It scans the host’s local kernel interfaces, sees that its assigned IP 10.20.20.11/32 falls within the 10.20.20.0/24 block, and binds its replication sockets exclusively to that dummy interface.

This ensures that your high-volume storage synchronization completely bypasses your VM workload network. It also forces that traffic out over your physical links using Jumbo Frames (MTU 9000) and leverages the sub-second BFD fault protection configured in your FRR infrastructure.
If you are planning to roll out OpenStack compute services on these same nodes, let me know if you would like to explore how to align Nova or Neutron network configurations with this host-routed L3 design.



To integrate OpenStack Compute (Nova) and Networking (Neutron) with a host-routed L3 CLOS topology, you must first define exactly where your infrastructure components live.
------------------------------
## Part 1: What Does "These Same Nodes" Mean?
In cloud architecture, a node's classification depends entirely on the Ceph daemons running on it, which dictates its network and hardware profile.

+-----------------------------------+   +-----------------------------------+

|      Hyperconverged Node          |   |       Dedicated Compute Node      |
|                                   |   |                                   |
|   [Nova Compute]   [Ceph OSD]     |   |   [Nova Compute]                  |
|                                   |   |                                   |
|   Requires Both Networks:         |   |   Requires One Network:           |
|   - 10.10.10.X (Workload/Public)  |   |   - 10.10.10.X (Workload/Public)  |
|   - 10.20.20.X (Storage Cluster)  |   |                                   |
+-----------------------------------+   +-----------------------------------+

## Scenario A: You Choose "These Same Nodes" (Hyperconverged Infrastructure - HCI)
"These same nodes" means the physical bare-metal server runs both Nova-Compute (VMs) and Ceph OSDs (Storage Daemons). [1] 

* The Rule: If a host runs a Ceph OSD, it MUST have both networks configured via Netplan and FRR: the Workload network (lo) and the Storage Cluster network (ceph-dummy).
* Why: OSDs are the data-shuffling engines. They use the Storage Cluster network to replicate terabytes of data horizontally to other OSDs, and they use the Workload/Public network to serve disk data up to Nova VMs.
* Note: Running only Ceph MONs or MGRs on a node does not justify a dedicated cluster network. MONs/MGRs only handle small metadata coordination and live entirely on the standard Workload/Public network.

## Scenario B: You Choose "Not These Same Nodes" (Dedicated Compute / Disaggregated)
This means your nodes are split into two pure, single-purpose hardware pools: dedicated Ceph Storage nodes (running OSDs) and dedicated OpenStack Compute nodes (running only Nova-Compute). [2, 3] 

* The Storage Nodes: Run OSDs. They require both lo (Workload/Public) and ceph-dummy (Storage Cluster) networks.
* The Compute Nodes: Run only VMs. They ONLY require the lo (Workload/Public) network. They completely drop the ceph-dummy interface. They never see backend Ceph replication traffic; they communicate purely across the standard L3 fabric over IPv4 to fetch storage blocks from the storage nodes' public interfaces. [4, 5] 

------------------------------
## Part 2: Aligning Nova and Neutron with Host-Routed L3 CLOS
When you terminate BGP directly on the host, traditional layer-2 networking constructs (like VLANs, trunking, or standard Linux bridges bridging to physical interfaces) become obsolete. The host is a router. [6, 7] 
Here is how you must configure Neutron and Nova to adapt to this architecture.
## 1. The Neutron Architecture: Switching to a Routed-Network Driver
You cannot use standard ML2/OVS or ML2/OVN with flat provider networks because the physical switch ports (enp2s0 / enp3s0) do not have Layer 2 switching broadcast domains.

* The Solution: You must utilize an architectural model called Neutron Routed Provider Networks or deploy an L3-native plugin such as Calico for OpenStack. [8] 
* How it operates: Neutron configures Nova VMs to attach to local, isolated virtual bridges or TAP interfaces on the host. When a VM launches, the host kernel routes its traffic directly. The local host FRR daemon then dynamically advertises that specific VM’s /32 IP address upstream to the SONiC leaf switches. [9] 

## 2. Nova Configuration Alignment (nova.conf) [10, 11] 
Nova needs to be explicitly configured to talk to Ceph over the L3 Workload network using librbd, bypassing traditional storage attachments.

[libvirt]
images_type = rbd
images_rbd_pool = vms
images_rbd_ceph_conf = /etc/ceph/ceph.conf
rbd_user = openstack
rbd_secret_uuid = 457a1954-20da-4a5c-897a-9a9ecf61ba35

## 3. The Crucial Host-Level ceph.conf Alignment
Because the compute host connects via L3, you must ensure the local /etc/ceph/ceph.conf file present on the Nova Compute nodes maps seamlessly to your routed networks:

[global]
# Tells librbd that the Ceph storage endpoints live on your L3 Workload block
public_network = 10.10.10.0/24

# Defines the BGP loopback IP anchors of your Ceph MONs so Nova can discover the cluster
mon_host = 10.10.10.11, 10.10.10.12, 10.10.10.13

------------------------------
## Part 3: Configuration Matrix: HCI vs. Dedicated Nodes

| Feature / Setting [12, 13, 14, 15, 16] | HCI Node ("Same Nodes") | Dedicated Compute Node | Dedicated Storage Node |
|---|---|---|---|
| Nova-Compute Running | Yes | Yes | No |
| Ceph OSD Running | Yes | No | Yes |
| Netplan Interfaces | lo AND ceph-dummy | lo ONLY | lo AND ceph-dummy |
| Jumbo Frames (MTU 9000) | Required (for ceph-dummy) | Optional / Dynamic | Required (for ceph-dummy) |
| FRR Prefix Advertisements | 10.10.10.X/32 & 10.20.20.X/32 | 10.10.10.X/32 Only | 10.10.10.X/32 & 10.20.20.X/32 |
| Traffic Handled | VM traffic + Storage Replication | VM traffic only | Ceph Replication only |

If you plan to design this, let me know if you would like to map out the Neutron Routed Provider Network definition commands, or if you want to look at how VM migration traffic (Live Migration) should be handled across this L3 topology.

[1] [https://www.mirantis.com](https://www.mirantis.com/blog/openstack-ironic-bare-metal-matter/)
[2] [https://jonathangazeley.com](https://jonathangazeley.com/2023/04/12/kubernetes-homelab-part-5-hyperconverged-storage-again/)
[3] [https://documentation.suse.com](https://documentation.suse.com/sbp/cloud/html/SBP-CloudLS-master/index.html)
[4] [https://jonathangazeley.com](https://jonathangazeley.com/2023/04/12/kubernetes-homelab-part-5-hyperconverged-storage-again/)
[5] [https://blog.devgenius.io](https://blog.devgenius.io/longhorn-on-microk8s-replicated-storage-for-a-4-node-homelab-cluster-c6a8ec783283)
[6] [https://docs.openstack.org](https://docs.openstack.org/openstack-ansible/rocky/reference/architecture/container-networking.html)
[7] [https://archives.flockport.com](https://archives.flockport.com/flockport-labs-use-lxc-containers-as-routers/)
[8] [https://www.openstack.org](https://www.openstack.org/use-cases/containers/leveraging-containers-and-openstack/)
[9] [https://engineering.linecorp.com](https://engineering.linecorp.com/en/blog/verda-at-cloudnative-openstack-days-2019-2-2)
[10] [https://docs.openstack.org](https://docs.openstack.org/nova/2024.2//admin/configuration/index.html)
[11] [https://mindmajix.com](https://mindmajix.com/openstack/installing-configuring-ovs-apiserver-neutron)
[12] [https://www.edureka.co](https://www.edureka.co/community/64817/can-anyone-explain-how-nova-works-internally)
[13] [https://docs.openstack.org](https://docs.openstack.org/juno/config-reference/content/hypervisor-configuration-basics.html)
[14] [https://firstcloud.pl](https://firstcloud.pl/blog/openstack-block-storage-operators-guide/)
[15] [https://events.static.linuxfound.org](https://events.static.linuxfound.org/sites/events/files/slides/OpenStack%20On%20AArch64%20%28linuxcon%29.pdf)
[16] [https://docs.redhat.com](https://docs.redhat.com/en/documentation/red_hat_openstack_platform/17.1/html-single/deploying_an_overcloud_in_a_red_hat_openshift_container_platform_cluster_with_director_operator/index)



Deploying the OVN-BGP-Agent on your host servers is the ideal production-grade choice for this architecture. It bridges the gap between OpenStack OVN’s software-defined virtual networks and your physical L3 CLOS routed-to-host network.
The agent operates by watching OVN Southbound databases and dynamically configuring local kernel routes and FRR evpn/routing policies on the fly, eliminating the need for complex SDN overlays (like VXLAN or Geneve) across your leaf-spine fabric. [1] 
------------------------------
## Part 1: Detailed Impact on Workload Networks
The OVN-BGP-Agent alters how VM traffic transitions from a virtual network space into your physical hardware network.

+-------------------------------------------------------------+

|                     Ubuntu Compute Host                     |
|                                                             |
|   [ VM 1 ]              [ VM 2 ]                            |
|  10.100.1.5          10.200.1.99                            |
|       |                     |                               |
|       +----------+----------+                               |
|                  |                                          |
|                  v                                          |
|         [ OVN Virtual Router ]                              |
|                  |                                          |
|                  v (Injected by OVN-BGP-Agent)              |
|        [ FRR Routing Daemon ]                               |
|       /                      \                              |
|      v                        v                             |
+-------------------------------------------------------------+
    enp2s0                    enp3s0
  (To TOR L1)               (To TOR L2)


* True /32 Host Routing for Floating IPs and Provider Networks: When a VM spawns or receives a Floating IP, the OVN-BGP-Agent detects it and injects a local /32 rule into the host’s kernel routing table. FRR picks up this local path and immediately announces it upstream via BGP Unnumbered to your SONiC switches.
* Tenant Isolation via BGP EVPN (BGP-EVPN Mode): For private, isolated tenant networks, the agent automatically maps OVN virtual networks to local Virtual Routing and Forwarding (VRF) instances and VXLAN Network Identifiers (VNIs) on the host. Tenant isolation is maintained across your physical switches using standard BGP EVPN Type-2 (MAC/IP) and Type-5 (Prefix) advertisements, keeping tenant traffic cryptographically or logically sandboxed from end to end.
* Elimination of Centralized Gateway Bottlenecks: In traditional OpenStack layouts, tenant internet and floating IP traffic must pass through a centralized network node. OVN-BGP-Agent enables distributed routing directly at the compute layer, allowing VMs to talk straight to their Top-of-Rack switches over both enp2s0 and enp3s0 simultaneously using ECMP.

------------------------------
## Part 2: Detailed Impact on Storage Networks (Rook-Ceph)
Because Rook-Ceph runs on the host network layer (provider: host), it sits structurally underneath the virtual OVN routing domain.

* Strict Physical Data Path Separation: The OVN-BGP-Agent manages VM workloads and tenant routes, but it leaves your physical system network boundaries intact. Your Rook-Ceph cluster_network traffic remains locked to your ceph-dummy interface. This traffic bypasses the OVN virtual bridges completely and travels directly via the standard host Linux kernel over your Jumbo Frame (MTU 9000) physical links. [2, 3] 
* Storage Access via Public Network Boundaries: When a VM needs to read or write data to Ceph, the traffic leaves the OVN environment and hits the Ceph public_network endpoint (10.10.10.X). Because this endpoint is anchored to the host's loopback interface, traffic routing happens inside the local Linux kernel, resulting in near-zero latency for local storage calls on hyperconverged nodes.
* MTU Safety: OVN-BGP-Agent manages its virtual endpoints dynamically, ensuring that tenant or provider networks do not interfere with the fixed, high-performance MTU constraints of your Ceph storage infrastructure.

------------------------------
## Part 3: Configuration Adjustments Needed in FRR (/etc/frr/frr.conf)
To allow the OVN-BGP-Agent to inject and manage routes dynamically without breaking your existing static Ceph loopback advertisements, your host FRR daemon must be configured to support EVPN and dynamic route leaking.
You must append the following blocks to your server's existing FRR configuration to enable the agent to announce tenant paths:

! Enable EVPN structure inside FRR to support OVN-BGP-Agent multi-tenancy
router bgp 65101
  
  # Address Family for tenant isolation via EVPN
  address-family evpn
    neighbor TOR-FABRIC activate
    
    # Instructs FRR to advertise tenant routes learned from OVN local interfaces
    advertise-all-vni
  exit-address-family

! Modify your existing IPv4 outbound map to permit OVN-BGP-Agent managed prefixes
route-map EXPORT-HOST-ROUTES permit 10
  match ip address prefix-list HOST-IP-RANGE
  
# Permit dynamic floating IPs or provider network blocks generated by the agent
route-map EXPORT-HOST-ROUTES permit 20
  match interface bgp-nic

------------------------------
## Operational Comparison Matrix

| Architectural Layer [4, 5] | Impact with OVN-BGP-Agent |
|---|---|
| VM Workload Performance | Maximum Performance. Eliminates double encapsulation and central routing bottlenecks; uses hardware ECMP across physical interfaces. |
| Tenant Isolation | Hardware-Enforced. Accomplished via standards-based VRF/EVPN bindings instead of proprietary SDN controllers. |
| Ceph Storage Traffic | No Impact / Safe. Storage replication completely bypasses OVN processes and continues running natively over the ceph-dummy fabric. |
| FRR Management | Dynamic. FRR shifts from a static config file to a dynamic hybrid setup, requiring careful route-mapping to ensure tenant routes do not leak into storage fabrics. |

------------------------------
## ✅ Architectural Summary
By combining Rook-Ceph on Host Networking with the OVN-BGP-Agent, you create a highly optimized, fully distributed, enterprise-grade cloud node.
The host operating system handles heavy storage backend replication using a clean, dedicated dummy interface with a 9000 MTU. Simultaneously, the OVN-BGP-Agent manages elastic tenant virtualization and workload placement, advertising all routes upstream to your SONiC switches over a consistent eBGP Unnumbered data plane. [6] 
Would you like to see how to define the corresponding Neutron network templates to trigger the OVN-BGP-Agent correctly, or should we look into setting up the VRF definitions for tenant separation on your SONiC switch fabric?

[1] [https://docs.openstack.org](https://docs.openstack.org/ovn-bgp-agent/latest/contributor/drivers/evpn_mode_design.html)
[2] [https://ltomasbo.wordpress.com](https://ltomasbo.wordpress.com/2021/02/04/openstack-networking-with-bgp/)
[3] [https://docs.redhat.com](https://docs.redhat.com/en/documentation/red_hat_openstack_platform/17.1/html-single/configuring_dynamic_routing_in_red_hat_openstack_platform/index)
[4] [https://openmetal.io](https://openmetal.io/docs/edu/openstack/what-are-the-openstack-networking-essentials/)
[5] [https://platform9.com](https://platform9.com/blog/networking-in-platform9-private-cloud-director-open-flexible-and-powerful/)
[6] [https://developers.redhat.com](https://developers.redhat.com/articles/2022/09/22/learn-about-new-bgp-capabilities-red-hat-openstack-17)



## Part 1: How the Host FRR Config Dynamically Updates
In this architecture, your frr.conf file is not modified or reloaded when a new tenant or VM is created. The files on disk remain static. Instead, the dynamic updates occur entirely in-memory within the Linux kernel and the FRR routing engine through the following automated pipeline:

[OpenStack API] -> (Triggers VM Creation / Tenant Add)
       |
       v
[OVN Northbound DB] -> (Synchronizes state)
       |
       v
[OVN Southbound DB]
       |
       v  (Monitored in real-time by daemon)
[ovn-bgp-agent] (Running as a system daemon on every host)
       |
       +---> 1. Linux Kernel: Creates dummy interfaces, VRFs, and veth pairs
       |
       +---> 2. FRR via Zebra API: Injects /32 routes and EVPN VNIs dynamically


   1. Kernel Injection: When a VM launches, the ovn-bgp-agent system daemon detects the event via the OVN Southbound Database. It creates a local virtual interface (or TAP device) for the VM and associates it with a specific Linux VRF (Virtual Routing and Forwarding) table to maintain tenant isolation. [1, 2, 3, 4, 5] 
   2. The Zebra Protocol: The agent then communicates directly with FRR using an internal, real-time API socket called Zebra. It instructs FRR to add a new /32 path or attach a new VNI to the running BGP table.
   3. Instant Upstream Advertisement: FRR instantly advertises the newly added route upstream to your SONiC switches over the active BGP Unnumbered sessions. When a VM terminates, the agent tears down the local kernel interfaces, and Zebra removes the route from FRR, withdrawing it from the physical network within milliseconds.

------------------------------
## Part 2: Why BGP Alone Isn't Enough (The Need for EVPN) [6] 
While standard BGP is excellent for routing bare-metal hosts or global infrastructures, it falls short when multi-tenant clouds like OpenStack require strict isolation: [7] 

* Overlapping IP Spaces (The Tenant Conflict): Tenant A might create a private network using 10.0.0.0/24, and Tenant B might create an identical 10.0.0.0/24 network. If you use standard BGP, the fabric cannot distinguish between these networks, leading to major routing corruption.
* The Solution: EVPN (Ethernet VPN): EVPN introduces the concept of a Route Distinguisher (RD) and Route Targets (RT). It takes the tenant's IP/MAC address, appends a unique tag (the VNI), and encapsulates the traffic into VXLAN. [8, 9, 10, 11, 12] 
* Fabric Separation: Standard BGP handles your Underlay (the physical routing paths, your loopbacks, and your Ceph storage network). EVPN handles your Overlay (the isolated, virtual paths for tenant traffic). [13, 14, 15, 16, 17] 

------------------------------
## Part 3: Complete Fabric BGP/EVPN Configuration (SONiC & FRR) [18, 19, 20] 
To support this design, your leaf-spine fabric must act as an IP Fabric with an EVPN Control Plane. The Spine switches act as BGP Route Reflectors to distribute tenant EVPN routes without requiring a full-mesh configuration. [21, 22, 23, 24, 25] 

       +-----------------------+

       |      Exit Router      |  <-- Peers with External WAN/Internet
       +-----------------------+
                   |
       +-----------------------+

       |      Border Leaf      |  <-- Connects External World to EVPN Fabric
       +-----------------------+
               /       \
              /         \
    +-----------+     +-----------+

    |  Spine 1  |     |  Spine 2  |   <-- BGP Route Reflectors (Underlay + EVPN)
    +-----------+     +-----------+
              \         /
               \       /
    +-----------------------------+

    |         SONiC TOR L1        |   <-- VTEP (Terminates VXLAN, peers with Host)
    +-----------------------------+
                   |
         (BGP Unnumbered / EVPN)
                   |
       +-----------------------+

       |   Ubuntu Compute Host |   <-- Runs OVN-BGP-Agent (Dynamic VTEP)
       +-----------------------+

## 1. Spine Switch Configuration (SONiC / FRR) [26] 
The Spines do not terminate VXLAN tunnels; they simply reflect Underlay routes and EVPN overlay routes between the Leaf switches and Border Leafs. [27, 28, 29] 

! Spine 1 Configuration (ASN 65000)
frr defaults traditional
hostname spine-01
!
router bgp 65000
  bgp router-id 10.0.0.101
  bgp bestpath as-path multipath-relax
  
  # Underlay Peering Group to Leafs & Borders
  neighbor FABRIC-LEAFS peer-group
  neighbor FABRIC-LEAFS remote-as external
  neighbor FABRIC-LEAFS interface
  
  # Address Family for physical underlay infrastructure routing
  address-family ipv4 unicast
    maximum-paths 64
    neighbor FABRIC-LEAFS activate
  exit-address-family

  # EVPN Address Family - Functions as a Route Reflector for Overlay Isolation
  address-family evpn
    neighbor FABRIC-LEAFS activate
    neighbor FABRIC-LEAFS route-reflector-client
  exit-address-family

## 2. Top-of-Rack (TOR) Leaf Switch Configuration (SONiC / FRR) [30, 31] 
The Leaf switch peers with the Spines for the fabric transport, and peers with the compute hosts via BGP Unnumbered to accept EVPN packets directly from the ovn-bgp-agent. [32] 

! SONiC TOR L1 Configuration (ASN 65001)
frr defaults traditional
hostname tor-l1
!
router bgp 65001
  bgp router-id 10.0.0.1
  bgp bestpath as-path multipath-relax
  
  # Peer connections up to the Spines
  neighbor TO-SPINES peer-group
  neighbor TO-SPINES remote-as 65000
  neighbor TO-SPINES interface
  
  # Peer connections down to OpenStack compute hosts
  neighbor SERVERS peer-group
  neighbor SERVERS remote-as external
  neighbor SERVERS interface
  
  address-family ipv4 unicast
    maximum-paths 64
    neighbor TO-SPINES activate
    neighbor SERVERS activate
  exit-address-family

  # EVPN Pass-Through downstream to the Host Agent
  address-family evpn
    neighbor TO-SPINES activate
    neighbor SERVERS activate
    advertise-all-vni
  exit-address-family

## 3. Border Leaf Configuration (SONiC / FRR) [33] 
The Border Leaf maps your internal tenant EVPN VNIs into traditional routing tables or VRFs so they can connect to your physical edge routers.

! Border Leaf Configuration (ASN 65009)
frr defaults traditional
hostname border-leaf-01
!
# Define a VRF to terminate Tenant A's external boundary
vrf Tenant-A-Outside
 vni 10001   # Matches the OVN-BGP-Agent dynamic tenant VNI
exit-vrf
!
router bgp 65009
  bgp router-id 10.0.0.99
  
  neighbor TO-SPINES peer-group
  neighbor TO-SPINES remote-as 65000
  neighbor TO-SPINES interface
  
  # Peer connection facing the corporate Exit Router
  neighbor TO-EXIT-ROUTER peer-group
  neighbor TO-EXIT-ROUTER remote-as 64512
  neighbor Ethernet48 interface
  
  address-family ipv4 unicast
    neighbor TO-SPINES activate
  exit-address-family

  address-family evpn
    neighbor TO-SPINES activate
  exit-address-family
  
  # VRF BGP Instance: Translates the EVPN data block to external standard L3 WAN routes
  router bgp 65009 vrf Tenant-A-Outside
    address-family ipv4 unicast
      neighbor TO-EXIT-ROUTER activate
      redistribute evpn
    exit-address-family
    
    address-family evpn
      advertise ipv4 unicast
    exit-address-family

## 4. Exit Router Configuration (Standard Enterprise Edge Router)
The Exit Router does not need to understand EVPN or VXLAN. It sees the Border Leaf as a standard, bare-metal Next-Hop peer, keeping your external core simple and easy to manage. [34, 35] 

! Exit Router Configuration (ASN 64512)
router bgp 64512
  neighbor 192.168.100.2 remote-as 65009  # Physical IP link to Border Leaf Ethernet48
  
  address-family ipv4 unicast
    neighbor 192.168.100.2 activate
    # Learns all OpenStack tenant floating IPs as standard IPv4 paths
  exit-address-family

If you would like to test this setup, let me know if you need help writing the ovn-bgp-agent.conf initialization file to ensure it aligns perfectly with these specific VNI definitions.

[1] [https://docs.openstack.org](https://docs.openstack.org/ovn-bgp-agent/latest/contributor/drivers/evpn_mode_design.html)
[2] [https://ltomasbo.wordpress.com](https://ltomasbo.wordpress.com/2021/02/04/openstack-networking-with-bgp/)
[3] [https://www.youtube.com](https://www.youtube.com/watch?v=Zy-d3iR24p4)
[4] [https://lfnetworking.org](https://lfnetworking.org/fd-io-introduces-vpp-release-20-05/)
[5] [https://blog.ipspace.net](https://blog.ipspace.net/2024/03/frr-rib-fib/)
[6] [https://lists.fd.io](https://lists.fd.io/g/vpp-dev/topic/proposal_vxlan_evpn/114114690)
[7] [https://www.redhat.com](https://www.redhat.com/en/blog/metallb-in-bgp-mode)
[8] [https://www.cisco.com](https://www.cisco.com/c/en/us/td/docs/dcn/whitepapers/securing-network-infrastructure-in-vxlan-bgp-evpn-data-centers.html)
[9] [https://www.linkedin.com](https://www.linkedin.com/pulse/understanding-evpn-ethernet-vpn-vxlan-bgp-beginners-guide-arthur-xu-3alne)
[10] [https://www.happiestminds.com](https://www.happiestminds.com/blogs/demystifying-evpn-the-future-of-scalable-and-efficient-network-virtualization/)
[11] [https://docs.nvidia.com](https://docs.nvidia.com/networking-ethernet-software/nvue-reference/Show-Commands/BGP-EVPN/)
[12] [https://www.linkedin.com](https://www.linkedin.com/pulse/understanding-evpn-ethernet-vpn-vxlan-bgp-beginners-guide-arthur-xu-3alne)
[13] [https://www.reddit.com](https://www.reddit.com/r/networking/comments/15a62if/vxlan_ospf_underlay_and_bgp_evpn_overlay_in/)
[14] [https://link.springer.com](https://link.springer.com/article/10.1186/s13677-025-00814-0)
[15] [https://www.theasciiconstruct.com](https://www.theasciiconstruct.com/blog/category/junos/)
[16] [https://www.juniper.net](https://www.juniper.net/documentation/us/en/software/junos/evpn/topics/concept/evpn-vxlan-security-monitor.html)
[17] [https://www.hjp.at](https://www.hjp.at/doc/rfc/rfc7364.html)
[18] [https://github.com](https://github.com/sonic-net/SONiC/blob/master/doc/vxlan/EVPN/EVPN_VXLAN_HLD.md)
[19] [https://www.netpilot.io](https://www.netpilot.io/blog/frr-cloud-lab-guide)
[20] [https://xrdocs.io](https://xrdocs.io/ncs5500/tutorials/bgp-evpn-and-l3vpn-interworking)
[21] [https://lists.fd.io](https://lists.fd.io/g/vpp-dev/topic/proposal_vxlan_evpn/114114690)
[22] [https://oneuptime.com](https://oneuptime.com/blog/post/2026-01-30-evpn-configuration/view)
[23] [https://www.cisco.com](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/15-mt/irg-15-mt-book/irg-pbb-evpn-rr-support.html)
[24] [https://www.reddit.com](https://www.reddit.com/r/networking/comments/1245i72/vxlan_underlay_clarity_question/)
[25] [https://arubanetworking.hpe.com](https://arubanetworking.hpe.com/techdocs/VSG/docs/010-campus-design/esp-campus-design-058-netconductor/)
[26] [https://xflowresearch.com](https://xflowresearch.com/wp-content/uploads/2023/06/VXLAN-L2-EVPN-Guide-for-SONiC-in-GNS3.docx.pdf)
[27] [https://www.juniper.net](https://www.juniper.net/documentation/us/en/software/nce/evpn-vxlan-mac-vrf/EVPN_VxLAN_MAC-VRF.pdf)
[28] [https://deliabtech.com](https://deliabtech.com/blogs/data-center/policy-based-routing-in-vxlan-evpn/)
[29] [https://medium.com](https://medium.com/@adamkirchberger/evpn-distributed-control-plane-using-arista-veos-44a4d211a881)
[30] [https://www.nextplatform.com](https://www.nextplatform.com/connect/2020/10/26/frr-the-most-popular-network-router-youve-never-heard-of/1636827)
[31] [https://stordis.com](https://stordis.com/overlay-configuration-examples-with-bgp-underlay/)
[32] [https://docs.nvidia.com](https://docs.nvidia.com/networking/display/public/sol/rdg+for+red-hat+openstack+cloud+over+nvidia+converged+high-performance+ethernet+network)
[33] [https://xflowresearch.com](https://xflowresearch.com/wp-content/uploads/2023/06/VXLAN-L2-EVPN-Guide-for-SONiC-in-GNS3.docx.pdf)
[34] [https://blog.golle.org](https://blog.golle.org/posts/VXLAN/L3VPN)
[35] [https://community.cisco.com](https://community.cisco.com/t5/data-center-switches/vxlan-evpn/td-p/5240969)



## Part 1: Moving to an eBGP-Everything Fabric Design
Shifting the entire data center network topology to an eBGP-only fabric (meaning Every Spine, Every Leaf, and Every Compute Node runs a distinct Autonomous System Number) simplifies scaling and troubleshooting. It completely removes the need for iBGP Route Reflectors on the Spine switches. [1] 
## Structural Changes from the Previous Setup:

* The Spines: Instead of reflecting routes via an iBGP cluster, Spines operate as pure, protocol-agnostic L3 switch nodes. They forward eBGP routing updates downstream without modifying them or needing to track client peer-group states.
* Next-Hop Handling: In an eBGP-only model, switches naturally rewrite the BGP next-hop attribute to themselves when passing routes between AS boundaries. However, for EVPN to accurately form direct host-to-host VXLAN tunnels (VTEP to VTEP), the physical spine switches must not rewrite the next-hop for EVPN Type-2 and Type-5 packets. You must enforce next-hop-unchanged within the EVPN address-family configuration on the Spines and Leaf switches. [2, 3, 4, 5] 

------------------------------
## Part 2: Automation Mechanics—Who Updates the Network Components?
When a tenant creates a new private L3 router or isolated network network within OpenStack, zero manual configuration happens on any switch, and zero config files are changed on disk. The components are provisioned programmatically down the line:
## 1. On the Compute Hosts (Linux VRF & FRR Stack)
The ovn-bgp-agent is the exact entity responsible for automating your host’s infrastructure. [6, 7] 

* Linux Kernel VRF Creation: The agent monitors the OVN Southbound Database. When a tenant provisions a new OpenStack L3 Router attached to an EVPN network, the agent instantly runs a kernel call to spin up a native Linux VRF device (ip link add vrf-tenantX type vrf table X). It names the VRF based on the OpenStack router ID and binds a local dummy interface inside it. [6, 8, 9, 10] 
* FRR In-Memory Injection: The agent communicates over a local runtime socket with the FRR daemon using the Zebra API. It forces FRR to spin up an in-memory BGP routing instance inside that specific VRF, associating it with the target VXLAN Network Identifier (VNI) and configuring its corresponding Route Distinguisher (RD) and Route Targets (RT) instantly. [9, 11, 12] 

## 2. On the Fabric Switches (SONiC TOR & Border Leafs)
Because the fabric switches are explicitly configured with advertise-all-vni within their EVPN settings, they act as a clean pass-through matrix.
When the host's FRR daemon begins transmitting the newly generated EVPN Type-2/Type-5 routing records up to the Leaf switches via BGP Unnumbered, the Leaf switches dynamically learn and insert the tenant's paths on-the-fly. [6, 13] 
## 3. On the Border-Leaf Switches (External Boundary)
The Border Leaf does need to know how to route that specific tenant to the internet or corporate WAN. This boundary can be managed via two strategies:

* Automated (Central Controller): An infrastructure automation framework (such as an Ansible operator or a NetOps agent triggered by OpenStack's networking-bgpvpn notification hooks) executes an API call against the Border-Leaf pair to declare the static VRF and VNI mapping. [8] 
* Pre-Provisioned (Tenant Pools): In massive enterprise clouds, network admins pre-configure a pool of VRFs and VNIs (e.g., Tenant-VRF-01 through Tenant-VRF-50) on the Border Leafs ahead of time. When an OpenStack tenant project is initiated, it is simply allocated a pre-configured ID from that active fabric pool.

------------------------------
## Part 3: Full eBGP Fabric & EVPN Config Overhaul
Here is how the complete eBGP configuration maps across the entire data center network chain.

                  +-----------------------------------+

                  |            Exit Router            | (ASN 64512)
                  +-----------------------------------+
                                    |
                  +-----------------------------------+

                  |            Border Leaf            | (ASN 65009)
                  +-----------------------------------+
                            /               \
                           /                 \
            +-------------------+       +-------------------+

            |     Spine 01      |       |     Spine 02      | (ASN 65000)
            +-------------------+       +-------------------+
                            \                 /
                             \               /
                  +-----------------------------------+

                  |            SONiC TOR L1           | (ASN 65001)
                  +-----------------------------------+
                                    |
                         (eBGP Unnumbered / EVPN)
                                    |
                  +-----------------------------------+

                  |        Ubuntu Compute Host        | (ASN 65101)
                  +-----------------------------------+

## 1. Spine Switch Configuration (Pure eBGP Transition)

! Spine 1 Configuration (ASN 65000)
frr defaults traditional
hostname spine-01
!
router bgp 65000
  bgp router-id 10.0.0.101
  bgp bestpath as-path multipath-relax
  
  # Dynamic peer templates for eBGP downstream leaf switches
  neighbor FABRIC-LEAFS peer-group
  neighbor FABRIC-LEAFS remote-as external
  neighbor FABRIC-LEAFS interface
  
  address-family ipv4 unicast
    maximum-paths 64
    neighbor FABRIC-LEAFS activate
  exit-address-family

  address-family evpn
    neighbor FABRIC-LEAFS activate
    # CRITICAL: Prevents the spine from rewriting its own IP as the next-hop for EVPN tunnels
    neighbor FABRIC-LEAFS nexthop-local unchanged
  exit-address-family

## 2. Top-of-Rack (TOR) Leaf Switch Configuration [14] 

! SONiC TOR L1 Configuration (ASN 65001)
frr defaults traditional
hostname tor-l1
!
router bgp 65001
  bgp router-id 10.0.0.1
  bgp bestpath as-path multipath-relax
  
  neighbor TO-SPINES peer-group
  neighbor TO-SPINES remote-as 65000
  neighbor TO-SPINES interface
  
  neighbor SERVERS peer-group
  neighbor SERVERS remote-as external
  neighbor SERVERS interface
  
  address-family ipv4 unicast
    maximum-paths 64
    neighbor TO-SPINES activate
    neighbor SERVERS activate
  exit-address-family

  address-family evpn
    neighbor TO-SPINES activate
    neighbor SERVERS activate
    # CRITICAL: Forces next-hops to stay bound to the server's loopback addresses
    neighbor TO-SPINES nexthop-local unchanged
    neighbor SERVERS nexthop-local unchanged
    advertise-all-vni
  exit-address-family

## 3. Border Leaf Configuration (VRF Lite Mapping & EVPN Export) [15] 
The Border Leaf maps internal EVPN instances into cleartext IPv4 paths toward your upstream edge routers.

! Border Leaf Configuration (ASN 65009)
frr defaults traditional
hostname border-leaf-01
!
# Example tenant VRF configuration mapped to a shared public edge
vrf Tenant-A-Outside
 vni 10001
exit-vrf
!
router bgp 65009
  bgp router-id 10.0.0.99
  
  neighbor TO-SPINES peer-group
  neighbor TO-SPINES remote-as 65000
  neighbor TO-SPINES interface
  
  address-family ipv4 unicast
    neighbor TO-SPINES activate
  exit-address-family

  address-family evpn
    neighbor TO-SPINES activate
    neighbor TO-SPINES nexthop-local unchanged
  exit-address-family

# -------------------------------------------------------------
# Tenant Dynamic Translation Layer
# -------------------------------------------------------------
router bgp 65009 vrf Tenant-A-Outside
  # Distinct local identifier for this VRF instance
  bgp router-id 10.0.0.99
  
  # Establishes eBGP peering directly to the physical external exit router
  neighbor 192.168.100.1 remote-as 64512
  
  address-family ipv4 unicast
    neighbor 192.168.100.1 activate
    
    # Injects tenant EVPN VM paths into the Exit Router's standard L3 routing table
    redistribute evpn
  exit-address-family
  
  address-family evpn
    # Learns default internet routes from the Exit Router and pushes them down into the fabric
    advertise ipv4 unicast
  exit-address-family

------------------------------
## Part 4: Workload vs. Storage Operational Routing Flow

   1. Workload Route Ad (Dynamic): ovn-bgp-agent spins up a VM inside OpenStack on Tenant VRF 10001. The local host FRR daemon passes a Type-5 EVPN packet up to Leaf 65001. The leaf passes it to Spine 65000, which passes it to Border Leaf 65009. The Border Leaf accepts the route inside its local VRF Tenant-A-Outside and redistributes it out to the internet as a bare IPv4 target address. [6, 9, 12, 16] 
   2. Storage Traffic (Static): Your Rook-Ceph replication networks completely ignore this EVPN fabric. The ceph-dummy address (10.20.20.11/32) is advertised natively within the global underlay routing path (address-family ipv4 unicast). Storage blocks travel point-to-point directly via the bare infrastructure layer at wire speed, ensuring VM storage processes are never delayed by overlay computing encapsulation or OVN-BGP-Agent activities. [17] 

Would you like to examine an example of a packet trace analysis showing exactly how a packet from a VM is encapsulated in VXLAN while a Ceph replication packet travels unencapsulated on the same physical wire?

[1] [https://www.reddit.com](https://www.reddit.com/r/networking/comments/1dz2qds/best_practices_and_more_information_about_bgp/)
[2] [https://www.youtube.com](https://www.youtube.com/watch?v=KE-CF8bD1CU)
[3] [https://www.cisco.com](https://www.cisco.com/c/en/us/td/docs/switches/datacenter/nexus7000/sw/unicast/config/cisco_nexus7000_unicast_routing_config_guide_8x/configuring_advanced_bgp.html)
[4] [https://blog.ipspace.net](https://blog.ipspace.net/2024/10/evpn-designs-ebgp/)
[5] [https://www.cisco.com](https://www.cisco.com/c/en/us/products/collateral/switches/nexus-9000-series-switches/guide-c07-734107.html)
[6] [https://developers.redhat.com](https://developers.redhat.com/articles/2025/07/09/how-deploy-evpn-openstack-services-openshift)
[7] [https://docs.redhat.com](https://docs.redhat.com/en/documentation/red_hat_openstack_platform/17.1/html-single/configuring_dynamic_routing_in_red_hat_openstack_platform/index)
[8] [https://docs.openstack.org](https://docs.openstack.org/ovn-bgp-agent/latest/contributor/drivers/evpn_mode_design.html)
[9] [https://docs.openstack.org](https://docs.openstack.org/ovn-bgp-agent/latest/contributor/drivers/evpn_mode_design.html)
[10] [https://developers.redhat.com](https://developers.redhat.com/articles/2022/09/22/learn-about-new-bgp-capabilities-red-hat-openstack-17)
[11] [https://canonical-microovn.readthedocs-hosted.com](https://canonical-microovn.readthedocs-hosted.com/en/latest/explanation/bgp-redirect/)
[12] [https://docs.nvidia.com](https://docs.nvidia.com/networking-ethernet-software/guides/EVPN-Network-Reference/EVPN-Deployment-Scenarios/)
[13] [https://www.linkedin.com](https://www.linkedin.com/pulse/understanding-evpn-ethernet-vpn-vxlan-bgp-beginners-guide-arthur-xu-3alne)
[14] [https://stordis.com](https://stordis.com/overlay-configuration-examples-with-bgp-underlay/)
[15] [https://ovn-kubernetes.io](https://ovn-kubernetes.io/features/bgp-integration/route-advertisements/)
[16] [https://dev.to](https://dev.to/firstpasslab/build-a-vxlan-evpn-leaf-spine-fabric-lab-on-eve-ng-with-nexus-9000v-complete-nx-os-walkthrough-3047)
[17] [https://www.cisco.com](https://www.cisco.com/c/en/us/products/collateral/sanity/que-release/test-qa-white-paper-c11-739942.html)



Yes, it is absolutely possible to have the VTEP (Virtual Tunnel Endpoint) and VNI (VXLAN Network Identifier) encapsulation happen directly on the Host Server instead of the TOR switch. In fact, if you are using the OVN-BGP-Agent, the architecture is explicitly designed to terminate the VTEP directly on the Host Server. [1, 2, 3] 
When a tenant creates a network, the ovn-bgp-agent calls the Linux kernel to spin up a local VXLAN interface (ip link add vxlan-XXXX type vxlan id VNI...) and binds it to the corresponding Linux VRF. The host itself becomes the VTEP, sending encapsulated VXLAN packets straight out of enp2s0 and enp3s0. The upstream SONiC TOR switches treat these packets as standard IPv4 UDP traffic, entirely unaware that OpenStack tenant networks exist inside them. [4] 
Choosing whether to place your VTEP boundary on the Host Server (Software/Host-Overlay) versus the TOR Switch (Hardware/Network-Overlay) is a fundamental architectural decision. Below is the breakdown of how these two approaches compare.
------------------------------
## Comparison of VTEP Placement Strategies

APPROACH 1: VTEP on Host Server (Your Current OVN-BGP-Agent Design)
+---------------------------------------------------+

| Compute Host (VTEP)                               |
| [VM] -> [VXLAN Encapsulation (VNI)] -> [Kernel]   |
+---------------------------------------------------+
                         |
           (Standard IPv4 UDP Packet)
                         v
+---------------------------------------------------+

| SONiC TOR Switch (Pure L3 Underlay Router)        |
+---------------------------------------------------+

-------------------------------------------------------------------------

APPROACH 2: VTEP on TOR Switch (Hardware VXLAN)
+---------------------------------------------------+

| Compute Host (Bare L3 / Tagged VLAN)              |
| [VM] ------> [VLAN Tag / Plain IPv4] -----------> |
+---------------------------------------------------+
                         |
                         v
+---------------------------------------------------+

| SONiC TOR Switch (VTEP)                           |
| [Hardware ASIC] -> [VXLAN Encapsulation (VNI)]    |
+---------------------------------------------------+

------------------------------
## Technical & Strategic Trade-Offs## 1. Performance & CPU Overhead

* Host Server VTEP: Higher CPU Overhead. The host CPU must handle VXLAN encapsulation and decapsulation for every network packet leaving or entering a VM. While modern Intel/AMD CPUs have features like VXLAN Task Offloading to mitigate this, heavy networking workloads will still consume CPU cycles that could otherwise run OpenStack tenant VMs. [5] 
* TOR Switch VTEP: Wire-Speed Performance. Encapsulation is handled natively by the switch's specialized ASIC (e.g., Broadcom Trident/Tomahawk). The switch processes millions of packets per second with near-zero latency, completely freeing up compute host resources.

## 2. Network Simplicity & "Blast Radius"

* Host Server VTEP: Unmatched Simplicity for the Fabric. Your SONiC TOR, Spine, and Border Leaf switches do not need to configure virtual networks or track complex EVPN MAC tables. The physical network remains a plain, rock-solid Layer 3 IP CLOS fabric. If a host misbehaves, the "blast radius" is contained entirely to that single server. [6] 
* TOR Switch VTEP: Complex Fabric Management. Your switches must actively run a complex EVPN control plane to sync MAC addresses, ARP tables, and VTEP IPs across the data center. A misconfiguration on a switch can disrupt network connectivity for the entire row or cluster. [7, 8, 9] 

## 3. Support for Bare-Metal and Non-Virtual Workloads

* Host Server VTEP: Poor Integration with Non-OS Workloads. If you want to connect a physical legacy appliance, a hardware firewall, or a bare-metal database node directly into an OpenStack tenant network, you cannot do it easily. The bare-metal device lacks an OVN-BGP-Agent to wrap its packets in VXLAN.
* TOR Switch VTEP: Excellent Hybrid Integration. Because the switch handles the encapsulation at the physical port level, you can plug a bare-metal server into Ethernet4, map that port to a specific VNI, and it will seamlessly communicate with a cloud VM running on a compute host across the room. [10] 

## 4. Hardware Vendor Lock-In & Cost

* Host Server VTEP: Open and Hardware-Agnostic. You can use the cheapest, most basic L3 switches available. As long as the switch can route standard IPv4 packets and support eBGP Unnumbered, your cloud will work flawlessly. You are never locked into specific high-end switch ASICs.
* TOR Switch VTEP: Strict Hardware Dependency. You must purchase advanced switches that explicitly support hardware VxLAN Routing (RIOT) and EVPN asymmetric/symmetric routing profiles. Cheap or low-end switches cannot be used as TOR nodes.

------------------------------
## Trade-Off Summary Matrix

| Evaluation Criteria [11, 12, 13, 14] | VTEP on Host Server (Software) | VTEP on TOR Switch (Hardware) |
|---|---|---|
| Encapsulation Location | Compute Host OS (ovn-bgp-agent) | Switch Silicon (ASIC) |
| Switch Configuration Burden | Zero. Switch only routes raw UDP. | High. Switch runs full EVPN/VXLAN. |
| Host Resource Impact | Consumes host CPU for packet wrapping. | Near-zero host overhead. |
| Fabric Scalability | Excellent. Limited only by host capabilities. | Limited by Switch ASIC table sizes. |
| Bare-Metal Device Support | Difficult (Requires software gateways). | Native (Map a physical port to a VNI). |

------------------------------
## Architectural Verdict for Your Environment [15] 
Because you are planning an infrastructure utilizing the OVN-BGP-Agent, keeping the VTEP on the Host Server is the optimal choice. [16, 17] 
This design perfectly matches the decentralized philosophy of an L3 CLOS network. It prevents your SONiC switches from becoming bloated with virtual machine tenant states. Furthermore, it creates a clean separation of concerns for your storage: your Rook-Ceph replication network runs natively on the host's raw physical network interfaces at wire-speed with a 9000 MTU, completely untouched by the host's internal OVN VXLAN virtual overlay loops.
Would you like to see how to write a sample configuration for the ovn-bgp-agent.conf file to handle host-based VTEP bindings, or should we look at how to tune Linux Kernel parameters (like sysctl RPC values) to handle high-volume host-based VXLAN processing?

[1] [https://www.bdrshield.com](https://www.bdrshield.com/blog/vmware-nsx-t-components-and-working/)
[2] [https://subscription.packtpub.com](https://subscription.packtpub.com/book/cloud_and_networking/9781788392495/1/ch01lvl1sec02/what-is-openstack-networking)
[3] [https://www.keysight.com](https://www.keysight.com/blogs/en/tech/traf-gen/2020/11/19/what-are-the-key-requirements-to-support-vmotion-across-data-center-sites)
[4] [https://www.digihunch.com](https://www.digihunch.com/2020/07/dockersnetwork/)
[5] [https://ipads.se.sjtu.edu.cn](https://ipads.se.sjtu.edu.cn/_media/publications/liatc23.pdf)
[6] [https://www.flackbox.com](https://www.flackbox.com/netapp-vlans-networking-tutorial)
[7] [https://www.datacenterknowledge.com](https://www.datacenterknowledge.com/networking/data-center-network-topology-a-guide-to-optimizing-performance)
[8] [https://www.fs.com](https://www.fs.com/glossary/vlan-trunking-protocol-vtp-g633.html)
[9] [https://lokna.no](https://lokna.no/?p=1116)
[10] [https://www.keysight.com](https://www.keysight.com/blogs/en/tech/traf-gen/2020/11/19/what-are-the-key-requirements-to-support-vmotion-across-data-center-sites)
[11] [https://blog.invgate.com](https://blog.invgate.com/vxlan-vs-vlan)
[12] [https://www.keysight.com](https://www.keysight.com/blogs/en/tech/traf-gen/2020/11/19/what-are-the-key-requirements-to-support-vmotion-across-data-center-sites)
[13] [https://community.cisco.com](https://community.cisco.com/t5/switching/vtp-prunning-on-a-interface/td-p/4903031)
[14] [https://www.qsfptek.com](https://www.qsfptek.com/network-glossary/vxlan.html)
[15] [https://www.rack2cloud.com](https://www.rack2cloud.com/virtualization-architecture/)
[16] [https://docs.redhat.com](https://docs.redhat.com/it/documentation/red_hat_openstack_services_on_openshift/18.0/html-single/deploying_a_dynamic_routing_environment/index)
[17] [https://www.hjp.at](https://www.hjp.at/doc/rfc/rfc7348.html)


