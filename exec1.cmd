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






@@@@@@@@@@@@@@@@@@@@@@@@@@@@@4th@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
ssh admin@Border_Leaf1 "docker exec bgp vtysh -c 'conf t' -c 'router bgp 65021' -c 'no neighbor Ethernet22'"
ssh admin@Border_Leaf2 "docker exec bgp vtysh -c 'conf t' -c 'router bgp 65022' -c 'no neighbor Ethernet22'"

ssh ubuntu@Host34_1 "systemctl is-active frr; sudo vtysh -c 'show bgp summary'; ip -6 addr show dev enp2s0; ip -6 addr show dev enp3s0; sudo vtysh -c 'show run' | grep -A5 'neighbor enp'"
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


############################-5th-#######################################
# Check MonitorSrv bridge wiring — are BL1 and BL2 on the same bridge?
ssh nh1221@R620 "brctl show br-MS-BL1 2>/dev/null; echo '---'; brctl show br-MS-BL2 2>/dev/null; echo '---'; virsh domiflist MonitorSrv"

# Check Host34_1 bridge — who is actually on it?
ssh nh1221@R620 "brctl show br-H341-L3; echo '---'; brctl show br-H341-L4"

# Test L2 reachability from Host34_1
ssh ubuntu@Host34_1 "ping6 -c 2 -I enp2s0 ff02::1%enp2s0 2>&1 | tail -5; echo '---'; ip -6 neigh show dev enp2s0"

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@-6th-@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
ssh admin@Leaf_L3 "show interfaces status Ethernet0; show interfaces status Ethernet4; echo '---'; ip link show eth1; echo '---'; ip -6 addr show Ethernet0; echo '---'; ip -6 neigh show dev Ethernet0; echo '---'; sonic-db-cli CONFIG_DB HGETALL 'PORT|Ethernet0'"

If breakout was applied and broke the VS SAI, try reverting it:

ssh admin@Leaf_L3 "sudo config interface breakout Ethernet0 '1x40G[10G]' -y"
ssh admin@Leaf_L4 "sudo config interface breakout Ethernet0 '1x40G[10G]' -y"


Or if that doesn't work, restart syncd to rebuild the internal bridges:

ssh admin@Leaf_L3 "sudo systemctl restart syncd"
ssh admin@Leaf_L4 "sudo systemctl restart syncd"
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


#########################-7th-################################################

Fix — restore correct PORT config and restart syncd:

# Fix Ethernet0 CONFIG_DB on Leaf_L3
ssh admin@Leaf_L3 "sonic-db-cli CONFIG_DB HMSET 'PORT|Ethernet0' lanes '125,126,127,128' speed '40000' index '1'; sudo systemctl restart syncd"

# Fix Ethernet0 CONFIG_DB on Leaf_L4
ssh admin@Leaf_L4 "sonic-db-cli CONFIG_DB HMSET 'PORT|Ethernet0' lanes '125,126,127,128' speed '40000' index '1'; sudo systemctl restart syncd"

Note: restarting syncd will briefly drop ALL data-plane sessions on those switches (spine and Host34_2), but they'll re-establish in ~60-120 seconds.

Then after ~2 minutes, verify:

ssh admin@Leaf_L3 "docker exec bgp vtysh -c 'show bgp summary'"
ssh admin@Border_Leaf1 "docker exec bgp vtysh -c 'show bgp summary'"

######################################################
###############%%%%%%%%%%%%%%%-8th-%%%%%%%%%%%%%%%%%%%%%%%%

Exit_Router1 (172.16.2.98)
ssh admin@172.16.2.98

# 1. Check current state
/routing/bgp/template/print
/routing/bgp/connection/print detail

# 2. Fix the template (set local AS + router-id)
/routing/bgp/template/set [find name="fabric"] as=65253 router-id=10.0.99.1

# 3. Fix the connection (set remote AS and ensure template link)
/routing/bgp/connection/set [find name~"Border"] \
  remote.as=65021 \
  templates=fabric \
  local.role=ebgp \
  output.redistribute=connected,static \
  output.default-originate=always \
  disabled=no

# 4. If connection doesn't exist with that name, find and fix by address:
/routing/bgp/connection/set [find where remote.address="10.0.253.0/32"] \
  remote.as=65021 as=65253 \
  templates=fabric \
  local.role=ebgp \
  output.redistribute=connected,static \
  output.default-originate=always \
  disabled=no

# 5. Disable and re-enable to restart the session
/routing/bgp/connection/disable [find where remote.address~"10.0.253"]
/routing/bgp/connection/enable [find where remote.address~"10.0.253"]

# 6. Verify
:delay 5s
/routing/bgp/session/print

Expected output after fix:

Flags: E - established
 0 E remote.address=10.0.253.0 .as=65021
     local.address=10.0.253.1 .as=65253 ebgp
     prefix-count=19
	 
	 
