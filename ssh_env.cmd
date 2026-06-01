The Ansible side is already dynamic — your profile drives the ProxyJump via ansible_ssh_common_args. The problem is only manual SSH from the terminal. Here's how to make that dynamic too using the same AUTOMATION_PROFILE env var:

Replace your SSH config's static wildcard block with Match directives:

# --- Lab VMs: dynamic jump host based on AUTOMATION_PROFILE ---
Match host 172.16.2.*,Spine_*,Leaf_*,Host*,Border_*,MonitorSrv,Exit_Router* exec "[ \"${AUTOMATION_PROFILE:-ubuntu_r810_kvm}\" = 'ubuntu_r620_kvm' ]"
    ProxyJump R620
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Match host 172.16.2.*,Spine_*,Leaf_*,Host*,Border_*,MonitorSrv,Exit_Router*
    ProxyJump R810
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

How it works:

SSH evaluates Match exec top-down. If AUTOMATION_PROFILE=ubuntu_r620_kvm, it jumps through R620.
Otherwise (including unset / ubuntu_r810_kvm), the fallback block jumps through R810.
Same env var that Ansible reads — one switch controls both.
In your .bashrc / .zshrc:

export AUTOMATION_PROFILE=ubuntu_r810_kvm   # or ubuntu_r620_kvm

Then:

# Uses R810 by default
ssh Host12_1

# Switch to R620
export AUTOMATION_PROFILE=ubuntu_r620_kvm
ssh Host12_1   # now goes through R620


XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
Created scripts/setup_ssh_config.sh. Here's how it works:

One-time setup (run from WSL):

cd /mnt/c/Users/nh1221/data-center/scripts
chmod +x setup_ssh_config.sh
./setup_ssh_config.sh

Daily use — same env var drives both Ansible and manual SSH:

# In .bashrc or before running commands:
export AUTOMATION_PROFILE=ubuntu_r810_kvm   # default

# Manual SSH now goes through R810
ssh Host12_1      # ✓ jumps through R810

# Switch to R620 cluster
export AUTOMATION_PROFILE=ubuntu_r620_kvm
ssh Host12_1      # ✓ jumps through R620

Key design choices:

Uses Match host ... exec "..." — SSH evaluates the env var at connect time
Inserted at TOP of ~/.ssh/config (SSH first-match wins)
Managed block with markers — safe to re-run, won't duplicate
Same AUTOMATION_PROFILE that Ansible reads in group_vars/all.yml
Overridable via env vars: R810_HOST, R620_HOST, KVM_HYPERVISOR_USER, SSH_KEY_PATH
After running the script, remove your old Host 172.16.2.* spine-* ... block that routes through dc-hypervisor.


Remove the old conflicting wildcard block the warning flagged — edit ~/.ssh/config and delete the old Host 172.16.2.* spine-* 
... section that was below the managed block. Then test:

ssh Host12_1

The generated exec line will now be:

exec "[ ${AUTOMATION_PROFILE:-ubuntu_r810_kvm} = ubuntu_r620_kvm ]"
No escaped quotes — the shell gets a clean [ test with the unquoted variable (safe since profile values contain no spaces).

