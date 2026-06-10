Running Kubespray with Calico on top of an OpenStack cloud that also uses Calico for Neutron creates a "Calico-on-Calico" architecture. This setup causes severe networking conflicts because both layers try to manage the same underlying host routing tables, interfaces, and IP spaces.
Here are the primary conflicts you will encounter:
## 💥 IPAM and Subnet Overlaps

* IP Allocation Clashes: Both OpenStack and Kubernetes will try to assign IP addresses to their respective endpoints (VMs and Pods).
* Routing Confusion: If the Kubernetes Pod CIDR overlaps with the OpenStack VM IP pool, the Linux kernel will not know whether to route traffic to a local Pod or an OpenStack VM. [1] 

## 🌐 BGP Routing Conflicts

* AS Number Collisions: Both Calico instances use BGP (Border Gateway Protocol) to announce routes. If both layers use the same Autonomous System (AS) number on the same host, BGP sessions will reject routes due to loop detection.
* Route Reflection Wars: If both layers attempt to establish full-mesh BGP peerings or use the same top-of-rack (ToR) switches as Route Reflectors, they will overwrite each other's routing entries.

## 🔌 Felix Configuration and Iptables Fights

* Rule Overwriting: Calico relies on an agent called Felix on each node to manage iptables, nftables, and routing tables. Two independent Felix agents running on the same host will continuously overwrite each other's firewall and forwarding rules. [2, 3] 
* Interface Management: Both agents will attempt to control host network interfaces, leading to dropped packets and broken network policies.

## 🛡️ Encapsulation Conflicts

* Tunneling Clashes: If both layers use IP-in-IP or VXLAN encapsulation without explicit configuration, the overlay headers can conflict.
* MTU Issues: Double encapsulation (wrapping a Pod VXLAN packet inside a VM VXLAN packet) drastically shrinks the Maximum Transmission Unit (MTU), causing severe packet fragmentation and performance drops.

------------------------------
## 🛠️ How to Resolve These Conflicts
If you must run this specific architecture, apply these isolation strategies:

* Isolate via Nested Virtualization: Run Kubespray inside OpenStack VMs, not directly on the bare-metal hypervisors. This isolates the Kubernetes Calico Felix agent inside the VM namespace, away from the OpenStack hypervisor Felix agent.
* Change AS Numbers: Assign distinct BGP AS numbers to the OpenStack Calico layer and the Kubespray Calico layer.
* Strict CIDR Separation: Ensure the Kubernetes Pod CIDR, Service CIDR, and OpenStack Neutron subnets are entirely unique.
* Adjust MTU Settings: Lower the MTU in the Kubespray Calico configuration (typically to 1400 or lower) to accommodate the double overlay overhead.

To help narrow down the best solution, could you tell me if you are deploying Kubernetes directly on the OpenStack control plane (bare metal) or inside OpenStack VMs?

