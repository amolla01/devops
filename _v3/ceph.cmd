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


# Re-run everything (safe — each step is idempotent)ansible-playbook playbooks/reused/deploy_ceph_rook.yml -i inventory/hosts.yml -v# Skip what's working, run only failed phaseansible-playbook playbooks/reused/deploy_ceph_rook.yml \  -i inventory/hosts.yml --tags rook_cluster -v# Skip already-prepared nodes, just do cluster+dashboardansible-playbook playbooks/reused/deploy_ceph_rook.yml \  -i inventory/hosts.yml --tags rook_cluster,rook_dashboard,rook_validate -v


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

One exception: Phase 0 disk wipe (ceph_osd_wipe_disks: true) will re-wipe disks that are not mounted. If OSDs failed mid-creation (disk wiped but OSD pod didn't start), re-running is safe — Rook will re-claim the empty disk. If you want to skip disk prep entirely on re-run:

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
Why it's separate: The core cluster (deploy_ceph_rook.yml) already creates the kube-rbd pool/StorageClass for general workloads. The infra pool is an additional tenant-isolated pool specifically for infrastructure services in the sheba-cloud-infra namespace — it has its own replication settings (size=2, min_size=1) tuned for the lab.

Dependency: deploy_ceph_infra_pool.yml requires the Rook toolbox pod to be running (created by Phase 2 of deploy_ceph_rook.yml), so it will fail if run before the cluster is healthy.

