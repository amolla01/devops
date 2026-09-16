I’m checking the wrapper command surface now, because a 3-hour failed rerun means the next useful fix is to make retries narrower instead of re-running the whole Kubespray path every time.

Read [](file:///c%3A/dc-lab/clab/sonic-clab/playbooks/kubespray.yml#155-155), lines 155 to 178

The current wrapper always reruns the entire `cluster.yml`, which is wasting hours once the control plane already exists. I’m adding a narrow retry hook so you can restart at the join/app stage instead of paying the full cost every time.

Generating patch (19 lines) in [](file:///c%3A/dc-lab/clab/sonic-clab/playbooks/kubespray.yml)


```

```
I’ve added resume controls to the wrapper so you can stop burning 3 hours on every retry. I’m validating the edit now; then I’ll tell you the exact rerun shape that matches your current cluster state.

Ran terminal command: wsl.exe -d ubuntu-24.04 bash -lc 'cd /mnt/c/dc-lab/clab/sonic-clab && ANSIBLE_CONFIG=$PWD/ansible.cfg ansible-playbook --syntax-check playbooks/kubespray.yml'

Then the right move is to stop treating this like a fresh deploy. A 3-hour failed rerun means the wrapper needed a resume path, so I added one in kubespray.yml: it now accepts optional `kubespray_limit` and `kubespray_start_at_task` passthroughs to the inner Kubespray command, and the playbook still syntax-checks cleanly.

Given your current state:
- control plane exists
- several workers are already registered
- nodes are still `NotReady`

you should not keep paying the full `cluster.yml` cost unless the log shows a failure in an early foundational role. The next rerun should be narrow.

Use the wrapper like this from your control node:

```bash
ANSIBLE_CONFIG=$PWD/ansible.cfg ansible-playbook -i inventory.yml playbooks/kubespray.yml \
  -e kubespray_forks=2 \
  -e "kubespray_start_at_task=Kubernetes Apps | Wait for kube-apiserver"
```

If the failure is still specifically around remaining workers joining, make it narrower:

```bash
ANSIBLE_CONFIG=$PWD/ansible.cfg ansible-playbook -i inventory.yml playbooks/kubespray.yml \
  -e kubespray_forks=2 \
  -e "kubespray_limit=kube_node" \
  -e "kubespray_start_at_task=Kubeadm | Create kubeadm token for joining nodes with 24h expiration (default)"
```

Two constraints matter here:
1. `--start-at-task` only works if the named task is later than the real failure root. If the underlying break is earlier, this will not help.
2. `--limit kube_node` is only appropriate once the control plane is already healthy enough to serve joins and app deployment.

The important delta is this: the codebase now supports targeted retries, so you should no longer need another blind 3-hour full run just to test whether the remaining workers or CNI can finish.

If you can paste the tail of `/opt/fabric-cache/logs/kubespray-inner.log` from the latest failed run, I can tell you which of those two resume commands is the correct one instead of guessing.

Made changes.

I’m checking the wrapper command surface now, because a 3-hour failed rerun means the next useful fix is to make retries narrower instead of re-running the whole Kubespray path every time.

Read [](file:///c%3A/dc-lab/clab/sonic-clab/playbooks/kubespray.yml#155-155), lines 155 to 178

The current wrapper always reruns the entire `cluster.yml`, which is wasting hours once the control plane already exists. I’m adding a narrow retry hook so you can restart at the join/app stage instead of paying the full cost every time.

Generating patch (19 lines) in [](file:///c%3A/dc-lab/clab/sonic-clab/playbooks/kubespray.yml)


```

```
I’ve added resume controls to the wrapper so you can stop burning 3 hours on every retry. I’m validating the edit now; then I’ll tell you the exact rerun shape that matches your current cluster state.

Ran terminal command: wsl.exe -d ubuntu-24.04 bash -lc 'cd /mnt/c/dc-lab/clab/sonic-clab && ANSIBLE_CONFIG=$PWD/ansible.cfg ansible-playbook --syntax-check playbooks/kubespray.yml'

Then the right move is to stop treating this like a fresh deploy. A 3-hour failed rerun means the wrapper needed a resume path, so I added one in kubespray.yml: it now accepts optional `kubespray_limit` and `kubespray_start_at_task` passthroughs to the inner Kubespray command, and the playbook still syntax-checks cleanly.

Given your current state:
- control plane exists
- several workers are already registered
- nodes are still `NotReady`

you should not keep paying the full `cluster.yml` cost unless the log shows a failure in an early foundational role. The next rerun should be narrow.

Use the wrapper like this from your control node:

```bash
ANSIBLE_CONFIG=$PWD/ansible.cfg ansible-playbook -i inventory.yml playbooks/kubespray.yml \
  -e kubespray_forks=2 \
  -e "kubespray_start_at_task=Kubernetes Apps | Wait for kube-apiserver"
```

If the failure is still specifically around remaining workers joining, make it narrower:

```bash
ANSIBLE_CONFIG=$PWD/ansible.cfg ansible-playbook -i inventory.yml playbooks/kubespray.yml \
  -e kubespray_forks=2 \
  -e "kubespray_limit=kube_node" \
  -e "kubespray_start_at_task=Kubeadm | Create kubeadm token for joining nodes with 24h expiration (default)"
```

Two constraints matter here:
1. `--start-at-task` only works if the named task is later than the real failure root. If the underlying break is earlier, this will not help.
2. `--limit kube_node` is only appropriate once the control plane is already healthy enough to serve joins and app deployment.

The important delta is this: the codebase now supports targeted retries, so you should no longer need another blind 3-hour full run just to test whether the remaining workers or CNI can finish.

If you can paste the tail of `/opt/fabric-cache/logs/kubespray-inner.log` from the latest failed run, I can tell you which of those two resume commands is the correct one instead of guessing.

Made changes.

No. The second command is **not broader**. It is actually **narrower in host scope** and **safer for your current failure mode**.

The difference is:

1. First command:
```bash
ANSIBLE_CONFIG=$PWD/ansible.cfg ansible-playbook -i inventory.yml playbooks/kubespray.yml \
  -e kubespray_forks=2 \
  -e "kubespray_start_at_task=Kubernetes Apps | Wait for kube-apiserver"
```
This is broader in host scope and later in the play. It assumes join/CNI prerequisites are already done correctly. If they are not, it skips too much and can fail in a less obvious way.

2. Second command:
```bash
ANSIBLE_CONFIG=$PWD/ansible.cfg ansible-playbook -i inventory.yml playbooks/kubespray.yml \
  -e kubespray_forks=2 \
  -e "kubespray_limit=kube_node" \
  -e "kubespray_start_at_task=Kubeadm | Create kubeadm token for joining nodes with 24h expiration (default)"
```
This is narrower in host scope and starts earlier in the worker-join slice. For your current state, that is the lower-risk option.

Given what you have now:
- control plane exists
- some workers joined
- many/all nodes are still `NotReady`
- previous failures were around join/reachability

the **second command is the correct next attempt**.

One caution: if your inventory defines control-plane nodes inside `kube_node` too, this limit may still include them. That is usually still acceptable, but it is less “workers-only” than the name suggests. Even then, it is still safer than jumping straight to the later Kubernetes apps stage.

So the practical sequence should be:

1. Run the second command first.
2. If that succeeds and workers finish joining, then run a broader follow-up to finish late-stage apps/CNI if needed.
3. If it fails again, read `/opt/fabric-cache/logs/kubespray-inner.log` and we diagnose the exact remaining host/task instead of doing another 3-hour blind rerun.

So yes: use the second one next, but not because it is broader. Use it because it is **narrower and better aligned to the actual failure slice**.

You should **keep** `ANSIBLE_CONFIG=$PWD/ansible.cfg` on the **outer** command.

There are two separate Ansible layers now:

1. Outer run:
- runs your wrapper playbook in this repo
- needs this repo’s config from ansible.cfg
- without it, Ansible may ignore the repo-local config because the repo is under `/mnt/c/...` and treated as world-writable

2. Inner run:
- runs Kubespray inside `{{ kubespray_dest }}`
- should **not** inherit the outer repo config
- I already fixed that in kubespray.yml by unsetting inherited `ANSIBLE_CONFIG` and explicitly setting the inner one to Kubespray’s own ansible.cfg

So the correct model is:

- outer command: keep `ANSIBLE_CONFIG=$PWD/ansible.cfg`
- inner Kubespray invocation: already isolated to Kubespray’s own config

If you drop it from the outer command, you risk going back to the earlier class of problems where Ansible ignores repo-local settings like `roles_path`, SSH defaults, and inventory behavior. The inner fix does not replace that; it only prevents the outer config from leaking into Kubespray.

So yes, it is “already there” in the sense that you keep passing it on the outer command, and that is still the right thing to do. The part we changed was making sure it does **not** bleed into the nested Kubespray run.

I’m fixing the resume-argument quoting at the shell boundary so task names with spaces and `|` survive intact instead of being truncated to `Kubeadm`.

Read [](file:///c%3A/dc-lab/clab/sonic-clab/playbooks/kubespray.yml#155-155), lines 155 to 190

I’ve got the exact weak point: the wrapper is building a shell command inline, and `|` inside task names is being interpreted by the shell. I’m switching that one block to a bash array so optional arguments survive exactly as data, not shell syntax.

Generating patch (58 lines) in [](file:///c%3A/dc-lab/clab/sonic-clab/playbooks/kubespray.yml)


```

```
I replaced the inline shell concatenation with a bash argument array, which is the right fix for values like `Kubeadm | Create ...` that contain both spaces and pipe characters. I’m validating it now; if syntax holds, the resume path is usable again.

Ran terminal command: wsl.exe -d ubuntu-24.04 bash -lc 'cd /mnt/c/dc-lab/clab/sonic-clab && ANSIBLE_CONFIG=$PWD/ansible.cfg ansible-playbook --syntax-check playbooks/kubespray.yml'

The resume path is fixed now. I changed kubespray.yml so the inner Kubespray command is built as a Bash array instead of inline shell text. That matters because task names like `Kubeadm | Create kubeadm token for joining nodes with 24h expiration (default)` contain spaces and `|`, and the shell was previously mangling them down to `Kubeadm`. The wrapper still syntax-checks cleanly.

You can retry the narrow resume command again:

```bash
ANSIBLE_CONFIG=$PWD/ansible.cfg ansible-playbook -i inventory.yml playbooks/kubespray.yml \
  -e kubespray_forks=2 \
  -e "kubespray_limit=kube_node" \
  -e "kubespray_start_at_task=Kubeadm | Create kubeadm token for joining nodes with 24h expiration (default)"
```

At this point the wrapper has the main hardening it was missing:
- correct containerd fix
- persistent inner log path
- no SSH multiplexing for the inner run
- default forks at `2`
- inner run forced to use Kubespray’s own ansible.cfg
- safe quoting for `--limit` and `--start-at-task`

If this still fails, the next signal should be directly from `/opt/fabric-cache/logs/kubespray-inner.log`, not from the wrapper itself.

Made changes.
