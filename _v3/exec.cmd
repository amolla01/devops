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
