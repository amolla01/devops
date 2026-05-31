virsh dumpxml Exit_Router1 | grep -A3 -B2 br-BL1-ER1
virsh dumpxml Exit_Router2 | grep -A3 -B2 br-BL2-ER2

ssh Border_Leaf1 "ping -c 3 10.0.253.1"
ssh Border_Leaf2 "ping -c 3 10.0.253.3"
ssh Exit_Router1 '/ping 10.0.253.0 count=3'
ssh Exit_Router2 '/ping 10.0.253.2 count=3'

ssh Border_Leaf1 "sudo timeout 20 tcpdump -ni Ethernet0 tcp port 179 -vv"

ssh Exit_Router1 '/routing bgp connection disable [find where name="to_Border_Leaf1"]; /routing bgp connection enable [find where name="to_Border_Leaf1"]'
ssh Border_Leaf1 "sudo ss -ltnp | grep :179"
ssh Border_Leaf2 "sudo ss -ltnp | grep :179"
Best next script:
data-center/_v1/troubleshooting-scripts/test_tcp179.sh

cd /mnt/c/Users/nh1221/data-center/_v1/troubleshooting-scripts
bash ./test_tcp179.sh

If that still leaves ambiguity, run this next:
data-center/_v1/troubleshooting-scripts/test_tcp_direction.sh

If that suggests SONiC-side listener or namespace weirdness, run:
data-center/_v1/troubleshooting-scripts/debug_bl1_bgp_ns.sh

And if it points to bridge attachment or wrong fabric port mapping, run:
data-center/_v1/troubleshooting-scripts/diagnose_port_bridge.sh
(venv) nh1221@Lab-ControlNode:/mnt/c/Users/nh1221/data-center/_v1/troubleshooting-scripts$ ./diagnose_port_bridge.sh
Usage: ./diagnose_port_bridge.sh <vm_name> <sonic_port> <mgmt_ip>

Examples:
  ./diagnose_port_bridge.sh Border_Leaf1 Ethernet124 172.16.2.31
  ./diagnose_port_bridge.sh Leaf_L1 Ethernet0 172.16.2.21
(venv) nh1221@Lab-ControlNode:/mnt/c/Users/nh1221/data-center/_v1/troubleshooting-scripts$
Run these next, in this order:

Run the BL1 interface-specific diagnostic:

cd /mnt/c/Users/nh1221/data-center/_v1/troubleshooting-scripts
./debug_bl1_eth0.sh

Run the bridge-mapping diagnostic on the correct port:

./diagnose_port_bridge.sh Border_Leaf1 Ethernet0 172.16.2.31./diagnose_port_bridge.sh Border_Leaf2 Ethernet0 172.16.2.32
./diagnose_port_bridge.sh Border_Leaf1 Ethernet0 172.16.2.31
./diagnose_port_bridge.sh Border_Leaf2 Ethernet0 172.16.2.32

You previously ran it for Ethernet124, which is the spine uplink, not the exit-router link. For this issue the relevant SONiC port is Ethernet0 on both border leaves.

If debug_bl1_eth0.sh does not show an obvious rp_filter or route problem, do one verbose checksum check:

ssh Border_Leaf1 "sudo timeout 10 tcpdump -i Ethernet0 port 179 -nn -vvv"

Then trigger a reconnect from ER1:
ssh Exit_Router1 '/routing bgp connection disable [find where name="to_Border_Leaf1"]; /routing bgp connection enable [find where name="to_Border_Leaf1"]'
ssh Exit_Router1 '/routing bgp connection disable [find where name="to_Border_Leaf1"]; /routing bgp connection enable [find where name="to_Border_Leaf1"]'

What I’m looking for:
If rp_filter is strict or the route/interface state is wrong, debug_bl1_eth0.sh will show it directly.
If diagnose_port_bridge.sh ... Ethernet0 ... shows Ethernet0 mapped to the wrong ethN or wrong OVS bridge, that is the root cause.
If verbose tcpdump shows bad TCP checksum on the SYN that reaches BL1, then we are back in packet-integrity territory despite the current NIC model.

cd /mnt/c/Users/nh1221/data-center/_v1/troubleshooting-scripts
chmod +x diagnose_border_exit_bgp.sh
./diagnose_border_exit_bgp.sh --profile bl1-er1
./diagnose_border_exit_bgp.sh --profile bl2-er2

It also supports fully custom arguments if you want to point it at another pair later:

./diagnose_border_exit_bgp.sh \
  --bl-name Border_Leaf1 --bl-mgmt 172.16.2.31 \
  --er-name Exit_Router1 --er-mgmt 172.16.2.98 \
  --bl-port Ethernet0 --bl-ip 10.0.253.0 --er-ip 10.0.253.1
