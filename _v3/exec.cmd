Option A — from your laptop (remote execution):
./deploy_lab_v3.sh --remote-v13-host nh1221@R810 --profile ubuntu_r810_kvm kvm-destroy
Option B — directly on the R810 (you're already SSH'd in):
cd ~/data-center/_v3
bash deploy_lab_v13.sh --profile ubuntu_r810_kvm destroy


Option 1 — Set up SSH key auth (recommended for automation):
# From WSL (Ubuntu-24.04):
ssh-keygen -t ed25519 -f ~/.ssh/id_r810 -N ""
ssh-copy-id -i ~/.ssh/id_r810 nh1221@R810

# Then run with the key:
./deploy_lab_v3.sh --ssh-key ~/.ssh/id_r810 --remote-v13-host nh1221@R810 --profile ubuntu_r810_kvm kvm-destroy

Option 2 — Just SSH in and run directly (quickest right now):
ssh nh1221@R810
cd ~/data-center/_v3
bash deploy_lab_v13.sh --profile ubuntu_r810_kvm destroy

You can now run with password auth:
./deploy_lab_v3.sh --allow-password --remote-v13-host nh1221@R810 --profile ubuntu_r810_kvm kvm-destroy
What changed:

Preflight now tries key-based auth first; if it fails and --allow-password is set, it falls back to interactive password prompts
Without --allow-password, the error message now shows 4 clear remediation options (set up keys, specify key path, allow password, or SSH in manually)
BatchMode=yes is only enforced when a key is explicitly provided and password auth isn't allowed
Claude Opus 4.6 • 3x
What changed:

REMOTE_V13_PATH no longer defaults to the local WSL path — it defaults to ~/deploy_lab_v13.sh on the remote
If the script isn't found on R810, it auto-copies it from your local _v3/deploy_lab_v13.sh via scp
You only need --remote-v13-path if you want a custom location on the remote
./deploy_lab_v3.sh --ssh-key /mnt/c/Users/nh1221/.ssh/id_dc_lab \
  --remote-v13-host nh1221@R810 \
  --profile ubuntu_r810_kvm kvm-destroy
Now the path will resolve to something like /home/nh1221/deploy_lab_v13.sh which printf '%q' won't mangle. The flow now:

SSHs to R810, runs echo $HOME → gets /home/nh1221
Sets REMOTE_V13_PATH=/home/nh1221/deploy_lab_v13.sh (absolute, no tilde)
Checks if it exists → if not, auto-copies + chmod +x
Runs it with the absolute path (safe through printf '%q')
Try again:


./deploy_lab_v3.sh --ssh-key ~/.ssh/id_dc_lab --remote-v13-host nh1221@R810 --profile ubuntu_r810_kvm kvm-destroy
./deploy_lab_v3.sh --ssh-key ~/.ssh/id_dc_lab --remote-v13-host nh1221@R810 --profile ubuntu_r810_kvm kvm-destroy

XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
Pre-run checklist
# One-time venv setup (if not done already):
cd /mnt/c/Users/nh1221/data-center
python3 -m venv venv
source venv/bin/activate
pip install -r _v3/requirements-ansible.txt

# For later stages (ceph, server networking):
ansible-galaxy collection install -r _v3/requirements-collections.yml

# Run day0:
cd _v3
./deploy_lab_v3.sh day0


ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ
# BGP session state across all hosts (switches + exit routers + servers)
ansible-playbook -i inventory/hosts.yml playbooks/reused/deploy_day1.yml --tags verify
# BGP session state across all hosts (switches + exit routers + servers)
ansible-playbook -i inventory/hosts.yml playbooks/reused/deploy_day1.yml --tags verify

# SONiC switches — IPv4 unicast routes (fabric + server loopbacks)
ansible -i inventory/hosts.yml sonic_switches -m shell \
  -a "vtysh -c 'show bgp ipv4 unicast'" --become

# Exit routers — routes received from border_leaf
ansible -i inventory/hosts.yml exit_routers -m community.routeros.command \
  -a "commands='/routing/bgp/route/print where received'"