Exit_Router2 (172.16.2.99)

ssh admin@172.16.2.99	 

# 1. Fix the template
/routing/bgp/template/set [find name="fabric"] as=65254 router-id=10.0.99.2

# 2. Fix the connection
/routing/bgp/connection/set [find where remote.address~"10.0.253.2"] \
  remote.as=65022 as=65254 \
  templates=fabric \
  local.role=ebgp \
  output.redistribute=connected,static \
  output.default-originate=always \
  disabled=no

# 3. Bounce the session
/routing/bgp/connection/disable [find where remote.address~"10.0.253"]
/routing/bgp/connection/enable [find where remote.address~"10.0.253"]

# 4. Verify
:delay 5s
/routing/bgp/session/print

If template "fabric" doesn't exist at all
If /routing/bgp/template/print shows nothing or a differently-named template, create from scratch:

Exit_Router1:

/routing/bgp/template/remove [find]
/routing/bgp/template/add name=fabric as=65253 router-id=10.0.99.1 \
  address-families=ip disabled=no

/routing/bgp/connection/remove [find]
/routing/bgp/connection/add name=to_Border_Leaf1 \
  remote.address=10.0.253.0/32 remote.as=65021 \
  local.role=ebgp local.address=10.0.253.1 \
  templates=fabric routing-table=main as=65253 multihop=no disabled=no \
  output.redistribute=connected,static output.default-originate=always
  
  Exit_Router2:
  
  /routing/bgp/template/remove [find]
/routing/bgp/template/add name=fabric as=65254 router-id=10.0.99.2 \
  address-families=ip disabled=no

/routing/bgp/connection/remove [find]
/routing/bgp/connection/add name=to_Border_Leaf2 \
  remote.address=10.0.253.2/32 remote.as=65022 \
  local.role=ebgp local.address=10.0.253.3 \
  templates=fabric routing-table=main as=65254 multihop=no disabled=no \
  output.redistribute=connected,static output.default-originate=always
  
  Verification from Border_Leaf side
After fixing, confirm from Border_Leaf1:

ssh admin@Border_Leaf1 "docker exec bgp vtysh -c 'show bgp summary'" | grep 10.0.253.1


Expected: state changes from Connect → shows a prefix count (like 1 or more).

Also verify routes are received:

ssh admin@Border_Leaf1 "docker exec bgp vtysh -c 'show ip bgp neighbors 10.0.253.1 received-routes'"

Summary: The AS numbers on the MikroTik BGP connections are 0 instead of 65253/65254. The remote.as is also 0 instead of 65021/65022. Setting these values and bouncing the connection will establish the sessions.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&-9th-&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
Step 1: Verify the link interface IP on Border_Leaf

# What interface has 10.0.253.0 on Border_Leaf1?
ssh admin@Border_Leaf1 "docker exec database redis-cli -n 4 keys 'INTERFACE|*253*'"
ssh admin@Border_Leaf1 "ip addr show | grep 10.0.253"

# Same for Border_Leaf2
ssh admin@Border_Leaf2 "docker exec database redis-cli -n 4 keys 'INTERFACE|*253*'"
ssh admin@Border_Leaf2 "ip addr show | grep 10.0.253"

If no output → The exit-router-facing interface on Border_Leaf doesn't have an IP. This is the root cause. You need to assign it.

Step 2: Check which physical port connects to the exit router
# Check interface status on Border_Leaf1

ssh admin@Border_Leaf1 "show interfaces status" | grep -i "Ethernet0\|Ethernet4"

# Or check all interfaces for the one that SHOULD connect to exit router
ssh admin@Border_Leaf1 "show ip interfaces"

Based on the Arista 7050QX-32S layout (QSFP+1 = Ethernet0, lanes 9-12), the exit router link is likely Ethernet0.

Step 3: Ping test from MikroTik side

ssh admin@172.16.2.98   # Exit_Router1

/ping 10.0.253.0 count=3
/interface/print where name~"sfp"
/ip/address/print where address~"10.0.253"

Step 4: Ping test from Border_Leaf side

ssh admin@Border_Leaf1 "ping -c 3 10.0.253.1"

Most Likely Fix: Assign IP to Border_Leaf exit interface
If Step 1 shows the IP isn't assigned, here's how to fix it:

Border_Leaf1 (exit port = Ethernet0, IP = 10.0.253.0/31):

ssh admin@Border_Leaf1

# Add IP to the exit-facing interface in config_db
sudo config interface ip add Ethernet0 10.0.253.0/31

# Verify
show ip interfaces | grep Ethernet0
ping 10.0.253.1

Border_Leaf2 (exit port = Ethernet0, IP = 10.0.253.2/31):

ssh admin@Border_Leaf2

sudo config interface ip add Ethernet0 10.0.253.2/31

# Verify
show ip interfaces | grep Ethernet0
ping 10.0.253.3

