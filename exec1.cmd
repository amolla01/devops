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

%%%%%%%%%%%%%%%%%%%%%%%%%%==13th==%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Border_Leaf1: Reverse breakout, restore Ethernet0
ssh admin@Border_Leaf1 bash -c '
  sonic-db-cli CONFIG_DB del "PORT|Ethernet5/1"
  sonic-db-cli CONFIG_DB del "PORT|Ethernet5/2"
  sonic-db-cli CONFIG_DB del "PORT|Ethernet5/3"
  sonic-db-cli CONFIG_DB del "PORT|Ethernet5/4"
  sonic-db-cli CONFIG_DB del "INTERFACE|Ethernet5/1"
  sonic-db-cli CONFIG_DB del "INTERFACE|Ethernet5/1|10.0.253.0/31"
  sonic-db-cli CONFIG_DB hmset "PORT|Ethernet0" lanes "9,10,11,12" speed "40000" alias "Ethernet5/1" index "5" admin_status "up" mtu "1500"
  sonic-db-cli CONFIG_DB hset "INTERFACE|Ethernet0" "NULL" "NULL"
  sonic-db-cli CONFIG_DB hset "INTERFACE|Ethernet0|10.0.253.0/31" "NULL" "NULL"
  config save -y
  sudo config reload -y
'
# Border_Leaf2: Same
ssh admin@Border_Leaf2 bash -c '
  sonic-db-cli CONFIG_DB del "PORT|Ethernet5/1"
  sonic-db-cli CONFIG_DB del "PORT|Ethernet5/2"
  sonic-db-cli CONFIG_DB del "PORT|Ethernet5/3"
  sonic-db-cli CONFIG_DB del "PORT|Ethernet5/4"
  sonic-db-cli CONFIG_DB del "INTERFACE|Ethernet5/1"
  sonic-db-cli CONFIG_DB del "INTERFACE|Ethernet5/1|10.0.253.2/31"
  sonic-db-cli CONFIG_DB hmset "PORT|Ethernet0" lanes "9,10,11,12" speed "40000" alias "Ethernet5/1" index "5" admin_status "up" mtu "1500"
  sonic-db-cli CONFIG_DB hset "INTERFACE|Ethernet0" "NULL" "NULL"
  sonic-db-cli CONFIG_DB hset "INTERFACE|Ethernet0|10.0.253.2/31" "NULL" "NULL"
  config save -y
  sudo config reload -y

%%%%%%%%%%%%%%%%%%%%%%%%%%==14th==%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Run deploy_breakout.yml — but do the two manual cleanup commands first since the playbook won't clean up the stale Ethernet5/1 IP entry or the corrupted Ethernet3 speed:

Step 1 — Quick manual cleanup (one liner):
ssh admin@Border_Leaf1 "sonic-db-cli CONFIG_DB del 'INTERFACE|Ethernet5/1'; sonic-db-cli CONFIG_DB del 'INTERFACE|Ethernet5/1|10.0.253.0/31'; config interface speed Ethernet3 10000; config save -y"
ssh admin@Border_Leaf2 "sonic-db-cli CONFIG_DB del 'INTERFACE|Ethernet5/1'; sonic-db-cli CONFIG_DB del 'INTERFACE|Ethernet5/1|10.0.253.2/31'; config interface speed Ethernet3 10000; config save -y"

Step 2 — Run the breakout playbook:
ansible-playbook playbooks/deploy_breakout.yml -i inventory/hosts.yml --limit border_leaves
%%%%%%%%%%%%%%%%%%%%%%%%%%==15th==%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
The rejectattr('stdout', 'match', '^[0-9]+$') logic:

'' (empty, port missing) → NOT a pure digit string → included → needs breakout ✓
'9,10,11,12' (multi-lane, not broken out) → NOT pure digits → included → needs breakout ✓
'9' (single lane, already broken out) → pure digits → excluded → skip ✓
Now restore PORT|Ethernet0 on BL2 and re-run:

ssh admin@Border_Leaf2 "sonic-db-cli CONFIG_DB hmset 'PORT|Ethernet0' lanes '9,10,11,12' speed '40000' alias 'Ethernet5/1' index '5' admin_status 'down' mtu '9100'"
ansible-playbook playbooks/deploy_breakout.yml -i inventory/hosts.yml --limit Border_Leaf2
No reload needed — portsyncd picks up the live CONFIG_DB change within seconds. The playbook will detect 9,10,11,12 → needs breakout → KVM software breakout → wait 10s → configure exit interface on Ethernet0.
'

%%%%%%%%%%%%%%%%%%%%%%%%%%==16th==%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Confirm on BL1:
ssh admin@172.16.2.31 "show interfaces status | grep -E 'Ethernet(20|22|24|28|120|124)'"

Fix on both border leaves:
for iface in Ethernet20 Ethernet22 Ethernet24 Ethernet28 Ethernet120 Ethernet124; do
  sudo config interface startup $iface
done
sudo config save -y

Root Cause 2 — BL2 → Exit_Router2 stuck at Active: ER2 NIC missing from bridge
Look at the OVS output:
Bridge br-BL1-ER1
    Port vnet103    ← BL1 NIC
    Port vnet37     ← Exit_Router1 NIC  ✓ Both sides present

Bridge br-BL2-ER2
    Port vnet70     ← BL2 NIC only
                    ← Exit_Router2 NIC MISSING

br-BL2-ER2 has only one vnet port. Exit_Router2's ether2 NIC is not attached to this bridge — BL2 sends ARP for 10.0.253.3, gets no reply, BGP stays Active forever.

Check on R620:

sudo virsh domiflist Exit_Router2
# Look for which bridge ether2 is wired to — expect br-BL2-ER2
If it's on the wrong bridge or detached, reattach:
sudo virsh detach-interface Exit_Router2 bridge <wrong-bridge> --config
sudo virsh attach-interface Exit_Router2 bridge br-BL2-ER2 --model virtio --config
sudo virsh reboot Exit_Router2
Root Cause 3 — BL1 → Exit_Router1 stuck at Connect: MikroTik ether2 is down
Connect (not Idle or Active) means BL1 is successfully sending TCP SYN to 10.0.253.1 — the L2 bridge is OK (br-BL1-ER1 has both vnet103 + vnet37). But MikroTik is not responding on BGP port 179.

Check on Exit_Router1:


ssh admin@172.16.2.98   # or via -J admin@<R620>
/interface print
/interface enable [find where name=ether2]
/ip address print

ether2 is almost certainly admin-disabled. After enabling it, also verify the BGP peer config points back to BL1:


/routing bgp peer print# expect: address=10.0.253.0, remote-as=65021
/routing bgp peer print
# expect: address=10.0.253.0, remote-as=65021
The spine and server links are purely an admin-down problem — the OVS bridges all have correct two-port wiring (br-BL1-S1, br-BL2-S1, br-BL1-S2, br-BL2-S2 all show two vnet ports each). Once you bring the interfaces up, those BGP sessions should establish within seconds.

%%%%%%%%%%%%%%%%%%%%%%%%%%==17th==%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

1. MikroTik password — you can't SSH in interactively
The script verified SSH key auth works (✓ SSH key auth works for Exit_Router1/2). The password was never set to amolla01 because the script found ER1/ER2 already at the CLI prompt (Case C — they were still logged in from your earlier manual session). The password is likely still empty but RouterOS blocks empty-password SSH login over the network (it only allows empty via console).

Fix — set the password now via console:

virsh console Exit_Router1
# press Enter, should see [admin@Exit_Router1] >
/user set admin password=amolla01
# Ctrl+] to exit

virsh console Exit_Router2
# press Enter
/user set admin password=amolla01
# Ctrl+] to exit

Then ssh admin@172.16.2.98 with amolla01 will work.
2. BGP still "Connect" / "Active" — ER1/ER2 have remote.as=0
Look at the script output:
remote.address=10.0.253.0 .as=0 .hold-time=infinity
The BGP connection was created in a previous run (before the Tcl fix) with as=0 because the variable wasn't substituted. The script's idempotent check (find where remote.address=...) found the existing broken entry and skipped re-creation.

