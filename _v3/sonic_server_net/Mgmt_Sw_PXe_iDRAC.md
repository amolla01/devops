### When, where and how to handle iDRAC IPMI/PXE netting their split vlan(from oob management and pxe booting perspective) that connects to management switch for L2 communication. Worth mentioning metallb for L2 access of dashboards by ops team members.

## 1. When, Where, and How to Handle the Network Split (The Layer 2 Architecture)
```
To ensure high-availability and prevent network loops, your iDRAC/IPMI hardware, MaaS PXE booting engine, and MetalLB operations dashboard pools should all share the exact same Out-of-Band (OOB) L2 Management network block (10.10.0.0/16).
However, they are separated chronologically and structurally using strict IP range carving inside your MaaS server and your physical CRS125-24G switch ports, rather than forcing complex VLAN tagging inside the server operating systems.

       [ Physical CRS125-24G Out-of-Band Management Switch ]
            │ (Untagged / Access Mode VLAN 10 on all ports)
            ├───► [ Port 1 ] ──► MaaS Server (DHCP / TFTP Provider)
            │
            ├───► [ Port 2 ] ──► Dell R630 Dedicated iDRAC Port 
            │                     (Hardware IP: 10.10.12.124)
            │
            └───► [ Port 3 ] ──► Dell R630 Interface `enp1s0` 
                                  - Lifecycle Step 1: PXE Boots via MaaS DHCP Pool
                                  - Lifecycle Step 2: Boots OS -> Netplan Static IP (10.10.12.24)
                                  - Lifecycle Step 3: Kubespray up -> MetalLB claims (10.10.100.x)
```
## How to split the space safely:
```
To prevent collisions, carve your 10.10.0.0/16 OOB subnet into dedicated logical brackets based on device functions:

* 10.10.0.1 - 10.10.0.254: Infrastructure Gateways, MaaS Controller, and local DNS/NTP engines.
* 10.10.1.0 - 10.10.99.255: Static Operating System Management IPs managed by Netplan (e.g., 10.10.RACK.U_SLOT).
* 10.10.100.0 - 10.10.199.255: MetalLB Address Pools reserved exclusively for your Kubespray dashboards.
* 10.10.200.0 - 10.10.240.255: Dynamic MaaS PXE Boot DHCP Pool (Temporary lease pool used only during OS installation).
* 10.10.241.0 - 10.10.254.254: Hardcoded iDRAC/IPMI Hardware IPs (Static tracking for bare-metal power controls).
```
------------------------------
## 2. Physical Switch Configuration (The "Where")
```
The network split happens at the CRS125-24G physical switch port layer.

* The Rule: Configure all ports on the CRS125 switch as standard Access Ports (Untagged) in your management VLAN (e.g., VLAN 10).
* The Reason: This simplifies your bare-metal setup. When the Dell motherboard requests a PXE boot, it does not know how to read tagged VLAN networks yet. By stripping tags at the switch port, the raw server NIC receives standard broadcast frames cleanly, allowing the PXE handshake to execute without data corruption.
```
------------------------------
## 3. Chronological Configuration Workflow (The "When" and "How")
```
The separation of these assets executes across a clear timeline as your servers transition from bare metal to a fully functioning cloud:

## Phase A: Hardware Baseline (iDRAC Initialization)
Before any operating system is installed, you boot into the Dell BIOS or use the front LCD panel to configure your iDRAC network interface. [1] 

* Set it to Static.
* Assign it an IP in your hardware range (e.g., 10.10.12.124 for a server in Rack 12, Slot 24).
* Connect a physical patch cable from the server's dedicated iDRAC port directly into the CRS125 switch. The MaaS server can now monitor and power-cycle this hardware asset at any time.

## Phase B: The Deployment Wave (MaaS PXE Booting)
When you tell MaaS to provision the host, MaaS executes an IPMI command to turn the machine on and forces a network boot. [2] 

* The server's primary 1G management port (enp1s0) broadcasts a DHCP request out across the CRS125 switch.
* MaaS intercepts this request and grants a temporary IP address strictly from the PXE Boot Dynamic Pool (10.10.200.x), along with a TFTP boot loader path.
* The server pulls down the Ubuntu Linux installation media over this temporary IP link.

## Phase C: Post-Boot Lockdowns (Netplan Execution)
Once the Ubuntu installation concludes, MaaS reboots the server into the newly provisioned disk.

* The 00-oob-management.yaml Netplan configuration file we created initializes.
* It kills the temporary MaaS DHCP lease and locks the interface down with its permanent, static administrative IP: 10.10.12.24, binding it safely inside the isolated kernel mgmt-vrf.
```
------------------------------
## 4. Integrating MetalLB Layer 2 for Operations Teams
```
Now that your host nodes are online and your Kubespray playbook runs, MetalLB takes over its designated section of the OOB network.
Because your operations team requires direct access to OpenStack Horizon, Grafana, and Prometheus dashboards, MetalLB must listen directly to your management broadcast network domain to answer ARP requests from local admin computers.
## Step A: Configure Kubespray Addons (addons.yml)
To map MetalLB cleanly into your infrastructure split, feed it the exact IP bracket we reserved for containerized services inside inventory/mycluster/group_vars/k8s_cluster/addons.yml:

metallb_enabled: truemetallb_protocol: "layer2"
metallb_config:
  address_pools:
    ops-dashboards:
      ip_range:
        - 10.10.100.1-10.10.100.254  # The dedicated MetalLB operations pool
      auto_assign: true

## Step B: How Traffic Flows to the Operations Team

   1. An administrator sits down at a workstation or a VPN gateway plugged into the physical CRS125 management switch network block.
   2. They open a browser and type in 10.10.100.10 (the virtual IP that MetalLB dynamically granted to your NGINX Ingress controller pod representing the OpenStack Horizon Dashboard).
   3. The administrator's laptop sends out a local network broadcast query: "Who owns IP 10.10.100.10?"
   4. MetalLB's internal daemon—running with hostNetwork: true directly on your master/worker nodes—intercepts this layer-2 broadcast out of interface enp1s0.
   5. MetalLB sends an immediate ARP response back across the CRS125 switch: "I have that IP, route your packets to my MAC address."
   6. The admin's browser traffic bridges through the Ingress controller directly into your cloud control containers.
```
This unified approach ensures that your hardware controls (iDRAC), provisioning scripts (PXE/MaaS), system configuration planes (Netplan), and cloud visibility frameworks (MetalLB) function together seamlessly on the same wire without causing port collisions, security bleeding, or single-point-of-failure outages.
To ensure your monitoring alerts route smoothly, would you like to review how to write a quick BGP export configuration to let external admin subnets route cleanly into this 10.10.0.0/16 OOB space via your Exit Routers?

