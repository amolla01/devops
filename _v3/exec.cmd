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