# Servers — FRR routes (should see leaf-learned prefixes)
ansible -i inventory/hosts.yml servers -m shell \
  -a "vtysh -c 'show bgp ipv4 unicast'" --become

Or if you want a single compact view showing session state + route count per peer:

ansible -i inventory/hosts.yml all -m shell \
  -a "vtysh -c 'show bgp summary'" --become -e ansible_shell_type=sh 2>/dev/null

What you'll see (without EVPN):

All Leaf↔Server sessions: Established with route counts (server loopbacks + subnets)
Border_Leaf↔Exit_Router: Established with route exchange
L2VPN EVPN AF: Still active on switches (from prior run) but no host-originated Type-2/5 routes yet — those appear only after deploy_evpn_overlay.yml
The underlay (IPv4 unicast) is fully verifiable without EVPN. EVPN adds the overlay tenant routes on top.

YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY
The Connect/never state persists because IPv6 link-local addresses aren't being assigned to the interfaces. The netplan link-local: [ipv6] directive isn't reliably triggering auto-configuration.
Let me gather diagnostics first to confirm the root cause:
# Run this on Host12_1 to see what's actually on the interfaces:
ssh Host12_1 "
echo '=== IPv6 link-local addresses ===';
ip -6 addr show dev enp2s0 | grep 'inet6 fe80';
ip -6 addr show dev enp3s0 | grep 'inet6 fe80';
echo '';
echo '=== IPv6 forwarding status ===';
sysctl net.ipv6.conf.all.forwarding net.ipv6.conf.enp2s0.disable_ipv6 net.ipv6.conf.enp3s0.disable_ipv6;
echo '';
echo '=== FRR running config ===';
sudo vtysh -c 'show running-config' | head -20;
echo '';
echo '=== BGP state ===';
sudo vtysh -c 'show bgp summary' | grep 'Neighbor\|State\|Connect\|Idle';
"
The fix requires explicitly assigning IPv6 link-local in the netplan config itself before netplan applies. Replace the netplan task with:

Now run the playbook again:
ansible-playbook playbooks/reused/deploy_server_networking.yml -i inventory/hosts.yml

ssh Host12_1 "ip -6 addr show dev enp2s0 | grep 'inet6 fe80'"
ssh Host12_1 "ip -6 addr show dev enp3s0 | grep 'inet6 fe80'"

If you see inet6 fe80::xxxx:xxxx:xxxx:xxxx/64, then IPv6 link-local is working. Then check BGP:

ssh Host12_1 "sudo vtysh -c 'show bgp summary' | grep -A5 'Neighbor'"

If still Connect/Idle: The problem is likely L2 connectivity between libvirt VNICs and SONiC switch ports. Run:

# From Host12_1, try to discover the leaf's link-local address
ssh Host12_1 "ping6 -c 2 -I enp2s0 ff02::1%enp2s0"
# Should show neighbor discovery responses from Leaf_L1

If 100% packet loss → the virtual network bridge isn't connected to SONiC. If neighbors appear → it's a FRR configuration issue (probably the no bgp ebgp-requires-policy line).
SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS
ansible localhost -m debug -a "msg='Host12_1 ASN={{ server_asn_map[\"Host12_1\"] }}, Leaf_L1 ASN={{ leaf_asn_map[\"Leaf_L1\"] }}'" -i inventory/hosts.yml


AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# 1. Verify the ACTUAL frr.conf has v6only
sudo cat /etc/frr/frr.conf | grep -A 5 "router bgp"

# 2. Check IPv6 link-locals exist
ip -6 addr show dev eth1 | grep fe80
ip -6 addr show dev eth2 | grep fe80

# 3. Check BGP logs
sudo tail -50 /var/log/frr/bgpd.log

# 4. Check if FRR can see the neighbors
sudo vtysh -c "show bgp neighbors" | head -40


SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS

Run this on the KVM hypervisor for a proof on Host12_1 first:
for br in br-H121-L1 br-H121-L2; do
  tap=$(sudo ovs-vsctl list-ports "$br" | grep '^vnet' | while read -r port; do
    sudo virsh domiflist Host12_1 | grep -q "$port" && echo "$port" && break
  done)
  echo "$br -> $tap"
  sudo ethtool -K "$tap" tx off
