## we have few ovs bridges, br-h101-l1, br-h102-l1 where two virtual 10g server host attaching them to an arista model 7050qx32 from port1 and two more bridge called br-h201-l2, br-h202-l2 simulating connection to model 7050qx32s with again two virtual 10g server host from physical port 1 and 2 . the difference between this two arista model is in case of 7050qx32, a 40g qsfp+ breakout cable that has 4 sfp+ cage on one end, is used to connect to two servers to the qsfp+ port1. however for model 7050qx32s, port1/2/3/4 all of them are sfp+ cage but port5 is qsfp+cage and internally when sfp+ lanes are activated, port5 is not as they are internally hardwired that way. so, two sfp+ cable from port1/2 is used to connect to two host servers. sonic is running in both of these models. now break-out configuration is needed to configure the sonic switch os to work. please describe in detail how the simulation with ovs bridge and it's respective veth interfaces will connect with the host servers and switch models described above. assume all these are provisioned as virtual instances in an ubuntu machine. decribe with pictorial diagram to understand better and troubleshoot easily. provide respective sonic commands to configure respecive interfaces ovs ports etc.

To simulate and configure this setup on a single Ubuntu host, you need to map Open vSwitch (OVS) bridges to the virtualized SONiC switches using Virtual Ethernet (veth) pairs.
Here is the comprehensive guide, architectural layout, and configuration steps for both Arista hardware profiles simulated in SONiC.
## Network Architecture Diagram
```mermaid
==========================================================================================
                               UBUNTU HOST (EMULATION ENVIRONMENT)
==========================================================================================

  [ SCENARIO 1: Arista 7050QX32 Profile ]         [ SCENARIO 2: Arista 7050QX32S Profile ]
  (40G QSFP+ Breakout Emulation)                  (Native 10G SFP+ Lane Emulation)

   +---------------+   +---------------+           +---------------+   +---------------+

   | Virtual Host  |   | Virtual Host  |           | Virtual Host  |   | Virtual Host  |
   |   Server 1    |   |   Server 2    |           |   Server 3    |   |   Server 4    |
   +-------+-------+   +-------+-------+           +-------+-------+   +-------+-------+

           |                   |                           |                   |
    [h101-eth1]         [h102-eth1]                 [h201-eth1]         [h202-eth1]

           |                   |                           |                   |
===========|===================|===========================|===================|==========
           v                   v                           v                   v
   +-------+-------+   +-------+-------+           +-------+-------+   +-------+-------+

   |  br-h101-l1   |   |  br-h102-l1   |           |  br-h201-l2   |   |  br-h202-l2   |  (OVS Bridges)
   +-------+-------+   +-------+-------+           +-------+-------+   +-------+-------+

           |                   |                           |                   |
     [veth-h101]         [veth-h102]                 [veth-h201]         [veth-h202]

           |                   |                           |                   |
     (veth pair)         (veth pair)                 (veth pair)         (veth pair)

           |                   |                           |                   |
     [veth-sw1-p1]       [veth-sw1-p2]               [veth-sw2-p1]       [veth-sw2-p2]
           v                   v                           v                   v
===========|===================|===========================|===================|==========

           |                   |                           |                   |
     [Ethernet0]         [Ethernet1]                 [Ethernet0]         [Ethernet1]
   +-------+-----------+-------+-------+           +-------+-----------+-------+-------+

   |     QSFP+ Channel 1 (40G)         |           |  SFP+ Port 1  |  SFP+ Port 2  |
   | (Split into 4x10G Lanes: 0,1,2,3) |           |   (Native)    |   (Native)    |
   |                                   |           |               |               |
   |       SONiC Switch Instance 1     |           |       SONiC Switch Instance 2     |
   |          (Arista 7050QX32)        |           |         (Arista 7050QX32S)        |
   +-----------------------------------+           +-----------------------------------+
```
------------------------------
## OVS and Host Connectivity Breakdown
Inside your Ubuntu emulation host, the connections are mapped via veth pipes. One end of the pipe plugs into the OVS bridge (representing the server layer), and the other end maps directly to the network interfaces assigned to the SONiC container or virtual machine.

   1. Scenario 1 (7050QX32): Ports Ethernet0 through Ethernet3 inside SONiC represent the breakout lanes of the physical Port 1 (QSFP+). Your configuration maps Server 1 to Lane 0 (Ethernet0) and Server 2 to Lane 1 (Ethernet1).
   2. Scenario 2 (7050QX32S): Ports Ethernet0 and Ethernet1 are native 10G SFP+ cages. No splitting occurs; they connect 1:1 to Server 3 and Server 4 respectively.

------------------------------
## Step 1: Ubuntu Linux Shell Infrastructure Configuration
Run these commands on your Ubuntu host to build the OVS bridges, instantiate the veth pairs, and link them together.
```
# 1. Create the Open vSwitch Bridges
sudo ovs-vsctl add-br br-h101-l1
sudo ovs-vsctl add-br br-h102-l1
sudo ovs-vsctl add-br br-h201-l2
sudo ovs-vsctl add-br br-h202-l2
# 2. Create VETH pairs for Scenario 1 (7050QX32)
sudo ip link add veth-h101 type veth peer name veth-sw1-p1
sudo ip link add veth-h102 type veth peer name veth-sw1-p2
# 3. Create VETH pairs for Scenario 2 (7050QX32S)
sudo ip link add veth-h201 type veth peer name veth-sw2-p1
sudo ip link add veth-h202 type veth peer name veth-sw2-p2
# 4. Attach the Host sides of the VETH pairs to respective OVS Bridges
sudo ovs-vsctl add-port br-h101-l1 veth-h101
sudo ovs-vsctl add-port br-h102-l1 veth-h102
sudo ovs-vsctl add-port br-h201-l2 veth-h201
sudo ovs-vsctl add-port br-h202-l2 veth-h202
# 5. Bring all emulation interfaces UP on the host
sudo ip link set veth-h101 up
sudo ip link set veth-sw1-p1 up
sudo ip link set veth-h102 up
sudo ip link set veth-sw1-p2 up
sudo ip link set veth-h201 up
sudo ip link set veth-sw2-p1 up
sudo ip link set veth-h202 up
sudo ip link set veth-sw2-p2 up
```
Note: The veth-swX-pX ends must be bound to your virtual SONiC instance runtime (e.g., passed as arguments via KVM/QEMU network flags or bound to Docker containers via a container runtime configuration).
------------------------------
## Step 2: SONiC Switch OS Breakout Configurations
SONiC manages physical port mapping via its config_db.json database. Port splitting and breakouts are executed via the CLI or metadata patches.
## Switch 1 Configuration: Arista 7050QX32 (QSFP+ Breakout)
To tell SONiC that the first physical 40G QSFP+ port is being broken down into 4 individual 10G logical lanes (Ethernet0, Ethernet1, Ethernet2, Ethernet3), run the following commands inside the Switch 1 CLI console:

# Break out the 40G Port 1 into 4x10G channels
sudo config interface breakout Ethernet0 "4x10G"
# Verify that the ports changed from a single 40G interface to 4 individual 10G ports
show interface breakout
# Bring the active breakout interfaces up
sudo config interface startup Ethernet0
sudo config interface startup Ethernet1
# Configure IP addressing for Server 1 and Server 2 links
sudo config interface ip add Ethernet0 10.101.1.1/24
sudo config interface ip add Ethernet1 10.102.1.1/24

## Switch 2 Configuration: Arista 7050QX32S (Native SFP+)
Because the 7050QX32S maps internal hardware serializer/deserializer lanes natively to SFP+ cages on ports 1 through 4, no breakout command is run on those interfaces. They are running at native speed. Port 5 remains inactive as requested due to internal lane sharing.
Run the following commands inside the Switch 2 CLI console:

# Ensure interfaces are running in native speed mode (usually defaults to 10G)# No breakout command is executed for Ethernet0 or Ethernet4 here.
# Bring the native SFP+ ports up
sudo config interface startup Ethernet0
sudo config interface startup Ethernet1
# Configure IP addressing for Server 3 and Server 4 links
sudo config interface ip add Ethernet0 10.201.1.1/24
sudo config interface ip add Ethernet1 10.202.1.1/24

------------------------------
## Step 3: Troubleshooting and Verification Flow
To verify data plane path connectivity or isolate configuration errors, use this command breakdown mapping down the interface stack:

   1. Verify OVS State on Ubuntu Host:
   
   sudo ovs-vsctl show
   
   Look for the presence of your interfaces under each bridge and ensure no errors are listed.
   2. Verify Physical Link State inside SONiC:
   
   show interfaces status
   
   For Switch 1, ensure Ethernet0 and Ethernet1 display operational speeds of 10000M (10G) instead of 40000M (40G).
   3. Trace Packets mapping (Host to SONiC):
   If communication fails, check packet counters at the boundary interfaces:
   
   # On Ubuntu Host:
   sudo ip -s link show veth-sw1-p1
   # Inside SONiC:
   show queue counters Ethernet0
   
   
To help optimize this virtual infrastructure, are you deploying these SONiC instances via Docker containers or KVM/QEMU virtual machines, and which SONiC release version are you using?




## For the lab, I am using virsh, qemu, ubuntu, openvswitch etc. How to troubleshoot 'The veth-swX-pX ends must be bound to your virtual SONiC instance runtime (e.g., passed as arguments via KVM/QEMU network flags or bound to Docker containers via a container runtime configuration).' as noted. Let's go for a real example. I intend to automate the process of configuration with this two arista model where the servers are connecting to two models mentioned above. Get the port_config.ini or port_config.json for SONiC and look at their breakout configuration. Create explicit, global and local vars to automate using ansible. design appropriate roles/tasks/jinja templates/playbooks for pre and post validation along with dynamically be able to configure any port breakout as per the var files data driven port breakout architecture.
To bridge your Open vSwitch (OVS) topology to KVM/QEMU managed by virsh, you should avoid direct veth pairing to the VM. Instead, the cleanest way to connect a KVM-based virtual SONiC instance to an OVS bridge is by provisioning a TAP device attached directly to the OVS bridge, which KVM uses as its network backend. [1] 
Here is the complete implementation, directory layout, and data-driven Ansible automation framework to handle both Arista profiles.
------------------------------
## Part 1: Troubleshooting KVM/OVS Binding (The Real Example)
If you pass a random host interface to virsh, it will fail because QEMU needs a file descriptor or a TAP interface it can control.
## The Proper Manual Wiring (virsh XML snippet)
For your virtual SONiC virtual machines, define the interfaces inside your Libvirt domain XML file using the type='bridge' configuration pointing to your OVS bridge:
```
<interface type='bridge'>
  <mac address='52:54:00:a1:b1:c1'/>
  <!-- This connects the VM port directly to your OVS bridge -->
  <source bridge='br-h101-l1'/>
  <virtualport type='openvswitch'/>
  <model type='virtio'/>
</interface>
```
When Libvirt boots this VM, it dynamically creates a TAP interface on the Ubuntu host and hot-plugs it into br-h101-l1. Inside the SONiC VM, this maps sequentially to its first front-panel data port (Ethernet0). [2] 
------------------------------
## Part 2: SONiC HwSKU Port Configurations
SONiC relies on standard hardware profile mappings (port_config.ini). For these Arista profiles, lanes are indexed inside the JSON/INI structure.
## 1. Arista-7050QX32 (40G QSFP+ Breakout Profile)
Physical QSFP+ ports use 4 internal SerDes lanes. Setting a port to 4x10G splits it into four logical interfaces.
port_config.ini representation:

# ports lanes speed
Ethernet0 1,2,3,4 10000
Ethernet1 5,6,7,8 10000
Ethernet2 9,10,11,12 10000
Ethernet3 13,14,15,16 10000

## 2. Arista-7050QX32S (Native SFP+ Profile)
Ports 1 to 4 are dedicated 10G SFP+ slots mapping 1 lane each. Port 5 (the shared QSFP+) is omitted when these are active.
port_config.ini representation:

# ports lanes speed
Ethernet0 1 10000
Ethernet1 2 10000
Ethernet2 3 10000
Ethernet3 4 10000
# Ethernet4 (Port 5) is skipped / unmapped if 1-4 are active

