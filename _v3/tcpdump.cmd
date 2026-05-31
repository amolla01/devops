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
What to do next

On the hypervisor, find the actual tap/vnet ports on the two border-exit bridges:

sudo ovs-vsctl list-ports br-BL1-ER1
sudo ovs-vsctl list-ports br-BL2-ER2

Disable TX offload on every vnet*/tap interface attached to those two bridges:

sudo ethtool -K <iface> tx off
If each bridge has two VM-side ports, do it for both ports on each bridge.

Verify the change:
sudo ethtool -k <iface> | grep tx-checksumming
You want it to report off.

Re-run the new diagnostic script first, not the playbook:
cd /mnt/c/Users/nh1221/data-center/_v3/troubleshooting-scripts
./diagnose_border_exit_bgp.sh --profile bl1-er1
./diagnose_border_exit_bgp.sh --profile bl2-er2


The generalized diagnostics are enough now. I’m not gathering more context; I’m tying the results back to the automation behavior and the next concrete remediation step.

The new script gave the decisive result.

This is the smoking gun:
On both Border_Leaf1 and Border_Leaf2, tcpdump on Ethernet0 sees SYNs from the exit routers with bad TCP checksums:

cksum 0x0e31 (incorrect -> 0xae2d)
cksum 0x0e35 (incorrect -> 0x7771)

At the same time:
FRR is listening on 0.0.0.0:179
rp_filter is 0
iptables is allowing TCP/179
the numbered /31 IPs are correct
the RouterOS peer object is present

So the current failure is not BGP config anymore. It is packet integrity on the KVM fabric path, and it lines up exactly with the earlier “hypervisor tap TX offload fix” path not applying:

No matching hypervisor tap interfaces were found via R810

That part is the real defect now.

What to do next

On the hypervisor, find the actual tap/vnet ports on the two border-exit bridges:
Disable TX offload on every vnet*/tap interface attached to those two bridges:
If each bridge has two VM-side ports, do it for both ports on each bridge.

Verify the change:
You want it to report off.

Re-run the new diagnostic script first, not the playbook:
What should change:
The tcpdump section should stop showing the incorrect checksum warning on the SYNs.
BL1/BL2 should start replying with SYN-ACK.
Then the SONiC neighbors should move out of Active.

Only after that, rerun:

ansible-playbook playbooks/reused/deploy_day1.yml \
  -i inventory/hosts.yml \
  -e automation_profile=ubuntu_r810_kvm \
  --limit "Exit_Router1:Exit_Router2" \
  --tags deploy

Important conclusion:
The automation already told us the root gap:
the hypervisor tap-offload discovery missed these interfaces, so the checksum fix never touched the real ports.

Natural next steps:

Paste the output of ovs-vsctl list-ports br-BL1-ER1 and ovs-vsctl list-ports br-BL2-ER2, and I’ll tell you exactly which interfaces to run ethtool -K ... tx off on.
If you want this fixed permanently, I can patch the _v3 automation so Phase 0 reliably discovers and disables offload on the actual bridge ports instead of missing them.


On R810, run the fuller offload disable against the four bridge ports you already identified:
sudo ethtool -K vnet1201 tx off tso off gso off gro off
sudo ethtool -K vnet1267 tx off tso off gso off gro off
sudo ethtool -K vnet1234 tx off tso off gso off gro off
sudo ethtool -K vnet1269 tx off tso off gso off gro off

Verify those flags actually stuck:

sudo ethtool -k vnet1201 | grep -E 'tx-check|tcp-segmentation|generic-segmentation|generic-receive'
sudo ethtool -k vnet1267 | grep -E 'tx-check|tcp-segmentation|generic-segmentation|generic-receive'
sudo ethtool -k vnet1234 | grep -E 'tx-check|tcp-segmentation|generic-segmentation|generic-receive'
sudo ethtool -k vnet1269 | grep -E 'tx-check|tcp-segmentation|generic-segmentation|generic-receive'
Rerun the generalized diag first, not deploy:
cd /mnt/c/Users/nh1221/data-center/_v3/troubleshooting-scripts
./diagnose_border_exit_bgp.sh --profile bl1-er1
./diagnose_border_exit_bgp.sh --profile bl2-er2

Use this on R810 for the same user that your R810_HOST points to, which looks like nh1221@R810.

