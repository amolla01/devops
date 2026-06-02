Immediate Action for Your Current Stuck Run
Ctrl+C the stuck playbook
Run: tail -50 /tmp/kubespray_deploy.log 
  — check what the inner playbook is actually doing

Clean up partial state:
ansible -i inventory/hosts.yml kube_nodes -m shell -a "rm -rf /tmp/releases/*" --become
  
Re-run with the updated playbook

After killing it, run these cleanup steps before re-running:
# 1. Kill any orphaned ansible-playbook processes
pkill -f "ansible-playbook.*cluster.yml" 2>/dev/null; sleep 2

# 2. Clean partial download state on all nodes
ansible -i inventory/hosts.yml kube_nodes -m shell \
  -a "rm -rf /tmp/releases/* 2>/dev/null; true" --become

# 3. Re-run the playbook (now uses download_run_once=true + piped transfer)
ansible-playbook -i inventory/hosts.yml playbooks/reused/deploy_kubespray.yml


The new run will:

Download images once on host12-1 (proven to work)
Distribute via piped transfer (dd over ssh) instead of rsync — no more silent failures through ProxyJump
Show a "tail -f /tmp/kubespray_deploy.log" hint so you can monitor progress in another terminal

XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

Two things: the kubectl binary and the kubeconfig file from the cluster.

1. Install kubectl (in WSL)
# Download kubectl matching your cluster version (v1.29.4)
curl -LO "https://dl.k8s.io/release/v1.29.4/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Verify
kubectl version --client

2. Fetch kubeconfig from first control plane

# Copy admin.conf from host12-1 (first controller)
mkdir -p ~/.kube
ssh -o ProxyJump=nh1221@R810 ubuntu@host12-1 "sudo cat /etc/kubernetes/admin.conf" > ~/.kube/config
chmod 600 ~/.kube/config

3. Fix the API server address
The kubeconfig will reference the internal cluster IP (e.g., 127.0.0.1:6443 or the VIP). You need to point it to a reachable control plane IP:

# Check what's in the kubeconfig
grep server ~/.kube/config

# If it says 127.0.0.1, replace with the actual control plane IP
# (Host12_1's IP - check your inventory)
sed -i 's|https://127.0.0.1:6443|https://<HOST12_1_IP>:6443|' ~/.kube/config

4. Establish connectivity to the API server
Since you go through ProxyJump (R810), you likely can't reach host12-1:6443 directly from WSL. Set up a tunnel:

# SSH tunnel: local port 6443 → host12-1:6443 via R810
ssh -N -L 6443:host12-1:6443 nh1221@R810 &

# Then set kubeconfig to use localhost
sed -i 's|https://.*:6443|https://127.0.0.1:6443|' ~/.kube/config

5. Test

kubectl get nodes
kubectl get pods -A

Or as a one-liner automation (add to your playbook as a post-deploy step):

ssh -o ProxyJump=nh1221@R810 ubuntu@host12-1 "sudo cat /etc/kubernetes/admin.conf" \
  | sed "s|https://127.0.0.1:6443|https://host12-1:6443|" > ~/.kube/config

