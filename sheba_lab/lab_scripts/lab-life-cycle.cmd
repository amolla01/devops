Corrected: Full Teardown & Rebuild from WSL (/mnt/c/Users/nh1221/data-center/_v3)
Your .deploy_lab_v3.env already has R810_HOST=nh1221@R810, SSH_KEY_PATH=~/.ssh/id_dc_lab, and AUTOMATION_PROFILE=ubuntu_r810_kvm — so no flags needed.

PHASE A: TEARDOWN

cd /mnt/c/Users/nh1221/data-center/_v3

# 1. Destroy all 18 VMs + networks + disks on R810 (syncs v13 script, runs remotely)
./deploy_lab_v3.sh kvm-destroy
# → Type 'DESTROY' when prompted

PHASE B: FRESH KVM DEPLOY (18 VMs)

# 2. Deploy all VMs (copies deploy_lab_v13.sh to R810, runs phases 0-6 remotely)
#    Uses /opt/fabric-cache on R810 for images (the script's phase1 downloads if missing)
./deploy_lab_v3.sh kvm-deploy

PHASE C: REBOOT R810 (Validate Persistence)

# 3. Reboot R810 remotely
ssh nh1221@R810 'sudo reboot'

# 4. Wait ~3 min, then verify VMs restarted
./deploy_lab_v3.sh remote-status

PHASE D: DAY-0 (Base Provisioning — All Devices)

# 5. Day-0: SONiC + CHR + Servers (runs ansible-playbook from WSL)
./deploy_lab_v3.sh day0

PHASE E: DAY-1 (Fabric BGP Wiring — All Devices)

# 6. Day-1: SONiC fabric BGP + CHR eBGP + Server FRR
./deploy_lab_v3.sh day1

PHASE F: LEAF-SERVER BGP + SERVER NETWORKING

# 7. Leaf downlink BGP to servers
ansible-playbook -i inventory/hosts.yml playbooks/reused/deploy_leaf_server_bgp.yml -v

# 8. Server fabric interfaces + FRR verification
ansible-playbook -i inventory/hosts.yml playbooks/reused/deploy_server_networking.yml -v

PHASE G: VALIDATE FABRIC CONVERGENCE

# 9. Verify BGP sessions (all device types)
ansible-playbook -i inventory/hosts.yml playbooks/reused/deploy_day1.yml --tags verify -v

PHASE H: INFRASTRUCTURE SERVICES (K8s + Ceph + Monitoring)

# 10. All infra in one shot: Kubespray → PostgreSQL → MaaS → Ceph → OpenStack Helm → Monitoring
./deploy_lab_v3.sh infra-services

Or individually:

# 10a. Preflight download (cache artifacts)
ansible-playbook -i inventory/hosts.yml playbooks/reused/preflight_download.yml -v

# 10b. Kubernetes
ansible-playbook -i inventory/hosts.yml playbooks/reused/deploy_kubespray.yml -v

# 10c. Ceph (Rook)
ansible-playbook -i inventory/hosts.yml playbooks/reused/deploy_ceph_rook.yml -v

# 10d. MetalLB (BGP mode)
ansible-playbook -i inventory/hosts.yml playbooks/reused/deploy_metallb.yml -v

# 10e. Monitoring
ansible-playbook -i inventory/hosts.yml playbooks/reused/deploy_monitoring.yml -v


QUICK REFERENCE (Minimum commands for full fabric):

cd /mnt/c/Users/nh1221/data-center/_v3
./deploy_lab_v3.sh kvm-destroy
./deploy_lab_v3.sh kvm-deploy
ssh nh1221@R810 'sudo reboot'
# (wait ~3 min)
./deploy_lab_v3.sh day0
./deploy_lab_v3.sh day1
ansible-playbook -i inventory/hosts.yml playbooks/reused/deploy_leaf_server_bgp.yml -v
ansible-playbook -i inventory/hosts.yml playbooks/reused/deploy_server_networking.yml -v
./deploy_lab_v3.sh infra-services

NOTES:
deploy_lab_v3.sh auto-syncs deploy_lab_v13.sh to R810 via SCP (sha256 comparison) before every kvm-* action
Ansible playbooks run locally in WSL, targeting VMs via 172.16.2.x management network (reachable through R810 NAT)
The wrapper sets ANSIBLE_CONFIG to $SCRIPT_DIR/ansible.cfg automatically
If ansible-playbook isn't on PATH, it activates the venv at ../_v3/../venv/bin/activate
Steps 7–8 aren't wrapped in deploy_lab_v3.sh actions yet — run them as raw ansible-playbook commands


XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

Now let me look at the most critical part — the issue of SONiC showing Arista default neighbors. 
This happens because the SONiC VS image ships with a default hwsku and default config_db.json. 
When you boot without Day-0, you get the image's built-in Arista/generic config. Let me check how the push_config + reload_config replaces it:

Known OVS/vnet/Connectivity Issues & Mitigations

Issue 1: Stale OVS vnet Ports Survive Teardown (CRITICAL)
Problem: teardown() calls force_delete_vm() which calls clean_stale_ovs_ports(). But OVS ports are only removed if /sys/class/net/<port> doesn't exist. 
  If libvirtd still holds the tap device briefly after virsh destroy, the stale port is NOT cleaned. On re-deploy, 
  the new VM gets vnet0 but the OVS bridge still has a stale vnet0 entry pointing to the old UUID — libvirt then picks vnet1, 
  but OVS may reject it ("port already exists").

Fix already in code: clean_stale_ovs_ports + force_delete_vm pair. But there's a race.

What to do: After kvm-destroy, run an explicit OVS cleanup before re-deploying:

# After destroy, ensure OVS is fully clean:
ssh nh1221@R810 'for br in $(sudo ovs-vsctl list-br); do
    for port in $(sudo ovs-vsctl list-ports "$br" | grep vnet); do
        sudo ovs-vsctl --if-exists del-port "$br" "$port"
    done
done'


Issue 2: SONiC Ships with Default Arista config_db.json (YOUR CURRENT PROBLEM)
Problem: The SONiC VS 202405 image has a built-in default config_db.json that uses the image's embedded hwsku (likely Force10-S6000 or Arista-7260CX3-C64).
  Until Day-0 runs config reload -y with the rendered config, you see default LLDP neighbors and Arista-named interfaces. 
  If Day-0 doesn't complete cleanly (SSH timeout, service instability), the SONiC switch remains on its default config.

What to do: Ensure Day-0 runs to completion. The config reload -y in reload_config.yml completely replaces the running config. 
  Verify with:

# After day0 completes, check on any SONiC switch:
ssh admin@172.16.2.23 "show interfaces status | head -5"
# Should show YOUR ports (Ethernet0, Ethernet4, Ethernet120, Ethernet124)
# NOT default Arista ports (fortyGigE0/0, etc.)

Issue 3: Servers Not Running FRR (YOUR OTHER CURRENT PROBLEM)
Problem: The phase5_5_server_config() function in deploy_lab_v13.sh configures FRR with direct SSH commands.
  But the Ansible Day-1 playbook (deploy_day1.yml --limit servers) uses the sonic_server_net role which does the proper Jinja2-templated FRR config. 
  If phase5.5 partially succeeded but Day-1 never ran (or failed), you get empty FRR.

What to do: Don't rely on phase5.5's inline FRR config. After kvm-deploy, the proper flow is:

deploy_day0.yml → base OS config
deploy_day1.yml --limit servers → proper FRR + netplan via sonic_server_net role
The phase5.5 in the shell script is a convenience stopgap. The Ansible roles are the source of truth.

Issue 4: CHR TCP Checksum (Border-Leaf ↔ Exit_Router BGP Never Forms)
Problem documented in memory: CHR with rtl8139 NIC model can still produce partial checksums. 
  The qemu hook (ethtool -K <tap> tx off) only works on the receiving side tap.

What to do: The deploy script already uses rtl8139 for CHR + installs the qemu hook. But verify post-deploy: 

ssh nh1221@R810 'for tap in $(virsh domiflist Exit_Router1 | awk "/vnet/{print \$1}"); do
    echo "$tap: $(ethtool -k $tap | grep tx-checksum)"
done'

If TX checksum is still on, the hook didn't fire. Manually:

ssh nh1221@R810 'for tap in $(virsh domiflist Exit_Router1 | awk "/vnet/{print \$1}"); do sudo ethtool -K $tap tx off; done'
ssh nh1221@R810 'for tap in $(virsh domiflist Exit_Router2 | awk "/vnet/{print \$1}"); do sudo ethtool -K $tap tx off; done'

Issue 5: Race Between VM Boot and OVS Port Attachment
Problem: When virt-install creates a VM with OVS-backed NICs, libvirt creates the tap device and adds it to OVS. But if OVS restarts (due to apt upgrade or service instability), the ports vanish from the flow table while the VM is running. On next VM power-cycle, the tap/vnet may be re-attached with a different ofport.

What to do: After reboot of R810, verify OVS port state:

ssh nh1221@R810 'sudo ovs-vsctl show | grep -c "Port vnet"'
# Should match total fabric NICs across all 18 VMs