------------------------------
## Part 3: Data-Driven Ansible Automation Design## Directory Structure
```mermaid
sonic-provisioning/
├── group_vars/
│   └── all.yml
├── host_vars/
│   ├── switch1-7050qx32.yml
│   └── switch2-7050qx32s.yml
├── roles/
│   └── sonic_breakout/
│       ├── templates/
│       │   └── config_db.json.j2
│       └── tasks/
│           ├── main.yml
│           ├── pre_check.yml
│           └── post_check.yml
└── deploy_topology.yml
```
## Variable Architecture## Global Variables (group_vars/all.yml)
```yaml
---ansible_user: adminansible_network_os: sonicsonic_config_dir: /etc/sonic

## Switch 1 Context Profile (host_vars/switch1-7050qx32.yml)

---hwsku: "Arista-7050QX32"interfaces:
  - name: "Ethernet0"
    breakout_mode: "4x10G"
    lanes: "1,2,3,4"
    speed: 10000
    ip_address: "10.101.1.1/24"
    enabled: true
  - name: "Ethernet1"
    breakout_mode: "4x10G"
    lanes: "5,6,7,8"
    speed: 10000
    ip_address: "10.102.1.1/24"
    enabled: true

## Switch 2 Context Profile (host_vars/switch2-7050qx32s.yml)

---hwsku: "Arista-7050QX32S"interfaces:
  - name: "Ethernet0"
    breakout_mode: "1x10G"
    lanes: "1"
    speed: 10000
    ip_address: "10.201.1.1/24"
    enabled: true
  - name: "Ethernet1"
    breakout_mode: "1x10G"
    lanes: "2"
    speed: 10000
    ip_address: "10.202.1.1/24"
    enabled: true

------------------------------
## Part 4: Ansible Role Implementation## Pre-Validation Tasks (roles/sonic_breakout/tasks/pre_check.yml)

---
- name: Pre-Check | Verify SONiC connectivity and fetch version details
  sonic_command:
    commands: ["show version"]
  register: sonic_version_output

- name: Pre-Check | Ensure current HWSKU matches variables
  fail:
    msg: "Target hardware platform mismatch! Expected {{ hwsku }}."
  when: hwsku not in sonic_version_output.stdout[0]

- name: Pre-Check | Validate interface state configuration entries
  assert:
    that:
      - item.name is defined
      - item.speed in [10000, 40000]
    fail_msg: "Interface definition contains variable formatting errors."
  loop: "{{ interfaces }}"
```
## Jinja2 Layout Configuration Engine (roles/sonic_breakout/templates/config_db.json.j2)
```
{
    "PORT": {
        {% for intf in interfaces %}
        "{{ intf.name }}": {
            "alias": "{{ intf.name }}",
            "lanes": "{{ intf.lanes }}",
            "speed": "{{ intf.speed }}",
            "admin_status": "{{ 'up' if intf.enabled else 'down' }}"
        }{{ ',' if not loop.last else '' }}
        {% endfor %}
    },
    "INTERFACE": {
        {% for intf in interfaces %}
        {% if intf.ip_address is defined %}
        "{{ intf.name }}|{{ intf.ip_address }}": {},
        {% endif %}
        {% endfor %}
    },
    "BREAKOUT_CFG": {
        {% for intf in interfaces %}
        "{{ intf.name }}": {
            "brkout_mode": "{{ intf.breakout_mode }}"
        }{{ ',' if not loop.last else '' }}
        {% endfor %}
    }
}
```
## Execution Core Tasks (roles/sonic_breakout/tasks/main.yml)
```
---
- include_tasks: pre_check.yml

- name: Core | Deploy customized JSON breakout metadata profile
  template:
    src: config_db.json.j2
    dest: "{{ sonic_config_dir }}/config_db.json"
    backup: yes
  register: json_patch

- name: Core | Hot reload SONiC configuration database if modifications occurred
  sonic_command:
    commands: ["sudo config reload -y"]
  when: json_patch.changed
  async: 60
  poll: 5

- include_tasks: post_check.yml

## Post-Validation Verification Tasks (roles/sonic_breakout/tasks/post_check.yml)

---
- name: Post-Check | Wait for SONiC configuration engine to initialize
  pause:
    seconds: 15

- name: Post-Check | Query execution runtime interface state
  sonic_command:
    commands: ["show interface status"]
  register: interface_status

- name: Post-Check | Confirm breakout states match runtime values
  assert:
    that:
      - "'{{ item.name }}' in interface_status.stdout[0]"
      - "'{{ item.speed }}M' in interface_status.stdout[0]"
    fail_msg: "Interface breakout assertion failed for {{ item.name }}"
  loop: "{{ interfaces }}"

## Execution Playbook Runner (deploy_topology.yml)

---
- name: Execute Automated Hardware Breakout Configuration Engine
  hosts: all
  gather_facts: no
  roles:
    - sonic_breakout
```
------------------------------
Would you like to build an inventory file example to orchestrate these connections, or do you need assistance generating the Ubuntu-side automation scripts to map the virsh OVS bridges dynamically?

