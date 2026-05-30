After recreating all 18 VMs, the shortest path to restore connectivity and BGP for the full lab is:

Validate the rebuilt VMs are reachable.
Run day-0 for all hosts.
Run day-1 deploy for all hosts.
Run day-1 verify for all hosts.
If exit routers still fail, rerun only that slice for focused debugging.
The two playbooks that matter for connectivity and BGP are deploy_day0.yml and

deploy_day1.yml. The wrapper maps day0 and day1 directly to those playbooks in deploy_lab_v3.sh.

Run these from /mnt/c/Users/nh1221/data-center/_v3:

./deploy_lab_v3.sh --remote-v13-host nh1221@R810 --ssh-key /mnt/c/Users/nh1221/.ssh/id_dc_lab --profile ubuntu_r810_kvm kvm-validate

  ansible-playbook playbooks/reused/deploy_day0.yml -i inventory/hosts.yml -e automation_profile=ubuntu_r810_kvm -v

  ansible-playbook playbooks/reused/deploy_day1.yml -i inventory/hosts.yml -e automation_profile=ubuntu_r810_kvm --tags deploy -v

  ansible-playbook playbooks/reused/deploy_day1.yml -i inventory/hosts.yml -e automation_profile=ubuntu_r810_kvm --tags verify -v

  That full sequence covers all three areas you asked for:

fabric switches
servers
exit routers
If you want the wrapper form instead of raw playbooks, the equivalent high-level sequence is:

./deploy_lab_v3.sh --profile ubuntu_r810_kvm day0
./deploy_lab_v3.sh --profile ubuntu_r810_kvm day1

But for your current troubleshooting, the raw ansible-playbook form is better because you can separate deploy from verify.

If the full-lab verify still fails and you want to focus only on the exit routers afterward, use:
ansible-playbook playbooks/reused/deploy_day1.yml -i inventory/hosts.yml -e automation_profile=ubuntu_r810_kvm --limit exit_routers --tags deploy -v

  ansible-playbook playbooks/reused/deploy_day1.yml -i inventory/hosts.yml -e automation_profile=ubuntu_r810_kvm --limit exit_routers --tags verify -v

  If you also want the post-playbook verification commands, run these right after --tags verify:

ssh Border_Leaf1 "sudo vtysh -c 'show bgp summary'"
ssh Border_Leaf2 "sudo vtysh -c 'show bgp summary'"
ssh Exit_Router1 "/routing bgp connection print detail"
ssh Exit_Router1 "/routing bgp session print detail"
ssh Exit_Router2 "/routing bgp connection print detail"
ssh Exit_Router2 "/routing bgp session print detail"

  Recommended execution order for your current state:

kvm-validate
deploy_day0.yml
deploy_day1.yml --tags deploy
deploy_day1.yml --tags verify
If needed, rerun exit_routers only
If you want, I can turn that into one copy-paste runbook block with comments for the exact nh1221 environment.

GPT-5.4 • 1x

AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
Then check live RouterOS state directly, because that is the cheapest discriminating check now:
ssh Exit_Router1 "/ip firewall filter print detail"
ssh Exit_Router1 "/ip address print detail"
ssh Exit_Router1 "/interface ethernet print detail where running=yes"
ssh Exit_Router1 "/routing bgp session print detail"

ssh Exit_Router2 "/ip firewall filter print detail"
ssh Exit_Router2 "/ip address print detail"
ssh Exit_Router2 "/interface ethernet print detail where running=yes"
ssh Exit_Router2 "/routing bgp session print detail"

For the server-side Idle peers, the next useful step is separate and should not be mixed with the exit-router check:

Run --limit servers --tags deploy -v.
Run --limit "servers,leaves,border_leaves" --tags verify -v.
If the leaves still show host peers at msgRcvd=0/msgSent=0, capture one server’s ip -o link, cat /etc/netplan/*.yaml, and sudo vtysh -c "show bgp summary" output.