Issue 6: forward-bpdu=true Reset After OVS Restart
Problem: Phase 3 sets other-config:forward-bpdu=true on each OVS bridge so LLDP frames (01:80:c2:00:00:0e) pass between SONiC switches. If OVS service restarts, this setting persists in OVSDB. But if the bridge is deleted and re-created (as in teardown+deploy), the setting must be re-applied. This is correctly done in phase3.

What to verify: After deploy:

ssh nh1221@R810 'sudo ovs-vsctl get bridge br-L1-S1 other-config'
# Should include forward-bpdu="true"

Corrected Execution Order (Avoiding All Known Issues)

cd /mnt/c/Users/nh1221/data-center/_v3

# ══════ STEP 1: FULL TEARDOWN ══════
./deploy_lab_v3.sh kvm-destroy
# Type DESTROY when prompted

# ══════ STEP 2: VERIFY CLEAN STATE ══════
ssh nh1221@R810 'sudo ovs-vsctl list-br'
# Should show NO bridges (or only non-lab bridges)
ssh nh1221@R810 'sudo virsh list --all'
# Should show NO VMs

# If stale bridges remain:
ssh nh1221@R810 'for br in $(sudo ovs-vsctl list-br | grep "^br-"); do sudo ovs-vsctl del-br "$br"; done'

# ══════ STEP 3: FRESH KVM DEPLOY ══════
./deploy_lab_v3.sh kvm-deploy
# Wait for full completion (all phases 0-6)

# ══════ STEP 4: VERIFY OVS + VMs ══════
./deploy_lab_v3.sh remote-status
ssh nh1221@R810 'sudo ovs-vsctl show | grep -c Port'

# ══════ STEP 5: REBOOT R810 (Test Persistence) ══════
ssh nh1221@R810 'sudo reboot'
# Wait 3-4 minutes
./deploy_lab_v3.sh remote-status
# Verify all 18 VMs are "running"

# ══════ STEP 6: VERIFY QEMU HOOK FIRED (TX OFFLOAD) ══════
ssh nh1221@R810 'for vm in Exit_Router1 Exit_Router2 Host12_1 Spine_S1; do
    echo "=== $vm ==="; virsh domiflist $vm | awk "/vnet/{print \$1}" | while read tap; do
        echo "  $tap tx-off: $(ethtool -k $tap 2>/dev/null | grep "tx-checksumming" | awk "{print \$2}")"
    done
done'
# ALL should show "off"

# ══════ STEP 7: DAY-0 (Replace default SONiC config) ══════
./deploy_lab_v3.sh day0
# This pushes YOUR config_db.json and does config reload -y
# The Arista default interfaces will be GONE after this step

# ══════ STEP 8: VERIFY DAY-0 WORKED ══════
ssh admin@172.16.2.11 "show runningconfiguration all | head -5"   # Spine_S1
ssh admin@172.16.2.23 "show interfaces status | head -5"          # Leaf_L3
# Should show Ethernet0, Ethernet4, Ethernet120, Ethernet124 — NOT Arista defaults

# ══════ STEP 9: DAY-1 (Fabric BGP) ══════
./deploy_lab_v3.sh day1
# This configures eBGP unnumbered on SONiC, FRR on servers, BGP on CHR

# ══════ STEP 10: LEAF-SERVER BGP ══════
ansible-playbook -i inventory/hosts.yml playbooks/reused/deploy_leaf_server_bgp.yml -v

# ══════ STEP 11: SERVER NETWORKING ══════
ansible-playbook -i inventory/hosts.yml playbooks/reused/deploy_server_networking.yml -v

# ══════ STEP 12: VERIFY BGP CONVERGENCE ══════
ansible-playbook -i inventory/hosts.yml playbooks/reused/deploy_day1.yml --tags verify -v

# ══════ STEP 13: INFRASTRUCTURE ══════
./deploy_lab_v3.sh infra-services

Key Differences From Last Time
What went wrong before	What prevents it now
SONiC showing Arista defaults	Day-0 does full config reload -y replacing the image's built-in config
Servers no FRR	Day-1 sonic_server_net role installs + configures FRR properly
Stale OVS ports after teardown	Explicit OVS bridge deletion verification in Step 2
CHR BGP stuck in Connect	rtl8139 NIC + qemu hook TX offload disable + Step 6 verification
Cloud-init wiping netplan on reboot	Fixed in deploy script (user-data + runcmd cloud-init.disabled)
VMs not starting after R810 reboot	virsh autostart + qemu hook + NAT persistence

  