Fix — delete and re-add on both ERs:
ssh -i ~/id_dc_lab admin@172.16.2.98
# or virsh console Exit_Router1

/routing bgp connection remove [find]
/routing bgp connection add name=to-BL1 as=65253 remote.address=10.0.253.0 remote.as=65021 router-id=10.0.253.1 local.role=ebgp
/routing bgp connection print
# Ctrl+] if on console
ssh -i ~/id_dc_lab admin@172.16.2.98
# or virsh console Exit_Router1

/routing bgp connection remove [find]
/routing bgp connection add name=to-BL1 as=65253 remote.address=10.0.253.0 remote.as=65021 router-id=10.0.253.1 local.role=ebgp
/routing bgp connection print
# Ctrl+] if on console
virsh console Exit_Router2
/routing bgp connection remove [find]
/routing bgp connection add name=to-BL2 as=65254 remote.address=10.0.253.2 remote.as=65022 router-id=10.0.253.3 local.role=ebgp
/routing bgp connection print
# Ctrl+]

3. MonitorSrv / BL1/BL2 — br-MS-BL1 has no BL1 vnet
Border_Leaf1/2 have no br-MS-BL1 or br-MS-BL2 NIC in their domiflist. The deploy script put MonitorSrv's NIC at position 7 (br-MS-BL1) but BL1/BL2's NICs at position 5 — however position 5 is also br-MS-BL1 in the bridge list. The script output says "no live vnet found" because awk '$3=="br-MS-BL1"' found no match in BL1's domiflist (all non-pad bridges are br-BL1-ER1, br-HB-BL1, br-HB2-BL1, br-BL1-S2, br-BL1-S1).

The deploy never created the br-MS-BL1 NIC on BL1/BL2. The bridge definition in deploy_lab_v13.sh:

VM_BRIDGES[Border_Leaf1]="br-BL1-ER1,@4,br-HB-BL1,br-HB2-BL1,br-MS-BL1,@22,br-BL1-S2,br-BL1-S1"

Position 5 = br-MS-BL1, but there are 28 pad bridges between position 2 and the @22 marker — it got pushed to a pad NIC. The deploy worked correctly BUT with type=bridge (not OVS), so even though br-MS-BL1 was assigned, libvirt's brctl addif silently failed. The vnet IS there but named differently than br-MS-BL1 in domiflist column 3.

Actually — looking more carefully: BL1's NIC at vnet44 should be br-MS-BL1 (position 5 after the @4 pad skip). But domiflist shows it as br-pad. This means the deploy mapped it wrong, OR the XML was overwritten.

Quick fix — manually add the correct BL vnets to OVS:

First remove the bogus BL1_VNET entry:

sudo ovs-vsctl del-port br-MS-BL1 BL1_VNET

Then check which vnet corresponds to BL1's 5th NIC (MAC 52:54:00:69:d4:ab = vnet44):
# Verify by checking the XML
virsh dumpxml Border_Leaf1 | grep -A3 "br-MS-BL1"
virsh dumpxml Border_Leaf2 | grep -A3 "br-MS-BL2"
# Verify by checking the XML
virsh dumpxml Border_Leaf1 | grep -A3 "br-MS-BL1"
virsh dumpxml Border_Leaf2 | grep -A3 "br-MS-BL2"
If those return nothing, BL1/BL2 were never given br-MS-BL1/BL2 NICs and you need to hot-add them or restart BL1/BL2 with corrected XML.


XXXXXXXXXXXXXXXXXXXXXXXXXX==18th==XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
Which command to execute now since following is returning nothing: # Verify by checking the XML
virsh dumpxml Border_Leaf1 | grep -A3 "br-MS-BL1"
virsh dumpxml Border_Leaf2 | grep -A3 "br-MS-BL2"