done
Then verify immediately:
ssh Host12_1 "sudo vtysh -c 'show bgp summary'"
ssh Leaf_L1 "sudo vtysh -c 'show bgp summary'"
ssh Leaf_L2 "sudo vtysh -c 'show bgp summary'"
If Host12_1 comes up, apply the same fix for all server VMs using the bridge map from
declare -A VM_BRIDGES=(
  [Host12_1]="br-H121-L1 br-H121-L2"
  [Host12_2]="br-H122-L1 br-H122-L2"
  [Host12_3]="br-H123-L1 br-H123-L2"
  [Host34_1]="br-H341-L3 br-H341-L4"
  [Host34_2]="br-H342-L3 br-H342-L4"
  [HostB12_1]="br-HB-BL1 br-HB-BL2"
  [HostB12_2]="br-HB2-BL1 br-HB2-BL2"
  [MonitorSrv]="br-MS-BL1 br-MS-BL2"
)

for vm in "${!VM_BRIDGES[@]}"; do
  for br in ${VM_BRIDGES[$vm]}; do
    tap=$(sudo ovs-vsctl list-ports "$br" | grep '^vnet' | while read -r port; do
      sudo virsh domiflist "$vm" | grep -q "$port" && echo "$port" && break
    done)
    [ -n "$tap" ] && sudo ethtool -K "$tap" tx off
  done
done
One secondary issue remains on the border leaves: Border_Leaf1 and Border_Leaf2 show stale extra neighbors on Ethernet20/24/28 and an old numbered peer in your live output. That is separate cleanup. First get one host pair established by applying the tap offload fix; if it works, I can help clean the border leaf neighbor drift next.
DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
The next discriminating checks on Host12_1 are:
ssh Host12_1 "sudo ss -ltnp | grep ':179 ' || true"
ssh Host12_1 "sudo systemctl status frr --no-pager -l"
ssh Host12_1 "sudo journalctl -u frr -n 100 --no-pager"
ssh Host12_1 "sudo ufw status verbose || true"
ssh Host12_1 "sudo iptables -S || true"
ssh Host12_1 "sudo nft list ruleset || true"
ssh Host12_1 "sudo vtysh -c 'show bgp neighbor enp2s0 json'"
If you want a quick manual probe before more logs, run this on Host12_1:
ssh Host12_1 "sudo ufw allow 179/tcp; sudo iptables -I INPUT -p tcp --dport 179 -j ACCEPT; sudo ip6tables -I INPUT -p tcp --dport 179 -j ACCEPT; sudo systemctl restart frr"
Then immediately re-check:
ssh Host12_1 "sudo vtysh -c 'show bgp summary'"
ssh Leaf_L1 "sudo vtysh -c 'show bgp summary'"
If you send the ss, journalctl, and firewall outputs, I can tell you exactly which host-side condition is blocking bgpd.

CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC

The most likely remaining cause is that you disabled TX offload only on the host-side taps, but not on the leaf-side taps on the same bridges. I also patched the repo automation so future runs apply the fix to all target fabric VMs, not just servers, in deploy_lab_v13.sh:1475.

Test that directly on the hypervisor for the Host12_1 path:
for vm_br in "Leaf_L1 br-H121-L1" "Leaf_L2 br-H121-L2"; do
  set -- $vm_br
  vm="$1"
  br="$2"
  tap=$(sudo ovs-vsctl list-ports "$br" | grep '^vnet' | while read -r port; do
    sudo virsh domiflist "$vm" | grep -q "$port" && echo "$port" && break
  done)
  echo "$vm $br -> $tap"
  sudo ethtool -K "$tap" tx off
done
Then restart FRR on the three VMs in that path and recheck:
ssh Host12_1 "sudo systemctl restart frr; sudo vtysh -c 'show bgp summary'"
ssh Leaf_L1 "sudo systemctl restart frr; sudo vtysh -c 'show bgp summary'"
ssh Leaf_L2 "sudo systemctl restart frr; sudo vtysh -c 'show bgp summary'"
If Host12_1 comes up after that, apply the same leaf-side fix for the rest of the fabric:

Leaf_L1/L2 on br-H121-L1 br-H122-L1 br-H123-L1 br-H121-L2 br-H122-L2 br-H123-L2
Leaf_L3/L4 on br-H341-L3 br-H342-L3 br-H341-L4 br-H342-L4
Border_Leaf1/2 on br-HB-BL1 br-HB2-BL1 br-MS-BL1 br-HB-BL2 br-HB2-BL2 br-MS-BL2
If you want, I can give you one consolidated hypervisor script that fixes all leaf and border-leaf taps in one pass.


VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV
Do this on Host12_1 first:
ssh Host12_1 "sudo vtysh <<'EOF'
configure terminal
router bgp 65101
 no neighbor enp2s0 interface remote-as 65011
 no neighbor enp3s0 interface remote-as 65012
 neighbor enp2s0 interface v6only
 neighbor enp2s0 remote-as external
 neighbor enp2s0 description Leaf_L1
 neighbor enp3s0 interface v6only
 neighbor enp3s0 remote-as external
 neighbor enp3s0 description Leaf_L2
 address-family ipv4 unicast
  neighbor enp2s0 activate
  neighbor enp2s0 soft-reconfiguration inbound
  neighbor enp3s0 activate
  neighbor enp3s0 soft-reconfiguration inbound
 exit-address-family
 address-family ipv6 unicast
  neighbor enp2s0 activate
  neighbor enp3s0 activate
 exit-address-family
end
write
EOF"
Then immediately check:
ssh Host12_1 "sudo vtysh -c 'show bgp summary'"
ssh Host12_1 "sudo vtysh -c 'show bgp neighbor enp2s0 json'"
ssh Leaf_L1 "sudo vtysh -c 'show bgp summary'"
ssh Leaf_L2 "sudo vtysh -c 'show bgp summary'"
FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
Run these exact checks from Windows cmd:
ssh Host12_1 "ip -d link show enp2s0"
ssh Host12_1 "ip -d link show enp3s0"
ssh Host12_1 "ip -6 addr show dev enp2s0"
ssh Host12_1 "ip -6 addr show dev enp3s0"
ssh Host12_1 "ip -6 route get fe80::21c:73ff:fea1:101 dev enp2s0"
ssh Host12_1 "ip -6 route get fe80::21c:73ff:fea1:102 dev enp3s0"
ssh Host12_1 "sysctl net.ipv6.conf.enp2s0.disable_ipv6 net.ipv6.conf.enp3s0.disable_ipv6"
ssh Host12_1 "ls -l /etc/netplan"
ssh Host12_1 "grep -R \"bond0\\|enp2s0\\|enp3s0\" /etc/netplan"
ssh Host12_1 "sudo timeout 15 tcpdump -ni enp2s0 -vv 'icmp6 or tcp port 179'"
Then, during that 15-second window:
ssh Leaf_L1 "sudo vtysh -c 'clear bgp Ethernet0'"
ssh Leaf_L1 "sudo vtysh -c 'clear bgp Ethernet0'"
If you paste the outputs from the 8 host checks first, I can tell you immediately whether this is a host interface-state problem or whether we need to move to a packet-drop/checksum proof on the guest path.


PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP
Run this immediately on Host12_1 to prove it before rerunning Ansible:
ssh Host12_1 "for i in enp2s0 enp3s0; do sudo ethtool -K $i tx off tso off gso off gro off; done"
ssh Host12_1 "sudo systemctl restart frr"
ssh Host12_1 "sudo vtysh -c 'show bgp summary'"
ssh Leaf_L1 "sudo vtysh -c 'show bgp summary'"
ssh Leaf_L2 "sudo vtysh -c 'show bgp summary'"

ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ

LLDP works (proving L2 / KVM bridge is fine), so the block is at L3 (ARP/IP) or L4 (iptables/firewall).

Run these diagnostics (in order):

# 1. L3 ping test — most critical
ssh Border_Leaf1 "ping -c 3 10.0.253.1"

