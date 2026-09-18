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



Now I have everything I need. This log set is decisive — let me pin down the two distinct failures before fixing. 

Read [](file:///c%3A/dc-lab/clab/sonic-clab/playbooks/calico-post-deploy.yml#168-168), lines 168 to 190

The RBAC fix worked (install-cni now exits clean and writes `10-calico.conflist`), which uncovered the *actual* two problems. Let me apply the fixes: switch IP autodetection off the fragile `ens2` guess onto the known-good node InternalIP, and make diagnostics capture the calico-node (Felix) container logs, not just install-cni.  

Replacing 15 lines with 19 lines in [](file:///c%3A/dc-lab/clab/sonic-clab/playbooks/calico-post-deploy.yml)


```

```


Ran terminal command: wsl bash -lc 'cd /mnt/c/dc-lab/clab/sonic-clab && export ANSIBLE_CONFIG=$PWD/ansible.cfg && ansible-playbook -i inventory.yml playbooks/calico-post-deploy.yml --syntax-check && echo CALICO_SYNTAX_OK'

Updated memory file [](file:///c%3A/Users/nh4134/AppData/Roaming/Code/User/workspaceStorage/77d38b8fb836138bdc64636f049387ed/GitHub.copilot-chat/memory-tool/memories/OTI0ZDZiNDEtMmMwOC00MTZhLTgzOTktNWViOTA4ZGQ0MTM4/lab-controlpath.md)

Playbook fixes are in and syntax-checked green. Here's the full deep dive.

## What the logs actually prove

Your logs let us peel this apart cleanly. The RBAC fix worked — the story has moved on:

1. **install-cni now succeeds.** Its log ends with `Created /host/etc/cni/net.d/10-calico.conflist … Done configuring CNI. Sleep= false`, and `crictl ps -a` shows `install-cni … Exited` with the init containers (`upgrade-ipam`, `install-cni`, `mount-bpffs`) all exiting **0**. On the master, `/etc/cni/net.d/10-calico.conflist` and `calico-kubeconfig` exist. So the token-RBAC chapter is closed.

2. **All 16 nodes are `Ready`.** That's why the convergence string went from `''` to `16 16` — kubelet marks the node Ready once the CNI conf file is on disk, independent of the pod.

3. **The thing crash-looping now is the *main* `calico-node` (Felix) container, not an init container.** The pod describe shows `spec.containers{calico-node}` and `crictl` shows `calico-node … Exited … 6` with `exit_status:1`. The readiness message `felix is not ready: … dial tcp 127.0.0.1:9099: connect: connection refused` is a *symptom*: the container exits during startup, so nothing is listening on Felix's port 9099.

A container that exits `1` deterministically on **all 16 nodes**, 6–7 times each over 16 minutes, is a **config failure**, not slowness. That points straight at one env var.

## Root cause #1 — the IP-autodetection guess (deterministic Calico killer)

The `Repair the global Calico DaemonSet env` task was setting:

```
IP_AUTODETECTION_METHOD=interface=^ens2$
```

`ens2` was a **guess**. `calico/node` startup (`startup.go`) runs IP autodetection *before* Felix starts; if no interface matches that regex, it logs `Unable to autodetect an IPv4 address using interface regex 'ens2'` and **exits 1** → CrashLoopBackOff on every node → `AVAILABLE 0` → your assert fails. It doesn't matter that the CNI is installed; the pod can never go Ready.

**Fix applied:** switched to the NIC-name-independent method that uses the address Kubernetes already assigned each node (the `10.0.x.y` InternalIPs you saw in `get nodes -o wide`):

```yaml
IP_AUTODETECTION_METHOD={{ calico_ip_autodetect_method | default('kubernetes-internal-ip') }}
```

This can't miss — every node has a valid InternalIP, and it's independent of whether the interface is `ens2`, `ens3`, `enp1s0`, etc. I also made the diagnostic dump the `calico-node` container logs (current **and** `--previous`), so future failures show the Felix error directly instead of only install-cni.

**Confirm the theory in 5 seconds** (before/after re-run):
```bash
kubectl -n kube-system logs $(kubectl -n kube-system get pod -l k8s-app=calico-node -o name | head -1) -c calico-node --previous | head -40
```
You should see the `Unable to autodetect` line. After the fix + re-run, that same command shows Felix starting normally.

## Root cause #2 — etcd is disk-bound (the systemic stressor)

This is real and independent, and it's why the *whole control plane* is twitchy. Every etcd VM shows:

```
slow fdatasync   took 2.226s  expected 1s
leader failed to send out heartbeat on time; ... overloaded likely from slow disk   heartbeat-interval 600ms
apply request took too long   took 1.9s–2.3s   expected 100ms
waiting for ReadIndex response took too long, retrying
```

Interpretation:
- Your **600/6000 tuning did take effect** (`heartbeat-interval: 600ms` is right there in the log), and it's what's keeping quorum from collapsing. Good.
- But the **backing disk fsync takes 2+ seconds**. etcd must `fdatasync` every raft commit to the WAL; when that takes 2s, apiserver reads/writes stall, which is exactly why you also saw `kube-apiserver Readiness probe failed: statuscode 500`, `kube-controller-manager … connection refused`, and scheduler/controller **leader elections churning**. Calico's startup talking to that browning-out apiserver adds intermittent slowness on top of the deterministic `ens2` crash.

Widening timeouts can't fix a 2-second fsync — you have to make fsync cheap. For a **virtual lab**, the highest-leverage, in-guest knob is to tell etcd to stop waiting on physical sync:

On **each** of `k8s-db-01/02/03` (note `/etc/etcd.env` is root-only — use `sudo`), one member at a time:

```bash
sudo grep -q UNSAFE_NO_FSYNC /etc/etcd.env || \
  echo 'ETCD_UNSAFE_NO_FSYNC=true' | sudo tee -a /etc/etcd.env
sudo systemctl restart etcd
# wait for this member to report healthy before moving to the next:
sudo systemctl status etcd --no-pager | head -5
```

Do them **serially** (restart db-01, confirm healthy, then db-02, then db-03) so you never drop quorum. This turns the 2s WAL sync into microseconds and the `apply request took too long` / heartbeat warnings disappear.

> Trade-off, stated plainly: `unsafe-no-fsync` means an abrupt power-loss of an etcd VM can lose its last few writes. For a lab that's acceptable; do **not** carry this into production. The permanent/production-grade alternative is to fix it at the hypervisor: give the etcd data disk `cache=writeback` (or `unsafe`) and, ideally, back it with SSD/NVMe rather than a qcow2 on spinning/overcommitted storage.

Optional extra relief while stressed: keep the `logSeverityScreen: Warning` you already set, and avoid running multiple heavy playbooks against the cluster simultaneously.

## Do this next (in order)

1. **Sync** this repo edit into your run repo (`/mnt/c/Users/nh1221/dc_lab/clab/sonic-clab`) — the `IP_AUTODETECTION_METHOD` change is the actual fix.
2. Apply the **etcd `UNSAFE_NO_FSYNC`** change on the three db VMs (serial restarts) to calm the datastore.
3. Re-run:
   ```bash
   ANSIBLE_CONFIG=$PWD/ansible.cfg ansible-playbook -i inventory.yml playbooks/calico-post-deploy.yml
   ```

Expected result: `calico-node` pods go `1/1 Running`, the DaemonSet converges to `16 16 16`, the assert passes, and CoreDNS (currently blocked by no CNI) schedules right after. If anything still fails, the new diagnostic will now print the Felix (`calico-node`) crash reason directly in the assert message.

Made changes.
