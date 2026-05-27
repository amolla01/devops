Option A — from your laptop (remote execution):
./deploy_lab_v3.sh --remote-v13-host nh1221@R810 --profile ubuntu_r810_kvm kvm-destroy
Option B — directly on the R810 (you're already SSH'd in):
cd ~/data-center/_v3
bash deploy_lab_v13.sh --profile ubuntu_r810_kvm destroy