# 2. ARP table — is MAC resolved?
ssh Border_Leaf1 "ip neigh show dev Ethernet0"

# 3. SONiC iptables (Control Plane ACL) — is TCP/179 being dropped?
ssh Border_Leaf1 "sudo iptables -L INPUT -n --line-numbers | head -50"

# 4. Verify FRR running config after bgpcfgd rebuild
ssh Border_Leaf1 "sudo vtysh -c 'show run' | grep -B2 -A8 '10.0.253'"

# 5. From MikroTik Exit_Router1 — can IT ping BL1?
#    /ping 10.0.253.0 count=3 interface=ether2

# 6. From MikroTik Exit_Router1 — any firewall blocking?
#    /ip/firewall/filter/print

The most likely root cause (given LLDP works but TCP doesn't):

SONiC CACL — caclmgrd hasn't added the iptables rule for the new IP peer (restarting bgp does NOT restart caclmgrd)
ARP not resolving — SONiC needs to ARP for 10.0.253.1 but something is preventing broadcast/reply
If ping in step 1 fails → problem is ARP or routing. If ping works but iptables shows a DROP for port 179 without a matching ACCEPT for 10.0.253.1 → fix with:

ssh Border_Leaf1 "sudo iptables -I INPUT -p tcp -s 10.0.253.1 --dport 179 -j ACCEPT"
ssh Border_Leaf2 "sudo iptables -I INPUT -p tcp -s 10.0.253.3 --dport 179 -j ACCEPT"
XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
Immediate fix (run now, no playbook needed):
# Exit_Router1 — accept BGP from Border_Leaf1
ssh Exit_Router1 "/ip firewall filter add chain=input action=accept protocol=tcp src-address=10.0.253.0/32 dst-port=179 comment=accept-bgp-Border_Leaf1 place-before=[find where comment~\"drop-all-else\" and chain=input]"

# Exit_Router2 — accept BGP from Border_Leaf2
ssh Exit_Router2 "/ip firewall filter add chain=input action=accept protocol=tcp src-address=10.0.253.2/32 dst-port=179 comment=accept-bgp-Border_Leaf2 place-before=[find where comment~\"drop-all-else\" and chain=input]"

After adding those rules, the BGP session should come up within ~30 seconds (the ConnectRetry timer). You can also force an immediate retry:

ssh Border_Leaf1 "sudo vtysh -c 'clear bgp 10.0.253.1'"
ssh Border_Leaf2 "sudo vtysh -c 'clear bgp 10.0.253.3'"

Then verify:

ssh Border_Leaf1 "sudo vtysh -c 'show bgp summary' | grep 10.0.253"
ssh Exit_Router1 "/routing/bgp/session/print"

You should see the E flag (Established) on both sides.
DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
The problem must be at the TCP level. There could be stale conntrack entries from the earlier blocked attempts, or an OUTPUT chain issue on SONiC. Run these diagnostics:
# 1. Check SONiC OUTPUT chain (maybe blocking outbound BGP)
ssh Border_Leaf1 "sudo iptables -L OUTPUT -n --line-numbers"

# 2. Packet capture — the definitive test (what's actually on the wire?)
ssh Border_Leaf1 "sudo timeout 10 tcpdump -i Ethernet0 -n 'tcp port 179' 2>&1 | head -30"

# 3. Flush MikroTik stale conntrack entries from prior blocked attempts
ssh Exit_Router1 "/ip firewall connection remove [find where dst-address~\"10.0.253\" or src-address~\"10.0.253\"]"

# 4. Toggle the MikroTik BGP connection to force a clean TCP retry
ssh Exit_Router1 "/routing bgp connection disable to_Border_Leaf1; :delay 3; /routing bgp connection enable to_Border_Leaf1"

# 5. Then check immediately
ssh Border_Leaf1 "sudo vtysh -c 'show bgp summary' | grep 10.0.253"
ssh Exit_Router1 "/routing/bgp/session/print"
The tcpdump (#2) is the most important — it will show us whether SYN packets are actually being sent/received and what happens to them (SYN-ACK? RST? Nothing?). That will pinpoint exactly where the connection is breaking.
