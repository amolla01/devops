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

