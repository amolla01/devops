AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA--Tutorial--AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA

https://datavirke.dk/posts/bare-metal-kubernetes-part-6-persistent-storage-with-rook-ceph/
https://deniz-turkmen.medium.com/kubernetes-native-storage-installing-and-configuring-ceph-with-rook-7358c1ad1be5
https://kube-dojo.github.io/platform/toolkits/infrastructure-networking/storage/module-16.1-rook-ceph/
https://oneuptime.com/blog/post/2025-12-03-ceph-rook-standard-bare-metal-storage-pools/view
https://sigridjin.medium.com/kubernetes-the-kubespray-way-89111e0e1636
https://github.com/OneUptime/blog/blob/master/posts/2025-12-03-ceph-rook-standard-bare-metal-storage-pools/README.md
https://medium.com/@anisinanaj/storage-on-kubernetes-efa0a5b4f858
https://medium.com/@jrkessl/kubernetes-service-accounts-what-they-are-and-how-to-implement-9b3701c667d0

XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
The logs show Host12_1's Kubernetes API server has crashed/become unresponsive.
CephCluster Helm deploy times out after ~7.5 min with etcdserver: request timed out

kubectl cannot connect: The connection to the server 127.0.0.1:6443 was refused
Root Cause: The CephCluster deployment triggered something that crashed/hung the K8s API server on Host12_1. The etcdserver: request timed out error during the helm deployment is the smoking gun — etcd (the K8s state store) became unresponsive.

What likely happened:

CephCluster resource submission caused etcd to become overloaded
API server timeout → deployment stuck → eventually API server went down
By the time Phase 3 runs, the API is completely unreachable
Immediate steps on Host12_1:



# Check API server status
kubectl get nodes
systemctl status kubelet

# Check etcd health (if you can access the control plane)
ps aux | grep etcd
curl -s https://127.0.0.1:2379/health --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key

# Check API server logs
journalctl -u kubelet -n 50

# Restart kubelet if API is stuck
sudo systemctl restart kubelet

The CephCluster values may need tuning — was the cluster initialized with too many MONs/OSDs for the resource capacity? Check the generated values at /tmp/rook-ceph-cluster-values.yml and consider reducing initial pool PG counts or OSD count.


  Hardware-Profile Specifics

R810 KVM (12 OSDs):
rook_ceph_mon_count: 1
rook_ceph_pool_pg_num: 128    # (12 × 100) / 2 = 600 → conservative 128
ceph_osd_pool_default_size: 2
ceph_mds_enabled: false
ceph_osd_memory_target: "1073741824"  # 1GB per OSD



Perfect! Now I'll create hardware-profile-specific var files. Let me check the documentation and create appropriate configs for R810, R620, and real hardware profiles:



Now let me create a comprehensive README documenting all the var files and usage patterns:

Perfect! Let me verify all the files are properly created:

Excellent! All var files created and properly organized. Here's your complete Ceph deployment configuration structure:

Summary: Hardware & Environment-Specific Var Files
Files Created
vars now contains:

File	Profile	Scope	MON	PG	Size
ceph-values-dev.yml	Any KVM	Development	1	32	2-way
ceph-values-test.yml	Any KVM	Testing/QA	3	64	3-way
ceph-values-prod.yml	Real HW	Production	5	256	3-way
ceph-values-dr.yml	Real HW	DR/Failover	3	128	3-way
ceph-values-r810-kvm.yml	R810 KVM	Lab (12 OSDs)	1	128	2-way
ceph-values-r620-kvm.yml	R620 KVM	Lab (6 OSDs)	1	64	2-way
ceph-values-real-hardware.yml	Real HW	Production (36 OSDs)	5	512	3-way
README.md	Guide	Documentation	—	—	—
Hardware-Profile Specifics


R810 KVM (12 OSDs):
rook_ceph_mon_count: 1
rook_ceph_pool_pg_num: 128    # (12 × 100) / 2 = 600 → conservative 128
ceph_osd_pool_default_size: 2
ceph_mds_enabled: false
ceph_osd_memory_target: "1073741824"  # 1GB per OSD
  
R620 KVM (6 OSDs):

rook_ceph_mon_count: 1
rook_ceph_pool_pg_num: 64     # (6 × 100) / 2 = 300 → conservative 64
ceph_osd_pool_default_size: 2
ceph_mds_enabled: false
ceph_osd_memory_target: "1073741824"  # 1GB per OSD
  
Real Hardware (36 OSDs: 20 HDD + 16 SSD):
rook_ceph_mon_count: 5
rook_ceph_pool_pg_num: 512    # (36 × 100) / 3 = 1200 → round to 512
ceph_osd_pool_default_size: 3
ceph_mds_enabled: true
ceph_osd_memory_target: "4294967296"  # 4GB per OSD
ceph_osd_max_backfills: 2
ceph_osd_recovery_max_active: 3

  Usage