Confirmed that BL1 lacked NICs for br-MS-BL1
The user confirmed that virsh dumpxml Border_Leaf1 | grep -A3 "br-MS-BL1" returns nothing. This means BL1/BL2 were never given NICs connected to br-MS-BL1/br-MS-BL2 OVS bridges. The deploy script has the bridge mapping but the actual VMs don't have those NICs.

Looking at the deploy script's bridge definition:

VM_BRIDGES[Border_Leaf1]="br-BL1-ER1,@4,br-HB-BL1,br-HB2-BL1,br-MS-BL1,@22,br-BL1-S2,br-BL1-S1"

So the script maps out specific NIC positions: the first one connects to br-BL1-ER1, then there's padding, followed by br-HB-BL1 and br-HB2-BL1, then br-MS-BL1 at position 7, more padding, and finally the S2 and S1 bridges at the end.

vnet43 is mapped to br-HB2-BL1, and then vnet44 should connect to br-MS-BL1 for NIC 7, but it's showing br-pad instead. This looks like a deployment script bug where the MS-BL1 bridge got incorrectly mapped to a pad bridge.
Since the grep search found no reference to br-MS-BL1 in BL1's XML, the NIC was never properly connected. Rather than hot-attaching a new NIC (which would mess up the ordering), I should modify vnet44 directly by removing it from br-pad and attaching it to br-MS-BL1 using OVS commands.

For BL2, I need to find the equivalent vnet at position 7 — looking at the NIC mapping, vnet77 is currently on br-pad but should be on br-MS-BL2 instead, since it corresponds to Ethernet28.

The deploy script has a bug where it placed these NICs on br-pad rather than the correct bridges. Since these are bridge-type NICs with taps connected to br-pad, I can move them to fix the mapping. The first step is to move vnet44 from br-pad.

Actually, wait—I need to reconsider. With type=bridge, libvirt uses Linux bridging, not OVS. If br-pad is an OVS bridge, the brctl command would have failed, so the vnet44 tap might not actually be connected to br-pad at all.

But looking at the OVS output, vnet44 and vnet77 are both clearly listed as ports in br-pad. So the fix is to move vnet44 to br-MS-BL1 and vnet77 to br-MS-BL2, and also remove that bogus "BL1_VNET" port from br-MS-BL1. I'll need to update the XML configs too to make these changes persist across restarts.

Now I should bundle together all the fixes needed—the port moves, the password issue, and the BGP configuration—into a single set of commands to run.

The BL1/BL2 br-MS-BL1/br-MS-BL2 NICs were deployed as br-pad by mistake. Counting positions in domiflist:

BL1 vnet44 = NIC position 7 = Ethernet28 → should be br-MS-BL1, currently in br-pad
BL2 vnet77 = NIC position 7 = Ethernet28 → should be br-MS-BL2, currently in br-pad
Run all three fixes in sequence:

# ── Fix 1: Move BL vnets from br-pad to correct OVS bridges ──
sudo ovs-vsctl del-port br-pad vnet44
sudo ovs-vsctl add-port br-MS-BL1 vnet44
sudo ovs-vsctl del-port br-MS-BL1 BL1_VNET   # remove bogus entry from earlier

sudo ovs-vsctl del-port br-pad vnet77
sudo ovs-vsctl add-port br-MS-BL2 vnet77

# verify 2 ports each
sudo ovs-vsctl list-ports br-MS-BL1
sudo ovs-vsctl list-ports br-MS-BL2

# ── Fix 2: Set MikroTik password via console ──
virsh console Exit_Router1
# press Enter → should see [admin@Exit_Router1] >
# type:  /user set admin password=amolla01
# then Ctrl+]

virsh console Exit_Router2
# press Enter → should see [admin@Exit_Router2] >
# type:  /user set admin password=amolla01
# then Ctrl+]

# ── Fix 3: Fix BGP (remote.as=0 → correct ASN) ──
virsh console Exit_Router1
# /routing bgp connection remove [find]
# /routing bgp connection add name=to-BL1 as=65253 remote.address=10.0.253.0 remote.as=65021 router-id=10.0.253.1 local.role=ebgp
# /routing bgp connection print
# Ctrl+]

