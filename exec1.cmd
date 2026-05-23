# 1. Check FRR is using correct interface names
ssh ubuntu@172.16.2.47 "sudo vtysh -c 'show running-config' | grep -A2 'neighbor'"

# 2. Check IPv6 link-local on fabric interfaces (required for BGP unnumbered)
ssh ubuntu@172.16.2.47 "ip -6 addr show enp2s0; ip -6 addr show enp3s0"

# 3. Check interfaces are up and have carrier
ssh ubuntu@172.16.2.47 "ip link show enp2s0; ip link show enp3s0"

# 4. Check if FRR bgpd is actually running
ssh ubuntu@172.16.2.47 "sudo systemctl status frr | head -15"

# 5. Check FRR BGP neighbor detail for the specific error
ssh ubuntu@172.16.2.47 "sudo vtysh -c 'show bgp neighbor enp2s0' | head -30"

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
# Check failing servers — look for NO-CARRIER
ssh ubuntu@Host34_1 "ip link show enp2s0; ip link show enp3s0"
ssh ubuntu@HostB12_2 "ip link show enp2s0; ip link show enp3s0"
ssh ubuntu@MonitorSrv "ip link show enp2s0; ip link show enp3s0"

# Compare with working server — should show LOWER_UP
ssh ubuntu@Host12_1 "ip link show enp2s0; ip link show enp3s0"

#########################################################
# List all libvirt networks/bridges
virsh net-list --all

# Check which networks each VM's NICs are attached to
virsh domiflist Host34_1
virsh domiflist MonitorSrv
virsh domiflist HostB12_2

# Compare with working VM
virsh domiflist Host12_1
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


# Failing server — check for fe80:: on fabric NICs
ssh ubuntu@Host34_1 "ip -6 addr show dev enp2s0; ip -6 addr show dev enp3s0; sysctl net.ipv6.conf.enp2s0.disable_ipv6; sysctl net.ipv6.conf.enp3s0.disable_ipv6"

# Working server — for comparison
ssh ubuntu@Host12_1 "ip -6 addr show dev enp2s0; ip -6 addr show dev enp3s0; sysctl net.ipv6.conf.enp2s0.disable_ipv6; sysctl net.ipv6.conf.enp3s0.disable_ipv6"

ssh ubuntu@Host34_1 "sudo sysctl -w net.ipv6.conf.enp2s0.disable_ipv6=0; sudo sysctl -w net.ipv6.conf.enp3s0.disable_ipv6=0; sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0"
ssh ubuntu@Host34_2 "sudo sysctl -w net.ipv6.conf.enp2s0.disable_ipv6=0; sudo sysctl -w net.ipv6.conf.enp3s0.disable_ipv6=0; sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0"
ssh ubuntu@HostB12_2 "sudo sysctl -w net.ipv6.conf.enp2s0.disable_ipv6=0; sudo sysctl -w net.ipv6.conf.enp3s0.disable_ipv6=0; sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0"
ssh ubuntu@MonitorSrv "sudo sysctl -w net.ipv6.conf.enp2s0.disable_ipv6=0; sudo sysctl -w net.ipv6.conf.enp3s0.disable_ipv6=0; sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0"

ssh ubuntu@Host34_1 "sudo systemctl restart frr"
ssh ubuntu@Host34_2 "sudo systemctl restart frr"
ssh ubuntu@HostB12_2 "sudo systemctl restart frr"
ssh ubuntu@MonitorSrv "sudo systemctl restart frr"

$$$$$$$$$$$$$$$$$$$$$3'RD$$$$$$$$$$$$$$$$$
##################3rd########################


# Check Leaf_L3's vNIC order vs working Leaf_L1
ssh nh1221@R620 "virsh domiflist Leaf_L3; echo '---'; virsh domiflist Leaf_L1"

# Check if Ethernet0 on Leaf_L3 actually has IPv6 link-local (from SONiC)
ssh admin@Leaf_L3 "ip -6 addr show Ethernet0 2>/dev/null || echo 'NO SUCH INTERFACE'"

# Check what Linux interfaces exist inside Leaf_L3
ssh admin@Leaf_L3 "ip link show | grep -E '^[0-9]+:' | head -40"

# Test L2 reachability: can Host34_1 see anything on the link?
ssh ubuntu@Host34_1 "ping6 -c 3 -I enp2s0 ff02::1"


# 1. Remove OLD incorrect BGP neighbors from switches
ssh admin@Leaf_L3 "docker exec bgp vtysh -c 'conf t' -c 'router bgp 65013' -c 'no neighbor Ethernet1 interface v6only' -c 'no neighbor Ethernet1 remote-as 65105'"
ssh admin@Leaf_L4 "docker exec bgp vtysh -c 'conf t' -c 'router bgp 65014' -c 'no neighbor Ethernet2 interface v6only' -c 'no neighbor Ethernet2 remote-as 65105'"
ssh admin@Border_Leaf1 "docker exec bgp vtysh -c 'conf t' -c 'router bgp 65021' -c 'no neighbor Ethernet21 interface v6only' -c 'no neighbor Ethernet21 remote-as 65107' -c 'no neighbor Ethernet22 interface v6only' -c 'no neighbor Ethernet22 remote-as 65108'"
ssh admin@Border_Leaf2 "docker exec bgp vtysh -c 'conf t' -c 'router bgp 65022' -c 'no neighbor Ethernet21 interface v6only' -c 'no neighbor Ethernet21 remote-as 65107' -c 'no neighbor Ethernet22 interface v6only' -c 'no neighbor Ethernet22 remote-as 65108'"

# 2. Enable IPv6 link-local on the CORRECT ports (all failing switches)
for sw in Leaf_L3 Leaf_L4; do
  ssh admin@$sw 'sonic-db-cli CONFIG_DB HSET "INTERFACE|Ethernet0" "ipv6_use_link_local_only" "enable"'
  ssh admin@$sw 'sonic-db-cli CONFIG_DB HSET "INTERFACE|Ethernet4" "ipv6_use_link_local_only" "enable"'
done
for sw in Border_Leaf1 Border_Leaf2; do
  ssh admin@$sw 'sonic-db-cli CONFIG_DB HSET "INTERFACE|Ethernet24" "ipv6_use_link_local_only" "enable"'
  ssh admin@$sw 'sonic-db-cli CONFIG_DB HSET "INTERFACE|Ethernet28" "ipv6_use_link_local_only" "enable"'
done

# 3. Remove any breakout that was applied (revert to native 40G)
for sw in Leaf_L3 Leaf_L4; do
  ssh admin@$sw 'config interface breakout Ethernet0 1x40G'  # If breakout was applied
done

# 4. Re-run the leaf-server BGP playbook with corrected ports
cd /mnt/c/Users/nh1221/data-center/claude-opus-4.6-v1
ansible-playbook playbooks/deploy_leaf_server_bgp.yml -t deploy --limit "Leaf_L3,Leaf_L4,Border_Leaf1,Border_Leaf2"

# 5. Verify
ansible-playbook playbooks/deploy_leaf_server_bgp.yml -t verify