[1] [https://www.dell.com](https://www.dell.com/support/contents/en-ae/videos/videoplayer/how-to-perform-software-raid-configuration-using-idrac-service-module/6335467009112)
[2] [https://docs.openstack.org](https://docs.openstack.org/ironic/6.2.4/deploy/user-guide.html)


# Let's below map out all the subnets we explored thus far with their uses and the Kubespray ansible variables names and locations with the values that requires to be configured for K8 cluster build that implements them along with CNI/FRR/Netplan, all those IP/IP-Subnet touchpoints for a successful and mapped out implementation.

Here is the complete, master architectural blueprint for your OpenStack-on-Kubernetes deployment over a 100G SONiC BGP-Unnumbered fabric.
This guide pulls together every logical subnet, physical touchpoint, traffic-shaping parameter, and Netplan profile we explored, mapping them directly to their exact Kubespray Ansible variable names, file locations, and structural values to guarantee a conflict-free deployment.
------------------------------
## 🗺️ Part 1: The Master Subnet & Interface Worksheet
```
To ensure that your infrastructure remains structured and troubleshooting-friendly, all system assets utilize an explicit coordinate system matching their physical datacenter position:

* [ZONE]: 1 (Data Center 1, Availability Zone 1)
* [RACK]: 12 (Physical Server Rack Number)
* [SLOT]: 24 (Dell PowerEdge R630 Unit position inside the rack)
```
| Operational Network Plane [1, 2, 3] | Address Space Schema | Target Interface | Primary Architectural Purpose |
|---|---|---|---|
| iDRAC / IPMI Hardware | 10.10.241.0 - 10.10.254.254 | Dedicated iDRAC Port | Out-of-band bare-metal power cycle controls. |
| MaaS PXE Boot Engine | 10.10.200.0/24 | enp1s0 (During Boot) | Dynamic DHCP/TFTP pool for streaming OS installations. |
| OOB Host OS Management | 10.10.[RACK].[SLOT]/24 | enp1s0 (Post Boot) | Static Ubuntu OS administration via secure mgmt-vrf. |
| MetalLB Dashboard Pool | 10.10.100.0/24 | enp1s0 (Virtual ARP) | Exposing Horizon/Grafana to Operations staff. |
| Fabric Loopback Anchor | 10.[ZONE].[RACK].[SLOT]/32 | lo | System Router ID advertised via BGP Unnumbered. |
| Underlay Workload Fabric | BGP Unnumbered (IPv6 LL) | enp2s0 / enp3s0 | Active-Active multi-homed links to 100G TOR switches. |
| Ceph Storage Replication | 192.168.50.[SLOT]/24 | ceph-dummy0 | Isolated backend data replication shaped via Linux HTB. |
| K8s Pod Plane (Calico) | 10.233.0.0/18 | Virtual cali+ | Unencapsulated local pod namespaces leaked to host FRR. |
| K8s Service Plane | 10.233.64.0/18 | IPVS Virtual | Local cluster runtime virtual IPs; never exits the host. |
| OpenStack Public Endpoints | 203.0.113.0/24 | Virtual OVS Bridges | External provider network floating IPs leaked by OVN BGP. |
| OpenStack Tenant Spaces | 10.0.0.0/8, 172.16.0.0/12 | Encapsulated OVS | 100% open reusable private spaces isolated via Geneve. |

------------------------------
## 📂 Part 2: Multi-File Host Netplan Configuration
```
To prevent configuration errors from locking you out of your machines, split your Netplan files on each bare-metal Ubuntu worker/controller node inside /etc/netplan/:
## 🔒 /etc/netplan/00-oob-management.yaml

network:
  version: 2
  renderer: networkd
  vrfs:
    mgmt-vrf:
      table: 1000
      interfaces: [enp1s0]
  ethernets:
    enp1s0:
      dhcp4: false
      addresses: [10.10.12.24/24] # 10.10.[RACK].[SLOT]
      routes:
        - to: default
          via: 10.10.12.1
          metric: 1000

## 🌐 /etc/netplan/10-fabric-underlay.yaml

network:
  version: 2
  renderer: networkd
  ethernets:
    enp2s0:
      dhcp4: false
      ipv6-privacy: false
    enp3s0:
      dhcp4: false
      ipv6-privacy: false
  loopbacks:
    lo:
      addresses: [10.1.12.24/32] # 10.[ZONE].[RACK].[SLOT]

## 📦 /etc/netplan/20-storage-replication.yaml

network:
  version: 2
  renderer: networkd
  dummy-devices:
    ceph-dummy0:
      addresses: [192.168.50.24/24] # 192.168.50.[SLOT]
```
------------------------------
## 🛠️ Part 3: Kubespray Ansible Variable Touchpoints
```
To configure Kubespray to use Calico in pass-through host-routed mode, enable your OOB load balancers, and isolate port dependencies, modify the files inside your inventory directory structure exactly as follows:

## 📝 File Location 1: inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml [4] 
This file configures your base Kubernetes cluster mechanics and disables Calico's encapsulation planes. [5] 

# Enforce native CNI integration without conflicting dynamic overlay tunnelskube_network_plugin: calico
# Address space configurations mapped directly to our worksheetkube_pods_subnet: 10.233.0.0/18kube_service_addresses: 10.233.64.0/18
# Enable Multus so OpenStack pods can bridge natively out of Calico to the fabrickube_network_plugin_multus: true
# Leverage IPVS mode for high-performance load balancing within the Service planekube_proxy_mode: ipvs

## 📝 File Location 2: inventory/mycluster/group_vars/k8s_cluster/k8s-net-calico.yml
This file strips the BIRD routing engine out of Calico, freeing TCP Port 179 exclusively for your host’s native FRR system daemon.

# CRITICAL: Eliminate BIRD to prevent host port conflict with system FRRcalico_network_backend: "none"
# Completely disable overlay encapsulation to write clean /32 routes to the kernelcalico_ipip_mode: "Never"calico_vxlan_mode: "Never"
# Turn off NAT Outgoing since the upstream SONiC fabric routes Pod IPs nativelycalico_nat_outgoing: false

## 📝 File Location 3: inventory/mycluster/group_vars/k8s_cluster/addons.yml
This file activates the platform infrastructure add-ons required to expose dashboards over the isolated OOB management tier.

# Enable NGINX Ingress and bind it directly to the host network stack for line-rate speedingress_nginx_enabled: trueingress_nginx_host_network: true
# Enable Cert-Manager to automate internal OpenStack endpoint SSL certificatescert_manager_enabled: true
# Enable Metrics Server for real-time pod/node resource trackingmetrics_server_enabled: true
# Enable local volume provisioner to support low-latency storage blocks for OpenStack DBslocal_volume_provisioner_enabled: truelocal_volume_provisioner_storage_classes:
  local-storage:
    host_dir: /mnt/disks
    mount_dir: /mnt/disks
# Enable MetalLB and assign it the dedicated OOB dashboard management poolmetallb_enabled: truemetallb_protocol: "layer2"metallb_config:
  address_pools:
    ops-dashboards:
      ip_range:
        - 10.10.100.1-10.10.100.254
      auto_assign: true
```
------------------------------
## ⚙️ Part 4: Post-Kubespray Host Integrations## 1. Linux Traffic Control (HTB CPU Optimization)
```
To protect your compute server CPUs and ensure Ceph data replication never starves your production workloads, execute this traffic-shaping block on your host operating systems to map your multi-homed links:

for DEV in enp2s0 enp3s0; do
  sudo tc qdisc del dev $DEV root 2> /dev/null || true
  sudo tc qdisc add dev $DEV root handle 1: htb default 20
  sudo tc class add dev $DEV parent 1: classid 1:1 htb rate 10gbit
  # Class 10: Prioritized Kubernetes & OpenStack Workloads
  sudo tc class add dev $DEV parent 1:1 classid 1:10 htb rate 6gbit ceil 10gbit prio 1
  # Class 20: Capped Ceph Storage Replication Traffic
  sudo tc class add dev $DEV parent 1:1 classid 1:20 htb rate 4gbit ceil 4gbit prio 2
  sudo tc filter add dev $DEV parent 1:0 protocol ip prio 2 u32 match ip src 192.168.50.0/24 flowid 1:20done
```
## 2. Host FRR Export Configuration (/etc/frr/frr.conf)
Your host's native FRR daemon will smoothly manage the BGP Unnumbered topology, picking up the unencapsulated Calico pod paths and OVN provider blocks from the kernel while strictly blocking your Ceph and OOB management networks:
```
router bgp 4200000124  # Aligned Private ASN: 4200000[RACK][SLOT]
 bgp router-id 10.1.12.24  # Matching System Loopback ID
 no bgp default ipv4-unicast
 !
 neighbor enp2s0 interface remote-as external
 neighbor enp3s0 interface remote-as external
 !
 address-family ipv4 unicast
  neighbor enp2s0 activate
  neighbor enp2s0 capability extended-nexthop
  neighbor enp3s0 activate
  neighbor enp3s0 capability extended-nexthop
  !
  # Dynamic Kernel ingestion filtered via route-map boundary
  redistribute kernel route-map RM_FABRIC_EXPORT
  maximum-paths 64
 exit-address-family
!
ip prefix-list PL_K8S_PODS permit 10.233.0.0/18 ge 32
ip prefix-list PL_OPENSTACK_FLOATING permit 203.0.113.0/24 ge 24
!
route-map RM_FABRIC_EXPORT permit 10
 match ip address prefix-list PL_K8S_PODS
!
route-map RM_FABRIC_EXPORT permit 20
 match ip address prefix-list PL_OPENSTACK_FLOATING
!
route-map RM_FABRIC_EXPORT deny 100
```
This cohesive blueprint completely maps out all parameters needed to build a highly available, robust container and virtualization platform with explicit network isolation and zero overlapping resource constraints.
To ensure your cluster scaling operations run smoothly, would you like to review how to format the Kubespray inventory hosts configuration file (hosts.yaml) to mirror this node mapping schema?

[1] [https://as.zabedu.ru](https://as.zabedu.ru/en/virtual2/vmware2/vrealize2/vra8-kubespray-en)
[2] [https://blog.devgenius.io](https://blog.devgenius.io/k8s-ipvs-mode-introduction-6457a02cd91a)
[3] [https://oneuptime.com](https://oneuptime.com/blog/post/2026-03-20-plan-ipv4-allocation-10-0-0-0-8/view)
[4] [https://forge.inrae.fr](https://forge.inrae.fr/dipso/kubespray/-/blob/master/docs/setting-up-your-first-cluster.md)
[5] [https://www.plural.sh](https://www.plural.sh/blog/cni-kubernetes-guide/)