SSH to R810 and confirm the binary paths:
ssh nh1221@R810
command -v ovs-vsctl
command -v virsh
command -v ethtool

Create a narrow sudoers rule with visudo:
sudo visudo -f /etc/sudoers.d/nh1221-kvm-offload
Put this in that file, adjusting paths only if step 1 showed different ones:
Cmnd_Alias KVM_OFFLOAD_CMDS = /usr/bin/ovs-vsctl, /usr/bin/virsh, /usr/sbin/ethtool, /sbin/ethtool
nh1221 ALL=(root) NOPASSWD: KVM_OFFLOAD_CMDS
Fix permissions on the sudoers file:
sudo chmod 440 /etc/sudoers.d/nh1221-kvm-offload
sudo chown root:root /etc/sudoers.d/nh1221-kvm-offload
Verify the exact non-interactive commands now work:
sudo -n ovs-vsctl list-br
sudo -n virsh list
sudo -n ethtool -k vnet1201
Verify the same flow works over SSH from your control host:
ssh nh1221@R810 'sudo -n ovs-vsctl list-br'
ssh nh1221@R810 'sudo -n virsh list'
ssh nh1221@R810 'sudo -n ethtool -k vnet1201'
Then rerun just the preflight/deploy slice you care about:
cd /mnt/c/Users/nh1221/data-center/_v3
ansible-playbook playbooks/reused/deploy_day1.yml -i inventory/hosts.yml -e automation_profile=ubuntu_r810_kvm --limit "Border_Leaf1:Border_Leaf2:Exit_Router1:Exit_Router2" --tags deploy
XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
So what we are doing now is this:

Eliminate the environment mismatch.
Run the deploy only after exporting the env file, so the automation really uses nh1221@R810:
cd /mnt/c/Users/nh1221/data-center/_v3
set -a
source ./.deploy_lab_v3.env
set +a
echo "$R810_HOST"
Re-run the same deploy and confirm the Phase 0 label changes behavior.
It should no longer effectively fall back to plain R810.
ansible-playbook playbooks/reused/deploy_day1.yml -i inventory/hosts.yml -e automation_profile=ubuntu_r810_kvm --limit "Border_Leaf1:Border_Leaf2:Exit_Router1:Exit_Router2" --tags deploy
If the peers are still Active, localize the failure hop, not the config shape.
At that point the next useful test is simultaneous packet capture on:
Border leaf fabric port
The matching R810 vnet port
The CHR side
Run these on the control node:
ssh Border_Leaf1 'sudo vtysh -c "show running-config" | grep -A8 -B3 "neighbor 10.0.253.1"'
ssh Border_Leaf2 'sudo vtysh -c "show running-config" | grep -A8 -B3 "neighbor 10.0.253.3"'

The next commands to run are:

Check whether FRR has a password/MD5 configured for those exact numbered neighbors:


ssh Border_Leaf1 'sudo vtysh -c "show running-config" | grep -A8 -B3 "neighbor 10.0.253.1"'
ssh Border_Leaf2 'sudo vtysh -c "show running-config" | grep -A8 -B3 "neighbor 10.0.253.3"'


If you still want the R810 tap capture, force a tty for sudo:
ssh -t nh1221@R810 "sudo timeout 10 tcpdump -ni vnet1267 host 10.0.253.0 and port 179 -vv"
ssh -t nh1221@R810 "sudo timeout 10 tcpdump -ni vnet1269 host 10.0.253.2 and port 179 -vv"


If those come back clean, the next step is one synchronized handshake capture to prove where the SYN-ACK dies:
ssh Border_Leaf1 "sudo timeout 10 tcpdump -ni Ethernet0 host 10.0.253.1 and port 179 -vv"
ssh Border_Leaf2 "sudo timeout 10 tcpdump -ni Ethernet0 host 10.0.253.3 and port 179 -vv"
ssh nh1221@R810 "sudo timeout 10 tcpdump -ni vnet1267 host 10.0.253.0 and port 179 -vv"
ssh nh1221@R810 "sudo timeout 10 tcpdump -ni vnet1269 host 10.0.253.2 and port 179 -vv"