[1] [https://oneuptime.com](https://oneuptime.com/blog/post/2026-03-02-how-to-create-virtual-switches-with-ovs-on-ubuntu/view)
[2] [https://containerlab.dev](https://containerlab.dev/manual/kinds/sonic-vm/)


###  Usually the parents port's I usually comes across for SONiC is multiple of 4 logically, meaning Ethernet0, Ethernet4 etc wand after breakout looks like the practice is the index it increases is by 1. Please reflect that in var declaration section to make it obvious before and after breakout.


You are entirely correct. In physical high-density switch architectures, front-panel QSFP+ or QSFP28 cages are hardwired to specific SerDes lane blocks in increments of four.
When a parent port like Ethernet0 (representing the physical cage) is broken out from a single 40G channel into four 10G channels, the configuration engine dynamically instantiates the child interfaces sequentially: Ethernet0, Ethernet1, Ethernet2, and Ethernet3. The next physical parent cage then begins at Ethernet4. [1] 
Here is the revised, highly explicit Ansible variable architecture reflecting this physical-to-logical relationship for both Arista models.
## Step 1: Explicit Variable Architecture## Switch 1 Context: Arista 7050QX32 (QSFP+ Breakout Model)
In this model, every physical cage is a 40G QSFP+ port (spaced by 4). We explicitly define the parent port, its breakout transformation, and the resulting child interfaces that map to your host servers.
```yaml
# host_vars/switch1-7050qx32.yml
---hwsku: "Arista-7050QX32"
# Physical Breakout Map# Parent Cage Port: Ethernet0 (Physical Port 1)#   ↳ Mode 4x10G -> Generates logical child ports: Ethernet0, Ethernet1, Ethernet2, Ethernet3# Parent Cage Port: Ethernet4 (Physical Port 2)#   ↳ Mode 4x10G -> Generates logical child ports: Ethernet4, Ethernet5, Ethernet6, Ethernet7
breakout_topology:
  - parent_port: "Ethernet0"
    breakout_mode: "4x10G"
    child_ports:
      - name: "Ethernet0"        # Sub-lane 0 -> Maps to Server 1
        lanes: "1"
        speed: 10000
        ip_address: "10.101.1.1/24"
        enabled: true
      - name: "Ethernet1"        # Sub-lane 1 -> Maps to Server 2
        lanes: "2"
        speed: 10000
        ip_address: "10.102.1.1/24"
        enabled: true
      - name: "Ethernet2"        # Sub-lane 2 (Unused in lab, but created by breakout)
        lanes: "3"
        speed: 10000
        enabled: false
      - name: "Ethernet3"        # Sub-lane 3 (Unused in lab, but created by breakout)
        lanes: "4"
        speed: 10000
        enabled: false

## Switch 2 Context: Arista 7050QX32S (Native SFP+ + QSFP+ Shared Lanes)
For this hardware profile, the first four physical cages are natively 10G SFP+ slots. Internally, they occupy the exact same SerDes lanes (1,2,3,4) that would normally feed a single 40G QSFP+ port. Because they are individual cages, they are treated as four discrete non-breakout parent ports tracking by 1 natively.

# host_vars/switch2-7050qx32s.yml
---hwsku: "Arista-7050QX32S"
# Physical Layout# SFP+ Cage 1: Ethernet0 (Lane 1) -> Maps to Server 3# SFP+ Cage 2: Ethernet1 (Lane 2) -> Maps to Server 4# SFP+ Cage 3: Ethernet2 (Lane 3) -> Unused# SFP+ Cage 4: Ethernet3 (Lane 4) -> Unused# QSFP+ Cage 5: Ethernet4 (Lanes 5,6,7,8) -> Disabled internally because SFP+ lanes are active
breakout_topology:
  - parent_port: "Ethernet0"
    breakout_mode: "1x10G"      # Native SFP+ mode, no division
    child_ports:
      - name: "Ethernet0"
        lanes: "1"
        speed: 10000
        ip_address: "10.201.1.1/24"
        enabled: true

  - parent_port: "Ethernet1"
    breakout_mode: "1x10G"
    child_ports:
      - name: "Ethernet1"
        lanes: "2"
        speed: 10000
        ip_address: "10.202.1.1/24"
        enabled: true

  - parent_port: "Ethernet2"
    breakout_mode: "1x10G"
    child_ports:
      - name: "Ethernet2"
        lanes: "3"
        speed: 10000
        enabled: false

  - parent_port: "Ethernet3"
    breakout_mode: "1x10G"
    child_ports:
      - name: "Ethernet3"
        lanes: "4"
        speed: 10000
        enabled: false
```
------------------------------
## Step 2: Updated Jinja2 Template (config_db.json.j2)
Since our variable structure nested the generated child ports inside their parent hardware definitions, we adapt the template loop engine to unroll them correctly into the SONiC database format.
```
{
    "PORT": {
        {% set port_list = [] %}
        {% for breakout in breakout_topology %}
            {% for child in breakout.child_ports %}
                {% do port_list.append(child) %}
            {% endfor %}
        {% endfor %}
        {% for port in port_list %}
        "{{ port.name }}": {
            "alias": "{{ port.name }}",
            "lanes": "{{ port.lanes }}",
            "speed": "{{ port.speed }}",
            "admin_status": "{{ 'up' if port.enabled else 'down' }}"
        }{{ ',' if not loop.last else '' }}
        {% endfor %}
    },
    "INTERFACE": {
        {% set intf_list = [] %}
        {% for breakout in breakout_topology %}
            {% for child in breakout.child_ports %}
                {% if child.ip_address is defined %}
                    {% do intf_list.append(child) %}
                {% endif %}
            {% endfor %}
        {% endfor %}
        {% for intf in intf_list %}
        "{{ intf.name }}|{{ intf.ip_address }}": {}{{ ',' if not loop.last else '' }}
        {% endfor %}
    },
    "BREAKOUT_CFG": {
        {% for breakout in breakout_topology %}
        "{{ breakout.parent_port }}": {
            "brkout_mode": "{{ breakout.breakout_mode }}"
        }{{ ',' if not loop.last else '' }}
        {% endfor %}
    }
}
```
------------------------------
## Step 3: Updated Post-Validation Task (tasks/post_check.yml)
The pre and post-validation loops now smoothly flatten the child port hierarchies to assert runtime values on the switch.
```
---
- name: Post-Check | Wait for SONiC database synchronization
  pause:
    seconds: 15

- name: Post-Check | Query actual SONiC operational interface state
  sonic_command:
    commands: ["show interface status"]
  register: interface_status

- name: Post-Check | Enforce breakout child port state alignment
  assert:
    that:
      - "'{{ item.name }}' in interface_status.stdout"
      - "'{{ item.speed }}M' in interface_status.stdout"
    fail_msg: "Validation error: Child port {{ item.name }} failed breakout verification."
  loop: "{{ breakout_topology | map(attribute='child_ports') | flatten }}"
  when: item.enabled
```
If you plan to scale this out to more switches, would you like me to show you how to use Ansible to auto-generate the virsh XML interface blocks matching these specific parent/child configurations on your Ubuntu host?

[1] [https://www.micasnetworks.com](https://www.micasnetworks.com/support/help-center/open-network-switches/query-reference/port-numbering-in-sonic)

### Yes, I do.

To automate the binding between your host Open vSwitch (OVS) bridges and the KVM/virsh virtual machines, we can use Ansible to manipulate the Libvirt XML configuration.
Instead of dealing with unreliable raw veth scripts, this approach uses the standard OVS Libvirt integration. When you define an interface as an openvswitch virtual port, Libvirt automatically manages creating the internal TAP interface and plugging it into the OVS bridge whenever the VM boots.
Here is the automation structure, including variable definitions, Jinja2 XML templates, and playbooks to dynamically configure your host networking.
------------------------------
## Step 1: Variable Definitions for Host Automation
Add host-specific layout properties to your inventory variable tracking files. This bridges the physical/logical breakout definitions to actual host-side components.
## Switch 1 Host Settings (host_vars/switch1-7050qx32.yml)
```
---# Append this to your existing switch1 filevm_name: "sonic-sw1-7050qx32"
# Maps physical/logical child ports inside SONiC to target bridges on the hosthost_network_mapping:
  - switch_port: "Ethernet0"
    ovs_bridge: "br-h101-l1"
    mac_address: "52:54:00:a1:b1:10"
  - switch_port: "Ethernet1"
    ovs_bridge: "br-h102-l1"
    mac_address: "52:54:00:a1:b1:20"

## Switch 2 Host Settings (host_vars/switch2-7050qx32s.yml)

---# Append this to your existing switch2 filevm_name: "sonic-sw2-7050qx32s"
host_network_mapping:
  - switch_port: "Ethernet0"
    ovs_bridge: "br-h201-l2"
    mac_address: "52:54:00:a2:b2:10"
  - switch_port: "Ethernet1"
    ovs_bridge: "br-h202-l2"
    mac_address: "52:54:00:a2:b2:20"
```
------------------------------
## Step 2: Libvirt XML Interface Interface Jinja2 Template
We will create a Jinja2 snippet that generates standard Libvirt domain interface elements for OVS connectivity. Save this as roles/kvm_ovs_provision/templates/ovs_interfaces.xml.j2.
```
<!-- Interfaces managed dynamically via Ansible for {{ vm_name }} -->
{% for mapping in host_network_mapping %}
<interface type='bridge'>
  <mac address='{{ mapping.mac_address }}'/>
  <source bridge='{{ mapping.ovs_bridge }}'/>
  <virtualport type='openvswitch'/>
  <model type='virtio'/>
  <!-- Mapping reference for troubleshooting: Virtual SONiC interface {{ mapping.switch_port }} -->
</interface>
{% endfor %}
```
------------------------------
## Step 3: Ansible Tasks for Dynamic Host Provisioning
Create a new role roles/kvm_ovs_provision on your Ubuntu infrastructure host. These tasks will query your existing virtual switch state, inject the XML components dynamically, and restart the VM cleanly.
## Production Tasks File (roles/kvm_ovs_provision/tasks/main.yml)
```
---
- name: KVM/OVS | Ensure target Open vSwitch bridges are active on Host
  openvswitch.openvswitch.openvswitch_bridge:
    name: "{{ item.ovs_bridge }}"
    state: present
  loop: "{{ host_network_mapping }}"
  delegate_to: localhost

- name: KVM/OVS | Generate isolated temporary interface configuration fragment
  template:
    src: ovs_interfaces.xml.j2
    dest: "/tmp/{{ vm_name }}_interfaces.xml"
  delegate_to: localhost

- name: KVM/OVS | Query existing Libvirt configuration from virsh
  community.libvirt.virt:
    name: "{{ vm_name }}"
    command: get_xml
  register: current_vm_xml
  delegate_to: localhost

- name: KVM/OVS | Hot-attach network interfaces if VM is running (Idempotent)
  shell: |
    # Attach dynamically if the interface MAC is missing from the running instance configuration
    if ! virsh domxml-to-native qemu --domain {{ vm_name }} 2>/dev/null | grep -q "{{ item.mac_address }}"; then
      virsh attach-device {{ vm_name }} /tmp/{{ vm_name }}_interfaces.xml --config --live
    fi  loop: "{{ host_network_mapping }}"
  delegate_to: localhost
  register: attach_result
  changed_when: "'Device attached successfully' in attach_result.stdout"

- name: KVM/OVS | Clean up temporary workspace artifacts
  file:
    path: "/tmp/{{ vm_name }}_interfaces.xml"
    state: absent
  delegate_to: localhost

------------------------------
## Step 4: Verification and Troubleshooting Script
To ensure everything tied together seamlessly without configuration collision across layers, run this verification task to check the operational runtime environment on your host:
## Post-Check Task Bundle (roles/kvm_ovs_provision/tasks/verify.yml)

---
- name: Verify | Inspect active OVS state directly from host
  command: ovs-vsctl show
  register: ovs_host_state
  delegate_to: localhost

- name: Verify | Confirm KVM virtual TAP instances are assigned to bridges
  assert:
    that:
      - "'{{ item.ovs_bridge }}' in ovs_host_state.stdout"
    fail_msg: "OVS runtime error: Bridge {{ item.ovs_bridge }} is not configured or missing from the host environment."
  loop: "{{ host_network_mapping }}"

- name: Verify | Output operational mappings for infrastructure tracking
  debug:
    msg: "SUCCESS: VM {{ vm_name }} Port {{ item.switch_port }} tied directly to Host OVS Bridge {{ item.ovs_bridge }} via MAC {{ item.mac_address }}."
  loop: "{{ host_network_mapping }}"

------------------------------
## How to Run the Unified Lab Automation Playbook
Combine both your SONiC Breakout Configuration Layer and your KVM Host Network Automation Layer into one main execution playbook.

# deploy_lab_infrastructure.yml
---
- name: Phase 1 - Orchestrate Ubuntu Host Physical Network Layer
  hosts: localhost
  gather_facts: no
  tasks:
    - name: Run KVM Host Network Provisioning Loop
      include_role:
        name: kvm_ovs_provision
      vars:
        # Dynamically loop across all your virtual switch variable scopes
        vm_name: "{{ hostvars[item]['vm_name'] }}"
        host_network_mapping: "{{ hostvars[item]['host_network_mapping'] }}"
      loop: "{{ groups['all'] }}"
      when: hostvars[item]['host_network_mapping'] is defined

- name: Phase 2 - Configure Data-Driven SONiC Breakout OS Engines
  hosts: all
  gather_facts: no
  roles:
    - sonic_breakout
```
If you would like to test the validation layer, I can show you how to write automated end-to-end ping validation tasks inside the servers to verify traffic flows clean through your OVS-to-SONiC pipeline. Would you like to add that?

### Since Arista has for our example models 32 & 36  physical ports. And we are towards the beginning just wiring few devices. What will happen to the rest of the SONiC interfaces for running the switch successfully. How to Handle them in the virsh xml provided above? How to virsh start the instance through ansible as well, so, we see respective vms are configured and communicating?

When simulating high-density switches like the Arista 7050QX32 (32 physical ports) in a virtualized lab environment, handling unconfigured interfaces is a critical design choice.
## How to Handle Unused Ports in virsh and SONiC
If you do not map all 32 ports in your Libvirt XML, SONiC will still boot successfully. SONiC relies on its internal hardware profile mapping (port_config.ini). If QEMU only presents 4 network interfaces to the VM, SONiC will see Ethernet0 through Ethernet3 as active hardware, while Ethernet4 through Ethernet124 will simply remain in a permanent Down or No-Asic state.
However, to ensure your automation scales cleanly when you add more devices later, the best practice is to dynamically map only the active ports to your specific OVS lab bridges, and loop-back or stub the remaining unused ports so the VM matches the exact layout of the physical switch without cluttering your host's networking.
------------------------------
## Step 1: Upgraded, Production-Ready Host Variables
We introduce a loop to generate stub interfaces for unassigned ports up to the hardware maximum (32 physical ports).
```
# host_vars/switch1-7050qx32.yml
---hwsku: "Arista-7050QX32"vm_name: "sonic-sw1-7050qx32"total_physical_ports: 32
# Active lab mappingshost_network_mapping:
  - switch_port: "Ethernet0"
    ovs_bridge: "br-h101-l1"
    mac_address: "52:54:00:a1:b1:10"
  - switch_port: "Ethernet1"
    ovs_bridge: "br-h102-l1"
    mac_address: "52:54:00:a1:b1:20"
```
------------------------------
## Step 2: Dynamic virsh XML Jinja2 Template
This template creates specific OVS bindings for your active lab ports. For all remaining ports up to the device maximum, it dynamically maps them to a generic host dummy bridge (br-stub) so that QEMU satisfies the switch's interface count.
Save this to roles/kvm_ovs_provision/templates/ovs_interfaces.xml.j2:
```
<!-- Active Lab Interface Mappings -->
{% for mapping in host_network_mapping %}
<interface type='bridge'>
  <mac address='{{ mapping.mac_address }}'/>
  <source bridge='{{ mapping.ovs_bridge }}'/>
  <virtualport type='openvswitch'/>
  <model type='virtio'/>
  <!-- Mapping: SONiC {{ mapping.switch_port }} -> Host {{ mapping.ovs_bridge }} -->
</interface>
{% endfor %}
<!-- Automated Stub Mappings for Remaining Switch Capacity -->
{% set active_count = host_network_mapping | length %}
{% set remaining_ports = total_physical_ports - active_count %}
{% for i in range(remaining_ports) %}
<interface type='bridge'>
  <!-- Generate unique MAC addresses to prevent collisions -->
  <mac address='52:54:00:ff:b1:{{ "%02x" | format(i) }}'/>
  <source bridge='br-stub'/>
  <virtualport type='openvswitch'/>
  <model type='virtio'/>
</interface>
{% endfor %}
```
------------------------------
## Step 3: Complete Automation Tasks (roles/kvm_ovs_provision/tasks/main.yml)
This comprehensive tasks file ensures the br-stub bridge exists, updates the VM interface layout, defines/starts the instance, and waits for it to become responsive.
```
---
- name: KVM/OVS | Ensure common stub bridge exists for unmapped ports
  openvswitch.openvswitch.openvswitch_bridge:
    name: "br-stub"
    state: present
  delegate_to: localhost

- name: KVM/OVS | Ensure active laboratory OVS bridges are present
  openvswitch.openvswitch.openvswitch_bridge:
    name: "{{ item.ovs_bridge }}"
    state: present
  loop: "{{ host_network_mapping }}"
  delegate_to: localhost

- name: KVM/OVS | Compile full network interface XML template fragment
  template:
    src: ovs_interfaces.xml.j2
    dest: "/tmp/{{ vm_name }}_interfaces.xml"
  delegate_to: localhost

- name: KVM/OVS | Update Libvirt domain definition configuration file
  shell: |
    # Clean out old dynamic interface blocks and inject the updated array
    virsh dumpxml {{ vm_name }} > /tmp/{{ vm_name }}_current.xml
    sed -i '/<interface type=.bridge.>/,/<\/interface>/d' /tmp/{{ vm_name }}_current.xml
    sed -i '/<\/devices>/e cat /tmp/{{ vm_name }}_interfaces.xml' /tmp/{{ vm_name }}_current.xml
    virsh define /tmp/{{ vm_name }}_current.xml  delegate_to: localhost
  register: xml_define_result
  changed_when: true

- name: KVM/OVS | Boot the SONiC virtual instance lifecycle
  community.libvirt.virt:
    name: "{{ vm_name }}"
    state: running
  delegate_to: localhost
  register: vm_start_state

- name: KVM/OVS | Clean workspace temporary file markers
  file:
    path: "{{ item }}"
    state: absent
  loop:
    - "/tmp/{{ vm_name }}_interfaces.xml"
    - "/tmp/{{ vm_name }}_current.xml"
  delegate_to: localhost

- name: Validation | Wait for SONiC Management Plane to become responsive
  wait_for:
    host: "{{ ansible_host }}"
    port: 22
    delay: 10
    timeout: 300
    state: started
  delegate_to: localhost

------------------------------
## Step 4: Post-Boot Verification Playbook
Add this verification playbook to confirm your layout is alive and components are communicating through the layers.

# verify_communication.yml
---
- name: Post-Boot Verification Layer
  hosts: all
  gather_facts: no
  tasks:
    - name: Verification | Check interface layout inside SONiC OS
      sonic_command:
        commands: ["show interface status"]
      register: sonic_status

    - name: Verification | Confirm broken out child ports are Up
      assert:
        that:
          - "'Ethernet0' in sonic_status.stdout"
          - "'Ethernet1' in sonic_status.stdout"
        fail_msg: "SONiC data plane ports failed to initialize after VM boot."

    - name: Verification | Test data path ping to host-side server IPs
      sonic_command:
        commands:
          - "ping -c 3 10.101.1.100" # Assuming Server 1 IP on br-h101-l1
          - "ping -c 3 10.102.1.100" # Assuming Server 2 IP on br-h102-l1
      register: ping_results
      ignore_errors: yes
      when: hwsku == "Arista-7050QX32"

    - name: Diagnostics | Display runtime connection results
      debug:
        var: ping_results.stdout_lines
      when: ping_results.stdout_lines is defined
```
If you plan to scale this simulation, would you like me to show you how to generate the Ansible inventory group structures to seamlessly separate your host execution commands from your inner switch operating system configurations?


### yes, I do. Also need a pathway to automate the configuration on real hardware following the same switch model/server wiring in place.


## Part 1: Ansible Inventory Architecture (Lab vs. Real Hardware)
To seamlessly control both your Ubuntu KVM hypervisor host and the SONiC operating systems running inside the switches, you must use a dual-layer inventory. This allows you to run host preparation tasks (like provisioning OVS bridges) on the Ubuntu machine while sending NOS configurations (like breakouts and IP addresses) straight to the switches.
We also design this to accommodate a Real Hardware transition path by grouping switches under a shared platform type but assigning different connection variables (SSH vs. Console/Management network).
## Comprehensive Inventory File (inventory.ini)

[hypervisors]
ubuntu-kvm-host ansible_host=192.168.1.50 ansible_connection=ssh ansible_user=labadmin

[virtual_switches]
sonic-sw1-7050qx32  ansible_host=192.168.1.101
sonic-sw2-7050qx32s ansible_host=192.168.1.102

[physical_switches]
arista-prod-01      ansible_host=10.10.10.11
arista-prod-02      ansible_host=10.10.10.12

# Umbrella groups to inherit configurations cleanly
[sonic_nodes:children]
virtual_switches
physical_switches
```
## Shared SONiC Configurations (group_vars/sonic_nodes.yml)

---ansible_user: adminansible_ssh_pass: YourSecureSonicPasswordansible_network_os: sonicsonic_config_dir: /etc/sonic

## Virtual vs. Physical Connection Handling

# group_vars/virtual_switches.yml
---# Instructs Ansible that these are emulated inside our target KVM hostis_virtual: truetarget_hypervisor: "ubuntu-kvm-host"

# group_vars/physical_switches.yml
---# Real switches use direct out-of-band management hardware networksis_virtual: false# Real hardware might require specialized AAA tokens or individual secretsansible_ssh_common_args: '-o StrictHostKeyChecking=no'

------------------------------
## Part 2: Unified Execution Playbook
This unified architecture allows you to change a single group pattern to swap your pipeline flawlessly between lab verification and data-center production deployments.

# site.yml
---
- name: Step 1 - Provision Emulated Host Infrastructure (Lab Only)
  hosts: hypervisors
  gather_facts: no
  tasks:
    - name: Dynamically invoke KVM/OVS wiring for virtual instances
      include_role:
        name: kvm_ovs_provision
      vars:
        # Loop through all switches marked as virtual and execute on the hypervisor host
        vm_name: "{{ hostvars[item]['vm_name'] }}"
        host_network_mapping: "{{ hostvars[item]['host_network_mapping'] }}"
        total_physical_ports: "{{ hostvars[item]['total_physical_ports'] | default(32) }}"
      loop: "{{ groups['virtual_switches'] }}"
      when: hostvars[item]['is_virtual'] | default(false)

- name: Step 2 - Deploy Network Configuration (Lab & Production Hardware)
  hosts: sonic_nodes
  gather_facts: no
  roles:
    - sonic_breakout
```
------------------------------
## Part 3: The Pathway to Real Hardware Deployment
Moving from KVM to physical Arista bare metal requires adapting how data layers talk to the switch fabric, without changing your data-driven Ansible code architecture.
```
  [ VIRTUAL ENV (KVM) ]                      [ REAL HARDWARE (Bare Metal) ]
   Ansible Code Engine                        Ansible Code Engine (UNTOUCHED)
           │                                                │
           ▼                                                ▼
┌──────────────────────┐                    ┌──────────────────────────────┐
│  virsh / QEMU vNIC   │                    │  Physical QSFP+ Cage         │
│  (VirtIO Emulation)  │                    │  (Broadcom / Mellanox ASIC)  │
└──────────┬───────────┘                    └──────────────┬───────────────┘
           │                                                │
           ▼                                                ▼
  port_config.ini / json                      port_config.ini / json
  (Maps veth/TAP lanes)                       (Maps Hardware SerDes lanes)
```
To take your playbook live on real Arista hardware running SONiC, implement this operational framework:
## 1. Decouple Virtual Port Stubs
Real hardware handles its unconfigured ports automatically via the underlying physical ASIC driver (such as Broadcom or Mellanox).

* When running against production switches, the kvm_ovs_provision phase is completely bypassed by the playbook's when: hostvars[item]['is_virtual'] conditional statement.

## 2. Align Physical SerDes Lanes
On an actual Arista 7050QX32, the lanes value in your host variable files must exactly align with the platform's hardware manual specification (the internal SerDes channels assigned to the physical cage pins).

* Your template config_db.json.j2 remains identical; you only change the host variables to reflect real physical properties if they vary from the QEMU mapping.

## 3. Real Hardware Post-Validation Check
On production gear, looking for a port status change isn't enough; you must verify transceiver electronics signaling. Update your validation tasks to include layer-1 hardware assertions.
Add this task block inside roles/sonic_breakout/tasks/post_check.yml:
```
- name: Production | Assert L1 Transceiver diagnostic levels (Physical Only)
  sonic_command:
    commands: ["show interface transceiver presence"]
  register: xcvir_status
  when: not is_virtual

- name: Production | Enforce that broken out cages recognize physical media
  assert:
    that:
      - "'Present' in xcvir_status.stdout"
    fail_msg: "Hardware Warning: Transceiver or breakout cable not detected in production cage."
  loop: "{{ breakout_topology }}"
  when: 
    - not is_virtual
    - item.child_ports | selectattr('enabled', 'equalto', true) | list | length > 0

## 4. Safe Production Deployment Strategy
When deploying to physical production hardware, running a sudden config reload can cause infrastructure traffic loss. Optimize your production task flow by adding a confirmation safety valve:

- name: Production | Safety-valve before applying hardware breakout changes
  pause:
    prompt: "WARNING: You are modifying real hardware configurations on {{ inventory_hostname }}. Type 'DEPLOY' to push changes."
  register: production_confirmation
  when: not is_virtual

- name: Production | Force exit if deployment not explicitly confirmed
  fail:
    msg: "Deployment aborted by user request."
  when: 
    - not is_virtual
    - production_confirmation.user_input != "DEPLOY"
```
To help finalize your automation pipeline, do your production switches rely on a centralized ZTP (Zero Touch Provisioning) server for their base image bootstrap, or will you be configuring the initial management IP addresses manually over a console connection?

### No ZTP at this point. exploring the options on real hardware.


When transitioning to real hardware without Zero Touch Provisioning (ZTP), your primary challenge is bootstrapping the initial Out-of-Band (OOB) Management IP address and enabling SSH. Once that initial link is established, your existing data-driven Ansible automation framework can take over completely.
Below are the industry-standard options for initializing SONiC on real Arista hardware, along with an automated strategy to handle the initial deployment.
------------------------------
## Option 1: On-Box Initialization via ONIE (Best Practice)
When you purchase or install SONiC on bare-metal hardware, it boots into ONIE (Open Network Install Environment) before the OS is active. Even without a ZTP server, ONIE provides a minimal, interactive shell accessible via the physical serial console port.

   1. Connect your laptop to the Arista switch's RJ45 console port using an RS-232/USB adapter (baud rate 9600 or 115200).
   2. Boot the switch into ONIE Rescue Mode or ONIE Embed Mode.
   3. Use a regular USB flash drive formatted to FAT32 containing your SONiC binary image (sonic-arista.bin).
   4. Mount the drive on-box and execute the local install command manually:
   
   onie-nos-install /mnt/usb/sonic-arista.bin
   
   
This installs the base operational image directly onto the switch flash storage.
------------------------------
## Option 2: Post-Boot Console Manual Baseline
Once SONiC is installed via ONIE and reboots, it spins up with a factory-default configuration database. Because there is no management IP, network ports are inactive. You must log in via the serial console using the default credentials (admin / YourDefaultPassword) to paste the minimal bootstrap commands: [1] 

# Set up the physical management port (Eth0 is typically the dedicated OOB port)
sudo config interface ip add Management0 10.10.10.11/24 10.10.10.1
# Enable SSH access for automation
sudo config ssh server enable
# Save configuration to the active database
sudo config save -y

------------------------------
## Phase 3: Transitioning Your Ansible Playbook (The Bootstrapping Automation)
To completely eliminate repetitive manual tasks after that initial login, you can create a Bootstrap Playbook. This playbook temporarily connects to the switch via local serial terminal servers (like an open-gear console box) or a temporary laptop connection, configures it, and instantly hands it off to your main inventory fabric.
## Modified Inventory Layer for Real Hardware Initialization

[new_hardware]
# Real switches waiting for initial out-of-band management configuration
arista-prod-01 ansible_host=10.10.10.11
arista-prod-02 ansible_host=10.10.10.12

[production_switches:children]
new_hardware

## The Automated Onboarding Tasks (roles/sonic_bootstrap/tasks/main.yml)
You can use Ansible's raw connectivity layer or generic transport mechanisms to push the initial baseline JSON block before applying breakout configurations.
```
---
- name: Bootstrap | Check if Management plane is accessible via standard SSH
  wait_for:
    host: "{{ ansible_host }}"
    port: 22
    timeout: 5
  register: ssh_test
  ignore_errors: yes
  delegate_to: localhost

- name: Bootstrap | Notify operator if manual terminal intervention is required
  fail:
    msg: "Switch {{ inventory_hostname }} is unreachable at {{ ansible_host }}. Please ensure the management port is cabled or IP is manually configured."
  when: ssh_test.failed

- name: Bootstrap | Synchronize physical system time for secure AAA authentication
  sonic_command:
    commands: ["sudo timedatectl set-ntp true"]
  when: not ssh_test.failed

- name: Bootstrap | Lock down standard admin administrative password
  sonic_command:
    commands: ["echo 'admin:YourNewSecureProductionPassword' | sudo chpasswd"]
  no_log: true

------------------------------
```
## Summary Checklist to Go Live on Hardware

| Step | Action | Tool | Notes |
|---|---|---|---|
| 1 | Flash Base OS | ONIE + USB Drive | Done once per physical switch chassis. |
| 2 | OOB IP Baseline | Serial Console | Apply OOB Management IP and Enable SSH. |
| 3 | Run Bootstrap | Ansible (new_hardware) | Pushes security policies, NTP, and logins. |
| 4 | Run Fabric Config | Ansible (sonic_breakout) | Your exact lab playbook executes breakouts, interfaces, and routing data-driven layers natively on the ASIC. |

This strategy ensures that your automation logic remains identical between your Ubuntu/KVM lab simulation and real production hardware. The only difference is the physical medium transport layer.
If you are using terminal servers in your rack, would you like to see how to configure Ansible's proxy command options to connect straight to the switch console ports through an SSH jump host?

[1] [https://github.com](https://github.com/sonic-net/SONiC/blob/master/doc/ztp/ztp.md)




#### For simulating a complete production level Routed to Host Leaf Spine CLOS 3 fabric, which option will have less network complexity for complete setup, creating all the vms through virsh by a script deploy/ubuntu/sonic vms and then apply port/interface configuration or the approach provided above, where virsh vm's configuration xml created from virsh bridge designed and later start vms?

For simulating a production-level, 3-stage Clos fabric (Leaf-Spine Routed-to-Host) in a lab environment, the approach provided above—generating complete, declarative Libvirt XML files and then launching the VMs—is significantly less complex, less error-prone, and much closer to a real-world pipeline.
Here is a analytical breakdown of why the declarative XML approach minimizes network complexity compared to a dynamic scripting approach, along with how it directly benefits a 3-stage Clos architecture.
------------------------------
## The Two Approaches Compared## 1. The Dynamic Scripted Approach (High Complexity)
In this method, you boot generic "blank" virtual machines first, and then use a host bash/python script or hot-plug commands (virsh attach-interface) to dynamically map OVS bridges and virtual Ethernet pairs while the system is initializing or running.

* Why it adds complexity: Linux reorders network interfaces based on the timing of when PCI slots are discovered or attached. If you attach 32 interfaces dynamically, your virtual SONiC instance might map physical port 1 to Ethernet4 and physical port 5 to Ethernet0. This completely breaks data-driven configuration automation.
* Troubleshooting nightmare: You have to constantly track temporary TAP index numbers on the Ubuntu host to find out which VM interface links to which OVS bridge.

## 2. The Declarative XML Approach (Low Complexity)
In this method, your Ansible playbook defines the entire hardware topology upfront into a static Libvirt XML configuration template, maps all active and stub ports sequentially, and then runs a single virsh start.

* Why it reduces complexity: QEMU presents the entire network bus to the SONiC guest operating system at exact boot time. PCI slots are fixed (0x03, 0x04, 0x05, etc.), meaning the physical cabling index directly and perfectly matches SONiC's EthernetX mapping every single boot.
* Idempotency: If a VM crashes or reboots, its network layout remains structurally identical.

------------------------------
## Why the Declarative XML Approach Wins for a Routed-to-Host Clos Fabric
A 3-stage Routed-to-Host Clos fabric demands precise structural mapping across three distinct layers. Managing this via dynamic scripting becomes unmaintainable quickly, whereas declarative data modeling keeps it clean:
```
  [Spine Layer]      Spine-1  <=== (Fabric Links) ===>  Spine-2
                        ▲                                  ▲
                        └───┐                          ┌───┘
                            ▼                          ▼
  [Leaf Layer]            Leaf-1                     Leaf-2
                            ▲                          ▲
                        ┌───┴───┐                  ┌───┴───┐
                        ▼       ▼                  ▼       ▼
  [Host Layer]       Server-1 Server-2          Server-3 Server-4
                    (Routed Links directly to Server Operating Systems)
```
## 1. Perfect Fabric Link Alignment (Leaf to Spine)
In a Clos network, predictable link grouping is vital for ECMP (Equal-Cost Multi-Path) routing.
Using the declarative XML approach, your host_vars completely map the topology. For example, Leaf-1's port Ethernet28 will always plug into Spine-1's port Ethernet0 via a dedicated OVS bridge (br-l1-s1), eliminating any tracking guesswork.
## 2. Seamless "Routed-to-Host" (BGP-to-the-Host) Emulation
Because you are routing all the way to the server, the virtual host servers (Ubuntu VMs) also need structured network configurations. By creating the XML files upfront, you can configure your server VMs to run FRRouting (FRR) or standard BGP daemons, aligning their interfaces perfectly with the Leaf switch child breakout ports.
## 3. Data-Driven Port Densities (The Stub Port Solution)
As established earlier, an Arista switch expects 32 or 36 ports. The declarative template fills the gaps up to the hardware profile maximum using br-stub. This allows SONiC to initialize its routing protocols (like BGP) across the active ports while gracefully ignoring the rest, perfectly mirroring a true production data center deployment.
------------------------------
## Recommended Pipeline Execution Workflow
To keep complexity at a minimum, organize your deployment pipeline into three distinct, decoupled phases using the automation architecture we built:

   1. Phase 1 (The Blueprint): Execute the host playbook to render the virsh XML definitions containing all exact active lab OVS bridges and loopback stub ports.
   2. Phase 2 (The Fabric Ignite): Run virsh start against all nodes (Spines, Leafs, and Host Servers). QEMU handles the virtual cabling instantaneously.
   3. Phase 3 (The Configuration Engine): Run your data-driven SONiC breakout and routing playbook to push IP addresses and BGP parameters down the known, stable interface index.

If you are mapping out the routing protocols for this Clos setup, would you like to see how to extend your existing Ansible variable architecture to automatically generate the BGP Peering and Autonomous System Number (ASN) configurations for the Leaf and Spine layers?

### Attaching my complete wiring. Analyze deeply. Understand interface wiring for different switch and device models and get information from internet on SONiC and ubuntu configuration. The provide a complete Ansible var files with relevant models and group / host var details with proper interface wiring setup through ansible.


To construct a production-ready, data-driven automation framework for this complex multi-vendor L3 Clos architecture (pp. 1-2), we must abstract the underlying hardware idiosyncrasies (such as the 40G QSFP+ breakouts (p. 2) versus standard SFP+ lanes (p. 2)) into clean, unified Ansible host variable models.Below is the production-grade blueprint, inventory scheme, and host/group variable design implementing the exact wiring topology requested (p. 1).Software Stack Requirements (Deployer Machine)To run these playbooks successfully, your Deployer Machine (p. 1) requires the following software layer:Ubuntu Linux 24.04 LTS / 22.04 LTS as the baseline OS.Ansible Core (>= 2.15) to orchestrate both Linux endpoints and network switches (p. 1).Ansible Collections:sonic.sonic_os (To push configuration to Celestica, Edge-Core, and Arista SONiC switches) (p. 2).community.libvirt & openvswitch.openvswitch (For hypervisor/simulation control if running via the KVM/OVS approach).ansible.netcommon & community.network (For core network tasks).Python Libraries: netaddr (for subnet parsing), jmespath (for complex variable filtering).FRRouting (FRR) & Netplan tools (built-in targeted dependencies for host server configurations) (p. 1).Directory Architecture Blueprinttextdeployer-fabric-root/
```
├── inventory.ini
├── vault.yml
├── group_vars/
│   ├── all.yml
│   ├── spines.yml
│   ├── leafs.yml
│   ├── border_leafs.yml
│   └── compute_nodes.yml
├── host_vars/
│   ├── Spine_S1.yml
│   ├── Spine_S2.yml
│   ├── Leaf_L1.yml
│   ├── Leaf_L3.yml
│   ├── Border-Leaf1.yml
│   └── Host12_1.yml
├── roles/
│   ├── fabric_breakout/
│   ├── fabric_routing/
│   └── host_networking/
└── site_deploy.yml
```
Use code with caution.Part 1: Ansible Inventory (inventory.ini)This structured inventory groups devices cleanly by their operational tier in the Clos topology (p. 1), separating switches by hardware capability to handle distinct profile templates.ini[spines]
```
Spine_S1 ansible_host=172.16.2.46 hw_model="Celestica-DX010"
Spine_S2 ansible_host=172.16.2.45 hw_model="Celestica-DX010"

[leafs_accton]
Leaf_L1 ansible_host=172.16.2.44 hw_model="Accton-AS5712-54X"
Leaf_L2 ansible_host=172.16.2.43 hw_model="Accton-AS5712-54X"

[leafs_arista_qx]
Leaf_L3 ansible_host=172.16.2.42 hw_model="Arista-7050QX-32"
Leaf_L4 ansible_host=172.16.2.41 hw_model="Arista-7050QX-32"

[border_leafs]
Border-Leaf1 ansible_host=172.16.2.40 hw_model="Arista-7050QX-32S"
Border-Leaf2 ansible_host=172.16.2.39 hw_model="Arista-7050QX-32S"

[leafs:children]
leafs_accton
leafs_arista_qx

[fabric_switches:children]
spines
leafs
border_leafs

[compute_nodes]
Host12_1 ansible_host=192.168.255.10
Host12_2 ansible_host=192.168.255.11
Host12_3 ansible_host=192.168.255.12
Host34_1 ansible_host=192.168.255.13
Host34_2 ansible_host=192.168.255.14
HostB12_1 ansible_host=192.168.255.15
HostB12_2 ansible_host=192.168.255.16
MonitorSrv ansible_host=192.168.255.17
```
Use code with caution.Part 2: Fabric Switch Variable InfrastructureGlobal Group Configuration (group_vars/fabric_switches.yml)yaml
```yaml
---
ansible_user: admin
ansible_network_os: sonic
sonic_config_dir: /etc/sonic
fabric_mgmt_subnet: "172.16.2.0/16"
Use code with caution.Spine Configuration Template Context (host_vars/Spine_S1.yml)yaml---
bgp_asn: 65000
loopback_ip: "10.0.0.1/32"

# Fabric Uplinks/Downlinks Map
fabric_ports:
  - name: "Ethernet0" # Connects to Leaf_L1 Eth68
    ip_address: "10.254.1.1/30"
  - name: "Ethernet4" # Connects to Leaf_L2 Eth68
    ip_address: "10.254.1.5/30"
  - name: "Ethernet8" # Connects to Leaf_L3 Eth124
    ip_address: "10.254.1.9/30"
  - name: "Ethernet12" # Connects to Leaf_L4 Eth124
    ip_address: "10.254.1.13/30"
  - name: "Ethernet16" # Connects to Border-Leaf1 Eth124
    ip_address: "10.254.1.17/30"
  - name: "Ethernet20" # Connects to Border-Leaf2 Eth124
    ip_address: "10.254.1.21/30"
Use code with caution.Leaf L1 Configuration Context (host_vars/Leaf_L1.yml)yaml---
bgp_asn: 65101
loopback_ip: "10.0.1.1/32"

# Upstream Infrastructure Connections
fabric_uplinks:
  - name: "Ethernet68" # Maps to Spine_S1 Eth0
    ip_address: "10.254.1.2/30"
    peer_asn: 65000
  - name: "Ethernet64" # Maps to Spine_S2 Eth0
    ip_address: "10.254.2.2/30"
    peer_asn: 65000

# Downstream Multi-Homed Host Server Connectivity
downstream_ports:
  - name: "Ethernet0" # Host12_1 enps1
    ip_address: "10.1.1.1/30"
  - name: "Ethernet1" # Host12_2 enps1
    ip_address: "10.1.1.5/30"
  - name: "Ethernet2" # Host12_3 enps1
    ip_address: "10.1.1.9/30"
Use code with caution.Leaf L3 Breakout Architecture Context (host_vars/Leaf_L3.yml)Because Leaf_L3 is an Arista-7050QX-32, its uplink speeds to the Spine must be calculated using explicitly defined parent breakout configurations (p. 2).yaml---
bgp_asn: 65103
loopback_ip: "10.0.1.3/32"

# Explicit Parent Breakout Definitions
breakout_topology:
  - parent_port: "Ethernet120"
    breakout_mode: "4x10G"
    child_ports:
      - name: "Ethernet120" # Spine_S2 Eth8 Connectivity
        lanes: "121"
        speed: 10000
        ip_address: "10.254.2.10/30"
        peer_asn: 65000
  - parent_port: "Ethernet124"
    breakout_mode: "4x10G"
    child_ports:
      - name: "Ethernet124" # Spine_S1 Eth8 Connectivity
        lanes: "125"
        speed: 10000
        ip_address: "10.254.1.10/30"
        peer_asn: 65000

# Server Access Ports
downstream_ports:
  - name: "Ethernet0" # Host34_1 enps1
    ip_address: "10.3.1.1/30"
  - name: "Ethernet1" # Host34_2 enps1
    ip_address: "10.3.1.5/30"
  - name: "Ethernet2" # Storage_Server_HDD_01 enps1
    ip_address: "10.3.2.1/30"
  - name: "Ethernet3" # Storage_Server_HDD_02 enps1
    ip_address: "10.3.2.5/30"
Use code with caution.Border-Leaf 1 Dynamic Mapping Context (host_vars/Border-Leaf1.yml)The Arista-7050QX-32S breakout profiles reflect native SFP+ port groupings (p. 2) as specified in the physical wiring requirements.yaml---
bgp_asn: 65201
loopback_ip: "10.0.2.1/32"

breakout_topology:
  - parent_port: "Ethernet120"
    breakout_mode: "4x10G"
    child_ports:
      - name: "Ethernet120" # Spine_S2 Eth16 Link
        lanes: "121"
        speed: 10000
        ip_address: "10.254.2.18/30"
        peer_asn: 65000
  - parent_port: "Ethernet124"
    breakout_mode: "4x10G"
    child_ports:
      - name: "Ethernet124" # Spine_S1 Eth16 Link
        lanes: "125"
        speed: 10000
        ip_address: "10.254.1.18/30"
        peer_asn: 65000

# Edge Upstream Route Connectivity (Exit-Router Connections)
external_uplinks:
  - name: "Ethernet3" # Exit-Router1 CRS326 ether24
    ip_address: "192.168.100.2/30"
    peer_asn: 64999

# Dedicated Server & Core Compute Tier Ports
downstream_ports:
  - name: "Ethernet0" # HostB12_1 enps1
    ip_address: "10.5.1.1/30"
  - name: "Ethernet1" # HostB12_2 enps1
    ip_address: "10.5.1.5/30"
  - name: "Ethernet2" # Storage_Server_SSD_01 enps1
    ip_address: "10.5.2.1/30"
  - name: "Ethernet3" # Storage_Server_SSD_02 enps1
    ip_address: "10.5.2.5/30"
Use code with caution.Part 3: Host Server Configuration Context (host_vars/Host12_1.yml)The multi-homed bare-metal compute servers run both Netplan and FRR natively (p. 1), allowing BGP-to-the-Host routing to handle active-active L3 forwarding loops into the OpenStack on Kubernetes cluster infrastructure (p. 1).yaml---
ansible_user: ubuntu
ansible_network_os: linux

# Multi-Homed Routing Variables
server_bgp_asn: 65501
server_loopback: "10.100.0.1/32"

# Netplan Wire Map
pxe_interface: "enps0" # OOB MaaS Deployment Link
pxe_ip: "192.168.255.10/24"

fabric_interfaces:
  - device: "enps1" # Plugs into Leaf_L1 Ethernet0
    ip_address: "10.1.1.2/30"
    peer_ip: "10.1.1.1"
    peer_asn: 65101
  - device: "enps2" # Plugs into Leaf_L2 Ethernet0
    ip_address: "10.1.2.2/30"
    peer_ip: "10.1.2.1"
    peer_asn: 65102
      
Use code with caution.Part 4: Jinja2 Automation Templates1. SONiC Interface DB Generation (roles/fabric_breakout/templates/config_db.json.j2)
```
json{
    "PORT": {
        {% if breakout_topology is defined %}
        {% for breakout in breakout_topology %}
            {% for child in breakout.child_ports %}
        "{{ child.name }}": {
            "alias": "{{ child.name }}",
            "lanes": "{{ child.lanes }}",
            "speed": "{{ child.speed }}",
            "admin_status": "up"
        }{{ ',' if not loop.last else '' }}
            {% endfor %}{{ ',' if not loop.last else '' }}
        {% endfor %}
        {% endif %}
    },
    "BREAKOUT_CFG": {
        {% if breakout_topology is defined %}
        {% for breakout in breakout_topology %}
        "{{ breakout.parent_port }}": {
            "brkout_mode": "{{ breakout.breakout_mode }}"
        }{{ ',' if not loop.last else '' }}
        {% endfor %}
        {% endif %}
    }
}
```
Use code with caution.2. Host Server Network Definition (roles/host_networking/templates/netplan.yaml.j2)
```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    {{ pxe_interface }}:
      addresses:
        - {{ pxe_ip }}
      nameservers:
        addresses:
    {% for intf in fabric_interfaces %}
    {{ intf.device }}:
      addresses:
        - {{ intf.ip_address }}
      critical: true
    {% endfor %}
Use code with caution.3. Host FRRouting Daemon Config (roles/host_networking/templates/frr.conf.j2)
```
text
frr version 8.1
frr defaults traditional
hostname {{ inventory_hostname }}
!
interface {{ server_loopback }}
!
router bgp {{ server_bgp_asn }}
 bgp router-id {{ server_loopback | ipaddr('address') }}
 no bgp default ipv4-unicast
 neighbor FABRIC peer-group
 {% for intf in fabric_interfaces %}
 neighbor {{ intf.peer_ip }} remote-as {{ intf.peer_asn }}
 neighbor {{ intf.peer_ip }} peer-group FABRIC
 {% endfor %}
 !
 address-family ipv4 unicast
  redistribute connected
  neighbor FABRIC activate
 exit-address-family
!
line vty
!

```
Use code with caution.
Part 5: Secure Secrets Pipeline (vault.yml)yaml---
vault_sonic_admin_password: "$6$rounds=40000$SaltString$YourEncryptedProductionSONiCSecretKeyHash..."
vault_ubuntu_sudo_password: "CleartextOrEncryptedSudoPasswordForHostProvisioning Tasks"
Use code with caution.
Part 6: Complete Automation Blueprint (site_deploy.yml)This production-ready execution engine applies configurations sequentially across layers, validating states before advancing to ensure fabric stability (p. 7).
```yaml
---
- name: Phase 1 - Orchestrate SONiC Fabric Layer Breakouts & Routing
  hosts: fabric_switches
  gather_facts: no
  tasks:
    - name: Deploy Custom JSON Database Profile Templates
      template:
        src: roles/fabric_breakout/templates/config_db.json.j2
        dest: "{{ sonic_config_dir }}/config_db.json"
        backup: yes
      register: database_patch

    - name: Hot reload SONiC configuration database if configurations changed
      sonic_command:
        commands: ["sudo config reload -y"]
      when: database_patch.changed

    - name: Validation | Enforce Data Plane Routing Connectivity Engine
      sonic_command:
        commands: ["show ip route"]
      register: routing_table
      retries: 3
      delay: 10
      until: "'bgp' in routing_table.stdout"

- name: Phase 2 - Configure Multi-Homed Host Target Infrastructure
  hosts: compute_nodes
  gather_facts: yes
  become: yes
  tasks:
    - name: Push Declarative Netplan Layout Mapping File
      template:
        src: roles/host_networking/templates/netplan.yaml.j2
        dest: /etc/netplan/01-netcfg.yaml
      register: netplan_cfg

    - name: Apply Host System Network Changes
      command: netplan apply
      when: netplan_cfg.changed

    - name: Deploy Dynamic FRR Underlay BGP Configurations
      template:
        src: roles/host_networking/templates/frr.conf.j2
        dest: /etc/frr/frr.conf
      register: frr_cfg

    - name: Restart FRRouting Daemon Engine
      service:
        name: frr
        state: restarted
      when: frr_cfg.changed

- name: Phase 3 - End-to-End Clos Infrastructure Verification Check
  hosts: compute_nodes
  gather_facts: no
  tasks:
    - name: Run End-to-End Data Fabric Ping Validations
      command: "ping -c 3 10.0.0.1" # Target Spine_S1 Loopback IP to confirm path
      register: ping_check
      failed_when: ping_check.rc != 0

```
Use code with caution.Since you are running an OpenStack on Kubernetes (KubeSpray) deployment on top of this routed fabric (pp. 1, 7), would you like to see the Calico / Cilium BGP peering configuration overlay variables to map your Kubernetes CNI directly into these Leaf switches?

### Please update everything above related with ipv4 since we will be using bgp unnumbered for the topology.

To transition this 3-stage Clos fabric to BGP Unnumbered, we eliminate the overhead of designing and assigning individual /30 point-to-point IPv4 addresses to link interfaces.
BGP Unnumbered uses IPv6 Router Advertisements (RA) and IPv6 Link-Local addresses to automatically discover neighbors. IPv4 routing prefixes are then carried dynamically across these IPv6 links using Extended Next-Hop Encoding (RFC 8950).
Here is your updated, fully data-driven BGP Unnumbered automation framework.
------------------------------
## Part 1: Ansible Inventory (inventory.ini)
The inventory structure remains the same, but we add clear autonomous system boundaries. Spines share a single ASN, while every Leaf pair or single Leaf is assigned its own distinct ASN (following standard eBGP design).
```
[spines]
Spine_S1 ansible_host=172.16.2.46 hw_model="Celestica-DX010" bgp_asn=65000 loopback_ip="10.0.0.1"
Spine_S2 ansible_host=172.16.2.45 hw_model="Celestica-DX010" bgp_asn=65000 loopback_ip="10.0.0.2"

[leafs_accton]
Leaf_L1 ansible_host=172.16.2.44 hw_model="Accton-AS5712-54X" bgp_asn=65101 loopback_ip="10.0.1.1"
Leaf_L2 ansible_host=172.16.2.43 hw_model="Accton-AS5712-54X" bgp_asn=65101 loopback_ip="10.0.1.2"

[leafs_arista_qx]
Leaf_L3 ansible_host=172.16.2.42 hw_model="Arista-7050QX-32" bgp_asn=65102 loopback_ip="10.0.1.3"
Leaf_L4 ansible_host=172.16.2.41 hw_model="Arista-7050QX-32" bgp_asn=65102 loopback_ip="10.0.1.4"

[border_leafs]
Border-Leaf1 ansible_host=172.16.2.40 hw_model="Arista-7050QX-32S" bgp_asn=65201 loopback_ip="10.0.2.1"
Border-Leaf2 ansible_host=172.16.2.39 hw_model="Arista-7050QX-32S" bgp_asn=65201 loopback_ip="10.0.2.2"

[fabric_switches:children]
spines
leafs_accton
leafs_arista_qx
border_leafs

[compute_nodes]
Host12_1 ansible_host=192.168.255.10 server_asn=65501 loopback_ip="10.100.0.1"
Host12_2 ansible_host=192.168.255.11 server_asn=65502 loopback_ip="10.100.0.2"
Host12_3 ansible_host=192.168.255.12 server_asn=65503 loopback_ip="10.100.0.3"
Host34_1 ansible_host=192.168.255.13 server_asn=65504 loopback_ip="10.100.0.4"
Host34_2 ansible_host=192.168.255.14 server_asn=65505 loopback_ip="10.100.0.5"
HostB12_1 ansible_host=192.168.255.15 server_asn=65506 loopback_ip="10.100.0.6"
HostB12_2 ansible_host=192.168.255.16 server_asn=65507 loopback_ip="10.100.0.7"
MonitorSrv ansible_host=192.168.255.17 server_asn=65508 loopback_ip="10.100.0.8"

------------------------------
```
## Part 2: Fabric Switch BGP Unnumbered Host Variables
We strip away all point-to-point IP configurations. The interface blocks now only need to identify which ports are running BGP Unnumbered.
## Spine 1 Variable Profile (host_vars/Spine_S1.yml)
```
---
# BGP Unnumbered interfaces towards the Leavesunnumbered_interfaces:
  - "Ethernet0"   # To Leaf_L1
  - "Ethernet4"   # To Leaf_L2
  - "Ethernet8"   # To Leaf_L3
  - "Ethernet12"  # To Leaf_L4
  - "Ethernet16"  # To Border-Leaf1
  - "Ethernet20"  # To Border-Leaf2

## Leaf L1 Variable Profile (host_vars/Leaf_L1.yml)

---# Fabric uplinks are purely unnumbered interfacesunnumbered_interfaces:
  - "Ethernet68"  # To Spine_S1
  - "Ethernet64"  # To Spine_S2
  - "Ethernet0"   # Downlink to Host12_1
  - "Ethernet1"   # Downlink to Host12_2
  - "Ethernet2"   # Downlink to Host12_3

## Leaf L3 Breakout & Unnumbered Profile (host_vars/Leaf_L3.yml)
For your Arista breakout cages, we define the breakout transformation and include the final logical child ports in the unnumbered orchestration engine.

---breakout_topology:
  - parent_port: "Ethernet120"
    breakout_mode: "4x10G"
    child_ports:
      - name: "Ethernet120" # To Spine_S2
        lanes: "121"
        speed: 10000
  - parent_port: "Ethernet124"
    breakout_mode: "4x10G"
    child_ports:
      - name: "Ethernet124" # To Spine_S1
        lanes: "125"
        speed: 10000
unnumbered_interfaces:
  - "Ethernet120"
  - "Ethernet124"
  - "Ethernet0"   # To Host34_1
  - "Ethernet1"   # To Host34_2
  - "Ethernet2"   # To Storage_Server_HDD_01
  - "Ethernet3"   # To Storage_Server_HDD_02

------------------------------
```
## Part 3: Host Server Configuration Context (host_vars/Host12_1.yml)
The multi-homed hosts configure their fabric links without any IPv4 addresses. Instead, IPv6 link-local capability is enabled via Netplan, allowing FRR on the host to peer dynamically using unnumbered interfaces.
```
---
pxe_interface: "enps0"pxe_ip: "192.168.255.10/24"
# Pure data interfaces to the Leaves - No IPv4 assignedfabric_interfaces:
  - name: "enps1" # Plugs into Leaf_L1 Ethernet0
  - name: "enps2" # Plugs into Leaf_L2 Ethernet0

------------------------------
```
## Part 4: Jinja2 Templates (BGP Unnumbered Native Configuration)
In modern versions of SONiC, BGP configuration is managed natively via frr.conf directly inside the FRR container component.
## 1. Switch Network Operating System Config (roles/fabric_routing/templates/frr.conf.j2)
This template sets up the switch interfaces to send IPv6 Router Advertisements, defines the BGP Unnumbered peer group, and activates Extended Next-Hop capabilities.
```
! SONiC Routing Configuration for {{ inventory_hostname }}
frr version 8.1
frr defaults traditional
hostname {{ inventory_hostname }}
!
{# Enable IPv6 Routing Advertisements on unnumbered links #}
{% for intf in unnumbered_interfaces %}
interface {{ intf }}
 no ipv6 nd suppress-ra
 ipv6 nd ra-interval 10
exit
!
{% endfor %}
!
router bgp {{ bgp_asn }}
 bgp router-id {{ loopback_ip }}
 no bgp default ipv4-unicast
 bgp bestpath as-path multipath-relax
 !
 {# Peer Group Definition using Interface Peering #}
 neighbor UNNUMBERED_FABRIC peer-group
 neighbor UNNUMBERED_FABRIC remote-as external
 neighbor UNNUMBERED_FABRIC capability extended-next-hop
 !
 {# Link every active unnumbered interface to the peer group #}
 {% for intf in unnumbered_interfaces %}
 neighbor {{ intf }} peer-group UNNUMBERED_FABRIC
 {% endfor %}
 !
 address-family ipv4 unicast
  network {{ loopback_ip }}/32
  neighbor UNNUMBERED_FABRIC activate
  neighbor UNNUMBERED_FABRIC send-community both
 exit-address-family
!

## 2. Host Server Netplan Config (roles/host_networking/templates/netplan.yaml.j2)

network:
  version: 2
  renderer: networkd
  ethernets:
    {{ pxe_interface }}:
      addresses:
        - {{ pxe_ip }}
    {% for intf in fabric_interfaces %}
    {{ intf.name }}:
      # Force IPv6 Link-Local only for BGP Unnumbered path tracking
      link-local: [ ipv6 ]
      optional: true
    {% endfor %}
```
## 3. Host FRRouting Configuration (roles/host_networking/templates/frr.conf.j2)
```
! Host Routing Configuration for {{ inventory_hostname }}
frr version 8.1
frr defaults traditional
hostname {{ inventory_hostname }}
!
interface lo
 ip address {{ loopback_ip }}/32
exit
!
router bgp {{ server_asn }}
 bgp router-id {{ loopback_ip }}
 no bgp default ipv4-unicast
 bgp bestpath as-path multipath-relax
 !
 neighbor HOST_FABRIC peer-group
 neighbor HOST_FABRIC remote-as external
 neighbor HOST_FABRIC capability extended-next-hop
 !
 {% for intf in fabric_interfaces %}
 neighbor {{ intf.name }} peer-group HOST_FABRIC
 {% endfor %}
 !
 address-family ipv4 unicast
  network {{ loopback_ip }}/32
  neighbor HOST_FABRIC activate
 exit-address-family
!

------------------------------
```
## Part 5: Deployment Execution Engine (site_deploy.yml)
The production execution playbook pushes interface state breakouts, writes the unnumbered FRR routing blocks directly into the network components, and reloads the routing engine safely.
```
---
- name: Phase 1 - Configure SONiC BGP Unnumbered Fabric Layer
  hosts: fabric_switches
  gather_facts: no
  tasks:
    - name: Push breakout mapping layers if hardware contains QSFP modules
      template:
        src: roles/fabric_breakout/templates/config_db.json.j2
        dest: "{{ sonic_config_dir }}/config_db.json"
      register: db_breakout

    - name: Apply breakout engine changes
      command: "sudo config reload -y"
      when: db_breakout.changed

    - name: Build and inject BGP Unnumbered routing layout matrix
      template:
        src: roles/fabric_routing/templates/frr.conf.j2
        dest: /etc/sonic/frr/frr.conf
      register: router_config

    - name: Soft-reload switch routing daemon control loop
      command: "vtysh -c 'write memory' && systemctl restart frr"
      when: router_config.changed

- name: Phase 2 - Configure Bare Metal Multi-Homed Host Targets
  hosts: compute_nodes
  gather_facts: no
  become: yes
  tasks:
    - name: Generate Netplan file with explicit IPv6 Link-Local targets
      template:
        src: roles/host_networking/templates/netplan.yaml.j2
        dest: /etc/netplan/01-netcfg.yaml
      register: netplan_patch

    - name: Refresh Host interface state mappings
      command: netplan apply
      when: netplan_patch.changed

    - name: Deploy Host Server BGP Unnumbered FRR profiles
      template:
        src: roles/host_networking/templates/frr.conf.j2
        dest: /etc/frr/frr.conf
      register: host_frr_patch

    - name: Activate Host Routing Layer
      service:
        name: frr
        state: restarted
      when: host_frr_patch.changed

- name: Phase 3 - Fabric Validation Engine
  hosts: fabric_switches
  gather_facts: no
  tasks:
    - name: Validation | Verify BGP Unnumbered Neighbor Adjacency Sessions
      sonic_command:
        commands: ["vtysh -c 'show bgp summary'"]
      register: bgp_state

    - name: Validation | Confirm active IPv4 Extended Next-Hop routes are passing
      assert:
        that:
          - "'Established' in bgp_state.stdout"
        fail_msg: "Fabric Validation Failure: Unnumbered routing adjacency failed to establish."
```
Would you like to build an automated post-boot check task to parse the routing table using the ipaddr module, confirming that each host can see every other host's IPv4 loopback across the unnumbered network mesh?

### Can we have a dedicated playbook that will complete the task up to starting the virsh vms (SONiC and Ubuntu) with appropriate openvswitch bridge/stub wiring with switch/ubuntu interfaces properly and completely data driven from the var files you created. Complete rendering of virsh xml that explains how the topology connectivity is working between switches/virsh tap interfaces etc. As you stated 3 phases above. Assuming this one is the first phase.

To automate the initial infrastructure orchestration phase on your Ubuntu hypervisor, we will map out a complete, standalone Ansible playbook and role.
This role generates the Open vSwitch (OVS) bridges, constructs the full, production-grade Libvirt domain XML files, inserts the active or stub interfaces sequentially to guarantee EthernetX mapping predictability inside SONiC, and then launches the entire virtual Clos fabric.
------------------------------
## Step 1: Directory Layout for Phase 1 Infrastructure

hypervisor-orchestration/
├── inventory.ini
├── group_vars/
│   ├── all.yml
│   ├── fabric_switches.yml
│   └── compute_nodes.yml
├── host_vars/
│   ├── Spine_S1.yml
│   ├── Leaf_L1.yml
│   ├── Leaf_L3.yml
│   └── Host12_1.yml
├── roles/
│   └── kvm_clos_provision/
│       ├── tasks/
│       │   └── main.yml
│       └── templates/
│           ├── kvm_sonic_domain.xml.j2
│           └── kvm_ubuntu_domain.xml.j2
└── phase1_ignite_fabric.yml

------------------------------
## Step 2: Comprehensive Infrastructure Variable Data-Model
These files fully define the logical switch/server identities alongside their corresponding physical host virtualizations. Unconfigured interfaces automatically derive sequential, deterministic stub-plugs up to the designated hardware limits (32 for Arista QX models, 54 for Edge-Core AS5712, etc.).
## 1. Spine 1 Definition Profile (host_vars/Spine_S1.yml)

---# Libvirt VM Guest System Specsvm_name: "vsonic-spine-s1"total_physical_ports: 32vm_cpu: 2vm_ram_mb: 4096os_variant: "debian11"disk_image_path: "/var/lib/libvirt/images/sonic-celestica.qcow2"
# Explicit active wiring to the Leaf Layerhost_network_mapping:
  - guest_interface: "Ethernet0"
    ovs_bridge: "br-s1-l1"       # Wired to Leaf_L1 Ethernet68
    mac_address: "52:54:00:a1:00:00"
  - guest_interface: "Ethernet4"
    ovs_bridge: "br-s1-l2"       # Wired to Leaf_L2 Ethernet68
    mac_address: "52:54:00:a1:00:04"
  - guest_interface: "Ethernet8"
    ovs_bridge: "br-s1-l3"       # Wired to Leaf_L3 Ethernet124
    mac_address: "52:54:00:a1:00:08"
  - guest_interface: "Ethernet12"
    ovs_bridge: "br-s1-l4"       # Wired to Leaf_L4 Ethernet124
    mac_address: "52:54:00:a1:00:12"
  - guest_interface: "Ethernet16"
    ovs_bridge: "br-s1-bl1"      # Wired to Border-Leaf1 Ethernet124
    mac_address: "52:54:00:a1:00:16"
  - guest_interface: "Ethernet20"
    ovs_bridge: "br-s1-bl2"      # Wired to Border-Leaf2 Ethernet124
    mac_address: "52:54:00:a1:00:20"

## 2. Leaf L1 Definition Profile (host_vars/Leaf_L1.yml)

---vm_name: "vsonic-leaf-l1"total_physical_ports: 54         # Edge/Accton AS5712 hardware profile layoutvm_cpu: 2vm_ram_mb: 4096os_variant: "debian11"disk_image_path: "/var/lib/libvirt/images/sonic-accton.qcow2"
host_network_mapping:
  - guest_interface: "Ethernet68"
    ovs_bridge: "br-s1-l1"       # Connects up to Spine_S1 Ethernet0
    mac_address: "52:54:00:b1:00:68"
  - guest_interface: "Ethernet64"
    ovs_bridge: "br-s2-l1"       # Connects up to Spine_S2 Ethernet0
    mac_address: "52:54:00:b1:00:64"
  - guest_interface: "Ethernet0"
    ovs_bridge: "br-l1-h12-1"    # Downlink to Host12_1 enps1
    mac_address: "52:54:00:b1:00:00"
  - guest_interface: "Ethernet1"
    ovs_bridge: "br-l1-h12-2"    # Downlink to Host12_2 enps1
    mac_address: "52:54:00:b1:00:01"
  - guest_interface: "Ethernet2"
    ovs_bridge: "br-l1-h12-3"    # Downlink to Host12_3 enps1
    mac_address: "52:54:00:b1:00:02"

## 3. Host Server Definition Profile (host_vars/Host12_1.yml)

---vm_name: "vhost-server-12-1"vm_cpu: 4vm_ram_mb: 8192os_variant: "ubuntu22.04"disk_image_path: "/var/lib/libvirt/images/ubuntu-openstack-base-1.qcow2"
# Ubuntu multi-homed mapping layerhost_server_interfaces:
  - os_dev: "enps0"
    ovs_bridge: "br-maas-pxe"    # Management, iDRAC, and MaaS network segment
    mac_address: "52:54:00:f0:12:01"
  - os_dev: "enps1"
    ovs_bridge: "br-l1-h12-1"    # L3 Unnumbered Link directly to Leaf_L1
    mac_address: "52:54:00:f1:12:01"
  - os_dev: "enps2"
    ovs_bridge: "br-l2-h12-1"    # L3 Unnumbered Link directly to Leaf_L2
    mac_address: "52:54:00:f2:12:01"

------------------------------
## Step 4: The Dynamic Libvirt Domain XML Engines
To maintain absolute PCI slot index predictability inside the guest operating system kernels, these templates unroll active ports directly into their targeted network structures while sweeping unassigned capacities sequentially into a common local loopback bridge (br-stub).
## 1. Network NOS Node Engine (roles/kvm_clos_provision/templates/kvm_sonic_domain.xml.j2)

<domain type='kvm'>
  <name>{{ vm_name }}</name>
  <memory unit='KiB'>{{ vm_ram_mb * 1024 }}</memory>
  <currentMemory unit='KiB'>{{ vm_ram_mb * 1024 }}</currentMemory>
  <vcpu placement='static'>{{ vm_cpu }}</vcpu>
  <os>
    <type arch='x86_64' machine='pc-q35-rhel9.0.0'>hvm</type>
    <boot dev='hd'/>
  </os>
  <features>
    <acpi/><apic/><pae/>
  </features>
  <cpu mode='host-passthrough' check='none'/>
  <clock offset='utc'/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' cache='none'/>
      <source file='{{ disk_image_path }}'/>
      <target dev='vda' bus='virtio'/>
    </disk>

    <!-- Slot 0: Out-of-Band (OOB) Management Interface Port (eth0) -->
    <interface type='bridge'>
      <source bridge='br-mgmt-vlan10'/>
      <virtualport type='openvswitch'/>
      <model type='virtio'/>
    </interface>

    <!-- Data Plane Array Compilation Loop (Sequential Device Index Enforcement) -->
    {% for port_num in range(total_physical_ports) %}
      {% set current_eth = "Ethernet" ~ port_num %}
      {% set matched_port = host_network_mapping | selectattr('guest_interface', 'equalto', current_eth) | list %}
      
      {% if matched_port | length > 0 %}
    <!-- Active Clos Fabric Member: {{ current_eth }} -->
    <interface type='bridge'>
      <mac address='{{ matched_port[0].mac_address }}'/>
      <source bridge='{{ matched_port[0].ovs_bridge }}'/>
      <virtualport type='openvswitch'/>
      <model type='virtio'/>
    </interface>
      {% else %}
    <!-- Hardware Lane Stub Loopback Protection: {{ current_eth }} -->
    <interface type='bridge'>
      <source bridge='br-stub'/>
      <virtualport type='openvswitch'/>
      <model type='virtio'/>
    </interface>
      {% endif %}
    {% endfor %}

    <serial type='pty'>
      <target port='0'/>
    </serial>
    <console type='pty'>
      <target type='serial' port='0'/>
    </console>
    <graphics type='vnc' port='-1' autoport='yes' listen='127.0.0.1'/>
  </devices>
</domain>

## 2. Bare-Metal Compute Simulation Node Engine (roles/kvm_clos_provision/templates/kvm_ubuntu_domain.xml.j2)

<domain type='kvm'>
  <name>{{ vm_name }}</name>
  <memory unit='KiB'>{{ vm_ram_mb * 1024 }}</memory>
  <vcpu placement='static'>{{ vm_cpu }}</vcpu>
  <os>
    <type arch='x86_64' machine='pc-q35-rhel9.0.0'>hvm</type>
    <boot dev='hd'/>
  </os>
  <features>
    <acpi/><apic/>
  </features>
  <cpu mode='host-passthrough'/>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='{{ disk_image_path }}'/>
      <target dev='vda' bus='virtio'/>
    </disk>

    <!-- Compute Array Interfacing Array Loop -->
    {% for nic in host_server_interfaces %}
    <!-- Native OS Device Allocation Mapping Reference: {{ nic.os_dev }} -->
    <interface type='bridge'>
      <mac address='{{ nic.mac_address }}'/>
      <source bridge='{{ nic.ovs_bridge }}'/>
      <virtualport type='openvswitch'/>
      <model type='virtio'/>
    </interface>
    {% endfor %}

    <serial type='pty'><target port='0'/></serial>
    <console type='pty'><target type='serial' port='0'/></console>
  </devices>
</domain>

------------------------------
## Step 5: Hypervisor Automated Execution Pipeline Task Engine
This production engine gathers structural mappings across your switches and compute hosts. It identifies all unique target bridges, spins them up cleanly inside the OVS daemon space, builds the complete XML specifications, imports them to the local hypervisor domain registries, and starts the entire virtual framework.
Save this script workspace to: roles/kvm_clos_provision/tasks/main.yml.

---
- name: Prep | Enforce structural runtime existence of global OVS stub tracking bridge
  openvswitch.openvswitch.openvswitch_bridge:
    name: "br-stub"
    state: present
  delegate_to: localhost

- name: Prep | Enforce structural runtime existence of global OVS OOB management bridge
  openvswitch.openvswitch.openvswitch_bridge:
    name: "br-mgmt-vlan10"
    state: present
  delegate_to: localhost

- name: Extract | Compute unique target OVS infrastructure fabric bridges
  set_fact:
    target_bridges: >-
      {% set bridges = [] %}
      {% if host_network_mapping is defined %}
        {% for mapping in host_network_mapping %}
          {% if mapping.ovs_bridge not in bridges %}
            {% set _ = bridges.append(mapping.ovs_bridge) %}
          {% endif %}
        {% endfor %}
      {% endif %}
      {% if host_server_interfaces is defined %}
        {% for nic in host_server_interfaces %}
          {% if nic.ovs_bridge not in bridges %}
            {% set _ = bridges.append(nic.ovs_bridge) %}
          {% endif %}
        {% endfor %}
      {% endif %}
      {{ bridges }}

- name: Fabric | Deploy structural Open vSwitch bridges across hypervisor host
  openvswitch.openvswitch.openvswitch_bridge:
    name: "{{ item }}"
    state: present
  loop: "{{ target_bridges }}"
  delegate_to: localhost

- name: Render | Build declarative architectural Libvirt XML blueprint configuration files
  template:
    src: "{{ 'kvm_sonic_domain.xml.j2' if (host_network_mapping is defined) else 'kvm_ubuntu_domain.xml.j2' }}"
    dest: "/tmp/libvirt_compiled_{{ vm_name }}.xml"
  delegate_to: localhost

- name: Libvirt | Define domain blueprint structures into target Hypervisor engine
  community.libvirt.virt:
    command: define
    xml: "{{ lookup('file', '/tmp/libvirt_compiled_' ~ vm_name ~ '.xml') }}"
  delegate_to: localhost

- name: Boot | Start runtime virtual machines across Clos layers simultaneously
  community.libvirt.virt:
    name: "{{ vm_name }}"
    state: running
  delegate_to: localhost

- name: Clean | Purge temporary workspace XML data models
  file:
    path: "/tmp/libvirt_compiled_{{ vm_name }}.xml"
    state: absent
  delegate_to: localhost

------------------------------
## Step 6: Master Ignition Playbook Runner (phase1_ignite_fabric.yml)
Execute this master playbook runner from your deployer terminal machine. It orchestrates the host environment sequentially to lay down the underlying Layer-1 structural virtualization matrix.

---
- name: Orchestrate Phase 1 - Ignite Virtual Clos Layer 1 Infrastructure
  hosts: localhost
  gather_facts: no
  tasks:
    - name: Instantiate Network Layer (Spines, Leafs, and Border Switches)
      include_role:
        name: kvm_clos_provision
      vars:
        vm_name: "{{ hostvars[item]['vm_name'] }}"
        total_physical_ports: "{{ hostvars[item]['total_physical_ports'] }}"
        vm_cpu: "{{ hostvars[item]['vm_cpu'] }}"
        vm_ram_mb: "{{ hostvars[item]['vm_ram_mb'] }}"
        os_variant: "{{ hostvars[item]['os_variant'] }}"
        disk_image_path: "{{ hostvars[item]['disk_image_path'] }}"
        host_network_mapping: "{{ hostvars[item]['host_network_mapping'] }}"
      loop: "{{ groups['fabric_switches'] }}"
      when: hostvars[item]['vm_name'] is defined

    - name: Instantiate Bare-Metal Server Compute Layer
      include_role:
        name: kvm_clos_provision
      vars:
        vm_name: "{{ hostvars[item]['vm_name'] }}"
        vm_cpu: "{{ hostvars[item]['vm_cpu'] }}"
        vm_ram_mb: "{{ hostvars[item]['vm_ram_mb'] }}"
        os_variant: "{{ hostvars[item]['os_variant'] }}"
        disk_image_path: "{{ hostvars[item]['disk_image_path'] }}"
        host_server_interfaces: "{{ hostvars[item]['host_server_interfaces'] }}"
      loop: "{{ groups['compute_nodes'] }}"
      when: hostvars[item]['vm_name'] is defined

Now that Phase 1 is completely automated, would you like to review how to implement Phase 2 (The Automated MaaS PXE Bootstrap) to configure your MaaS controller node and begin provisioning the Ubuntu servers automatically?

### Please do.

To implement Phase 2 (The Automated MaaS PXE Bootstrap), we move from the infrastructure layout layer to the orchestration layer (p. 7). In this step, your Deployer Machine prepares the Kubernetes control plane via KubeSpray (p. 7), installs a persistent database layer, and spins up Canonical MaaS (Metal as a Service) using Helm charts inside the cluster (p. 7).
Once active, MaaS intercepts PXE boot requests across your isolated br-maas-pxe bridge network to automatically discover, catalog, and provision your bare-metal server cluster with Ubuntu OS (pp. 5, 7).
------------------------------
## Step 1: Directory Architecture Extension
Add the MaaS deployment structure into your existing operational workspace:
```
deployer-fabric-root/
├── group_vars/
│   └── maas_masters.yml
├── host_vars/
│   └── HostB12_1.yml
├── roles/
│   ├── kubespray_bootstrap/
│   └── maas_helm_deploy/
│       ├── tasks/
│       │   └── main.yml
│       └── templates/
│           ├── postgres-values.yaml.j2
│           └── maas-values.yaml.j2
└── phase2_maas_bootstrap.yml

------------------------------
```
## Step 2: MaaS Master Node Variable Definitions (host_vars/HostB12_1.yml)
As outlined in your wiring specs, HostB12_1 functions as the Kubernetes cluster master node, housing the centralized PostgreSQL database instance and the MaaS Region/Rack controllers (p. 7).
```
---
# Host Identity Propertiesvm_name: "vhost-server-b12-1"ansible_host: "192.168.255.15"
# MaaS Specific Configuration Variablesmaas_admin_user: "admin"maas_admin_email: "infra-admin@datacenter.local"maas_admin_password: "VaultSecureMaaSAdminPassword123"
# Network Ranges for Dynamic Commissioning Poolsmaas_pxe_interface: "enps0"maas_pxe_network: "192.168.0.0"maas_pxe_cidr: "12"                  # Matches the 192.168.255.0/125 overall schememaas_dynamic_ip_range_start: "192.168.255.30"maas_dynamic_ip_range_end: "192.168.255.120"maas_upstream_dns: "8.8.8.8"

------------------------------
```
## Step 3: Production Helm Values Configuration Files
MaaS requires a backing transactional database (p. 7). We configure a highly available on-cluster PostgreSQL instance, followed by a customized values matrix that exposes MaaS directly onto the PXE network bridge using Kubernetes HostNetworking.
## 1. PostgreSQL Helm Values (roles/maas_helm_deploy/templates/postgres-values.yaml.j2)
```

architecture: replicationauth:
  username: maas_user
  password: SecretDatabasePassword456
  database: maas_dbprimary:
  persistence:
    enabled: true
    size: 20Gi
    storageClass: "ceph-rbd" # Backed by your integrated Ceph storage engine later

## 2. Canonical MaaS Helm Values (roles/maas_helm_deploy/templates/maas-values.yaml.j2)

image:
  repository: canonical/maas
  tag: "3.4-latest"
# Bind directly to the host network interface to receive PXE DHCP broadcastshostNetwork: true
serviceAccount:
  create: true
# Configures the parameters for the dynamic Rack and Region microservicesregion:
  database:
    host: "maas-postgres-primary.default.svc.cluster.local"
    port: 5432
    username: "maas_user"
    password: "SecretDatabasePassword456"
    name: "maas_db"
rack:
  # Instructs the internal DHCP daemon to respond across the virtual interface
  interfaces:
    - {{ maas_pxe_interface }}

------------------------------
```
## Step 4: MaaS Deployment & Automated Commissioning Tasks
This task engine executes sequentially on your Deployer Machine. It initiates KubeSpray (p. 7), installs Helm repositories, renders configuration layers, provisions MaaS, and drops into an intelligent loop checking the API status until the other host instances have successfully completed PXE commissioning (pp. 7-8).
Save this script workspace to: roles/maas_helm_deploy/tasks/main.yml.
```
---
- name: KubeSpray | Execute baseline Kubernetes cluster installation on HostB12_1
  ansible.builtin.command: >-
    ansible-playbook -i ../kubespray/inventory/mycluster/inventory.ini 
    ../kubespray/cluster.yml --become
  delegate_to: localhost
  changed_when: true

- name: Helm | Ensure Bitnami and Canonical repository definitions exist
  kubernetes.core.helm_repository:
    name: "{{ item.name }}"
    repo_url: "{{ item.url }}"
  loop:
    - { name: 'bitnami', url: 'https://bitnami.com' }
    - { name: 'canonical', url: 'https://canonical.com' }
  delegate_to: localhost

- name: Render | Compile customized transactional chart settings
  ansible.builtin.template:
    src: "{{ item.src }}"
    dest: "/tmp/{{ item.dest }}"
    mode: '0600'
  loop:
    - { src: 'postgres-values.yaml.j2', dest: 'postgres-values.yaml' }
    - { src: 'maas-values.yaml.j2', dest: 'maas-values.yaml' }
  delegate_to: localhost

- name: Database | Install persistent PostgreSQL storage instance via Helm
  kubernetes.core.helm:
    name: maas-postgres
    chart_ref: bitnami/postgresql
    values_file: /tmp/postgres-values.yaml
    release_namespace: default
  delegate_to: localhost

- name: Provision | Deploy Canonical MaaS architecture across Kubernetes worker nodes
  kubernetes.core.helm:
    name: maas-infrastructure
    chart_ref: canonical/maas
    values_file: /tmp/maas-values.yaml
    release_namespace: default
  delegate_to: localhost

- name: Bootstrap | Wait for MaaS Region APIs to initialize successfully
  ansible.builtin.uri:
    url: "http://{{ ansible_host }}:5240/MAAS/api/2.0/users/"
    status_code: 401 # API is alive but requires initialization tokens
  register: maas_api_status
  until: maas_api_status.status == 401
  retries: 24
  delay: 10
  delegate_to: localhost

- name: Post-Install | Create admin administrative authentication user credentials
  ansible.builtin.shell: |
    kubectl exec -it deployment/maas-infrastructure-region -- \
    maas-region createadmin \
    --username={{ maas_admin_user }} \
    --password={{ maas_admin_password }} \
    --email={{ maas_admin_email }} \
    --ssh-import=gh:canonical  delegate_to: localhost
  register: admin_creation
  failed_when: admin_creation.rc != 0 and "already exists" not in admin_creation.stderr
  changed_when: "'created successfully' in admin_creation.stdout"

- name: Network | Configure dynamic PXE DHCP subnets and onboarding scopes
  ansible.builtin.shell: |
    # Login to local MaaS API control structure
    MAAS_API_KEY=$(kubectl exec -it deployment/maas-infrastructure-region -- maas-region apikey --username={{ maas_admin_user }})
    maas login admin http://localhost:5240/MAAS/api/2.0/ "$MAAS_API_KEY"
    
    # Enable DHCP and manage the PXE booting range
    maas admin ipranges create type=dynamic \
      start_ip={{ maas_dynamic_ip_range_start }} \
      end_ip={{ maas_dynamic_ip_range_end }}
      
    # Turn on upstream DNS forwarding lookup resolution loops
    maas admin maas set-config name=upstream_dns value={{ maas_upstream_dns }}  delegate_to: localhost
  changed_when: true

- name: Automation | Poll MaaS API engine for fully commissioned nodes
  ansible.builtin.shell: |
    MAAS_API_KEY=$(kubectl exec -it deployment/maas-infrastructure-region -- maas-region apikey --username={{ maas_admin_user }})
    maas login admin http://localhost:5240/MAAS/api/2.0/ "$MAAS_API_KEY"
    maas admin machines read | jq -r '.[] | select(.status_name=="Ready") | .hostname'  delegate_to: localhost
  register: maas_ready_nodes
  until: 
    - hostvars['Host12_1']['vm_name'] in maas_ready_nodes.stdout
    - hostvars['Host34_1']['vm_name'] in maas_ready_nodes.stdout
  retries: 60
  delay: 30
  label: "Waiting for bare-metal targets to transition into 'Ready' state via automated network boot profiles."

------------------------------
```
## Step 5: Phase 2 Execution Playbook (phase2_maas_bootstrap.yml)
Execute this orchestration loop from your Deployer Machine terminal. This handles bringing up your Kubernetes-backed MaaS control plane (p. 7), lighting up the network-wide PXE discovery listeners (p. 5), and pulling the rest of the target fabric infrastructure into an active state (p. 7).
```
---
- name: Orchestrate Phase 2 - Deploy Kubernetes Control Plane & MaaS PXE Infrastructure
  hosts: compute_nodes
  gather_facts: no
  tasks:
    - name: Trigger MaaS deployment workflow loop on designated Master Node
      ansible.builtin.include_role:
        name: maas_helm_deploy
      when: inventory_hostname == "HostB12_1"
```
Once Phase 2 completes, your compute nodes will have complete Ubuntu installations with active management interfaces, ready for data-plane network setup (p. 7).
Would you like to move on to Phase 3 (The Distributed Ceph & OpenStack Blueprint) to show how the playbook dynamically discovers disks, partitions your storage arrays, and launches your containerized OpenStack Compute clusters (p. 7)?


### The BGP/Netplan/FRR configuration, is it completely done in Phase 1? If YES provide details how it is achieved? If not, provide playbook to complete that for Spine Layer, Leaf Layer, Border Leaf Layer, Exit Router Layer and Server layer. Assume servers are multihome.

No, the BGP/Netplan/FRR configurations are not done in Phase 1.
Phase 1 strictly provisions the physical virtualization boundaries (creating OVS bridges, building Libvirt domain definitions, sequentially assigning virtual hardware interface buses to avoid naming collisions, and booting the bare VM chassis). Because the switches and servers are completely blank at that moment, they have no operating system configurations.
Following our data-driven pipeline, the network configurations are applied in Phase 3 (after Phase 2 completes the MaaS OS provisioning layer).
Below is the production-grade, complete automated playbook, role structures, and templates to configure BGP Unnumbered and Netplan natively across your entire 3-stage Clos fabric.
------------------------------
## Step 1: Expanded Variable Map Including Exit Routers
We append the Exit-Router variables to the data-model schema, providing full upstream internet breakout context using your hardware descriptions (pp. 2, 6).
```
# host_vars/Exit-Router1.yml
---bgp_asn: 64999loopback_ip: "10.255.255.1"ansible_host: "172.16.2.48" # Connected to Management Switch Port 48ansible_network_os: routeros # Automated native Mikrotik CRS326 profiles
# Explicitly tracks connections back into the Clos border layerdownstream_interfaces:
  - name: "ether24" # Plugs directly into Border-Leaf1 Ethernet3
    peer_asn: 65201
# Outbound ISP connectionsupstream_interfaces:
  - name: "ether2"  # Admin wifi aggregation bridge
  - name: "ether24" # ISP Link

------------------------------
```
## Step 2: Directory Architecture Workspace
```
fabric-routing-orchestration/
├── phase3_configure_routing.yml
└── roles/
    ├── switch_fabric_routing/
    │   └── templates/
    │       └── switch_frr.conf.j2
    ├── exit_router_routing/
    │   └── templates/
    │       └── routeros_bgp.rsc.j2
    └── server_fabric_routing/
        └── templates/
            ├── host_netplan.yaml.j2
            └── host_frr.conf.j2

------------------------------
```
## Step 3: Jinja2 Architectural Templates## 1. Unified Switch Core Engine (roles/switch_fabric_routing/templates/switch_frr.conf.j2)
This blueprint generates native FRR configurations for Spines, Leafs, and Border-Leafs alike, implementing strict BGP Unnumbered link discovery and Multipath relaxation.
```
! SONiC Architecture Routing Template for {{ inventory_hostname }}
frr version 8.1
frr defaults traditional
hostname {{ inventory_hostname }}
!
{% for intf in unnumbered_interfaces %}
interface {{ intf }}
 no ipv6 nd suppress-ra
 ipv6 nd ra-interval 10
exit
!
{% endfor %}
!
router bgp {{ bgp_asn }}
 bgp router-id {{ loopback_ip }}
 no bgp default ipv4-unicast
 bgp bestpath as-path multipath-relax
 !
 {# Setup dynamic BGP Unnumbered peer configuration rules #}
 neighbor CLOS_FABRIC peer-group
 neighbor CLOS_FABRIC remote-as external
 neighbor CLOS_FABRIC capability extended-next-hop
 !
 {% for intf in unnumbered_interfaces %}
 neighbor {{ intf }} peer-group CLOS_FABRIC
 {% endfor %}
 !
 {# Handle legacy static IPv4 links if this node is a Border Leaf talking to Mikrotik Exit-Routers #}
 {% if external_uplinks is defined %}
 {% for uplink in external_uplinks %}
 neighbor {{ uplink.ip_address | ipaddr('peer') }} remote-as {{ uplink.peer_asn }}
 {% endfor %}
 {% endif %}
 !
 address-family ipv4 unicast
  network {{ loopback_ip }}/32
  neighbor CLOS_FABRIC activate
  neighbor CLOS_FABRIC send-community both
  {% if external_uplinks is defined %}
  {% for uplink in external_uplinks %}
  neighbor {{ uplink.ip_address | ipaddr('peer') }} activate
  {% endfor %}
  {% endif %}
 exit-address-family
!

## 2. Mikrotik RouterOS Exit-Router Provisioner (roles/exit_router_routing/templates/routeros_bgp.rsc.j2)
Since the Exit Routers are Mikrotik CRS326 platforms (p. 2), this converts variables into standard RouterOS CLI commands.

# Automated BGP Configuration Script for Mikrotik {{ inventory_hostname }}
/routing bgp instance
set default as={{ bgp_asn }} router-id={{ loopback_ip }} redistribute-connected=yes

/interface ethernet
{% for peer in downstream_interfaces %}
# Configure point-to-point interface properties
/ip address
add address=192.168.100.1/30 interface={{ peer.name }} comment="Link to Border Leaf"

/routing bgp peer
add name=to_border_leaf remote-address=192.168.100.2 remote-as={{ peer.peer_asn }} instance=default
{% endfor %}

## 3. Server Netplan Blueprint (roles/server_fabric_routing/templates/host_netplan.yaml.j2)

# Netplan configuration for Multi-Homed Host Server: {{ inventory_hostname }}network:
  version: 2
  renderer: networkd
  ethernets:
    {{ pxe_interface }}:
      addresses:
        - {{ pxe_ip }}
    {% for intf in fabric_interfaces %}
    {{ intf.name }}:
      # Force clean IPv6 link-local behavior to enable BGP Unnumbered discovery pathing
      link-local: [ ipv6 ]
      optional: true
    {% endfor %}

## 4. Server FRRouting Template (roles/server_fabric_routing/templates/host_frr.conf.j2)

! Multi-Homed Host Routing Configuration for {{ inventory_hostname }}
frr version 8.1
frr defaults traditional
hostname {{ inventory_hostname }}
!
interface lo
 ip address {{ loopback_ip }}/32
exit
!
router bgp {{ server_asn }}
 bgp router-id {{ loopback_ip }}
 no bgp default ipv4-unicast
 bgp bestpath as-path multipath-relax
 !
 neighbor SERVER_UPLINKS peer-group
 neighbor SERVER_UPLINKS remote-as external
 neighbor SERVER_UPLINKS capability extended-next-hop
 !
 {% for intf in fabric_interfaces %}
 neighbor {{ intf.name }} peer-group SERVER_UPLINKS
 {% endfor %}
 !
 address-family ipv4 unicast
  network {{ loopback_ip }}/32
  neighbor SERVER_UPLINKS activate
 exit-address-family
!

------------------------------
```
## Step 4: Standalone Execution Pipeline (phase3_configure_routing.yml)
This production playbook unrolls configurations across your fabric tiers sequentially. It configures the switches, provisions the edge routing paths, updates host server interfaces, and starts routing exchanges.
```
---
- name: Phase 3 (Part A) - Provision SONiC Switch Network Layer
  hosts: fabric_switches
  gather_facts: no
  serial: 2 # Updates pairs sequentially to avoid total fabric downtime loops
  tasks:
    - name: Switch Core | Generate and insert BGP Unnumbered routing layout matrix
      ansible.builtin.template:
        src: roles/switch_fabric_routing/templates/switch_frr.conf.j2
        dest: /etc/sonic/frr/frr.conf
      register: switch_router_config

    - name: Switch Core | Commit changes and refresh internal FRR container routing loops
      ansible.builtin.command: "vtysh -c 'write memory' && systemctl restart frr"
      when: switch_router_config.changed

- name: Phase 3 (Part B) - Provision Exit Router Boundaries
  hosts: exit_routers
  gather_facts: no
  tasks:
    - name: Exit Edge | Generate RouterOS script profile parameters
      ansible.builtin.template:
        src: roles/exit_router_routing/templates/routeros_bgp.rsc.j2
        dest: "/tmp/bgp_setup_{{ inventory_hostname }}.rsc"
      delegate_to: localhost
      register: routeros_script

    - name: Exit Edge | Push script payload to Mikrotik router endpoints via SSH
      netcommon.net_put:
        src: "/tmp/bgp_setup_{{ inventory_hostname }}.rsc"
        dest: "bgp_setup.rsc"
      when: routeros_script.changed

    - name: Exit Edge | Execute RouterOS command pipeline strings
      routeros.routeros.command:
        commands: ["/import file-name=bgp_setup.rsc"]
      when: routeros_script.changed

- name: Phase 3 (Part C) - Provision Multi-Homed Host Server Configurations
  hosts: compute_nodes
  gather_facts: no
  become: yes
  tasks:
    - name: Server Fabric | Write declarative Netplan link state definitions
      ansible.builtin.template:
        src: roles/server_fabric_routing/templates/host_netplan.yaml.j2
        dest: /etc/netplan/01-netcfg.yaml
      register: server_netplan_patch

    - name: Server Fabric | Apply Netplan kernel runtime updates
      ansible.builtin.command: netplan apply
      when: server_netplan_patch.changed

    - name: Server Fabric | Write local host BGP Unnumbered FRR daemon components
      ansible.builtin.template:
        src: roles/server_fabric_routing/templates/host_frr.conf.j2
        dest: /etc/frr/frr.conf
      register: server_frr_patch

    - name: Server Fabric | Restart host system routing service engine
      ansible.builtin.service:
        name: frr
        state: restarted
      when: server_frr_patch.changed

- name: Phase 3 (Part D) - Fabric Verification & Convergence Checks
  hosts: compute_nodes
  gather_facts: no
  tasks:
    - name: Validate | Poll local host FRR engine for established BGP unnumbered neighbors
      ansible.builtin.command: vtysh -c "show bgp summary json"
      register: bgp_json_summary
      changed_when: false
      retries: 6
      delay: 10
      until: 
        - (bgp_json_summary.stdout | from_json).peers | length > 0
        - (bgp_json_summary.stdout | from_json).peers.values() | map(attribute='state') | select('equalto', 'Established') | list | length == (bgp_json_summary.stdout | from_json).peers | length
```
## Verification Flow Breakdown
Once this playbook finishes running, you can trace packet flows downward across your layers using these diagnostic verification checkpoints:

   1. On Servers: Run ip route to confirm that the default route 0.0.0.0/0 points directly to an IPv6 link-local address (fe80::...) split across both multi-homed interfaces (enps1 and enps2) via Equal-Cost Multi-Pathing (ECMP).
   2. On Leaf Switches: Run show ip bgp summary to confirm that your Multi-Homed servers and upstream Spines have safely entered the Established operational tracking state.

If you are standardizing this for your upcoming OpenStack on Kubernetes infrastructure rollout, would you like to review how to implement an automated daily backup cron task inside Ansible to cleanly export these custom frr.conf configurations out to your secure vault repository?












