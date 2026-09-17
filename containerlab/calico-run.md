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