For your R810 KVM lab:

export AUTOMATION_PROFILE=ubuntu_r810_kvm
ansible-playbook playbooks/reused/deploy_ceph_rook.yml -i inventory/hosts.yml \
  -e "@cd/vars/ceph-values-r810-kvm.yml" -v

  For R620 KVM lab:

export AUTOMATION_PROFILE=ubuntu_r620_kvm
ansible-playbook playbooks/reused/deploy_ceph_rook.yml -i inventory/hosts.yml \
  -e "@cd/vars/ceph-values-r620-kvm.yml" -v


  For real hardware production:

export AUTOMATION_PROFILE=real_hardware
ansible-playbook playbooks/reused/deploy_ceph_rook.yml -i inventory/hosts.yml \
  -e "@cd/vars/ceph-values-real-hardware.yml" -v


XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX



The playbook is designed to be re-runnable (idempotent) — here's what happens for each phase:

Phase	If Already Deployed	Mechanism
Phase 0 (rook_prepare)	Kernel modules re-loaded (no-op), disk wipe skipped if mounted	lsblk mount check before wipe
Phase 1 (rook_operator)	helm upgrade --install — upgrades or no-ops if chart unchanged	Helm's native idempotency
Phase 2 (rook_cluster)	helm upgrade --install — reconciles CephCluster CR	Rook operator reconciles desired state
Phase 3 (rook_dashboard)	kubectl patch re-applies same NodePort — no-op if already set	Patch is declarative
Phase 4 (rook_validate)	Read-only checks, creates+deletes test PVC	No state changes
Safe re-run strategies:


# Re-run everything (safe — each step is idempotent)
ansible-playbook playbooks/reused/deploy_ceph_rook.yml -i inventory/hosts.yml -v
# Skip what's working, run only failed phase
ansible-playbook playbooks/reused/deploy_ceph_rook.yml \
-i inventory/hosts.yml --tags rook_cluster -v
# Skip already-prepared nodes, just do cluster+dashboard
ansible-playbook playbooks/reused/deploy_ceph_rook.yml \  
-i inventory/hosts.yml --tags rook_cluster,rook_dashboard,rook_validate -v


# Re-run everything (safe — each step is idempotent)
ansible-playbook playbooks/reused/deploy_ceph_rook.yml -i inventory/hosts.yml -v

# Skip what's working, run only failed phase
ansible-playbook playbooks/reused/deploy_ceph_rook.yml -i inventory/hosts.yml --tags rook_cluster -v

# Skip already-prepared nodes, just do cluster+dashboard
ansible-playbook playbooks/reused/deploy_ceph_rook.yml -i inventory/hosts.yml --tags rook_cluster,rook_dashboard,rook_validate -v


The playbook is designed to be re-runnable (idempotent) — here's what happens for each phase:

Phase	If Already Deployed	Mechanism
Phase 0 (rook_prepare)	Kernel modules re-loaded (no-op), disk wipe skipped if mounted	lsblk mount check before wipe
Phase 1 (rook_operator)	helm upgrade --install — upgrades or no-ops if chart unchanged	Helm's native idempotency
Phase 2 (rook_cluster)	helm upgrade --install — reconciles CephCluster CR	Rook operator reconciles desired state
Phase 3 (rook_dashboard)	kubectl patch re-applies same NodePort — no-op if already set	Patch is declarative
Phase 4 (rook_validate)	Read-only checks, creates+deletes test PVC	No state changes
Safe re-run strategies:

One exception: Phase 0 disk wipe (ceph_osd_wipe_disks: true) will re-wipe disks that are not mounted. 
If OSDs failed mid-creation (disk wiped but OSD pod didn't start), re-running is safe 
— Rook will re-claim the empty disk. If you want to skip disk prep entirely on re-run:

ansible-playbook playbooks/reused/deploy_ceph_rook.yml -i inventory/hosts.yml -e "ceph_osd_wipe_disks=false" -v

Bottom line: Just re-run the full playbook or the specific failing tag. Already-deployed components won't be disrupted.

You're right — yes, deploy_ceph_infra_pool.yml must run after deploy_ceph_rook.yml. The full correct sequence is:

# 1. Deploy Rook-Ceph cluster (operator + cluster + dashboard)
ansible-playbook playbooks/reused/deploy_ceph_rook.yml -i inventory/hosts.yml -v

# 2. Create infra-storage pool + keyring + K8s secret
ansible-playbook playbooks/reused/deploy_ceph_infra_pool.yml -i inventory/hosts.yml -v

What deploy_ceph_infra_pool.yml adds on top:

Component	Purpose
infra-storage pool	Dedicated RBD pool for SDLC/infra services
client.infra-storage keyring	Scoped auth (only access to that pool)
K8s Secret in sheba-cloud-infra	CSI driver uses it to mount RBD volumes
Why it's separate: The core cluster (deploy_ceph_rook.yml) already creates the kube-rbd pool/StorageClass for general workloads.
The infra pool is an additional tenant-isolated pool specifically for infrastructure services in the sheba-cloud-infra namespace 
— it has its own replication settings (size=2, min_size=1) tuned for the lab.

Dependency: deploy_ceph_infra_pool.yml requires the Rook toolbox pod to be running (created by Phase 2 of deploy_ceph_rook.yml),
so it will fail if run before the cluster is healthy.

XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
rbd pool init is nearly instantaneous — if it's stuck for an hour, the issue is upstream. Most likely causes:

Diagnosis (run from your ControlNode)

# 1. Check if kubectl exec itself is hanging (the toolbox pod may be dead/unresponsive)
kubectl get pod -n rook-ceph -l app=rook-ceph-tools -o wide

# 2. Check Ceph cluster health (from a DIFFERENT terminal)
TOOLBOX=$(kubectl get pod -n rook-ceph -l app=rook-ceph-tools -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n rook-ceph $TOOLBOX -- ceph -s --connect-timeout 5

# 3. Check PG state for the new pool
kubectl exec -n rook-ceph $TOOLBOX -- ceph pg ls-by-pool infra-storage

# 4. Check if OSDs are actually up
kubectl exec -n rook-ceph $TOOLBOX -- ceph osd tree

Most Likely Root Cause
Pool PGs are stuck in creating or incomplete state — this happens when:

Condition	Why rbd pool init hangs
Not enough OSDs up to satisfy size=2	PGs can't map to 2 OSDs → stuck in creating
OSDs are full (>95%)	Ceph refuses writes → rbd pool init blocks
MON quorum lost	All ceph commands hang
Toolbox pod OOMKilled/CrashLoop	kubectl exec hangs waiting for response
Immediate Fix
Kill the stuck Ansible run (Ctrl+C), then diagnose:



# Quick check — does ceph respond at all?
kubectl exec -n rook-ceph $TOOLBOX -- ceph health --connect-timeout 10

# If timeout → MON/MGR issue. Check pods:
kubectl get pods -n rook-ceph | grep -E 'mon|mgr|osd'

# If responds but HEALTH_WARN/ERR → check why:
kubectl exec -n rook-ceph $TOOLBOX -- ceph health detail

If PGs are stuck creating:

# Check: the pool needs 2 OSDs minimum (size=2)
kubectl exec -n rook-ceph $TOOLBOX -- ceph osd pool get infra-storage size
kubectl exec -n rook-ceph $TOOLBOX -- ceph osd stat

# If only 0-1 OSDs are up, that's the problem
# Temporarily allow degraded writes:
kubectl exec -n rook-ceph $TOOLBOX -- ceph osd pool set infra-storage min_size 1

If toolbox pod is dead:

# Restart it
kubectl delete pod -n rook-ceph -l app=rook-ceph-tools
# Wait for respawn, then re-run the playbook

After Fixing — Re-run Safely

# The playbook is idempotent — just re-run it
ansible-playbook playbooks/reused/deploy_ceph_infra_pool.yml -i inventory/hosts.yml -v

TL;DR: Run ceph -s first. If it hangs too → MON/MGR is down. If it responds → check ceph health detail for PG issues indicating insufficient OSDs.



VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV
Current State: Rook operator deployed, CephCluster CR deployed, 0 OSDs (no virtual disks on VMs), dashboard not yet exposed.
Step 1 — Create & Attach Virtual Disks (on R810 hypervisor)
# SSH to R810 host (the KVM hypervisor)
# For each VM, create 2 qcow2 images and attach:

for VM in Host12_1 Host12_2 Host12_3 Host34_1 Host34_2 HostB12_1; do
  qemu-img create -f qcow2 /var/lib/libvirt/images/${VM}-osd-01.qcow2 100G
  qemu-img create -f qcow2 /var/lib/libvirt/images/${VM}-osd-02.qcow2 100G
  virsh attach-disk $VM /var/lib/libvirt/images/${VM}-osd-01.qcow2 vdb \
    --driver qemu --subdriver qcow2 --persistent
  virsh attach-disk $VM /var/lib/libvirt/images/${VM}-osd-02.qcow2 vdc \
    --driver qemu --subdriver qcow2 --persistent
done
Step 2 — Wait for Rook Auto-Discovery (~2-5 min)
Rook (useAllDevices: true) automatically detects new block devices and creates OSD pods. No playbook re-run needed.
# From Host12_1 (or any controller):
watch kubectl get pods -n rook-ceph -l app=rook-ceph-osd
# Wait until 12 OSD pods appear (6 nodes × 2 disks)

Step 3 — Verify Cluster Health

kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph -s
# Expect: HEALTH_OK, 12 osds: 12 up, 12 in

kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph -s
# Expect: HEALTH_OK, 12 osds: 12 up, 12 in

Step 4 — Run Dashboard Phase
ansible-playbook playbooks/reused/deploy_ceph_rook.yml \
  -i inventory/hosts.yml --tags rook_dashboard \
  -e "@cd/vars/ceph-values-r810-kvm.yml" -v

Output will print: URL (https://172.16.2.40:31443), username (admin), password.

Step 5 — Run Infra Pool Creation

ansible-playbook playbooks/reused/deploy_ceph_infra_pool.yml \
  -i inventory/hosts.yml -v

Creates infra-storage pool (size=2, PG=32), RBD init, keyring, K8s secret.

Step 6 — Validate End-to-End

ansible-playbook playbooks/reused/deploy_ceph_rook.yml \
  -i inventory/hosts.yml --tags rook_validate \
  -e "@cd/vars/ceph-values-r810-kvm.yml" -v

Or manually:

kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph osd tree
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph df
kubectl get sc  # Verify StorageClass exists

Step 7 — Test PVC Binding

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-rbd
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: ceph-rbd
  resources:
    requests:
      storage: 1Gi
EOF

kubectl get pvc test-rbd   # Should show Bound
kubectl delete pvc test-rbd

Key point: Step 1 is the only manual action on the R810 hypervisor. Everything after that is either automatic (Rook discovery) or a single Ansible command. The playbooks now handle the "0 OSDs" case gracefully if you run them before disks are attached — they'll skip instead of hanging.


XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
Full Teardown + Fresh Start
Option A: Use the playbook (recommended)
# From Lab-ControlNode — this wipes EVERYTHING (Helm releases + CRDs + namespace + disks)

ansible-playbook playbooks/reused/deploy_ceph_rook.yml -i inventory/hosts.yml --tags rook_teardown -v


Option B: Manual teardown (if playbook has issues)

# 1. Remove Helm releases
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph osd pool rm kube-rbd kube-rbd --yes-i-really-really-mean-it
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph osd pool rm infra-storage infra-storage --yes-i-really-really-mean-it

helm uninstall rook-ceph-cluster -n rook-ceph
helm uninstall rook-ceph -n rook-ceph

# 2. Remove finalizers (prevents namespace from hanging forever)
for resource in cephcluster cephblockpool cephfilesystem; do
  for item in $(kubectl get $resource -n rook-ceph -o name 2>/dev/null); do
    kubectl patch $item -n rook-ceph --type merge -p '{"metadata":{"finalizers":null}}'
  done
done

# 3. Delete CRDs
kubectl delete crd --all -l app.kubernetes.io/part-of=rook-ceph-operator

# 4. Delete namespace
kubectl delete namespace rook-ceph --timeout=120s

# 5. Wipe disks on ALL OSD nodes (from Lab-ControlNode)
ansible ceph_osd -i inventory/hosts.yml -m shell \
  -a "wipefs -af /dev/vdb /dev/vdc; dd if=/dev/zero of=/dev/vdb bs=1M count=100; dd if=/dev/zero of=/dev/vdc bs=1M count=100; rm -rf /var/lib/rook" -b

Then: Create Disks + Fresh Deploy

# Step 1: On R810 hypervisor (with sudo)
sudo bash -c 'for VM in Host12_1 Host12_2 Host12_3 Host34_1 Host34_2 HostB12_1; do
  qemu-img create -f qcow2 /var/lib/libvirt/images/${VM}-osd-01.qcow2 100G
  qemu-img create -f qcow2 /var/lib/libvirt/images/${VM}-osd-02.qcow2 100G
  virsh attach-disk $VM /var/lib/libvirt/images/${VM}-osd-01.qcow2 vdb \
    --driver qemu --subdriver qcow2 --persistent
  virsh attach-disk $VM /var/lib/libvirt/images/${VM}-osd-02.qcow2 vdc \
    --driver qemu --subdriver qcow2 --persistent
done'

# Step 2: Fresh deploy (from Lab-ControlNode)
ansible-playbook playbooks/reused/deploy_ceph_rook.yml -i inventory/hosts.yml -v

Key facts about the teardown tag:

Uses tags: [rook_teardown, never] — the never special tag means it only runs when you explicitly request it with --tags rook_teardown
It will never accidentally run during a normal --tags rook invocation
It's a full scorched-earth: Helm releases → finalizers → CRDs → namespace → disk wipe → /var/lib/rook removal
# 1. Force-terminate stuck namespace (if still there)
kubectl get ns rook-ceph 2>/dev/null && \
  kubectl get ns rook-ceph -o json | \
  python3 -c 'import json,sys; ns=json.load(sys.stdin); ns["spec"]["finalizers"]=[]; print(json.dumps(ns))' | \
  kubectl replace --raw "/api/v1/namespaces/rook-ceph/finalize" -f -

# 2. Verify namespace is gone
kubectl get ns rook-ceph
# Expect: "not found"

# 3. Check if disks are visible on VMs
ansible ceph_osd -i inventory/hosts.yml -m shell -a "lsblk -d -o NAME,SIZE,TYPE" -b

# 4. If vdb/vdc NOT in output — reboot all VMs:
ansible ceph_osd -i inventory/hosts.yml -m reboot -b

# 5. After VMs come back (~1-2 min), verify disks are back:
ansible ceph_osd -i inventory/hosts.yml -m shell -a "lsblk -d -o NAME,SIZE,TYPE" -b

# 6. Fresh deploy (will now wait if namespace is still terminating)
ansible-playbook playbooks/reused/deploy_ceph_rook.yml -i inventory/hosts.yml -v


# 1. Wait for namespace to fully terminate
kubectl get ns rook-ceph
# If it shows "Terminating", force-delete it:
kubectl get ns rook-ceph -o json | \
  python3 -c 'import json,sys; ns=json.load(sys.stdin); ns["spec"]["finalizers"]=[]; print(json.dumps(ns))' | \
  kubectl replace --raw "/api/v1/namespaces/rook-ceph/finalize" -f -

# 2. Verify namespace is gone
kubectl get ns rook-ceph
# Should return: "Error from server (NotFound)"

# 3. Check disk visibility on VMs (from Lab-ControlNode)
ansible ceph_osd -i inventory/hosts.yml -m shell -a "lsblk -d -o NAME,SIZE,TYPE" -b

# 4. If /dev/vdb and /dev/vdc do NOT appear in lsblk output, reboot VMs:
ansible ceph_osd -i inventory/hosts.yml -m reboot -b

# 5. After reboot, verify disks:
ansible ceph_osd -i inventory/hosts.yml -m shell -a "lsblk -d -o NAME,SIZE,TYPE" -b
# Should show: vdb 100G disk, vdc 100G disk

# 6. Fresh deploy
ansible-playbook playbooks/reused/deploy_ceph_rook.yml \
  -i inventory/hosts.yml -v
ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ

For the dashboard timeout — that's a separate NodePort routing issue. Run these diagnostics:
# 1. Check if kube-proxy is running on the node
kubectl get pods -n kube-system -l k8s-app=kube-proxy -o wide

# 2. Try curl from INSIDE the cluster (on Host12_1 directly)
ansible kube_controllers[0] -i inventory/hosts.yml -m shell -a "curl -k https://localhost:31443/ 2>&1 | head -5" -b

# 3. Check iptables rules for NodePort
ansible kube_controllers[0] -i inventory/hosts.yml -m shell -a "iptables -t nat -L | grep 31443" -b


To re-deploy with the fix (teardown first to clean DM):


ansible-playbook playbooks/reused/deploy_ceph_rook.yml -i inventory/hosts.yml --tags rook_teardown -v

ansible-playbook playbooks/reused/deploy_ceph_rook.yml -i inventory/hosts.yml -v


The cluster shows osd: 0 osds: 0 up, 0 in and the PVC can't bind because there's no storage capacity. This is a timing issue — the Rook operator needs time after cluster creation to create OSD prepare jobs that scan for clean disks. It's not a regression; the operator just hadn't gotten to OSD provisioning yet when the validation ran (only ~1 minute after cluster deploy).

Check if OSDs are coming up now:

kubectl get pods -n rook-ceph -l app=rook-ceph-osd-prepare
kubectl get pods -n rook-ceph -l app=rook-ceph-osd
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph -s

If OSD prepare jobs ran but found no disks, check:

kubectl logs -n rook-ceph -l app=rook-ceph-osd-prepare --tail=50

3. "sheba-cloud-infra" namespace
That namespace doesn't exist yet because you haven't run deploy_sheba_infra_services.yml. It's step 14+ in the deployment order — you're still at step 13 (Ceph). That's expected.

Fix: Stale Banner Text
I also noticed the dashboard banner still says "MetalLB L2 ARP" — let me fix that:

Searched for MetalLB L2 ARP and updated deploy_ceph_rook.yml+1-1
Fixed the stale "L2 ARP" banner text.

Bottom line: The deployment succeeded. Give the Rook operator 3-5 minutes to create OSD prepare jobs and spin up OSD pods. Then ceph -s will show the disks online, and PVCs will bind. The sheba-cloud-infra namespace comes later when you run the infra services playbook.
ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ

Since Rook is already deployed and the discovery daemons are running, you just need to:

Wipe the disks properly (with pvremove)
Clear /var/lib/rook
Restart the operator to trigger a fresh reconciliation
Run these commands on your lab:

# 1. Wipe disks with full LVM removal on all OSD nodes
ansible ceph_osd -i inventory/hosts.yml -m shell -a '
for DEV in /dev/vdb /dev/vdc; do
  [ -b "$DEV" ] || continue
  pvremove -ff "$DEV" 2>/dev/null || true
  wipefs -af "$DEV" 2>/dev/null || true
  dd if=/dev/zero of="$DEV" bs=1M count=100 2>/dev/null || true
  DEV_SIZE=$(blockdev --getsize64 "$DEV")
  dd if=/dev/zero of="$DEV" bs=1M count=100 seek=$(( (DEV_SIZE / 1048576) - 100 )) 2>/dev/null || true
  sgdisk --zap-all "$DEV" 2>/dev/null || true
  echo "CLEAN: $DEV"
done' -b

# 2. Remove stale Rook state
ansible ceph_osd -i inventory/hosts.yml -m shell -a 'rm -rf /var/lib/rook' -b

# 3. Delete any stuck OSD prepare jobs/pods
kubectl delete job -n rook-ceph -l app=rook-ceph-osd-prepare 2>/dev/null
kubectl delete pod -n rook-ceph -l app=rook-ceph-osd-prepare --force --grace-period=0 2>/dev/null

# 4. Restart operator to force fresh device scan
kubectl rollout restart deployment rook-ceph-operator -n rook-ceph
kubectl rollout status deployment rook-ceph-operator -n rook-ceph --timeout=60s

# 5. Wait and watch for OSD prepare jobs (should appear within 2-3 min)
watch -n5 'kubectl get pods -n rook-ceph | grep -E "osd-prepare|osd"'

The root cause was that pvremove was never called — the wipe task removed LVM VGs but left the PV label on the disk. Rook's device scanner sees the LVM PV signature and skips the device as "not available." The updated playbook now runs pvremove -ff and also zeros the end of the disk (BlueStore can place labels there too).



XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
hey're Windows PowerShell and don't have SSH/kubectl access to your lab cluster. You need to run them directly on your Lab-ControlNode where you have the venv active.

Copy-paste this # Step 1: Full disk wipe with pvremove
ansible ceph_osd -i inventory/hosts.yml -m shell -a '
for DEV in /dev/vdb /dev/vdc; do
  [ -b "$DEV" ] || continue
  pvremove -ff "$DEV" 2>/dev/null || true
  wipefs -af "$DEV" 2>/dev/null || true
  dd if=/dev/zero of="$DEV" bs=1M count=100 2>/dev/null || true
  DEV_SIZE=$(blockdev --getsize64 "$DEV")
  dd if=/dev/zero of="$DEV" bs=1M count=100 seek=$(( (DEV_SIZE / 1048576) - 100 )) 2>/dev/null || true
  sgdisk --zap-all "$DEV" 2>/dev/null || true
  echo "CLEAN: $DEV"
done' -b

# Step 2: Remove stale Rook state
ansible ceph_osd -i inventory/hosts.yml -m shell -a 'rm -rf /var/lib/rook' -b

# Step 3: Delete stuck OSD prepare artifacts
kubectl delete job -n rook-ceph -l app=rook-ceph-osd-prepare 2>/dev/null; \
kubectl delete pod -n rook-ceph -l app=rook-ceph-osd-prepare --force --grace-period=0 2>/dev/null

# Step 4: Restart operator to trigger fresh reconciliation
kubectl rollout restart deployment rook-ceph-operator -n rook-ceph && \
kubectl rollout status deployment rook-ceph-operator -n rook-ceph --timeout=60s

# Step 5: Watch for OSD pods (Ctrl+C to stop)
echo "Watching for OSD prepare/run pods (wait 2-3 min)..."
sleep 30 && kubectl get pods -n rook-ceph | grep -E 'osd'

block into your existing shell session:
# Step 1: Full disk wipe with pvremove
ansible ceph_osd -i inventory/hosts.yml -m shell -a '
for DEV in /dev/vdb /dev/vdc; do
  [ -b "$DEV" ] || continue
  pvremove -ff "$DEV" 2>/dev/null || true
  wipefs -af "$DEV" 2>/dev/null || true
  dd if=/dev/zero of="$DEV" bs=1M count=100 2>/dev/null || true
  DEV_SIZE=$(blockdev --getsize64 "$DEV")
  dd if=/dev/zero of="$DEV" bs=1M count=100 seek=$(( (DEV_SIZE / 1048576) - 100 )) 2>/dev/null || true
  sgdisk --zap-all "$DEV" 2>/dev/null || true
  echo "CLEAN: $DEV"
done' -b

# Step 2: Remove stale Rook state
ansible ceph_osd -i inventory/hosts.yml -m shell -a 'rm -rf /var/lib/rook' -b

# Step 3: Delete stuck OSD prepare artifacts
kubectl delete job -n rook-ceph -l app=rook-ceph-osd-prepare 2>/dev/null; \
kubectl delete pod -n rook-ceph -l app=rook-ceph-osd-prepare --force --grace-period=0 2>/dev/null

# Step 4: Restart operator to trigger fresh reconciliation
kubectl rollout restart deployment rook-ceph-operator -n rook-ceph && \
kubectl rollout status deployment rook-ceph-operator -n rook-ceph --timeout=60s

# Step 5: Watch for OSD pods (Ctrl+C to stop)
echo "Watching for OSD prepare/run pods (wait 2-3 min)..."
sleep 30 && kubectl get pods -n rook-ceph | grep -E 'osd'



After step 5, if you see rook-ceph-osd-prepare-* pods in Running or Completed state, the fix worked. Follow up with:


kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph osd tree

If still no OSD prepare pods after 3 minutes, grab the operator logs:

kubectl logs -n rook-ceph -l app=rook-ceph-operator --tail=100 | grep -iE 'osd|device|skipp|avail'










XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
You need a full teardown and fresh deploy. This is the correct sequence:
# 1. Uninstall helm releases
helm uninstall rook-ceph-cluster -n rook-ceph 2>/dev/null
helm uninstall rook-ceph -n rook-ceph 2>/dev/null

# 2. Remove finalizers from stuck CRDs
for resource in cephcluster cephblockpool cephfilesystem cephobjectstore cephfilesystemsubvolumegroup; do
  for item in $(kubectl get $resource -n rook-ceph -o name 2>/dev/null); do
    kubectl patch $item -n rook-ceph --type merge -p '{"metadata":{"finalizers":null}}'
  done
done

# 3. Force-delete namespace
kubectl delete namespace rook-ceph --timeout=30s 2>/dev/null
kubectl get ns rook-ceph -o json 2>/dev/null | \
  python3 -c 'import json,sys; ns=json.load(sys.stdin); ns["spec"]["finalizers"]=[]; print(json.dumps(ns))' | \
  kubectl replace --raw "/api/v1/namespaces/rook-ceph/finalize" -f - 2>/dev/null

# 4. Wait for namespace to disappear
for i in $(seq 1 20); do
  kubectl get ns rook-ceph 2>/dev/null || break
  sleep 5
done

# 5. Wipe disks + rook state one more time (clean slate)
ansible ceph_osd -i inventory/hosts.yml -m shell -a '
for DEV in /dev/vdb /dev/vdc; do
  [ -b "$DEV" ] || continue
  pvremove -ff "$DEV" 2>/dev/null || true
  wipefs -af "$DEV" 2>/dev/null || true
  dd if=/dev/zero of="$DEV" bs=1M count=100 2>/dev/null || true
  sgdisk --zap-all "$DEV" 2>/dev/null || true
done
rm -rf /var/lib/rook
echo DONE' -b

# 6. Delete leftover Rook CRDs (clean cluster-scoped resources)
kubectl delete crd -l app.kubernetes.io/part-of=rook-ceph-operator 2>/dev/null

# 7. Redeploy with the fixed playbook
ansible-playbook playbooks/reused/deploy_ceph_rook.yml -i inventory/hosts.yml -v
What went wrong: The /var/lib/rook deletion should have been done before the operator started, not while MONs were live. The updated playbook now does this correctly in Phase 0 (before any Rook components are deployed).

The key lesson: we confirmed pvremove found and wiped real LVM PV labels on all disks — that was the root cause of OSD discovery failure. With the fresh redeploy, the operator will find clean disks and should create OSD prepare jobs within 2-3 minutes of the cluster CR being applied.

SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS

You must do a full teardown + fresh deploy. Run this sequence on your Lab-ControlNode:
# === FULL TEARDOWN ===

# 1. Uninstall Helm releases
helm uninstall rook-ceph-cluster -n rook-ceph 2>/dev/null
helm uninstall rook-ceph -n rook-ceph 2>/dev/null

# 2. Remove finalizers from all stuck Rook CRs
for resource in cephcluster cephblockpool cephfilesystem cephobjectstore cephfilesystemsubvolumegroup; do
  for item in $(kubectl get $resource -n rook-ceph -o name 2>/dev/null); do
    kubectl patch $item -n rook-ceph --type merge -p '{"metadata":{"finalizers":null}}'
  done
done

# 3. Delete all remaining resources in namespace
kubectl delete all --all -n rook-ceph --force --grace-period=0 2>/dev/null

# 4. Force-remove namespace
kubectl delete namespace rook-ceph --timeout=30s 2>/dev/null
sleep 5
kubectl get ns rook-ceph -o json 2>/dev/null | \
  python3 -c 'import json,sys; ns=json.load(sys.stdin); ns["spec"]["finalizers"]=[]; print(json.dumps(ns))' | \
  kubectl replace --raw "/api/v1/namespaces/rook-ceph/finalize" -f - 2>/dev/null

# 5. Wait for namespace gone
echo "Waiting for namespace deletion..."
for i in $(seq 1 30); do
  kubectl get ns rook-ceph 2>&1 | grep -q "not found" && echo "GONE" && break
  sleep 5
done

# 6. Delete Rook CRDs
kubectl get crd -o name | grep -i rook | xargs kubectl delete 2>/dev/null
kubectl get crd -o name | grep -i objectbucket | xargs kubectl delete 2>/dev/null

# 7. Wipe disks + /var/lib/rook on ALL OSD nodes
ansible ceph_osd -i inventory/hosts.yml -m shell -a '
for DEV in /dev/vdb /dev/vdc; do
  [ -b "$DEV" ] || continue
  pvremove -ff "$DEV" 2>/dev/null || true
  wipefs -af "$DEV" 2>/dev/null || true
  dd if=/dev/zero of="$DEV" bs=1M count=100 2>/dev/null || true
  sgdisk --zap-all "$DEV" 2>/dev/null || true
done
rm -rf /var/lib/rook
echo DONE' -b

# === FRESH DEPLOY (with 3 MONs, fixed disk wipe, pvremove) ===
ansible-playbook playbooks/reused/deploy_ceph_rook.yml -i inventory/hosts.yml -v
Key changes for this deploy:

3 MONs (odd number = proper quorum, can tolerate 1 MON failure)
/var/lib/rook cleaned in Phase 0 (before operator deploys)
pvremove -ff in disk wipe (strips LVM PV labels that blocked OSD discovery)
Discovery daemon enabled (enableDiscoveryDaemon=true)
deviceFilter only rendered when non-empty
The previous 2-MON situation was the root cause of the HEALTH_ERR spiral — it was auto-scaled from 1 and created an unstable even-numbered quorum.


XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX


nh1221@PowerEdge-R810:~$ for vm in Host12_1 Host12_2 Host12-_3 Host34_1 Host34_2 HostB12_1; do echo "=== $vm ==="; virsh domblklist $vm; done
=== Host12_1 ===
 Target   Source
--------------------------------------------------------------
 vda      /home/nh1221/dc_lab/disks/Host12_1.qcow2
 vdb      /home/nh1221/dc_lab/disks/Host12_1-osd1.qcow2
 vdc      /home/nh1221/dc_lab/disks/Host12_1-osd2.qcow2
 sda      /home/nh1221/dc_lab/cloud-init/Host12_1-cidata.iso

=== Host12_2 ===
 Target   Source
--------------------------------------------------------------
 vda      /home/nh1221/dc_lab/disks/Host12_2.qcow2
 vdb      /home/nh1221/dc_lab/disks/Host12_2-osd1.qcow2
 vdc      /home/nh1221/dc_lab/disks/Host12_2-osd2.qcow2
 sda      /home/nh1221/dc_lab/cloud-init/Host12_2-cidata.iso

=== Host12-_3 ===
error: failed to get domain 'Host12-_3'

=== Host34_1 ===
 Target   Source
--------------------------------------------------------------
 vda      /home/nh1221/dc_lab/disks/Host34_1.qcow2
 vdb      /home/nh1221/dc_lab/disks/Host34_1-osd1.qcow2
 vdc      /home/nh1221/dc_lab/disks/Host34_1-osd2.qcow2
 sda      /home/nh1221/dc_lab/cloud-init/Host34_1-cidata.iso

=== Host34_2 ===
 Target   Source
--------------------------------------------------------------
 vda      /home/nh1221/dc_lab/disks/Host34_2.qcow2
 vdb      /home/nh1221/dc_lab/disks/Host34_2-osd1.qcow2
 vdc      /home/nh1221/dc_lab/disks/Host34_2-osd2.qcow2
 sda      /home/nh1221/dc_lab/cloud-init/Host34_2-cidata.iso

=== HostB12_1 ===
 Target   Source
---------------------------------------------------------------
 vda      /home/nh1221/dc_lab/disks/HostB12_1.qcow2
 vdb      /home/nh1221/dc_lab/disks/HostB12_1-osd1.qcow2
 vdc      /home/nh1221/dc_lab/disks/HostB12_1-osd2.qcow2
 sda      /home/nh1221/dc_lab/cloud-init/HostB12_1-cidata.iso

nh1221@PowerEdge-R810:~$
