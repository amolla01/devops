I’m checking the Calico post-deploy play against the cluster configuration so I can pinpoint why the IPPool apply is failing and what the correct next step is.

Read [](file:///c%3A/dc-lab/clab/sonic-clab/playbooks/calico-post-deploy.yml)

Read [](file:///c%3A/dc-lab/clab/sonic-clab/group_vars/k8s_cluster.yml)

## Root cause

This failure is not in the YAML itself. It means the cluster API is up, but the Calico CRDs are not installed yet.

The key message is:

> `no matches for kind "IPPool" in version "projectcalico.org/v3"`  
> `ensure CRDs are installed first`

That is exactly what happens when `kubectl apply` tries to create a Calico CR object before the `projectcalico.org/v3` CRDs have been registered.

The play in playbooks/calico-post-deploy.yml does this in order:

1. Creates the Calico token RBAC
2. Tries to apply `IPPool`
3. Tries to apply `FelixConfiguration`
4. Tries to apply `BGPConfiguration`

The failure occurs at step 2 because the CRD is missing. So the offending task is the `Apply Calico IPPool` block in playbooks/calico-post-deploy.yml.

---

## Why this happened

The cluster is configured for Calico in group_vars/k8s_cluster.yml:

- `k8s_cni: calico`
- `calico_network_backend: "none"`
- `calico_ipip_mode: "Never"`
- `calico_vxlan_mode: "Never"`

That part is fine. But the post-deploy play assumes Calico is already fully installed. In your output, it is not: the CRD layer is absent.

---

## What to do next

Run these on the control node:

```bash
kubectl get crd | grep -i calico
kubectl api-resources | grep projectcalico
kubectl -n kube-system get pods
kubectl -n kube-system get ds calico-node
```

If you see no Calico CRDs, the cluster did not finish installing Calico cleanly and the correct fix is to repair or rerun the Calico/Kubespray install path, not to keep applying `IPPool` objects.

A safer repo-side guard would be to add a preflight check before the IPPool step:

```yaml
- name: Verify Calico CRDs are present
  ansible.builtin.command: kubectl get crd ippools.crd.projectcalico.org
  changed_when: false
  failed_when: false
```

and then fail early with a clear message if missing.

---

## Bottom line

This is not a bad YAML definition. It is a cluster-state problem:

- RBAC fix succeeded
- Calico CRDs are still missing
- therefore `IPPool` cannot be created

The next required action is to fix the Calico installation state on the cluster, then rerun the post-deploy play.
I’m updating the Calico repair play to include the Env var cleanup and explicit CRD readiness checks, then I’ll tell you whether Multus should follow after the Calico repair succeeds.

Read [](file:///c%3A/dc-lab/clab/sonic-clab/playbooks/multus-nad-deploy.yml)

Read [](file:///c%3A/dc-lab/clab/sonic-clab/playbooks/site.yml)

Replacing 91 lines with 122 lines in [](file:///c%3A/dc-lab/clab/sonic-clab/playbooks/calico-post-deploy.yml)


```

```


Checked [](file:///c%3A/dc-lab/clab/sonic-clab/playbooks/calico-post-deploy.yml), no problems found

Ran terminal command: cd /d/c:/dc-lab/clab/sonic-clab ; ANSIBLE_CONFIG=$PWD/ansible.cfg ansible-playbook -i inventory.yml playbooks/calico-post-deploy.yml --syntax-check
Completed with input: cd /d/c:/dc-lab/clab/sonic-clab ; ANSIBLE_CONFIG=$PWD/ansible.cfg ansible-playbook -i inventory.yml playbooks/calico-post-deploy.yml --syntax-check

The first syntax check hit a PowerShell path issue, so I’m re-running it with the Windows-native environment setup to get a real parse result.

Ran terminal command: cd 'C:\dc-lab\clab\sonic-clab'; $env:ANSIBLE_CONFIG = "$PWD\ansible.cfg"; ansible-playbook -i inventory.yml playbooks/calico-post-deploy.yml --syntax-check
Completed with input: cd 'C:\dc-lab\clab\sonic-clab'; $env:ANSIBLE_CONFIG = "$PWD\ansible.cfg"; ansible-playbook -i inventory.yml playbooks/calico-post-deploy.yml --syntax-check

## ✅ Updated Calico repair play

I enhanced playbooks/calico-post-deploy.yml so it now covers the failure pattern we observed:

- waits for the Calico CRDs to exist and become Established before applying `IPPool`
- re-enforces the Calico token RBAC rule for `serviceaccounts/token`
- repairs the global `calico-node` DaemonSet env to remove the bad/duplicate `IP_AUTODETECTION_METHOD` pattern and force the lab-safe value
- disables IP-IP and VXLAN explicitly for this deployment
- restarts `calico-node` and waits for the DaemonSet rollout to complete
- only then applies the `IPPool`, `FelixConfiguration`, and `BGPConfiguration`

This directly addresses the issues we saw:
- `IPPool` failed because CRDs were not ready/installed
- `calico-node` was crashing because of the global env mismatch
- the RBAC token permission was missing for the CNI bootstrap flow

I also checked the file for editor-reported issues, and VS Code reported: “No errors found” for playbooks/calico-post-deploy.yml.

> I could not run an actual Ansible syntax check from this workstation because `ansible-playbook` is not installed here; the terminal returned “ansible-playbook not recognized”. So the repo-side edit is in place and parse-clean in the editor, but the live kubectl validation still needs to happen on the lab control node.

---

## Should you run Multus after this?

Yes — but only after Calico is healthy.

The normal sequence in playbooks/site.yml is:

1. Kubespray
2. Calico repair
3. Multus NAD deploy
4. MetalLB / Ceph / addons

And playbooks/multus-nad-deploy.yml is gated to run after Kubernetes is stable enough to accept CRDs and network objects. It is not the first recovery step when Calico is still broken.

So the correct order is:

1. fix and verify Calico
2. `kubectl -n kube-system get pods`
3. wait until `calico-node` is `Running` and `Ready`
4. then run:
   - `ansible-playbook -i inventory.yml playbooks/multus-nad-deploy.yml`

---

## Recommended live validation on the control node

Run this once the cluster is reachable:

```bash
kubectl -n kube-system get ds calico-node
kubectl -n kube-system get pods
kubectl rollout status daemonset/calico-node -n kube-system --timeout=300s
kubectl get nodes
```

If those are healthy, continue with Multus:

```bash
ANSIBLE_CONFIG=$PWD/ansible.cfg ansible-playbook -i inventory.yml playbooks/multus-nad-deploy.yml
```

If you want, I can also tighten playbooks/calico-post-deploy.yml one more step by adding an explicit preflight check that aborts early with a clear message if Calico never comes up.

Made changes.
