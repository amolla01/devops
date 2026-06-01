Changes made:

Added | trim to proxy_jump_host, proxy_jump_resolved, and the final ansible_ssh_common_args injection in all.yml
Phase 3 play now explicitly sets ansible_ssh_common_args at play level with clean SSH options that only add ProxyJump when proxy_jump_host is genuinely non-empty
To deploy on the R810, sync the changes and run:

cd /mnt/c/Users/nh1221/data-center/_v3
git pull   # or copy the updated files

# Test connectivity first:
ssh ubuntu@172.16.2.40 -o StrictHostKeyChecking=no -o ConnectTimeout=5 echo ok

# Then run:
ansible-playbook playbooks/reused/deploy_kubespray.yml -i inventory/hosts.yml
If SSH still can't reach 172.16.2.x from WSL2, the VMs are on a libvirt bridge that WSL2's virtual network can't route to. In that case, run from native Linux on the R810 (not WSL):

  ssh nh1221@localhost   # escape WSL2 → native Linux
cd /path/to/data-center/_v3
ansible-playbook playbooks/reused/deploy_kubespray.yml -i inventory/hosts.yml

XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
Run Phase 5 alone using the verify tag:
ansible-playbook playbooks/reused/deploy_kubespray.yml -i inventory/hosts.yml --tags verify
This connects to the first controller (Host12_1), copies the kubeconfig, then runs:

kubectl get nodes -o wide — node status
Readiness check (all nodes Ready, count matches expected)
kubectl get pods -A -o wide — all system pods
CoreDNS running assertion
kubectl cluster-info — API server + CoreDNS endpoints
For a quick manual check directly on the controller:
ansible -i inventory/hosts.yml Host12_1 -m shell -a "kubectl get nodes -o wide && echo '---' && kubectl get pods -A" -e "KUBECONFIG=/etc/kubernetes/admin.conf"