Then, during those captures, trigger a fresh connect attempt from each CHR:
ssh Exit_Router1 "/routing bgp connection disable [find where name=\"to_Border_Leaf1\"]; :delay 2; /routing bgp connection enable [find where name=\"to_Border_Leaf1\"]"
ssh Exit_Router2 "/routing bgp connection disable [find where name=\"to_Border_Leaf2\"]; :delay 2; /routing bgp connection enable [find where name=\"to_Border_Leaf2\"]"


XXXXXXXXXXXXXXXXXXXXXXXXXXX
ssh Border_Leaf1 'sudo ethtool -k Ethernet0 | egrep "rx-check|tx-check|tcp-segmentation|generic-segmentation|generic-receive|large-receive"'
ssh Border_Leaf2 'sudo ethtool -k Ethernet0 | egrep "rx-check|tx-check|tcp-segmentation|generic-segmentation|generic-receive|large-receive"'

Then disable guest-side offloads for the exit-router-facing port:
ssh Border_Leaf1 'sudo ethtool -K Ethernet0 rx off tx off tso off gso off gro off || true'
ssh Border_Leaf2 'sudo ethtool -K Ethernet0 rx off tx off tso off gso off gro off || true'

Then verify:
ssh Border_Leaf1 'sudo ethtool -k Ethernet0 | egrep "rx-check|tx-check|tcp-segmentation|generic-segmentation|generic-receive|large-receive"'
ssh Border_Leaf2 'sudo ethtool -k Ethernet0 | egrep "rx-check|tx-check|tcp-segmentation|generic-segmentation|generic-receive|large-receive"'

After that, trigger fresh connection attempts and capture again:
ssh Exit_Router1 '/routing bgp connection disable [find where name="to_Border_Leaf1"]; :delay 2; /routing bgp connection enable [find where name="to_Border_Leaf1"]'
ssh Exit_Router2 '/routing bgp connection disable [find where name="to_Border_Leaf2"]; :delay 2; /routing bgp connection enable [find where name="to_Border_Leaf2"]'
ssh Border_Leaf1 "sudo timeout 10 tcpdump -ni Ethernet0 host 10.0.253.1 and port 179 -vv"
ssh Border_Leaf2 "sudo timeout 10 tcpdump -ni Ethernet0 host 10.0.253.3 and port 179 -vv"

What we want to see next:

If you start seeing 10.0.253.0.179 > 10.0.253.1.x: Flags [S.] and the equivalent on Border_Leaf2, then the checksum/offload path was the blocker.
If you still see only inbound SYNs and no SYN-ACK, then the next step is kernel-level counters on SONiC for dropped TCP/checksum packets, because by then we’ve ruled out MD5 and largely ruled out simple bridge wiring.

DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
The cheapest discriminating check now is kernel counters on the border leaves. Run these exactly in this order.

First, zero and read the relevant counters:
ssh Border_Leaf1 'sudo nstat -az | egrep "TcpExtTCPMD5|TcpInErrs|TcpInCsumErrors|IpInDiscards|IpInHdrErrors|IpInAddrErrors|TcpExtListenDrops|TcpExtListenOverflows"'
ssh Border_Leaf2 'sudo nstat -az | egrep "TcpExtTCPMD5|TcpInErrs|TcpInCsumErrors|IpInDiscards|IpInHdrErrors|IpInAddrErrors|TcpExtListenDrops|TcpExtListenOverflows"'

ssh Border_Leaf1 'sudo nstat -az | egrep "TcpExtTCPMD5|TcpInErrs|TcpInCsumErrors|IpInDiscards|IpInHdrErrors|IpInAddrErrors|TcpExtListenDrops|TcpExtListenOverflows"'ssh Border_Leaf2 'sudo nstat -az | egrep "TcpExtTCPMD5|TcpInErrs|TcpInCsumErrors|IpInDiscards|IpInHdrErrors|IpInAddrErrors|TcpExtListenDrops|TcpExtListenOverflows"'
Then trigger fresh BGP connection attempts:
ssh Exit_Router1 '/routing bgp connection disable [find where name="to_Border_Leaf1"]; :delay 2; /routing bgp connection enable [find where name="to_Border_Leaf1"]'
ssh Exit_Router2 '/routing bgp connection disable [find where name="to_Border_Leaf2"]; :delay 2; /routing bgp connection enable [find where name="to_Border_Leaf2"]'