[1] [https://oneuptime.com](https://oneuptime.com/blog/post/2026-03-13-diagnose-calico-pod-cidr-conflicts/view)
[2] [https://hackmd.io](https://hackmd.io/@gekart/calico-quiz)
[3] [https://blog.devgenius.io](https://blog.devgenius.io/k8s-networking-calico-part1-7f74395b6fe2)


When running OpenStack on top of Kubernetes (often called containerized OpenStack, using frameworks like OpenStack-Helm or Kolla-Ansible), your architecture reverses. [1] 
The Kubernetes cluster managed by Kubespray acts as the host layer, and Calico becomes the unified single-pane-of-glass data plane for both Kubernetes pods and OpenStack VMs. Instead of competing, the OpenStack Neutron pods integrate directly into the existing Kubernetes Calico infrastructure. [2] 
------------------------------
## 🏗️ The Integration Architecture
In this architecture, you eliminate Open vSwitch (OVS), Linux bridges, and traditional overlay tunneling (like VXLAN or GRE) entirely. [2] 

   1. The Shared Datastore (etcd): The [Calico ML2 Neutron driver](https://docs.tigera.io/calico/latest/getting-started/openstack/overview) running inside the containerized Neutron pods does not write to an independent database. Instead, it is configured to write its networking states directly into the same etcd instance used by Kubespray's Calico. [2, 3] 
   2. The Unified Host Agent (Felix): You do not run an OpenStack-specific Calico agent on the bare-metal hosts. The calico-node DaemonSet deployed by Kubespray (which includes the Felix agent) handles everything. It listens to etcd for both Kubernetes pod events and OpenStack VM creation events, programming the Linux kernel routes for both. [2, 3] 
   3. The Shared BGP Fabric: The calico-node BIRD daemon advertises the IPs of both the Kubernetes Pods and the OpenStack VMs to the physical Top-of-Rack (ToR) switches using a unified BGP mesh. [2, 4] 

------------------------------
## ⚙️ How the Components Change

| Component [2, 3, 5] | Traditional OpenStack | OpenStack on K8s (Unified Calico) |
|---|---|---|
| Neutron ML2 Core Plugin | ovs (Open vSwitch) or linuxbridge | calico (networking-calico ML2 plugin[](https://fuel-ccp.readthedocs.io/en/latest/using_calico_instead_of_ovs.html)) |
| Neutron Agents | L3 Agent, OVS Agent | None. Removed entirely from the deployment topology. |
| DHCP Agent | neutron-dhcp-agent (dnsmasq) | calico-dhcp-agent (runs as a container on K8s) |
| Data Plane Programming | OVS Flow Rules | Felix (calico-node pod running on the Kubespray node) |

------------------------------
## 🚀 Life of a Packet (VM-to-Pod Communication)
Because both environments share a pure Layer 3 routing table managed by the host's Linux kernel, communication becomes completely flat: [2, 4] 

   1. A tenant provisions an OpenStack VM.
   2. The containerized Neutron API creates a port and commits the data to etcd.
   3. The local calico-node pod (Felix) on the destination hypervisor detects the entry, creates a tap interface for the VM, and assigns its IP.
   4. When an OpenStack VM wants to talk to a Kubernetes Pod, the packet leaves the VM tap interface, enters the host's routing table, and is routed directly via native IP routing to the target Pod’s cali interface—with zero encapsulation or translation overhead. [2, 3, 4, 5] 

------------------------------
## ⚠️ Critical Constraints & Configuration Requirements
While this provides massive performance boosts, you must configure Kubespray and OpenStack with the following strict parameters:

* Disable Overlapping IPs in OpenStack: By default, OpenStack Neutron allows different tenants to create identical subnets (e.g., 10.0.0.0/24) using network namespaces. Because Calico uses a flat, global host routing table, you must disable overlapping local IP pools in your Neutron configuration (allow_overlapping_ips = False). [6] 
* Kubernetes Proxy Service for etcd: OpenStack Neutron pods run in isolated namespaces and cannot natively talk to localhost to hit etcd. You must configure a Kubernetes headless service or an etcd-proxy so the containerized Neutron control plane can reliably reach the Kubespray etcd cluster. [2] 
* Consistent MTU: Since there is no VXLAN/GRE overlay for the VMs, the MTU for OpenStack tenant networks should match the physical fabric MTU (usually 1500, or 9000 for Jumbo Frames).

------------------------------
To help you map out the exact configuration files, which orchestration framework are you planning to use to deploy the OpenStack pods on top of Kubernetes (e.g., OpenStack-Helm, Kolla-Ansible, or StarlingX)? [1] 

[1] [https://wiki.openstack.org](https://wiki.openstack.org/wiki/Containerizing_StarlingX_Infrastructure)
[2] [https://fuel-ccp.readthedocs.io](https://fuel-ccp.readthedocs.io/en/latest/using_calico_instead_of_ovs.html)
[3] [https://docs.tigera.io](https://docs.tigera.io/calico/latest/getting-started/openstack/overview)
[4] [https://kubernetes.feisky.xyz](https://kubernetes.feisky.xyz/en/extension/network/calico)
[5] [https://oneuptime.com](https://oneuptime.com/blog/post/2026-03-14-configure-openstack-neutron-api-calico/view)
[6] [https://www.youtube.com](https://www.youtube.com/watch?v=FhaS0HcISZ4)


Introducing ovn-bgp-agent and FRR into an environment where OpenStack runs on top of a Kubespray-deployed Kubernetes cluster changes the architecture fundamentally.
Because ovn-bgp-agent relies on OVN (Open Virtual Network) as the backend, Calico is no longer used for the OpenStack Neutron layer. Instead, you are building a Co-existing Routing Architecture: Kubespray uses Calico for Kubernetes pods, while OpenStack uses ML2/OVN paired with ovn-bgp-agent and FRR for VMs. Both components establish independent BGP sessions to your Top-of-Rack (ToR) switches to advertise host routes. [1, 2, 3, 4, 5] 
This specific "Route-to-the-Host" architecture impacts your networking integration across several critical domains:
------------------------------
## 1. BGP Daemon and AS Number Conflicts (FRR vs. BIRD)
Kubespray deploys Calico with its own embedded BGP routing daemon called BIRD. Since you are installing FRR on the same bare-metal host servers to back ovn-bgp-agent, two different routing daemons will compete for control over the host's BGP protocol stack. [4, 6] 

* The Port 179 Clash: Both BIRD (Calico) and FRR will attempt to bind to TCP port 179 (the standard BGP port) on the host's physical or loopback interfaces. The daemon that initializes second will fail to start.
* Autonomous System (AS) Isolation: If both daemons attempt to peer with the L3 CLOS spine/leaf switches using the exact same local AS number and same host IP, the upstream switches will flag the sessions as flapping or structurally broken due to loop detection.

## 2. Linux Kernel Routing and Policy Clashes
Because both Calico and ovn-bgp-agent handle traffic by writing directly to the host's Linux kernel network stack, they can step on each other's configurations. [1] 

* ovn-bgp-agent Design: This agent creates a Virtual Routing and Forwarding (VRF) instance or specific dummy network interfaces (like bgp-nic) to isolate VM traffic, instructing FRR to leak or advertise routes found in the kernel. [1, 5] 
* The Felix Interaction: Calico’s host agent (Felix) aggressively monitors the default Linux routing tables and iptables/nftables rules. If ovn-bgp-agent programs host routes or kernel configurations that intersect with Calico's monitored zones, Felix may misinterpret them as rogue entries and continually clear or overwrite them.

## 3. Asymmetric Routing on Ingress/Egress
Traffic originating from outside the data center moving through the L3 CLOS fabric to a VM or a Pod utilizes Equal-Cost Multi-Path (ECMP) routing. [7] 

* Pod Traffic: Hits a Kubespray node via the Calico-advertised Pod CIDR.
* VM Traffic: Moves through an OpenStack provider network or a Floating IP (FIP) advertised by FRR via ovn-bgp-agent.
* The Intersection Risk: If an OpenStack virtual machine needs to communicate directly with a Kubernetes control pod running on the same node (e.g., an OpenStack API pod reaching its backing database), the traffic might attempt to leave the node via FRR, route up to the CLOS switch, and then get sent back down via Calico. This induces massive latency and risks dropouts if firewalls block the un-encapsulated return path. [3, 4, 8] 

------------------------------
## 🛠️ Strategic Integration Blueprint
To cleanly integrate ovn-bgp-agent + FRR alongside Kubespray's Calico without service degradation, apply the following design parameters:

                  +-----------------------------------+

                  |        L3 CLOS Switches           |
                  +-----------------+-----------------+
                                    |
            BGP Session (BIRD)      |      BGP Session (FRR)
            [Pod Routes / Service]  |      [VM IPs / FIPs]
                                    |
  +---------------------------------+---------------------------------+

  | Bare-Metal L3 Host Server                                         |
  |                                                                   |
  |   +--------------------------+       +------------------------+   |
  |   |    Kubespray / Calico    |       |  OpenStack / OVN-BGP   |   |
  |   |  (Uses BIRD / Port 179)  |       | (Uses FRR / VRF Route) |   |
  |   +------------+-------------+       +-----------+------------+   |
  |                |                                 |                |
  |      Default Routing Table               Isolated Linux VRF       |
  +-------------------------------------------------------------------+

## A. Isolate Routing Daemons using BGP Multi-Instance or VRFs
Do not let BIRD and FRR compete for the same standard host interface.

* Configure Calico to bind to the primary host management IP.
* Configure FRR to run inside an isolated Linux VRF (evpn or provider VRF mode). This keeps FRR’s routing engine logically isolated inside its own networking namespace on the host, preventing TCP port conflicts on the default host namespace. [5] 
* Alternatively, disable Calico’s BIRD daemon entirely in Kubespray (no_global_bgp_peers: true) and use Calico's Kube-Controllers to announce pod routes to Kubernetes. Then, let FRR be the sole BGP speaker on the node, configuring FRR to dynamically ingest Calico's local network interfaces via route redistribution.

## B. Strict Address Isolation
Because both stacks map directly to the host layer, ensure clear boundaries:

* Kubernetes Pod/Service CIDRs: Must be strictly blocked and filtered within FRR's configuration to guarantee FRR never accidentally advertises a Kubernetes internal endpoint.
* OpenStack Provider Subnets: Must be explicitly blacklisted inside Calico's IPPool custom resources so Calico never attempts to claim or assign an IP belonging to an OpenStack VM pool.

## C. Adjust Calico Felix Monitoring
Configure Kubespray's Calico settings to prevent Felix from wiping out routes added by ovn-bgp-agent. You can tweak Calico's environment configurations (FELIX_INTERFACEEXCLUSION) to tell Felix to completely ignore the OVS/OVN bridges (e.g., br-ex, br-int) and the dummy interfaces created by the BGP agent. [1, 5] 
------------------------------
To help refine the configuration templates for your host nodes, what Linux distribution are you deploying on these bare-metal servers, and are you using iBGP or eBGP to peer with your CLOS fabric? [9] 

[1] [https://blog.epheo.eu](https://blog.epheo.eu/articles/openstack-bgp/index.html)
[2] [https://cloudification.io](https://cloudification.io/cloud-blog/ovn-traffic-flow-troubleshooting-in-openstack/)
[3] [https://ltomasbo.wordpress.com](https://ltomasbo.wordpress.com/2021/02/04/openstack-networking-with-bgp/)
[4] [https://oneuptime.com](https://oneuptime.com/blog/post/2026-02-09-calico-bgp-pod-routing/view)
[5] [https://developers.redhat.com](https://developers.redhat.com/articles/2025/07/09/how-deploy-evpn-openstack-services-openshift)
[6] [https://developers.redhat.com](https://developers.redhat.com/articles/2022/09/22/learn-about-new-bgp-capabilities-red-hat-openstack-17)
[7] [https://www.youtube.com](https://www.youtube.com/watch?v=ozjHhAbqXWg&t=158)
[8] [https://github.com](https://github.com/openstack/ovn-bgp-agent)
[9] [https://ovn-kubernetes.io](https://ovn-kubernetes.io/okeps/okep-5296-bgp/)



To integrate ovn-bgp-agent (using FRR) alongside Kubespray’s Calico on Ubuntu with an eBGP CLOS fabric, you must solve the fundamental problem of two distinct BGP routing engines (BIRD vs. FRR) competing for the same host network interface and TCP port 179.
Because you are using eBGP, your spine/leaf switches expect distinct Autonomous System (AS) numbers per host server (or per tier), and they will reject overlapping BGP sessions initiated from the same host source IP.
Here is the exact technical blueprint to achieve a stable architecture.
------------------------------
## 🏛️ The Recommended Architecture: FRR as the Sole Host BGP Speaker
The cleanest production design is to disable Calico's embedded BGP daemon (BIRD) entirely and leverage FRR as the single, unified BGP engine on the Ubuntu host. FRR will peer natively with your eBGP CLOS fabric, handling route advertisement for both Kubernetes Pods/Services and OpenStack VMs.

       +--------------------------------------------+

       |             eBGP CLOS Fabric               |
       |         (Spine / Leaf Switches)            |
       +---------------------+----------------------+
                             |
                             | Single eBGP Session per Link
                             | (FRR handling all prefixes)
                             v
+---------------------------------------------------------+

| Ubuntu Host Server (eBGP Private AS, e.g., 65001)       |
|                                                         |
|   +-----------------------+   +---------------------+   |
|   |   Kubespray / Calico  |   | OpenStack OVN Network|  |
|   | (BGP/BIRD Disabled)   |   |   (ovn-bgp-agent)   |   |
|   +-----------+-----------+   +----------+----------+   |
|               |                          |              |
|          caliXXXX interfaces        bgp-nic / VRF       |
|               |                          |              |
|               +------------+-------------+              |
|                            |                            |
|                            v                            |
|                     FRR Routing Daemon                  |
+---------------------------------------------------------+

## Why this is necessary on Ubuntu:
If you try to run both, Calico’s BIRD daemon will bind to the host's primary physical network interface. When FRR tries to start up to support ovn-bgp-agent, it will fail with a bind: Address already in use error on port 179. Forcing them onto different loopback interfaces causes the upstream eBGP CLOS switch to see two competing routers on the exact same physical link, leading to route flapping and loop-detection drops.
------------------------------
## 🛠️ Step-by-Step Implementation Blueprint## Step 1: Configure Kubespray to Disable Native BGP
When deploying or updating your cluster with Kubespray, modify your group_vars/k8s_cluster/k8s_net_calico.yml file to disable global BGP peering and the BIRD daemon. This converts Calico into a pure Kubernetes controller that tracks pod IPs but leaves routing to the host OS.
Set the following parameters:

# Disable Calico's internal BGP mesh and BIRD daemoncalico_no_global_bgp_peers: truecalico_network_backend: "none" # Prevents BIRD from initializing
# Ensure Felix ignores OVN and FRR interfacescalico_felix_interface_exclusion: "br-int,br-ex,bgp-nic,ovn-*"

## Step 2: Install and Configure FRR on the Ubuntu Host
Install the native FRR package on Ubuntu (apt install frr frr-pythontools). You must configure FRR to dynamically ingest both Kubernetes routes and OpenStack routes, then pass them cleanly to the eBGP CLOS fabric.
Edit /etc/frr/daemons to ensure bgpd is enabled:

bgpd=yes

Edit your FRR routing configuration (/etc/frr/frr.conf). You will use standard eBGP peering, assign a unique private AS to the host, and redistribute kernel routes (where Calico and OVN write their interfaces):

! Assign a unique Private AS per host (e.g., 65001)
router bgp 65001
 bgp router-id <HOST_PRIMARY_IP>
 no bgp ebgp-requires-policy
 
 ! Peer with your upstream L3 CLOS Leaf Switches
 neighbor <LEAF_1_IP> remote-as <LEAF_1_AS>
 neighbor <LEAF_1_IP> description Leaf-Switch-A
 neighbor <LEAF_2_IP> remote-as <LEAF_2_AS>
 neighbor <LEAF_2_IP> description Leaf-Switch-B
 
 address-family ipv4 unicast
  ! 1. Advertise Kubespray Pod / Service Subnets
  ! Calico writes these directly to the Linux Kernel routing table
  redistribute kernel route-map FILTER-TO-FABRIC
  
  ! 2. Advertise OpenStack VM Subnets / Floating IPs
  ! ovn-bgp-agent injects these into the host networking stack
  redistribute connected route-map FILTER-TO-FABRIC
  
  neighbor <LEAF_1_IP> activate
  neighbor <LEAF_2_IP> activate
 exit-address-family

! Prefix-list to ensure we only advertise intended K8s and OpenStack pools
ip prefix-list ALLOWED-PREFIXES seq 10 permit <K8S_POD_CIDR> le 32
ip prefix-list ALLOWED-PREFIXES seq 20 permit <K8S_SERVICE_CIDR> le 32
ip prefix-list ALLOWED-PREFIXES seq 30 permit <OPENSTACK_PROVIDER_CIDR> le 32

route-map FILTER-TO-FABRIC permit 10
 match ip address prefix-list ALLOWED-PREFIXES

## Step 3: Configure ovn-bgp-agent for Route Leakage
Configure your ovn-bgp-agent config file (/etc/ovn-bgp-agent/ovn-bgp-agent.conf) to operate in bgp or bgp-vrf mode. Because FRR is managing the BGP state globally on the host, configure ovn-bgp-agent to focus purely on exposing the VM ports to the local Linux host stack so FRR can read them.

[DEFAULT]
bgp_AS = 65001
# Match the driver to your OVN layout
driver = ovn_bgp_driver
# Direct ovn-bgp-agent to let FRR handle upstream communication
bgp_router_id = <HOST_PRIMARY_IP>

Depending on your design preference, if you choose bgp-vrf mode, ovn-bgp-agent will place VM routes inside a specific Linux VRF (e.g., vrf-provider). If you use this mode, simply add redistribute vrf vrf-provider inside your FRR configuration block.
------------------------------
## ⚠️ Potential Operational Risks to Monitor

   1. Route Over-Aggregation: Ensure your eBGP switches are configured to accept small subnet masks (down to /32 for individual host routes and OpenStack Floating IPs). If your upstream fabric aggregates routes too aggressively, traffic intended for a specific OpenStack VM might get dropped or sent to the wrong Kubespray host server.
   2. Next-Hop Subnet Validity: Because you are using eBGP, ensure that the interface IP connecting the Ubuntu host to the Leaf switch is a shared transit subnet. Upstream Leaf switches will reject a /32 VM route if the BGP next-hop parameter points to an unreachable local host interface.

------------------------------
To ensure this configuration integrates smoothly with your physical environment, are you planning to advertise individual OpenStack VM tenant IPs directly as /32 routes, or will you be using Floating IPs (NAT) via an OpenStack Provider Network?




To achieve strict multi-tenancy, complete security isolation, and support for multi-account traversal within an OpenStack cluster that sits on top of Kubespray, you cannot use a flat /32 BGP host-routing model for internal tenant networks.
If ovn-bgp-agent and FRR were to push every tenant’s private IP directly to your physical eBGP CLOS fabric, tenant networks would overlap, collide, and violate isolation rules.
To satisfy your multi-tenancy requirements, you must deploy an EVPN-VXLAN or Geneve Overlay architecture at the OpenStack layer, while reserving FRR and ovn-bgp-agent exclusively for Provider Networks, Floating IPs (FIPs), and BGP-to-the-Host Interconnects.
------------------------------
## 🗺️ The Multi-Tenant Security Architecture

+-----------------------------------------------------------------------+

|  PHYSICAL eBGP CLOS FABRIC (Underlay)                                 |
+-----------------------------------+-----------------------------------+
                                    |
                                    | eBGP (Public/Provider IPs only)
                                    v
+-----------------------------------------------------------------------+

|  UBUNTU HOST SERVER (Kubespray Node)                                  |
|                                                                       |
|   +--------------------------+     +------------------------------+   |
|   |  Kube-Pods & Services    |     |  FRR Routing Daemon          |   |
|   |  (Isolated via Calico)   |     |  (Peers with Fabric via VRF) |   |
|   +--------------------------+     +--------------+---------------+   |
|                                                   ^                   |
|                                                   | advertises FIPs   |
|   +-----------------------------------------------+---------------+   |
|   |  OPENSTACK OVN LAYER (The Virtualization Plane)               |   |
|   |                                                               |   |
|   |  [Tenant A (Acct 1)]           [Tenant A (Acct 2)]            |   |
|   |  Private CIDR: 10.0.0.0/24     Private CIDR: 10.0.0.0/24      |   |
|   |  VNI: 10001 (Isolated)         VNI: 10002 (Isolated)          |   |
|   |         \                              /                      |   |
|   |          +---> [ OVN Virtual Router ] <+                      |   |
|   |                (Controls Inter-Account Linkages)              |   |
+---+---------------------------------------------------------------+---+

------------------------------
## 1. Enforcing Isolation via Overlay Tunneling (Geneve/VXLAN)
To support overlapping subnets across multiple accounts (e.g., Account 1 and Account 2 both creating a 10.0.0.0/24 network), the OpenStack Neutron/OVN layer must encapsulate tenant traffic.

* How it integrates: Use OVN's native Geneve (or VXLAN) encapsulation for all internal East-West traffic. The encapsulated traffic flows securely between host servers over the Kubespray node's underlay IP fabric.
* The Benefit: The underlying physical CLOS switches and the host's primary routing table never see tenant private IPs. Absolute separation is maintained at Layer 2 and Layer 3 inside the OVN software plane.

## 2. Multi-Account Communication (Inter-Tenant Routing)
When a single tenant opens multiple OpenStack accounts and needs their independent resources to communicate, you must establish controlled peering points without breaking the global isolation model. OVN handles this purely in software using one of two methods:

* Option A: OVN Inter-Router Peering (Recommended): OVN allows you to connect two distinct tenant Logical Routers (belonging to separate projects/accounts) using a hidden transit logical switch. This keeps the traffic purely within the OVN software data plane on the hosts, routing at line rate without ever reaching the physical CLOS switches.
* Option B: OpenStack Address Scopes and Routed Provider Networks: You can create shared Address Scopes across the accounts. This informs OVN that while the projects are separate, their IP spaces are trusted. OVN can then route between them natively without requiring a Floating IP.

## 3. Redefining the Role of ovn-bgp-agent and FRR
In a strictly isolated multi-tenant design, ovn-bgp-agent does not advertise internal tenant networks. Instead, it must be configured in underlay or floating_ip mode.

* Floating IP Advertisement: When a tenant assigns a Floating IP (Public or Provider IP) to a VM, ovn-bgp-agent detects it, binds it to a local VRF interface on the host, and instructs FRR to advertise that specific /32 FIP to the eBGP CLOS fabric.
* Strict Security Boundaries: If Account 1 and Account 2 want to communicate via external endpoints, traffic exits Host A using Account 1's FIP, moves through the physical eBGP CLOS fabric, and enters Host B using Account 2's FIP. This guarantees that traffic undergoes full hardware-level security, firewall, and access-control list (ACL) auditing.

------------------------------
## 🛠️ Strict Multi-Tenancy Configuration Adjustments
To ensure your host infrastructure supports this without data leakage, apply these constraints to your deployment files:
## A. Configure ovn-bgp-agent for FIP-Only Exposure
Update your ovn-bgp-agent.conf file to strictly enforce that private tenant networks are masked, and only Floating IPs or Provider-backed networks are exposed to FRR:

[bgp]
# Expose ONLY Floating IPs and VMs attached directly to provider networks
expose_tenant_networks = False
expose_floating_ip = True

# Leverage Linux VRF on Ubuntu to isolate the external routing plane
bgp_vrf = vrf-provider

## B. Isolate OpenStack External Traffic via FRR VRFs
To guarantee that tenant public traffic never bleeds into Kubespray’s internal control plane or host management spaces, isolate FRR's BGP peering inside a dedicated VRF.
In your Ubuntu /etc/network/interfaces or Netplan config, define the VRF:

# Create the provider VRF
ip link add vrf-provider type vrf table 1001
ip link set dev vrf-provider up

Then, block your FRR configurations specifically into that VRF block:

router bgp 65001 vrf vrf-provider
 bgp router-id <HOST_PROVIDER_NIC_IP>
 ! eBGP Leaf Peering for Tenant Outbound/Inbound
 neighbor <LEAF_PROVIDER_IP> remote-as <LEAF_AS>
 
 address-family ipv4 unicast
  redistribute connected
 exit-address-family

------------------------------
To help finalize your network architecture design, how will tenants connect their separate accounts? Will you provide them with OpenStack Barbican/Designate features to link their networks internally, or do you expect them to link resources purely via External Floating IPs and Firewalls?




When a single tenant uses multiple OpenStack accounts (projects) and needs to connect resources across them within your OVN-backed architecture, you must balance security isolation, performance, and user self-service capabilities.
Because your underlying infrastructure uses Kubespray (Calico) and an eBGP CLOS fabric with FRR, the choice you make directly affects how much traffic stays local to the hypervisors versus how much traffic hits your physical switches.
Here are the four primary architectural options for cross-account connectivity, along with their detailed trade-offs.
------------------------------
## Option 1: OVN Router Peering (RBAC Network/Port Sharing)
This is the native, software-defined way to link projects inside OVN. Using OpenStack CLI/API commands, an administrator or an automated platform allows Project A to securely share a network or router interface with Project B using Role-Based Access Control (RBAC) policies. OVN creates a logical transit switch under the hood to bridge the two project routers.

* 👍 Pros:
* Line-Rate Performance: Traffic is routed entirely in software inside the OVN data plane. It never leaves the host nodes or hits the physical CLOS fabric.
   * Zero Extra Cost: Does not consume valuable public or provider Floating IPs (FIPs).
   * No Overhead: Avoids double-encapsulation penalties or NAT processing delays.
* 👎 Cons:
* Strict CIDR Coordination: Because this is direct Layer 3 routing, the tenant accounts cannot use overlapping IP spaces (e.g., both accounts cannot use 10.0.0.0/24).
   * Management Complexity: Requires precise OpenStack RBAC API orchestration to securely map dependencies between distinct user accounts.

## Option 2: External Floating IPs (NAT Hairpinning via CLOS Fabric)
In this model, resources in Account A talk to resources in Account B using their external Floating IPs. The traffic exits Account A’s VM, goes to the host's OVN boundary, gets translated via Source-NAT (SNAT), is advertised to the physical CLOS fabric via ovn-bgp-agent and FRR, and routes through the physical network before entering Account B via Destination-NAT (DNAT).

* 👍 Pros:
* Absolute Isolation: Accounts are completely decoupled. They can use identical overlapping private IP ranges (10.0.0.0/24) without conflict.
   * Hardware Auditing: All inter-account traffic passes through your physical network switches, allowing you to easily apply hardware firewalls, IDS/IPS, and centralized traffic logging.
   * Tenant Autonomy: Users can configure this completely on their own without requiring cloud administrator RBAC permissions.
* 👎 Cons:
* High Resource Consumption: Consumes two external/public IP addresses (one FIP per account resource) for what is ultimately internal traffic.
   * Performance Penalty: Traffic experiences higher latency because it leaves the host, travels up the fabric, undergoes NAT twice, and travels back down (hairpinning).

## Option 3: Routed Provider Networks with OpenStack Address Scopes
OpenStack allows administrators to define "Address Scopes." If two different accounts create networks within the same shared Address Scope, OpenStack realizes that these spaces are non-overlapping and legally routable. OpenStack then hooks both tenant networks up to a shared, routed Provider Network on the host.

* 👍 Pros:
* No NAT Overhead: Communication is pure routing, avoiding the performance hits of NAT or Floating IPs.
   * Granular Control: Perfect for a single entity that manages 20+ accounts and wants a centralized corporate "transit network" design.
* 👎 Cons:
* Host Route Ingestion: Because these are provider-backed networks, ovn-bgp-agent and FRR will need to actively announce these tenant prefixes up to your physical eBGP switches, increasing the size of your upstream routing tables.
   * Administrative Lock-in: Address scopes must be set up globally by the cloud administrator beforehand; tenants cannot create them dynamically.

## Option 4: Tenant-Managed VPNs or Overlay Proxies (e.g., Barbican + WireGuard)
Instead of relying on the cloud infrastructure to connect them, the tenant deploys a lightweight virtual appliance (like a WireGuard, IPsec, or HAProxy instance) inside a VM in Account A, and another in Account B. You can use OpenStack Barbican to securely store and inject the cryptographic VPN keys into the VMs during boot via cloud-init. The VMs then build their own encrypted tunnel over an external network or standard floating IPs.

* 👍 Pros:
* Zero Infrastructure Risk: Completely hands-off for the cloud administrator. If the tenant misconfigures their routing, they only break their own VMs, never the underlying host tables or FRR layers.
   * Overlapping IP Friendly: Fully supports overlapping internal subnets since the tenant controls the overlay encapsulations.
* 👎 Cons:
* Double Encapsulation & MTU Crises: Packets are encapsulated inside the tenant VPN, which is then encapsulated inside OpenStack’s OVN Geneve/VXLAN overlay. This dramatically shrinks your available MTU, causing severe packet fragmentation unless MTU sizes are lowered to 1300 or below inside the guest operating systems.
   * Wasted VM Compute: The tenant must pay for and run compute instances just to process routing and encryption workloads.

------------------------------
## Summary Matrix for Decision Making

| Selection Metric | Option 1: OVN Peering | Option 2: Floating IPs | Option 3: Address Scopes | Option 4: Tenant VPN |
|---|---|---|---|---|
| Allows Overlapping IPs? | ❌ No | Yes | ❌ No | Yes |
| Traffic Path | 💻 Purely Local Host | 🌐 Physical Fabric | 🎛️ Host to Local Gateway | 🌐 Encapsulated Fabric |
| Admin Effort | Medium (RBAC Automation) | Minimum | High (Pre-planned) | None (Tenant handles) |
| MTU Risk | Minimum | Minimum | Minimum | ⚠️ Critical Risk |
| Performance | 🚀 Maximum | 🐢 Medium (NAT Cost) | High | 🐢 Low |

------------------------------
To help you drill down into the exact deployment playbook, who will be responsible for triggering this connectivity? Will it be managed by automated CI/CD pipelines/Terraform (favoring Option 1), or do you have a multi-tenant self-service portal where users expect total network design freedom (favoring Option 2)?




# OpenStack on Kubernetes: Advanced Networking & Multi-Tenancy Blueprint
**Architecture Component:** Kubespray (Calico) + OpenStack (OVN / `ovn-bgp-agent` / FRR)  
**Host Operating System:** Ubuntu  
**Fabric Interconnect:** eBGP CLOS Fabric  

---

## 1. Core Architectural Overview

When deploying OpenStack on top of a Kubespray-managed Kubernetes cluster, the architecture reverses traditional models. Kubernetes acts as the base host infra plane, while OpenStack handles the workload virtualization layer. 

By introducing `ovn-bgp-agent` and FRR to interface with an eBGP CLOS fabric alongside Kubespray's Calico, the system transitions into a **Co-existing Routing Architecture**. Calico drives networking for Kubernetes pods, while ML2/OVN handles virtualization network mapping, relying on FRR to announce edge routes natively to the host.

### Technical Collision Risks (BIRD vs. FRR)
1. **The TCP Port 179 Clash:** By default, Calico deploys an embedded BGP daemon called BIRD. If FRR is initialized natively on the same Ubuntu host to back `ovn-bgp-agent`, both daemons will attempt to bind to the standard BGP port (TCP 179) on the host's primary interfaces, resulting in immediate initialization failure for the second daemon.
2. **Autonomous System (AS) Flapping:** Under an eBGP design, upstream spine/leaf switches expect discrete BGP sessions. If two separate local daemons attempt to open distinct sessions using the same host source IP and AS number, the upstream switches will flag the link for route looping and drop the sessions.
3. **Felix Routing Conflicts:** Calico’s host agent (`Felix`) aggressively cleans unauthorized changes in the Linux kernel routing and firewall (`iptables`/`nftables`) tables. Left unconfigured, Felix will continuously wipe out the host routes injected by `ovn-bgp-agent`.

---

## 2. Implementation Blueprint: FRR as the Unified Host Speaker

The production-grade resolution to the BIRD/FRR conflict is to **completely disable Calico’s internal BGP daemon (BIRD)** and establish **FRR as the single, unified BGP speaker** on the Ubuntu host interface.




<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OpenStack on K8s Networking Architecture</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 900px;
            margin: 0 auto;
            padding: 40px 20px;
            background-color: #f8f9fa;
        }
        h1 {
            color: #003366;
            border-bottom: 3px solid #003366;
            padding-bottom: 10px;
            margin-bottom: 5px;
        }
        h2 {
            color: #0056b3;
            margin-top: 30px;
            border-bottom: 1px solid #ddd;
            padding-bottom: 5px;
        }
        .subtitle {
            font-size: 1.1em;
            color: #666;
            margin-bottom: 30px;
            font-style: italic;
        }
        code {
            font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;
            background-color: #e9ecef;
            padding: 2px 6px;
            border-radius: 4px;
            font-size: 0.9em;
        }
        pre {
            background-color: #212529;
            color: #f8f9fa;
            padding: 15px;
            border-radius: 6px;
            overflow-x: auto;
            font-size: 0.85em;
            line-height: 1.4;
        }
        pre code {
            background-color: transparent;
            padding: 0;
            color: inherit;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
            background: #fff;
        }
        th, td {
            border: 1px solid #dee2e6;
            padding: 12px;
            text-align: left;
        }
        th {
            background-color: #003366;
            color: white;
        }
        tr:nth-child(even) {
            background-color: #f2f2f2;
        }
        .warning {
            background-color: #fff3cd;
            border-left: 5px solid #ffc107;
            padding: 15px;
            margin: 20px 0;
            border-radius: 4px;
        }
        .pro-list { color: #28a745; font-weight: bold; }
        .con-list { color: #dc3545; font-weight: bold; }
    </style>
</head>
<body>

    <h1>OpenStack on Kubernetes Architecture Blueprint</h1>
    <div class="subtitle">Integration Analysis: Kubespray (Calico) + OpenStack (OVN / ovn-bgp-agent / FRR) on Ubuntu via eBGP</div>

    <h2>1. Core Architectural Overview</h2>
    <p>When running OpenStack containerized on top of a Kubespray-deployed Kubernetes cluster, the foundational networking assumptions flip. Kubernetes handles the bare-metal host interfaces, and OpenStack acts as the tenant orchestration framework. By running <code>ovn-bgp-agent</code> alongside FRR to peer natively with an eBGP CLOS fabric, you build a <strong>Co-existing Routing Architecture</strong>.</p>
    
    <div class="warning">
        <strong>Critical System Conflict:</strong> Both Calico (via its native BIRD daemon) and host-level FRR will attempt to bind to the default BGP port (<strong>TCP 179</strong>) on the physical or loopback host interfaces. The engine that registers second will crash, destabilizing cluster-wide ingress/egress mapping.
    </div>

    <h2>2. Technical Solution: FRR as the Sole BGP Speaker</h2>
    <p>To eliminate interface contention, you must completely disable Calico's internal BGP engine and pass the task of advertising all local prefixes (Pods, Services, and Virtual Machine FIPs) exclusively to <strong>FRR</strong>.</p>

    <h3>Kubespray Calico Configuration Override</h3>
    <p>Apply these values inside your Kubespray configuration deployment to disable local BIRD instances and stop Calico's Felix agent from conflicting with OVN interfaces:</p>
    <pre><code># group_vars/k8s_cluster/k8s_net_calico.yml
calico_no_global_bgp_peers: true
calico_network_backend: "none"
calico_felix_interface_exclusion: "br-int,br-ex,bgp-nic,ovn-*"</code></pre>

    <h3>Host System FRR Engine Matrix</h3>
    <p>Update your Ubuntu host <code>/etc/frr/frr.conf</code> layout to aggregate routes out of both ecosystem environments seamlessly:</p>
    <pre><code>router bgp 65001
 bgp router-id 192.168.10.11
 no bgp ebgp-requires-policy
 
 neighbor 10.0.0.1 remote-as 65100
 neighbor 10.0.0.1 description Leaf-Switch-A
 
 address-family ipv4 unicast
  redistribute kernel route-map FILTER-TO-FABRIC
  redistribute connected route-map FILTER-TO-FABRIC
  neighbor 10.0.0.1 activate
 exit-address-family

ip prefix-list ALLOWED-PREFIXES seq 10 permit 10.233.0.0/18 le 32
ip prefix-list ALLOWED-PREFIXES seq 20 permit 10.233.64.0/18 le 32
ip prefix-list ALLOWED-PREFIXES seq 30 permit 203.0.113.0/24 le 32

route-map FILTER-TO-FABRIC permit 10
 match ip address prefix-list ALLOWED-PREFIXES</code></pre>

    <h2>3. Strict Multi-Tenancy & Security Isolation</h2>
    <p>To prevent address overlapping conflicts across isolated account environments, private tenant allocations are containerized inside OVN software-defined **Geneve overlay tunnels**. The host's public edge interfaces handle outer encapsulation headers only.</p>
    <ul>
        <li><code>expose_tenant_networks = False</code> inside <code>ovn-bgp-agent.conf</code> to enforce encapsulation boundaries.</li>
        <li><code>expose_floating_ip = True</code> to strictly permit public endpoint routing visibility via host FRR.</li>
        <li>Isolate external provider lanes by pinning host-level FRR configurations into an independent network <strong>VRF</strong> namespace on Ubuntu.</li>
    </ul>

    <h2>4. Cross-Account Interconnect Matrix</h2>
    <p>When a tenant sets up resources over independent accounts and requires cross-boundary links, evaluate the following platform configuration options:</p>

    <table>
        <thead>
            <tr>
                <th>Connectivity Model</th>
                <th>Architectural Method</th>
                <th>Trade-Off Advantages</th>
                <th>System Constraints</th>
            </tr>
        </thead>
        <tbody>
            <tr>
                <td><strong>Option 1: OVN Router Peering</strong></td>
                <td>Direct internal software bridging via tenant RBAC tokens inside the OVN layer.</td>
                <td><span class="pro-list">[+]</span> Maximum line-rate routing processing speed.<br><span class="pro-list">[+]</span> Consumes no Floating IPs.</td>
                <td><span class="con-list">[-]</span> Overlapping private IP subnets are strictly blocked.</td>
            </tr>
            <tr>
                <td><strong>Option 2: External Floating IPs</strong></td>
                <td>Traffic routes outward across the eBGP fabric and hairpins back via dual NAT translation.</td>
                <td><span class="pro-list">[+]</span> Absolute data isolation.<br><span class="pro-list">[+]</span> Allows completely overlapping tenant CIDRs.</td>
                <td><span class="con-list">[-]</span> Noticeable dual-NAT latency penalty.<br><span class="con-list">[-]</span> Heavy external IP pool allocation overhead.</td>
            </tr>
            <tr>
                <td><strong>Option 3: Address Scopes</strong></td>
                <td>Pre-mapped global address definitions route directly via host Provider Networks.</td>
                <td><span class="pro-list">[+]</span> Bypasses all processing overhead associated with NAT.</td>
                <td><span class="con-list">[-]</span> Imposes continuous up-front routing setup coordination.</td>
            </tr>
            <tr>
                <td><strong>Option 4: Tenant VPN Overlay</strong></td>
                <td>Crypto gateway appliances (WireGuard/IPsec) running straight inside the tenant VMs.</td>
                <td><span class="pro-list">[+]</span> Completely decoupled; zero administrative overhead.</td>
                <td><span class="con-list">[-]</span> Triple-encapsulation layers cripple MTU efficiency.</td>
            </tr>
        </tbody>
    </table>

</body>
</html>


I have generated the complete technical discussion formatted into both an HTML document and a Markdown (.md) file as requested.
Because I operate entirely as a text-based AI without local file-system writes, I cannot drop files directly onto your machine's hard drive. However, I have provided the complete, self-contained source code for both formats below. You can save them directly to your laptop in seconds using the instructions provided.
## 📝 Download File 1: Markdown (openstack_k8s_networking.md)
Copy the code block below, paste it into a text editor on your laptop (like VS Code, Notepad, or TextEdit), and save the file exactly as openstack_k8s_networking.md.

# OpenStack on Kubernetes: Advanced Networking & Multi-Tenancy Blueprint**Architecture Component:** Kubespray (Calico) + OpenStack (OVN / `ovn-bgp-agent` / FRR)  
**Host Operating System:** Ubuntu  
**Fabric Interconnect:** eBGP CLOS Fabric  
---## 1. Core Architectural Overview
When deploying OpenStack on top of a Kubespray-managed Kubernetes cluster, the architecture reverses traditional models. Kubernetes acts as the base host infra plane, while OpenStack handles the workload virtualization layer. 

By introducing `ovn-bgp-agent` and FRR to interface with an eBGP CLOS fabric alongside Kubespray's Calico, the system transitions into a **Co-existing Routing Architecture**. Calico drives networking for Kubernetes pods, while ML2/OVN handles virtualization network mapping, relying on FRR to announce edge routes natively to the host.
### Technical Collision Risks (BIRD vs. FRR)1. **The TCP Port 179 Clash:** By default, Calico deploys an embedded BGP daemon called BIRD. If FRR is initialized natively on the same Ubuntu host to back `ovn-bgp-agent`, both daemons will attempt to bind to the standard BGP port (TCP 179) on the host's primary interfaces, resulting in immediate initialization failure for the second daemon.2. **Autonomous System (AS) Flapping:** Under an eBGP design, upstream spine/leaf switches expect discrete BGP sessions. If two separate local daemons attempt to open distinct sessions using the same host source IP and AS number, the upstream switches will flag the link for route looping and drop the sessions.
3. **Felix Routing Conflicts:** Calico’s host agent (`Felix`) aggressively cleans unauthorized changes in the Linux kernel routing and firewall (`iptables`/`nftables`) tables. Left unconfigured, Felix will continuously wipe out the host routes injected by `ovn-bgp-agent`.
---## 2. Implementation Blueprint: FRR as the Unified Host Speaker
The production-grade resolution to the BIRD/FRR conflict is to **completely disable Calico’s internal BGP daemon (BIRD)** and establish **FRR as the single, unified BGP speaker** on the Ubuntu host interface.


+--------------------------------------------+
| eBGP CLOS Fabric |
| (Spine / Leaf Switches) |
+---------------------+----------------------+
|
| Single eBGP Session per Link
v
+---------------------------------------------------------+
| Ubuntu Host Server (eBGP Private AS, e.g., 65001) |
| |
| +-----------------------+ +---------------------+ |
| | Kubespray / Calico | | OpenStack OVN Network| |
| | (BGP/BIRD Disabled) | | (ovn-bgp-agent) | |
| +-----------+-----------+ +----------+----------+ |
| | | |
| caliXXXX interfaces bgp-nic / VRF |
| | | |
| +------------+-------------+ |
| | |
| v |
| FRR Routing Daemon |
+---------------------------------------------------------+


### Step 1: Kubespray Configuration (`group_vars/k8s_cluster/k8s_net_calico.yml`)
Configure Calico to track pod spaces inside Kubernetes without spinning up its local network routing daemon:

```yaml
calico_no_global_bgp_peers: true
calico_network_backend: "none"
calico_felix_interface_exclusion: "br-int,br-ex,bgp-nic,ovn-*"
```

### Step 2: Native FRR Engine Setup (`/etc/frr/frr.conf`)
Configure the host-level FRR engine to ingest both the Kubespray infrastructure prefixes and the OVN external boundaries, broadcasting them cleanly over eBGP:

```text
router bgp 65001
 bgp router-id 192.168.10.11
 no bgp ebgp-requires-policy
 
 neighbor 10.0.0.1 remote-as 65100
 neighbor 10.0.0.1 description Leaf-Switch-A
 neighbor 10.0.0.2 remote-as 65200
 neighbor 10.0.0.2 description Leaf-Switch-B
 
 address-family ipv4 unicast
  redistribute kernel route-map FILTER-TO-FABRIC
  redistribute connected route-map FILTER-TO-FABRIC
  neighbor 10.0.0.1 activate
  neighbor 10.0.0.2 activate
 exit-address-family

ip prefix-list ALLOWED-PREFIXES seq 10 permit 10.233.0.0/18 le 32
ip prefix-list ALLOWED-PREFIXES seq 20 permit 10.233.64.0/18 le 32
ip prefix-list ALLOWED-PREFIXES seq 30 permit 203.0.113.0/24 le 32

route-map FILTER-TO-FABRIC permit 10
 match ip address prefix-list ALLOWED-PREFIXES
```

---

## 3. Strict Multi-Tenancy Architecture

To achieve complete security isolation and support overlapping IP schemas across independent accounts (e.g., multiple accounts creating a `10.0.0.0/24` block), **private tenant routes must never bleed into the host's main routing table.**

1. **Isolation Layer:** Internal east-west tenant communications are handled entirely by OVN using software encapsulation tunnels (**Geneve** or VXLAN). The physical fabric and host routing modules remain completely blind to internal VM addressing.
2. **`ovn-bgp-agent` Policy Modification:** Configure the agent to process **Floating IPs (FIPs) and Provider Networks only**. `expose_tenant_networks` must be set to `False`.
3. **VRF Isolation on Ubuntu:** Create an isolated Linux VRF interface (`vrf-provider`) to separate tenant outbound traffic from the Kubernetes base control plane networks.

---

## 4. Cross-Account Tenant Connectivity Evaluation

When a single tenant operates multiple OpenStack projects and needs to securely bridge their resources, choose from the following architectural frameworks:

### Option 1: OVN Logical Router Peering (RBAC Inter-Network Sharing)
* **Mechanism:** Administrator utilizes OpenStack RBAC API mapping to establish a logical transit bridge directly inside the OVN virtualization mesh.
* **Trade-Offs:** Achieves maximum, line-rate virtualization speed since traffic never leaves the host compute engine. Consumes no Floating IPs. However, **strictly forbids overlapping IP CIDRs** between those accounts.

### Option 2: Floating IPs via Core CLOS Fabric (Hairpinning)
* **Mechanism:** VMs in Project A reach VMs in Project B via their external NAT targets. Traffic runs up out of the host compute pool into the physical switches, undergoes dual-NAT, and returns down.
* **Trade-Offs:** Supports absolute decoupled autonomy and allows identical overlapping IP schemas. Enables centralized state profiling via physical firewalls. However, induces a noticeable throughput and latency penalty due to dual-NAT serialization and physical link traversal.

### Option 3: Routed Provider Networks with Address Scopes
* **Mechanism:** Projects assign networks out of a pre-planned, shared global Address Scope, tying their interfaces into a unified physical Provider Network routing bridge.
* **Trade-Offs:** Eradicates NAT performance lag. However, requires intensive up-front administrative coordination, and forces FRR to scale its active upstream routing table size significantly.

### Option 4: Tenant-Managed VPN Overlays (WireGuard / IPsec)
* **Mechanism:** Tenant self-provisions routing instances inside their VMs, utilizing OpenStack Barbican to manage cryptographic security keys.
* **Trade-Offs:** Absolute zero management overhead for the cloud provider. However, introduces extreme **double encapsulation overhead** (Guest VPN over OVN Geneve over K8s Network), degrading the effective MTU to `1300` or lower and risking massive packet fragmentation.

------------------------------
## 🌐 Download File 2: HTML Document (openstack_k8s_networking.html)
Copy the code block below, paste it into a text editor, and save the file exactly as openstack_k8s_networking.html. You can then double-click the file to open a highly readable, styled reference sheet in any web browser.

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OpenStack on K8s Networking Architecture</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 900px;
            margin: 0 auto;
            padding: 40px 20px;
            background-color: #f8f9fa;
        }
        h1 {
            color: #003366;
            border-bottom: 3px solid #003366;
            padding-bottom: 10px;
            margin-bottom: 5px;
        }
        h2 {
            color: #0056b3;
            margin-top: 30px;
            border-bottom: 1px solid #ddd;
            padding-bottom: 5px;
        }
        .subtitle {
            font-size: 1.1em;
            color: #666;
            margin-bottom: 30px;
            font-style: italic;
        }
        code {
            font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;
            background-color: #e9ecef;
            padding: 2px 6px;
            border-radius: 4px;
            font-size: 0.9em;
        }
        pre {
            background-color: #212529;
            color: #f8f9fa;
            padding: 15px;
            border-radius: 6px;
            overflow-x: auto;
            font-size: 0.85em;
            line-height: 1.4;
        }
        pre code {
            background-color: transparent;
            padding: 0;
            color: inherit;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
            background: #fff;
        }
        th, td {
            border: 1px solid #dee2e6;
            padding: 12px;
            text-align: left;
        }
        th {
            background-color: #003366;
            color: white;
        }
        tr:nth-child(even) {
            background-color: #f2f2f2;
        }
        .warning {
            background-color: #fff3cd;
            border-left: 5px solid #ffc107;
            padding: 15px;
            margin: 20px 0;
            border-radius: 4px;
        }
        .pro-list { color: #28a745; font-weight: bold; }
        .con-list { color: #dc3545; font-weight: bold; }
    </style>
</head>
<body>

    <h1>OpenStack on Kubernetes Architecture Blueprint</h1>
    <div class="subtitle">Integration Analysis: Kubespray (Calico) + OpenStack (OVN / ovn-bgp-agent / FRR) on Ubuntu via eBGP</div>

    <h2>1. Core Architectural Overview</h2>
    <p>When running OpenStack containerized on top of a Kubespray-deployed Kubernetes cluster, the foundational networking assumptions flip. Kubernetes handles the bare-metal host interfaces, and OpenStack acts as the tenant orchestration framework. By running <code>ovn-bgp-agent</code> alongside FRR to peer natively with an eBGP CLOS fabric, you build a <strong>Co-existing Routing Architecture</strong>.</p>
    
    <div class="warning">
        <strong>Critical System Conflict:</strong> Both Calico (via its native BIRD daemon) and host-level FRR will attempt to bind to the default BGP port (<strong>TCP 179</strong>) on the physical or loopback host interfaces. The engine that registers second will crash, destabilizing cluster-wide ingress/egress mapping.
    </div>

    <h2>2. Technical Solution: FRR as the Sole BGP Speaker</h2>
    <p>To eliminate interface contention, you must completely disable Calico's internal BGP engine and pass the task of advertising all local prefixes (Pods, Services, and Virtual Machine FIPs) exclusively to <strong>FRR</strong>.</p>

    <h3>Kubespray Calico Configuration Override</h3>
    <p>Apply these values inside your Kubespray configuration deployment to disable local BIRD instances and stop Calico's Felix agent from conflicting with OVN interfaces:</p>
    <pre><code># group_vars/k8s_cluster/k8s_net_calico.yml
calico_no_global_bgp_peers: true
calico_network_backend: "none"
calico_felix_interface_exclusion: "br-int,br-ex,bgp-nic,ovn-*"</code></pre>

    <h3>Host System FRR Engine Matrix</h3>
    <p>Update your Ubuntu host <code>/etc/frr/frr.conf</code> layout to aggregate routes out of both ecosystem environments seamlessly:</p>
    <pre><code>router bgp 65001
 bgp router-id 192.168.10.11
 no bgp ebgp-requires-policy
 
 neighbor 10.0.0.1 remote-as 65100
 neighbor 10.0.0.1 description Leaf-Switch-A
 
 address-family ipv4 unicast
  redistribute kernel route-map FILTER-TO-FABRIC
  redistribute connected route-map FILTER-TO-FABRIC
  neighbor 10.0.0.1 activate
 exit-address-family

ip prefix-list ALLOWED-PREFIXES seq 10 permit 10.233.0.0/18 le 32
ip prefix-list ALLOWED-PREFIXES seq 20 permit 10.233.64.0/18 le 32
ip prefix-list ALLOWED-PREFIXES seq 30 permit 203.0.113.0/24 le 32

route-map FILTER-TO-FABRIC permit 10
 match ip address prefix-list ALLOWED-PREFIXES</code></pre>

    <h2>3. Strict Multi-Tenancy & Security Isolation</h2>
    <p>To prevent address overlapping conflicts across isolated account environments, private tenant allocations are containerized inside OVN software-defined **Geneve overlay tunnels**. The host's public edge interfaces handle outer encapsulation headers only.</p>
    <ul>
        <li><code>expose_tenant_networks = False</code> inside <code>ovn-bgp-agent.conf</code> to enforce encapsulation boundaries.</li>
        <li><code>expose_floating_ip = True</code> to strictly permit public endpoint routing visibility via host FRR.</li>
        <li>Isolate external provider lanes by pinning host-level FRR configurations into an independent network <strong>VRF</strong> namespace on Ubuntu.</li>
    </ul>

    <h2>4. Cross-Account Interconnect Matrix</h2>
    <p>When a tenant sets up resources over independent accounts and requires cross-boundary links, evaluate the following platform configuration options:</p>

    <table>
        <thead>
            <tr>
                <th>Connectivity Model</th>
                <th>Architectural Method</th>
                <th>Trade-Off Advantages</th>
                <th>System Constraints</th>
            </tr>
        </thead>
        <tbody>
            <tr>
                <td><strong>Option 1: OVN Router Peering</strong></td>
                <td>Direct internal software bridging via tenant RBAC tokens inside the OVN layer.</td>
                <td><span class="pro-list">[+]</span> Maximum line-rate routing processing speed.<br><span class="pro-list">[+]</span> Consumes no Floating IPs.</td>
                <td><span class="con-list">[-]</span> Overlapping private IP subnets are strictly blocked.</td>
            </tr>
            <tr>
                <td><strong>Option 2: External Floating IPs</strong></td>
                <td>Traffic routes outward across the eBGP fabric and hairpins back via dual NAT translation.</td>
                <td><span class="pro-list">[+]</span> Absolute data isolation.<br><span class="pro-list">[+]</span> Allows completely overlapping tenant CIDRs.</td>
                <td><span class="con-list">[-]</span> Noticeable dual-NAT latency penalty.<br><span class="con-list">[-]</span> Heavy external IP pool allocation overhead.</td>
            </tr>
            <tr>
                <td><strong>Option 3: Address Scopes</strong></td>
                <td>Pre-mapped global address definitions route directly via host Provider Networks.</td>
                <td><span class="pro-list">[+]</span> Bypasses all processing overhead associated with NAT.</td>
                <td><span class="con-list">[-]</span> Imposes continuous up-front routing setup coordination.</td>
            </tr>
            <tr>
                <td><strong>Option 4: Tenant VPN Overlay</strong></td>
                <td>Crypto gateway appliances (WireGuard/IPsec) running straight inside the tenant VMs.</td>
                <td><span class="pro-list">[+]</span> Completely decoupled; zero administrative overhead.</td>
                <td><span class="con-list">[-]</span> Triple-encapsulation layers cripple MTU efficiency.</td>
            </tr>
        </tbody>
    </table>

</body>
</html>

------------------------------
Would you like me to map out a specific automated automation pattern, such as a Terraform snippet or an Ansible task block, to help automate the setup of these network configurations across your Ubuntu hosts?