virsh console Exit_Router2
# /routing bgp connection remove [find]
# /routing bgp connection add name=to-BL2 as=65254 remote.address=10.0.253.2 remote.as=65022 router-id=10.0.253.3 local.role=ebgp
# /routing bgp connection print
# Ctrl+]

ssh admin@172.16.2.31 "docker exec bgp vtysh -c 'show bgp summary'"

All three neighbors (MonitorSrv, ER1, ER2) should transition to Established.


ZZZZZZZZZZZZZZZZZZZZZZZZZ==19th==ZZZZZZZZZZZZZZZZZZZZZZZZZZZZ
Great progress! MonitorSrv is now Established on both BL1 and BL2. The remaining issue is ER1 and ER2 BGP still showing "Connect" and "Active".

Looking at the problems:

ER1: The BGP session shows remote.as=0 in the session output even after re-adding the connection. Also notice the connection still shows local.default-address=10.0.253.1 — this is good. But the session print showed remote.as=0 which means the old stale session is still lingering. Wait, but we removed and re-added... Actually looking more carefully, after the remove and re-add:

The connection configuration looks correct now with the proper remote address and AS number set. But the session disappeared from the output entirely and hasn't re-established yet, while BL1 is still stuck in "Connect" state trying to reach ER1.

I'm wondering if the issue is that ER1 needs local.address specified explicitly instead of relying on local.default-address — even though the IP 10.0.253.1 is definitely configured on the interface, RouterOS might not be binding the BGP session to it correctly without an explicit local address setting. The error message from ER2 confirms it's missing the local.address binding, so I need to add local.address=10.0.253.1 for ER1 and local.address=10.0.253.3 for ER2 to fix the BGP peer connections.

MonitorSrv is now Established on both BL1 and BL2 — great!

The ER BGP issue is clear from ER2's error message: cannot listen to incoming connections, missing 'local-address'

The add command used router-id= but didn't set local.address=. RouterOS needs local.address to bind and accept incoming BGP connections. Fix both:

ssh -i ~/id_dc_lab admin@172.16.2.98
/routing bgp connection remove [find]
/routing bgp connection add name=to-BL1 as=65253 remote.address=10.0.253.0 remote.as=65021 local.address=10.0.253.1 router-id=10.0.253.1 local.role=ebgp
/routing bgp connection print
# wait 10s then:
/routing bgp session print
# quit (Ctrl+C)

ssh -i ~/id_dc_lab admin@172.16.2.99
/routing bgp connection remove [find]
/routing bgp connection add name=to-BL2 as=65254 remote.address=10.0.253.2 remote.as=65022 local.address=10.0.253.3 router-id=10.0.253.3 local.role=ebgp
/routing bgp connection print
# wait 10s then:
/routing bgp session print
# quit (Ctrl+C)


The key difference: local.address=10.0.253.X tells RouterOS which IP to bind TCP:179 on. Without it, it can't accept inbound connections from BL1/BL2.


YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY==20th==YYYYYYYYYYYYYYYYYYYYYYYYYY
Two problems are clear:

ER2: The script showed /interface enable ether2 → no such item. ER2 doesn't have ether2 — after the Phase 4 rebuild the interface may be named differently.
ER1: Session shows remote.as=0 — meaning the TCP handshake from BL1 is reaching ER1 but something is wrong with the BGP negotiation, or the old stale session hasn't cleared.
Run these diagnostics:

ssh -i ~/id_dc_lab admin@172.16.2.98
/interface print
/ping 10.0.253.0 count=3
/routing bgp session print detail
quit

ssh -i ~/id_dc_lab admin@172.16.2.99
/interface print
/ip address print
quit
ER2 likely has ether1 only (its data NIC might be named ether1 if the management NIC got renamed or removed during the rebuild). We need to see what interfaces exist and which one is connected to br-BL2-ER2, then add the IP to the correct interface.
