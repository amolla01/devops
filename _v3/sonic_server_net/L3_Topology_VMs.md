### we have few ovs bridges, br-h101-l1, br-h102-l1 where two virtual 10g server host attaching them to an arista model 7050qx32 from port1 and two more bridge called br-h201-l2, br-h202-l2 simulating connection to model 7050qx32s with again two virtual 10g server host from physical port 1 and 2 . the difference between this two arista model is in case of 7050qx32, a 40g qsfp+ breakout cable that has 4 sfp+ cage on one end, is used to connect to two servers to the qsfp+ port1. however for model 7050qx32s, port1/2/3/4 all of them are sfp+ cage but port5 is qsfp+cage and internally when sfp+ lanes are activated, port5 is not as they are internally hardwired that way. so, two sfp+ cable from port1/2 is used to connect to two host servers. sonic is running in both of these models. now break-out configuration is needed to configure the sonic switch os to work. please describe in detail how the simulation with ovs bridge and it's respective veth interfaces will connect with the host servers and switch models described above. assume all these are provisioned as virtual instances in an ubuntu machine. decribe with pictorial diagram to understand better and troubleshoot easily. provide respective sonic commands to configure respecive interfaces ovs ports etc.

To simulate and configure this setup on a single Ubuntu host, you need to map Open vSwitch (OVS) bridges to the virtualized SONiC switches using Virtual Ethernet (veth) pairs.
Here is the comprehensive guide, architectural layout, and configuration steps for both Arista hardware profiles simulated in SONiC.
## Network Architecture Diagram
```
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
```
Inside your Ubuntu emulation host, the connections are mapped via veth pipes. One end of the pipe plugs into the OVS bridge (representing the server layer), and the other end maps directly to the network interfaces assigned to the SONiC container or virtual machine.

   1. Scenario 1 (7050QX32): Ports Ethernet0 through Ethernet3 inside SONiC represent the breakout lanes of the physical Port 1 (QSFP+). Your configuration maps Server 1 to Lane 0 (Ethernet0) and Server 2 to Lane 1 (Ethernet1).
   2. Scenario 2 (7050QX32S): Ports Ethernet0 and Ethernet1 are native 10G SFP+ cages. No splitting occurs; they connect 1:1 to Server 3 and Server 4 respectively.
```
------------------------------
## Step 1: Ubuntu Linux Shell Infrastructure Configuration
```
Run these commands on your Ubuntu host to build the OVS bridges, instantiate the veth pairs, and link them together.

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

Note: The veth-swX-pX ends must be bound to your virtual SONiC instance runtime (e.g., passed as arguments via KVM/QEMU network flags or bound to Docker containers via a container runtime configuration).
```
------------------------------
## Step 2: SONiC Switch OS Breakout Configurations
```
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
```
------------------------------
## Step 3: Troubleshooting and Verification Flow
```
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
```   
   
To help optimize this virtual infrastructure, are you deploying these SONiC instances via Docker containers or KVM/QEMU virtual machines, and which SONiC release version are you using?

