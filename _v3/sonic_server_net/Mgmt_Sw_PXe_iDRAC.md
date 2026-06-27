# When, where and how to handle iDRAC IPMI/PXE netting their split vlan(from oob management and pxe booting perspective) that connects to management switch for L2 communication. Worth mentioning metallb for L2 access of dashboards by ops team members.

## 1. When, Where, and How to Handle the Network Split (The Layer 2 Architecture)
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

## How to split the space safely:
To prevent collisions, carve your 10.10.0.0/16 OOB subnet into dedicated logical brackets based on device functions:

* 10.10.0.1 - 10.10.0.254: Infrastructure Gateways, MaaS Controller, and local DNS/NTP engines.
* 10.10.1.0 - 10.10.99.255: Static Operating System Management IPs managed by Netplan (e.g., 10.10.RACK.U_SLOT).
* 10.10.100.0 - 10.10.199.255: MetalLB Address Pools reserved exclusively for your Kubespray dashboards.
* 10.10.200.0 - 10.10.240.255: Dynamic MaaS PXE Boot DHCP Pool (Temporary lease pool used only during OS installation).
* 10.10.241.0 - 10.10.254.254: Hardcoded iDRAC/IPMI Hardware IPs (Static tracking for bare-metal power controls).

------------------------------
## 2. Physical Switch Configuration (The "Where")
The network split happens at the CRS125-24G physical switch port layer.

* The Rule: Configure all ports on the CRS125 switch as standard Access Ports (Untagged) in your management VLAN (e.g., VLAN 10).
* The Reason: This simplifies your bare-metal setup. When the Dell motherboard requests a PXE boot, it does not know how to read tagged VLAN networks yet. By stripping tags at the switch port, the raw server NIC receives standard broadcast frames cleanly, allowing the PXE handshake to execute without data corruption.

------------------------------
## 3. Chronological Configuration Workflow (The "When" and "How")
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

------------------------------
## 4. Integrating MetalLB Layer 2 for Operations Teams
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

This unified approach ensures that your hardware controls (iDRAC), provisioning scripts (PXE/MaaS), system configuration planes (Netplan), and cloud visibility frameworks (MetalLB) function together seamlessly on the same wire without causing port collisions, security bleeding, or single-point-of-failure outages.
To ensure your monitoring alerts route smoothly, would you like to review how to write a quick BGP export configuration to let external admin subnets route cleanly into this 10.10.0.0/16 OOB space via your Exit Routers?

[1] [https://www.dell.com](https://www.dell.com/support/contents/en-ae/videos/videoplayer/how-to-perform-software-raid-configuration-using-idrac-service-module/6335467009112)
[2] [https://docs.openstack.org](https://docs.openstack.org/ironic/6.2.4/deploy/user-guide.html)
