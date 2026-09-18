Compacted conversationThe empty diagnostics are the tell here — look at the assert message:

```
Diagnostics: ### calico-node DaemonSet:\n### calico-node pods:\n### install-cni init logs ():
```

Every kubectl section came back **empty**, and the convergence string is `''`. That means the `kubectl get ds calico-node ... -o jsonpath` produced nothing at all. Let me read the exact wait/diagnostic tasks to see why they're returning empty while the earlier `set env`/`rollout restart` tasks succeeded. 

Read [](file:///c%3A/dc-lab/clab/sonic-clab/playbooks/calico-post-deploy.yml#1-1), lines 1 to 60

Read [](file:///c%3A/dc-lab/clab/sonic-clab/playbooks/calico-post-deploy.yml#180-180), lines 180 to 320

I have the full picture now. The decisive clue is in your assert message:

```
Diagnostics: ### calico-node DaemonSet:\n### calico-node pods:\n### install-cni init logs ():
```

**Every kubectl block produced zero stdout**, and the convergence string is `''` (not even `"16 16 "`). Two earlier tasks (`kubectl rollout restart daemonset/calico-node` had no `failed_when` and reported `changed`, so the DaemonSet object *exists*), yet the wait's `-o jsonpath` and the diagnostic's `get ds -o wide` returned nothing to stdout — which means those reads are erroring to **stderr** (resource-not-found / no pods / apiserver read error), and the playbook was only surfacing `.stdout`. So the playbook has been flying blind. Let me fix the diagnostics to actually capture evidence, then give you the manual debug commands. 

Replacing 39 lines with 53 lines in [](file:///c%3A/dc-lab/clab/sonic-clab/playbooks/calico-post-deploy.yml)


```

```


Ran terminal command: wsl bash -lc 'cd /mnt/c/dc-lab/clab/sonic-clab && export ANSIBLE_CONFIG=$PWD/ansible.cfg && ansible-playbook -i inventory.yml playbooks/calico-post-deploy.yml --syntax-check && echo CALICO_SYNTAX_OK'

Syntax is green. On the next run the failure message will now include node state, DaemonSet describe, kube-system events, pod describe, **and** `rc`/`stderr` — so it can no longer come back blank.

## What the last run actually told us

The RBAC fix landed (install-cni is no longer the blocker — otherwise the diagnostics would have shown crash logs). The new signal is that the convergence string was **empty (`''`)**, not `"16 16 0"`. An empty string means `kubectl get ds calico-node -o jsonpath='{.status.desiredNumberScheduled}...'` returned **nothing** — i.e. `desiredNumberScheduled` is `0`/absent (Kubernetes omits zero-value int fields). Combined with the `get ds -o wide` and `get pods` blocks also being empty, this points to **no calico-node pods being scheduled at all** (desired=0), or the reads erroring — not pods stuck on init. That's a node/scheduling or datastore-read problem, so we need real cluster state.

## Debug commands — run these in order

Fastest way from the Lab-ControlNode (uses your existing jump/inventory):

```bash
cd /mnt/c/Users/nh1221/dc_lab/clab/sonic-clab
export ANSIBLE_CONFIG=$PWD/ansible.cfg
ansible k8s-master-01 -i inventory.yml -m shell -a '
  echo "== NODES ==";        kubectl get nodes -o wide
  echo "== NODE READY/TAINTS =="; kubectl get nodes -o jsonpath="{range .items[*]}{.metadata.name}{\" ready=\"}{.status.conditions[?(@.type==\"Ready\")].status}{\" taints=\"}{.spec.taints}{\"\n\"}{end}"
  echo "== DS STATUS ==";     kubectl -n kube-system get ds calico-node -o wide; kubectl -n kube-system get ds calico-node -o jsonpath="{.status}{\"\n\"}"
  echo "== DS DESCRIBE ==";   kubectl -n kube-system describe ds calico-node | tail -30
  echo "== PODS ==";          kubectl -n kube-system get pods -o wide | grep -Ei "NAME|calico|coredns"
  echo "== EVENTS ==";        kubectl -n kube-system get events --sort-by=.lastTimestamp | tail -30
  echo "== ETCD HEALTH ==";   kubectl get --raw="/healthz/etcd"; echo; kubectl get --raw="/readyz?verbose" | tail -20
'
```

**Interpretation key:**
- `== NODES ==` shows the node(s) `NotReady` → the node has no working CNI (chicken-and-egg); look at `describe ds` / kubelet next.
- `== DS STATUS ==` `desiredNumberScheduled: 0` → the DaemonSet matches zero nodes. Check `describe ds` events ("0/N nodes are available: … untolerated taint …") and node taints above.
- Pods **Pending** → scheduler/taint/resource. Pods **Running but 0/1 Ready** → felix-ready failing (datastore/routing). **No pods listed** → confirms desired=0.

If nodes are `NotReady` or pods are missing, SSH to the master VM (through the R810 jump) and check the node runtime:

```bash
# On the k8s master VM:
sudo journalctl -u kubelet -n 120 --no-pager | grep -Ei 'cni|calico|NotReady|network'
ls -l /etc/cni/net.d/            # empty => no CNI conf written => node stays NotReady
ls -l /opt/cni/bin/ | grep -i calico
sudo crictl pods 2>/dev/null | grep -i calico
sudo crictl ps -a 2>/dev/null | grep -i calico
sudo journalctl -u containerd -n 80 --no-pager | tail -40
```

And on each etcd VM (`k8s-db-01/02/03`) to confirm the timing change took and the cluster is stable:

```bash
grep -E 'HEARTBEAT_INTERVAL|ELECTION_TIMEOUT' /etc/etcd.env
sudo systemctl status etcd --no-pager | head -15
sudo journalctl -u etcd -n 60 --no-pager | grep -Ei 'elect|leader|lost|slow|took too long'
```

`took too long` / repeated `leader changed` lines mean the datastore is still flapping (→ fix fabric routing with `playbooks/linux-bgp.yml`); a clean log with the new 600/6000 values means etcd is stable and the problem is purely node/CNI scheduling.

Paste back the `== NODES ==`, `== DS STATUS/DESCRIBE ==`, and `== PODS ==` output and I'll pinpoint the exact fix. My current strongest hypothesis: the single node is `NotReady` (no CNI conf in `/etc/cni/net.d`), which makes the DaemonSet report `desired=0` — a bootstrap ordering issue rather than RBAC.

Made changes.
