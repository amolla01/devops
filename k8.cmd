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