ssh Exit_Router1 '/routing bgp connection disable [find where name="to_Border_Leaf1"]; :delay 2; /routing bgp connection enable [find where name="to_Border_Leaf1"]'ssh Exit_Router2 '/routing bgp connection disable [find where name="to_Border_Leaf2"]; :delay 2; /routing bgp connection enable [find where name="to_Border_Leaf2"]'
Then immediately read the counters again:
ssh Border_Leaf1 'sudo nstat -az | egrep "TcpExtTCPMD5|TcpInErrs|TcpInCsumErrors|IpInDiscards|IpInHdrErrors|IpInAddrErrors|TcpExtListenDrops|TcpExtListenOverflows"'
ssh Border_Leaf2 'sudo nstat -az | egrep "TcpExtTCPMD5|TcpInErrs|TcpInCsumErrors|IpInDiscards|IpInHdrErrors|IpInAddrErrors|TcpExtListenDrops|TcpExtListenOverflows"'

ssh Border_Leaf1 'sudo nstat -az | egrep "TcpExtTCPMD5|TcpInErrs|TcpInCsumErrors|IpInDiscards|IpInHdrErrors|IpInAddrErrors|TcpExtListenDrops|TcpExtListenOverflows"'ssh Border_Leaf2 'sudo nstat -az | egrep "TcpExtTCPMD5|TcpInErrs|TcpInCsumErrors|IpInDiscards|IpInHdrErrors|IpInAddrErrors|TcpExtListenDrops|TcpExtListenOverflows"'
How to read the result:

If TcpExtTCPMD5* counters increase, Linux is rejecting the SYNs because of MD5 handling.
If TcpInCsumErrors or TcpInErrs increases, the SYNs are being dropped as bad TCP packets.
If neither moves, we step one layer lower and inspect FRR/kernel binding behavior on port 179.
One more small correction: your runtime playbook still has my earlier bad sudo probe. Copy the updated deploy_day1.yml before the next deploy so the false remote sudo requires a password warning goes away. But that is separate from the current Active issue.

Paste the two post-trigger nstat outputs. That should tell us which branch to pursue next.


AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
Immediate fix — run this on R810:

First, confirm the theory by checking kernel drop counters:
ssh Border_Leaf1 'cat /proc/net/snmp | grep Tcp'
Look for InCsumErrors — it will be non-zero and increasing.

Then apply the fix. The simplest approach is to change the NIC model to virtio with checksum offload disabled at the host level:
sudo virsh destroy Exit_Router1
sudo EDITOR="sed -i \"/<source bridge='br-BL1-ER1'\/>/,/<\/interface>/{s/<model type='rtl8139'\/>/<model type='virtio'\/>\n        <driver><host csum='off' gso='off' tso4='off' tso6='off'\/><\/driver>/}\"" virsh edit Exit_Router1
sudo virsh start Exit_Router1

sudo virsh destroy Exit_Router2
sudo EDITOR="sed -i \"/<source bridge='br-BL2-ER2'\/>/,/<\/interface>/{s/<model type='rtl8139'\/>/<model type='virtio'\/>\n        <driver><host csum='off' gso='off' tso4='off' tso6='off'\/><\/driver>/}\"" virsh edit Exit_Router2
sudo virsh start Exit_Router2
The <host csum='off'/> tells QEMU to not advertise VIRTIO_NET_F_CSUM to the guest, forcing RouterOS to compute full checksums in software before handing the packet to the virtual NIC. The packets will then arrive at the SONiC VMs with correct checksums.

If the sed-based virsh edit is too fragile, you can do it manually:
sudo virsh destroy Exit_Router1
sudo virsh edit Exit_Router1
Find the interface block with bridge='br-BL1-ER1', change:
<model type='rtl8139'/>
to:

<model type='virtio'/>
<driver>
  <host csum='off' gso='off' tso4='off' tso6='off'/>
</driver>

Then sudo virsh start Exit_Router1. Repeat for Exit_Router2 / br-BL2-ER2.

After the VMs come back up, the RouterOS ether2/ether3 interface names will shift because virtio enumerates differently. The playbook's KVM interface rebind logic should handle that automatically on the next deploy.

Let me also save this finding to repo memory so we don't re-investigate it:

Compacted conversation