Step 5: If ping works but BGP still won't connect — check MikroTik firewall

# On Exit_Router1:
/ip/firewall/filter/print where chain=input action=drop
# If there's a drop-all rule at the end, ensure BGP accept rule exists BEFORE it:
/ip/firewall/filter/add chain=input action=accept protocol=tcp dst-port=179 \
  src-address=10.0.253.0/24 place-before=[find where chain=input action=drop]
  
  Step 6: Clean up duplicate templates (cosmetic but avoids confusion)

# Exit_Router1 — remove duplicate template #2
/routing/bgp/template/remove 2

# Exit_Router2 — same
/routing/bgp/template/remove 2

&&&&&&&&&&&&&&&&&&&&&&&&&&&&-10TH-&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&

MikroTik firewall is correct — rule #3 explicitly allows TCP 179 from 10.0.253.0/24. (Side note: rules 9-17 are duplicates of 0-8, harmless but should be cleaned up later.)

The problem is on the SONiC/Border_Leaf side. Run these next:

Check 1: SONiC iptables on Border_Leaf1
ssh admin@Border_Leaf1 "sudo iptables -L INPUT -n --line-numbers" | grep -A2 -B2 "179\|DROP\|REJECT"
Or get the full chain:
ssh admin@Border_Leaf1 "sudo iptables -L INPUT -n --line-numbers"

Check 2: Direct TCP test from Border_Leaf1 → Exit_Router1 port 179
ssh admin@Border_Leaf1 "bash -c 'echo | nc -zv -w3 10.0.253.1 179 2>&1'"

If this says Connection refused → MikroTik BGP isn't listening (unlikely since session exists).
If this hangs/times out → something is blocking in the return path.
If this says succeeded/open → TCP works, issue is in BGP OPEN exchange.

Check 3: TCP test from Exit_Router1 → Border_Leaf1 port 179
# On Exit_Router1:
/ip/firewall/connection/print where dst-address~"10.0.253.0"
This shows if MikroTik's outbound TCP SYN to Border_Leaf1:179 is being tracked.

Check 4: KVM host bridge netfilter
# On your Dell R620 hypervisor (not a VM):
sudo sysctl net.bridge.bridge-nf-call-iptables
# On your Dell R620 hypervisor (not a VM):
sudo sysctl net.bridge.bridge-nf-call-iptables
If 1 → this is likely your culprit — the hypervisor is applying its own iptables to VM-to-VM traffic crossing the bridge, blocking TCP 179 even though ICMP passes (many host firewalls allow ICMP but drop unknown TCP).



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%-11th-%%%%%%%%%%%%%%%%%
# Step 1: Remove all stale vnet ports from every OVS bridge
sudo ovs-vsctl list-br | while read br; do
  sudo ovs-vsctl list-ports "$br" 2>/dev/null | grep '^vnet' | while read port; do
    echo "Removing stale port $port from $br"
    sudo ovs-vsctl --if-exists del-port "$br" "$port"
  done
done

# Step 2: Verify no vnet ports remain
sudo ovs-vsctl list-br | xargs -I{} sudo ovs-vsctl list-ports {} | grep vnet
# (should return nothing)

# Step 3: Start all VMs
for vm in $(virsh list --all --name); do
  virsh start "$vm" && echo "Started $vm" || echo "FAILED: $vm"
done

# Step 4: Verify
virsh list --all

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%-12th-%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Before re-running, you'll want to clean up the stale CONFIG_DB-based BGP neighbor entry from the previous run. Run this on each border leaf first:

ssh admin@Border_Leaf1 "sonic-db-cli CONFIG_DB del 'BGP_NEIGHBOR|10.0.253.1'; sonic-db-cli CONFIG_DB del 'BGP_NEIGHBOR_AF|10.0.253.1|ipv4'; sonic-db-cli CONFIG_DB del 'BGP_NEIGHBOR_AF|10.0.253.1|ipv6'"
ssh admin@Border_Leaf2 "sonic-db-cli CONFIG_DB del 'BGP_NEIGHBOR|10.0.253.3'; sonic-db-cli CONFIG_DB del 'BGP_NEIGHBOR_AF|10.0.253.3|ipv4'; sonic-db-cli CONFIG_DB del 'BGP_NEIGHBOR_AF|10.0.253.3|ipv6'"
Then also remove the stale IP/interface entries and restart BGP to get a clean slate:
ssh admin@Border_Leaf1 "config interface ip remove Ethernet5/1 10.0.253.0/31 2>/dev/null; sudo systemctl restart bgp"
ssh admin@Border_Leaf2 "config interface ip remove Ethernet5/1 10.0.253.2/31 2>/dev/null; sudo systemctl restart bgp"
Then re-run:
ansible-playbook playbooks/deploy_breakout.yml -i inventory/hosts.yml --limit border_leaves
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

