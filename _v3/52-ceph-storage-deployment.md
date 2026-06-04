# Ceph Storage Deployment — Complete Reference

## Overview

The lab deploys **Ceph Reef v18.2.2** as the unified block/filesystem storage backend for both Kubernetes and OpenStack workloads. Two deployment modes are supported:

| Mode | Mechanism | When to Use |
|------|-----------|-------------|
| **Rook** (default) | K8s-native operator, Ceph runs as pods in `rook-ceph` namespace | Post-Kubespray; preferred for KVM lab |
| **Cephadm** | Bare-metal podman containers orchestrated by cephadm CLI | Real hardware; no K8s available yet |

The active mode is controlled by `ceph_deploy_mode` in `roles/ceph/defaults/main.yml`.

---

## Architecture

```
┌───────────────────────────────────────────────────────────┐
│                   Kubernetes Cluster                        │
│  ┌──────────────────────────────────────────────────────┐ │
│  │              rook-ceph namespace                       │ │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────────────────┐  │ │
│  │  │ MON Pod │  │ MGR Pod │  │  OSD Pods (per disk) │  │ │
│  │  │ x1      │  │ x1      │  │  x12 (6 nodes × 2)  │  │ │
│  │  └─────────┘  └─────────┘  └─────────────────────┘  │ │
│  │  ┌─────────┐  ┌────────────────┐  ┌───────────────┐  │ │
│  │  │ MDS Pod │  │ Rook Operator  │  │ Dashboard     │  │ │
│  │  │ x1+stby │  │ (control loop) │  │ (NodePort:    │  │ │
│  │  └─────────┘  └────────────────┘  │  31443/HTTPS) │  │ │
│  │                                    └───────────────┘  │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                           │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  StorageClasses                                       │ │
│  │    ceph-rbd (default) — block volumes                │ │
│  │    ceph-filesystem    — shared filesystem            │ │
│  └──────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────┘
```

### Cluster Topology

| Node | Role | IPs | OSD Devices |
|------|------|-----|-------------|
| Host12_1 | K8s Controller + MON + OSD | 172.16.2.40 | /dev/vdb, /dev/vdc |
| Host12_2 | K8s Worker + OSD | 172.16.2.41 | /dev/vdb, /dev/vdc |
| Host12_3 | K8s Worker + OSD | 172.16.2.42 | /dev/vdb, /dev/vdc |
| Host34_1 | K8s Controller + MON + OSD | 172.16.2.43 | /dev/vdb, /dev/vdc |
| Host34_2 | K8s Worker + OSD | 172.16.2.44 | /dev/vdb, /dev/vdc |
| HostB12_1 | K8s Controller + OSD | 172.16.2.45 | /dev/vdb, /dev/vdc |

**Network:** Single flat 172.16.2.0/24 (both public + cluster network in KVM lab).

---

## File Inventory

### Playbooks

| File | Purpose |
|------|---------|
| `playbooks/reused/deploy_ceph_rook.yml` | **Primary** — Rook-Ceph K8s deployment (6 phases) |
| `playbooks/reused/deploy_ceph.yml` | Cephadm bare-metal deployment (6 phases) |
| `playbooks/reused/deploy_ceph_infra_pool.yml` | Create `infra-storage` pool + K8s Secret |
| `playbooks/reused/preflight_download.yml` | Pre-cache Rook charts + cephadm binary |

### Role (`roles/ceph/`)

| File | Purpose |
|------|---------|
| `defaults/main.yml` | Default variables (version pins, cache paths, deploy mode) |
| `tasks/main.yml` | Orchestrator — fails if mode=rook, else runs cephadm phases |
| `tasks/preflight.yml` | Install packages + cephadm (3-priority cache lookup) |
| `tasks/bootstrap.yml` | cephadm bootstrap on primary MON |
| `tasks/add_hosts.yml` | Expand cluster to additional hosts |
| `tasks/discover_volumes.yml` | Dynamic OSD device discovery (lsblk + OS root exclusion) |
| `tasks/deploy_osds.yml` | Activate OSD devices (dynamic or static) |
| `tasks/create_pools.yml` | Create pre-defined pools (kube-rbd, openstack-*, cephfs) |
| `tasks/create_keyrings.yml` | Generate client keyrings (client.kube, client.openstack) |
| `tasks/enable_services.yml` | Enable dashboard, MDS, prometheus modules |
| `tasks/validate.yml` | Health check and status report |
| `tasks/day1_osd_operations.yml` | Incremental OSD add/remove/rollback/update |
| `templates/cluster-spec.yaml.j2` | Cephadm declarative cluster specification |
| `templates/rook-ceph-cluster-values.yml.j2` | Rook CephCluster Helm values |

### Inventory Group Variables

| File | Contents |
|------|----------|
| `inventory/group_vars/ceph_mon.yml` | FSID, network config, pool definitions, keyrings, MDS |
| `inventory/group_vars/ceph_osd.yml` | Device selection, BlueStore config, performance tuning |

---

## Deployment Commands

### Prerequisites
```bash
# 1. Kubernetes must be running (Kubespray completed)
kubectl get nodes   # all nodes Ready

# 2. Pre-cache artifacts (run on deployer with internet access)
ansible-playbook playbooks/reused/preflight_download.yml \
  -i inventory/hosts.yml --tags ceph -v
```

### Rook-Ceph Deployment (Recommended)

```bash
# Full deployment (operator + cluster + validation)
ansible-playbook playbooks/reused/deploy_ceph_rook.yml \
  -i inventory/hosts.yml -v

# Phase-by-phase:
ansible-playbook playbooks/reused/deploy_ceph_rook.yml \
  -i inventory/hosts.yml --tags rook_prepare -v

ansible-playbook playbooks/reused/deploy_ceph_rook.yml \
  -i inventory/hosts.yml --tags rook_operator -v

ansible-playbook playbooks/reused/deploy_ceph_rook.yml \
  -i inventory/hosts.yml --tags rook_cluster -v

ansible-playbook playbooks/reused/deploy_ceph_rook.yml \
  -i inventory/hosts.yml --tags rook_dashboard -v

ansible-playbook playbooks/reused/deploy_ceph_rook.yml \
  -i inventory/hosts.yml --tags rook_validate -v
```

### Cephadm Deployment (Alternative)

```bash
# Requires ceph_deploy_mode: "cephadm" in defaults
ansible-playbook playbooks/reused/deploy_ceph.yml \
  -i inventory/hosts.yml -v

# Individual phases:
ansible-playbook playbooks/reused/deploy_ceph.yml \
  -i inventory/hosts.yml --tags ceph_preflight -v

ansible-playbook playbooks/reused/deploy_ceph.yml \
  -i inventory/hosts.yml --tags ceph_bootstrap -v

ansible-playbook playbooks/reused/deploy_ceph.yml \
  -i inventory/hosts.yml --tags ceph_osd -v

ansible-playbook playbooks/reused/deploy_ceph.yml \
  -i inventory/hosts.yml --tags ceph_pools,ceph_keyrings -v
```

### Post-Deployment: Infra Pool

```bash
# Creates infra-storage pool + K8s secret in sheba-cloud-infra namespace
ansible-playbook playbooks/reused/deploy_ceph_infra_pool.yml \
  -i inventory/hosts.yml -v
```

---

## Tag Reference

### Rook Playbook Tags (`deploy_ceph_rook.yml`)

| Tag | Scope | Description |
|-----|-------|-------------|
| `rook` | All phases | Run all Rook phases (prepare + operator + cluster + dashboard) |
| `rook_prepare` | Phase 0 | Wipe OSD disks, load kernel modules |
| `rook_operator` | Phase 1 | Deploy Rook operator Helm chart |
| `rook_cluster` | Phase 2 | Deploy CephCluster CR (MON/OSD/MGR pods) |
| `rook_dashboard` | Phase 3 | Expose dashboard via NodePort (31443), print admin credentials |
| `rook_validate` | Phase 4 | Health check, PVC binding test |
| `rook_teardown` | Phase 5+5b | **DESTRUCTIVE** — Full scorched-earth: Helm → finalizers → CRs → CRDs → namespace → disk wipe → /var/lib/rook (requires explicit tag; `never` prevents accidental execution) |

### Cephadm Role Tags (`roles/ceph/tasks/`)

| Tag | Scope | Description |
|-----|-------|-------------|
| `ceph_preflight` | All ceph nodes | Install cephadm, packages, kernel modules |
| `ceph_bootstrap` | Primary MON | Bootstrap cluster with cephadm |
| `ceph_hosts` | Primary MON | Expand cluster to additional hosts |
| `ceph_discover` | OSD hosts | Dynamic volume discovery |
| `ceph_osd` | Primary MON | Deploy OSDs on discovered devices |
| `ceph_pools` | Primary MON | Create pre-defined pools |
| `ceph_keyrings` | Primary MON | Generate client auth keyrings |
| `ceph_services` | Primary MON | Enable dashboard, MDS, prometheus |
| `ceph_validate` | Primary MON | Cluster health report |

---

## Key Variables

### Deployment Mode & Versions (`roles/ceph/defaults/main.yml`)

| Variable | Default | Description |
|----------|---------|-------------|
| `ceph_deploy_mode` | `rook` | `rook` or `cephadm` |
| `ceph_release` | `reef` | Ceph release name |
| `ceph_version` | `18.2.2` | Exact version for binary lookup |
| `ceph_container_image` | `quay.io/ceph/ceph:v18` | Container image for Rook pods |
| `rook_ceph_version` | `v1.14.7` | Rook operator Helm chart version |
| `rook_ceph_namespace` | `rook-ceph` | K8s namespace for all Ceph pods |

### Preflight Cache (`roles/ceph/defaults/main.yml`)

| Variable | Default | Description |
|----------|---------|-------------|
| `ceph_preflight_cache_dir` | `/opt/fabric-cache` | Root cache directory |
| `ceph_preflight_binaries_dir` | `…/binaries` | cephadm binary location |
| `ceph_preflight_images_dir` | `…/images` | Container images (tar) |
| `ceph_preflight_helm_dir` | `…/helm-charts` | Helm chart tarballs |
| `ceph_preflight_apt_dir` | `…/apt-packages` | Apt package cache |

### Cluster Identity (`inventory/group_vars/ceph_mon.yml`)

| Variable | Value | Description |
|----------|-------|-------------|
| `ceph_fsid` | `a1b2c3d4-e5f6-…` | Unique cluster UUID (never change) |
| `ceph_cluster_name` | `dc-lab-ceph` | Cluster name |
| `ceph_public_network` | `172.16.2.0/24` | Client-facing network |
| `ceph_cluster_network` | `172.16.2.0/24` | OSD replication network |
| `ceph_osd_pool_default_size` | `2` | Replica count (2 for lab) |
| `ceph_dashboard_port` | `8443` | Web UI port |

### OSD Configuration (`inventory/group_vars/ceph_osd.yml`)

| Variable | Value | Description |
|----------|-------|-------------|
| `ceph_osd_dynamic_discovery` | `true` | Auto-detect disks via lsblk |
| `ceph_osd_devices_default_kvm` | `[/dev/vdb, /dev/vdc]` | Default OSD devices for KVM |
| `ceph_osd_wipe_disks` | `true` | Wipe disk signatures before OSD create |
| `ceph_bluestore_block_db_size` | `…` | BlueStore DB partition size |

---

## Pools Created

| Pool Name | Application | Size | PGs | Consumer |
|-----------|-------------|------|-----|----------|
| `kube-rbd` | rbd | 2 | 32 | K8s CSI (default StorageClass) |
| `openstack-volumes` | rbd | 2 | 32 | Cinder block volumes |
| `openstack-images` | rbd | 2 | 16 | Glance images |
| `openstack-vms` | rbd | 2 | 32 | Nova ephemeral disks |
| `cephfs-data` | cephfs | 2 | 32 | CephFS data (shared FS) |
| `cephfs-metadata` | cephfs | 2 | 16 | CephFS metadata |
| `infra-storage` | rbd | 2 | 32 | SDLC/infra services |

---

## Preflight Cache Integration

The `preflight_download.yml` playbook (with `--tags ceph`) caches:

| Artifact | Location | Used By |
|----------|----------|---------|
| `cephadm` binary | `/opt/fabric-cache/binaries/cephadm-18.2.2` | preflight.yml (cephadm mode) |
| `rook-ceph-*.tgz` | `/opt/fabric-cache/helm-charts/` | deploy_ceph_rook.yml (operator) |
| `rook-ceph-cluster-*.tgz` | `/opt/fabric-cache/helm-charts/` | deploy_ceph_rook.yml (cluster CR) |

### Cache Lookup Priority (preflight.yml)

1. **Versioned binary** — `/opt/fabric-cache/binaries/cephadm-18.2.2`
2. **Unversioned binary** — `/opt/fabric-cache/binaries/cephadm`
3. **Internet download** — `https://download.ceph.com/rpm-reef/el9/noarch/cephadm`

### Helm Chart Cache (deploy_ceph_rook.yml)

1. **Cached tarball** — `helm upgrade --install rook-ceph /opt/fabric-cache/helm-charts/rook-ceph-*.tgz`
2. **Remote repo** — `helm upgrade --install rook-ceph rook-release/rook-ceph --version v1.14.7`

---

## Day 1 Operations

After initial deployment, use `day1_osd_operations.yml` for incremental changes:

```bash
# Show OSD status vs available devices
ansible-playbook playbooks/ceph_day1_operations.yml \
  -i inventory/hosts.yml -e "ceph_day1_action=status"

# Add newly discovered volumes as OSDs
ansible-playbook playbooks/ceph_day1_operations.yml \
  -i inventory/hosts.yml -e "ceph_day1_action=add"

# Remove a specific OSD (graceful drain + rebalance)
ansible-playbook playbooks/ceph_day1_operations.yml \
  -i inventory/hosts.yml \
  -e "ceph_day1_action=remove ceph_day1_target_host=Host12_2 ceph_day1_target_device=/dev/vdd"

# Rollback (re-add) a removed device
ansible-playbook playbooks/ceph_day1_operations.yml \
  -i inventory/hosts.yml \
  -e "ceph_day1_action=rollback ceph_day1_target_host=Host12_2 ceph_day1_target_device=/dev/vdd"

# Change OSD device class
ansible-playbook playbooks/ceph_day1_operations.yml \
  -i inventory/hosts.yml \
  -e "ceph_day1_action=update ceph_day1_osd_id=5 ceph_day1_device_class=ssd"
```

---

## Validation & Troubleshooting

### Quick Health Check (Rook)

```bash
# From any K8s controller:
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph -s
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph osd tree
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph df
```

### Pod Status

```bash
kubectl get pods -n rook-ceph -o wide
kubectl get cephcluster -n rook-ceph
kubectl get sc   # StorageClasses
```

### Test PVC Binding

```bash
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
```

### Common Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| OSD pods CrashLoopBackOff | Dirty disks (leftover LVM/partition) | `wipefs -af /dev/vdb && dd if=/dev/zero of=/dev/vdb bs=1M count=100` on host |
| MON not starting | Clock skew between nodes | Verify `chrony` running: `chronyc tracking` |
| PVC stuck Pending | No default StorageClass | `kubectl get sc` — check `ceph-rbd` is default |
| Operator pod not ready | CRDs not installed | `helm upgrade --install rook-ceph … --set crds.enabled=true` |
| `HEALTH_WARN too few PGs` | Pool pg_num too low | `ceph osd pool set <pool> pg_num 64` via toolbox |
| Cephadm role fails with "use deploy_ceph_rook.yml" | `ceph_deploy_mode: rook` | Expected — use Rook playbook instead |
| 0 OSDs — cluster HEALTH_WARN | Virtual disks not attached to VMs | On R810 host: create qcow2 + `virsh attach-disk` for /dev/vdb, /dev/vdc per VM |
| `rbd pool init` hangs forever | 0 OSDs up (no disks) | Playbook now skips init if 0 OSDs; attach disks first, then re-run |

### Dashboard Access

After Phase 3 (`rook_dashboard`), the Ceph Dashboard is exposed as a NodePort service on port **31443**.

```bash
# Get dashboard URL (from any machine that can reach cluster nodes)
https://<any-k8s-node-ip>:31443

# Username: admin
# Password: retrieve from Kubernetes secret:
kubectl -n rook-ceph get secret rook-ceph-dashboard-password \
  -o jsonpath='{.data.password}' | base64 -d ; echo

# From Lab-ControlNode (R810 host), use any VM node IP:
https://172.16.2.40:31443   # Host12_1
https://172.16.2.43:31443   # Host34_1

# Verify service is exposed:
kubectl get svc rook-ceph-mgr-dashboard -n rook-ceph
```

> **Note:** The dashboard uses a self-signed TLS certificate. Accept the browser warning to proceed.

**Override NodePort:** Set `ceph_dashboard_external_port` variable to change from default 31443:
```bash
ansible-playbook playbooks/reused/deploy_ceph_rook.yml \
  -i inventory/hosts.yml --tags rook_dashboard \
  -e "ceph_dashboard_external_port=32443" -v
```

### Teardown (DESTRUCTIVE — Full Reset)

The `rook_teardown` tag performs a **complete scorched-earth removal** in two sub-phases:

| Step | Action | Why |
|------|--------|-----|
| 1 | Helm uninstall rook-ceph-cluster | Remove CephCluster CR and all managed pods |
| 2 | Remove finalizers from all Ceph CRs | Prevents namespace from hanging indefinitely (Rook finalizers block delete until operator processes them) |
| 3 | Delete all Ceph CRs | Clean up remaining custom resources |
| 4 | Wait for OSD pods to terminate | Graceful shutdown before disk operations |
| 5 | Helm uninstall rook-ceph (operator) | Remove the operator itself |
| 6 | Delete all Rook CRDs | Remove API extensions from K8s API server |
| 7 | Delete rook-ceph namespace | Final K8s cleanup |
| 8 | Wipe /dev/vdb + /dev/vdc on all ceph_osd nodes | Remove BlueStore signatures (wipefs + dd zero + sgdisk --zap-all) |
| 9 | Remove /var/lib/rook on all OSD nodes | Stale metadata prevents re-bootstrap |

```bash
# Single command — does EVERYTHING (Helm + CRDs + namespace + disk wipe)
ansible-playbook playbooks/reused/deploy_ceph_rook.yml \
  -i inventory/hosts.yml --tags rook_teardown -v

# After teardown, ready for fresh deploy:
ansible-playbook playbooks/reused/deploy_ceph_rook.yml \
  -i inventory/hosts.yml -v
```

> 🛑 **IRREVERSIBLE** — All Ceph data, pools, and configuration permanently destroyed. The `never` tag ensures this cannot run accidentally during normal deployment.

---

## Deployment Sequence in Lab Build

```
deploy_lab_v13.sh sequence:
  ├── 1. Infrastructure (fabric, servers, KVM)
  ├── 2. Kubespray (K8s cluster)
  ├── 3. ► Ceph (this playbook) ◄
  │       ├── preflight_download.yml --tags ceph
  │       ├── deploy_ceph_rook.yml (operator + cluster)
  │       └── deploy_ceph_rook.yml --tags rook_dashboard
  ├── 4. Infra Pool
  │       └── deploy_ceph_infra_pool.yml
  ├── 5. OpenStack (uses Ceph RBD for Cinder/Glance/Nova)
  └── 6. Monitoring (Prometheus scrapes Ceph MGR metrics)
```

---

## R810 Physical Storage Layer (ubuntu_r810_kvm Profile)

### Host Disk Layout

The Dell PowerEdge R810 that hosts the KVM lab has the following physical disks:

| Device | Size | Role | Notes |
|--------|------|------|-------|
| `/dev/sda` | 465.3 GB | **OS (EXCLUDED)** | Ubuntu 24.04, boot/root partitions |
| `/dev/sdb` | 837.8 GB | OSD backing | Available for Ceph via KVM virtual disks |
| `/dev/sdc` | 931.0 GB | OSD backing | Available for Ceph via KVM virtual disks |
| `/dev/sdd` | 931.0 GB | OSD backing | Available for Ceph via KVM virtual disks |
| `/dev/sde` | 931.0 GB | OSD backing | Available for Ceph via KVM virtual disks |
| `/dev/sdf` | 1.1 TB | OSD backing | Available for Ceph via KVM virtual disks |
| **Total Available** | **~4.6 TB** | | 5 physical disks for Ceph pool |

### Storage Path: Physical → Virtual → Ceph

```
R810 Physical Disk (e.g. /dev/sdb, 838GB)
  └── qcow2 image (e.g. host12-1-osd-01.qcow2, 100GB)
        └── KVM VM sees as /dev/vdb
              └── Rook-Ceph OSD Pod claims device
                    └── BlueStore writes data directly
                          └── Ceph Pool (kube-rbd, openstack-volumes, etc.)
                                └── PVC consumed by PostgreSQL, OpenStack, etc.
```

### How `ceph_rook_use_all_devices` Maximizes Capacity

With `ceph_rook_use_all_devices: true` (default in `roles/ceph/defaults/main.yml`), the Rook operator **automatically discovers and claims** every empty block device on each OSD node — without needing explicit device lists in the inventory.

**What this means in practice:**

1. Provision KVM virtual disks from R810's 5 free physical drives
2. Attach them to any VM in the `ceph_osd` group
3. Rook finds the new device, creates an OSD pod, and expands the pool
4. **No Ansible/inventory change required** — pure capacity scaling

### Capacity Planning

| Allocation Strategy | Usable Ceph Pool (replica=2) | Usable Ceph Pool (replica=3) |
|--------------------|-----------------------------|------------------------------|
| Current (2×vdisk per VM, 6 VMs) | ~600 GB | ~400 GB |
| Maximized (spread all 4.6TB) | ~2.3 TB | ~1.5 TB |
| Balanced (80% of raw to Ceph) | ~1.8 TB | ~1.2 TB |

**Recommended for lab:** Allocate ~80% of each physical disk as KVM qcow2 for OSD backing, leaving 20% for host snapshots and overhead.

### Provisioning More Virtual Disks

To add more OSD capacity, create additional qcow2 images and attach to VMs:

```bash
# On R810 host (example: add 200GB disk to Host12_1)
qemu-img create -f qcow2 /var/lib/libvirt/images/host12-1-osd-03.qcow2 200G
virsh attach-disk Host12_1 /var/lib/libvirt/images/host12-1-osd-03.qcow2 vdd \
  --driver qemu --subdriver qcow2 --persistent

# Rook auto-discovers /dev/vdd and creates a new OSD pod — no playbook re-run needed
```

### Device Discovery Modes (Rook Template Logic)

The `rook-ceph-cluster-values.yml.j2` template supports two modes:

| Variable | Behavior | When to Use |
|----------|----------|-------------|
| `ceph_rook_use_all_devices: true` | Rook scans all nodes, claims every empty block device | Default — maximizes capacity, zero-config scaling |
| `ceph_rook_use_all_devices: false` | Uses per-host `ceph_osd_devices` from inventory | When you need precise control over which disks are OSDs |

Optional filter: `ceph_rook_device_filter: "^vd[b-z]$"` limits discovery to specific device name patterns.

---

## KVM-Specific Optimizations

| Setting | KVM Value | Production Value | Rationale |
|---------|-----------|------------------|-----------|
| Pool replica size | 2 | 3 | Fewer hosts in lab |
| MON count | 1 | 3-5 | Minimum quorum (single MON for lab) |
| OSD memory target | 1 GiB | 4+ GiB | Limited host RAM |
| MGR pod memory | 1 GiB | 2+ GiB | Reduced workload |
| PG autoscale | on | on | Same for both |
| Device discovery | `ceph_rook_use_all_devices: true` | per-host lists | Auto-claim all empty disks |
| Device filter | `""` (all devices) | `"^sd[b-z]$"` | Broader in lab, restrictive in prod |
| Network | single (172.16.2.0/24) | dual (public+cluster) | Single flat network |
| Control-plane toleration | yes | per-policy | Controllers are also OSDs |
| R810 backing disks | sdb–sdf (4.6TB total) | N/A | Physical storage pool for VMs |

---

## Environment & Hardware-Profile Var Files

Ceph tuning is **environment and hardware-aware** via dedicated var files in `cd/vars/`. Each file configures MON count, PG counts, replication levels, and memory targets appropriate for its specific deployment context.

### Var File Selector Matrix

Choose your var file based on **deployment environment** (dev/test/prod/dr) and **hardware profile** (R810 KVM / R620 KVM / real hardware):

| Environment | R810 KVM (12 OSDs) | R620 KVM (6 OSDs) | Real Hardware (36+ OSDs) |
|---|---|---|---|
| **Development** | `ceph-values-r810-kvm.yml` | `ceph-values-r620-kvm.yml` | `ceph-values-real-hardware.yml` |
| **Testing** | `ceph-values-test.yml` | `ceph-values-test.yml` | `ceph-values-test.yml` |
| **Production** | N/A (R810 not for prod) | N/A (R620 not for prod) | `ceph-values-prod.yml` |
| **Disaster Recovery** | N/A | N/A | `ceph-values-dr.yml` |

### Environment-Based Var Files

#### `ceph-values-dev.yml` — Development/Lab (Minimal Resources)

**Use for:** Quick testing, debugging, resource-constrained environments

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| `rook_ceph_mon_count` | 1 | Single MON sufficient for lab (minimum quorum, LOW etcd load) |
| `rook_ceph_pool_pg_num` | 32 | Extremely conservative (prevents etcd timeout with small clusters) |
| `rook_ceph_pool_pgp_num` | 32 | Matches PG count for balanced distribution |
| `ceph_osd_pool_default_size` | 2 | 2-way replication (acceptable for dev, one OSD loss OK) |
| `ceph_mds_enabled` | false | Disable CephFS (RBD-only labs) |
| `ceph_osd_max_backfills` | 1 | Minimal concurrent recovery |
| `ceph_osd_recovery_max_active` | 1 | One recovery op at a time |

**Deployment:**
```bash
ansible-playbook playbooks/reused/deploy_ceph_rook.yml \
  -i inventory/hosts.yml \
  -e "@cd/vars/ceph-values-dev.yml" -v
```

#### `ceph-values-test.yml` — Testing/QA (Production-Like)

**Use for:** Staging tests, performance validation, pre-production verification

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| `rook_ceph_mon_count` | 3 | 3-MON quorum (1-fault tolerance, representative) |
| `rook_ceph_pool_pg_num` | 64 | Moderate PG count (better data distribution than dev) |
| `rook_ceph_pool_pgp_num` | 64 | Matches PG count |
| `ceph_osd_pool_default_size` | 3 | 3-way replication (production-like) |
| `ceph_mds_enabled` | true | Enable MDS if testing CephFS |
| `ceph_osd_max_backfills` | 1 | Conservative recovery |
| `ceph_osd_recovery_max_active` | 1 | One recovery op at a time |

**Deployment:**
```bash
ansible-playbook playbooks/reused/deploy_ceph_rook.yml \
  -i inventory/hosts.yml \
  -e "@cd/vars/ceph-values-test.yml" -v
```

#### `ceph-values-prod.yml` — Production (Enterprise, 24+ OSDs)

**Use for:** Real production deployments with enterprise redundancy

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| `rook_ceph_mon_count` | 5 | 5-MON quorum (2-fault tolerance, high availability) |
| `rook_ceph_pool_pg_num` | 256 | High capacity baseline (better for 24+ OSDs) |
| `rook_ceph_pool_pgp_num` | 256 | Matches PG count |
| `ceph_osd_pool_default_size` | 3 | 3-way replication (standard production) |
| `ceph_mds_enabled` | true | Enable MDS for OpenStack Manila / K8s CephFS |
| `ceph_osd_max_backfills` | 2 | 2 concurrent backfills per OSD |
| `ceph_osd_recovery_max_active` | 3 | 3 concurrent recovery ops per OSD |
| `ceph_osd_memory_target` | 4GB | 4GB per OSD (scaled for enterprise) |

**Pre-deployment validation:**
- Verify cluster has 24+ OSDs
- Verify etcd has 8GB+ free memory
- Verify 3+ dedicated storage nodes

**Deployment:**
```bash
export AUTOMATION_PROFILE=real_hardware
ansible-playbook playbooks/reused/deploy_ceph_rook.yml \
  -i inventory/hosts.yml \
  -e "@cd/vars/ceph-values-prod.yml" -v
```

#### `ceph-values-dr.yml` — Disaster Recovery (Standby/Failover)

**Use for:** DR site deployments, passive or active failover sites

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| `rook_ceph_mon_count` | 3 | 3 MONs (compromise: HA + resource savings vs 5) |
| `rook_ceph_pool_pg_num` | 128 | Moderate PG count (standby site = lower active load) |
| `rook_ceph_pool_pgp_num` | 128 | Matches PG count |
| `ceph_osd_pool_default_size` | 3 | 3-way replication (must match production) |
| `ceph_mds_enabled` | true | Match production for failover compatibility |
| `ceph_osd_max_backfills` | 1 | Conservative (WAN link preservation) |
| `ceph_osd_recovery_max_active` | 2 | Limited concurrency (geo-sync friendly) |
| `ceph_osd_recovery_sleep` | 0.5s | Throttle recovery (preserve WAN bandwidth) |

**Key notes:**
- If DR is PASSIVE (warm standby): reduce PGs to 128, keep MON count at 3
- If DR is ACTIVE (serving clients): use identical settings to production
- Recovery must be conservative to preserve site-to-site replication bandwidth

**Deployment:**
```bash
export AUTOMATION_PROFILE=real_hardware
ansible-playbook playbooks/reused/deploy_ceph_rook.yml \
  -i inventory/hosts.yml \
  -e "@cd/vars/ceph-values-dr.yml" -v
```

### Hardware-Profile Var Files

#### `ceph-values-r810-kvm.yml` — Dell R810 KVM Lab (12 OSDs)

**Platform:** Dell PowerEdge R810 (256GB RAM, 64 CPU) hosting 6 VMs × 2 virtual disks = 12 OSDs

**Disk configuration:**
- Physical R810: sda (OS, excluded) + sdb–sdf (4.6TB available)
- 6 KVM VMs: Host12_1/2/3, Host34_1/2, HostB12_1 (each with /dev/vdb, /dev/vdc)

**OSD calculation:** 12 OSDs ÷ 2-way replication = (12 × 100) / 2 = 600 → round conservative to 128 PGs

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| `rook_ceph_mon_count` | 1 | Single MON (minimal K8s etcd load) |
| `rook_ceph_pool_pg_num` | 128 | Conservative (prevents etcd timeout with 12 OSDs) |
| `rook_ceph_pool_pgp_num` | 128 | Matches PG count |
| `ceph_osd_pool_default_size` | 2 | 2-way replication (VMs are not critical) |
| `ceph_mds_enabled` | false | Disable MDS (RBD-only workloads) |
| `ceph_osd_memory_target` | 1GB | 1GB per OSD (tight memory constraint on VMs) |
| `ceph_osd_max_backfills` | 1 | Single backfill (avoid overwhelming VMs) |
| `ceph_osd_recovery_sleep` | 0.5s | Throttle recovery |

**Capacity planning:**
- With 2-way replication: ~600 GB usable
- With 3-way replication: ~400 GB usable
- Can scale by adding more virtual disks to VMs (up to limit of 4.6TB physical)

**Deployment:**
```bash
export AUTOMATION_PROFILE=ubuntu_r810_kvm
ansible-playbook playbooks/reused/deploy_ceph_rook.yml \
  -i inventory/hosts.yml \
  -e "@cd/vars/ceph-values-r810-kvm.yml" -v
```

#### `ceph-values-r620-kvm.yml` — Dell R620 KVM Lab (6 OSDs)

**Platform:** Dell PowerEdge R620 (128GB RAM, 12-16 CPU) hosting 3 VMs × 2 virtual disks = 6 OSDs

**Disk configuration:**
- Physical R620: sda (OS, excluded) + sdb–sdg (~2-4TB each, smaller than R810)
- 3 KVM VMs: smaller VMs than R810 (8-16GB RAM each)

**OSD calculation:** 6 OSDs ÷ 2-way replication = (6 × 100) / 2 = 300 → round conservative to 64 PGs

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| `rook_ceph_mon_count` | 1 | Single MON (minimal etcd load) |
| `rook_ceph_pool_pg_num` | 64 | More conservative than R810 (smaller cluster) |
| `rook_ceph_pool_pgp_num` | 64 | Matches PG count |
| `ceph_osd_pool_default_size` | 2 | 2-way replication |
| `ceph_mds_enabled` | false | Disable MDS |
| `ceph_osd_memory_target` | 1GB | 1GB per OSD (very constrained on R620) |
| `ceph_osd_max_backfills` | 1 | Single backfill |
| `ceph_osd_recovery_sleep` | 1.0s | More aggressive throttle than R810 |

**Capacity planning:**
- With 2-way replication: ~300 GB usable (smaller than R810)
- More constrained resource budget than R810

**Deployment:**
```bash
export AUTOMATION_PROFILE=ubuntu_r620_kvm
ansible-playbook playbooks/reused/deploy_ceph_rook.yml \
  -i inventory/hosts.yml \
  -e "@cd/vars/ceph-values-r620-kvm.yml" -v
```

#### `ceph-values-real-hardware.yml` — Real Hardware (36+ OSDs)

**Platform:** Bare-metal enterprise servers with dedicated storage tier

**OSD topology:**
- 2 HDD Storage Nodes (Storage_Server_HDD_01/02): 10 OSDs each = 20 HDD OSDs
- 2 SSD Storage Nodes (Storage_Server_SSD_01/02): 8 OSDs each = 16 SSD OSDs
- **Total: 36 OSDs** with CRUSH-based tiering

**Device configuration:**
- HDD nodes: 10 × 4TB disks per node (sdb–sdl) = 40TB per HDD node
- SSD nodes: 8 × 1TB disks per node (sdb–sdi) = 8TB per SSD node

**OSD calculation:** 36 OSDs ÷ 3-way replication = (36 × 100) / 3 = 1200 → round to 512 PGs

**Etcd capacity planning:**
- Baseline: 100MB
- 512 PGs × 3 replicas = 1536 entries
- Estimate: ~250MB additional (total ~350MB per cluster)
- Supports up to 5 pools with 1024 PGs each

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| `rook_ceph_mon_count` | 5 | 5-MON HA (2-fault tolerance) |
| `rook_ceph_pool_pg_num` | 512 | Production baseline (36 OSDs, 3-way) |
| `rook_ceph_pool_pgp_num` | 512 | Matches PG count |
| `ceph_osd_pool_default_size` | 3 | 3-way replication (standard production) |
| `ceph_mds_enabled` | true | Enable for CephFS + OpenStack Manila |
| `ceph_osd_memory_target` | 4GB | 4GB per OSD (enterprise-grade) |
| `ceph_osd_max_backfills` | 2 | 2 concurrent backfills |
| `ceph_osd_recovery_max_active` | 3 | 3 concurrent recovery ops |
| `ceph_osd_recovery_sleep` | 0.1s | Minimal throttle (network-bound, not CPU) |
| `ceph_network_mtu` | 9000 | Jumbo frames for high throughput |

**Capacity planning:**
- 3-way replication on 36 OSDs with 512 PGs:
  - HDD tier: ~13 TB usable (40TB × 2 nodes / 3)
  - SSD tier: ~5 TB usable (8TB × 2 nodes / 3)
  - Total: ~18 TB usable pool capacity
- Can add multiple pools with same PG count without overwhelming etcd

**Pre-deployment checklist:**
- [ ] Verify all 36 OSDs auto-discovered by Rook
- [ ] Verify etcd cluster has 8GB+ free memory
- [ ] Verify all MON nodes have dedicated interfaces
- [ ] Verify CRUSH rules for HDD/SSD separation
- [ ] Enable Prometheus for capacity monitoring

**Deployment:**
```bash
export AUTOMATION_PROFILE=real_hardware
ansible-playbook playbooks/reused/deploy_ceph_rook.yml \
  -i inventory/hosts.yml \
  -e "@cd/vars/ceph-values-real-hardware.yml" -v
```

### Key Parameter Explanations

#### MON Count (`rook_ceph_mon_count`)

**What it does:** Number of Ceph Monitors (cluster state managers)

| Count | Quorum | Fault Tolerance | etcd Load | Use Case |
|-------|--------|-----------------|-----------|----------|
| 1 | Automatic | 0 faults | Minimal | Lab/dev only |
| 3 | 2 of 3 | 1 node | Low | Testing, small prod |
| 5 | 3 of 5 | 2 nodes | Medium | Enterprise production |
| 7 | 4 of 7 | 3 nodes | High | Multi-zone production |

**Impact:** Each MON = etcd replication + state distribution. More MONs = more etcd entries.

#### PG Count (`rook_ceph_pool_pg_num`)

**What it does:** Number of Placement Groups per pool (data distribution granularity)

**Formula:** `PGs = (OSDs × 100) / pool_size`, round down to power of 2

**Example:**
```
R810 lab (12 OSDs, 2-way):
  (12 × 100) / 2 = 600
  → Round down to conservative 128 PGs (not 512, avoid etcd pressure)

Real hardware (36 OSDs, 3-way):
  (36 × 100) / 3 = 1200
  → Round to 512 PGs (production-grade with 8GB etcd budget)
```

**Impact:** Each PG = etcd state entry (~10-100KB in CRUSH map)
- 32 PGs × 3 copies = 96 entries × ~50KB = 4.8MB
- 512 PGs × 3 copies = 1536 entries × ~50KB = 76.8MB
- 1024 PGs × 3 copies = 3072 entries × ~50KB = 153.6MB (etcd may stall!)

**Why conservative in labs:** K8s etcd runs with only ~100MB baseline in small clusters. High PGs = memory pressure = API timeouts.

#### Pool Replication (`ceph_osd_pool_default_size`)

**What it does:** Number of data replicas per object

| Size | Failure Tolerance | Space Overhead | Use Case |
|------|------------------|-----------------|----------|
| 1x | None (DANGER!) | 100% | Never in production |
| 2x | 1 OSD loss | 50% | Lab/dev only |
| 3x | 2 OSD loss | 33% | Standard production |
| 4x | 3 OSD loss | 25% | Multi-zone DC, ultra-high-availability |

**Impact:** Smaller pool_size = smaller PG count in formula. 2x vs 3x replication = ~25% fewer PGs needed.

#### MDS Enable (`ceph_mds_enabled`)

**What it does:** Enables Ceph Metadata Server (required for CephFS)

| Setting | Impact | When to Disable |
|---------|--------|-----------------|
| true | Adds MDS pods, ~200-500MB memory per MDS | RBD-only labs, no CephFS needed |
| false | No MDS = no CephFS support | Default for lab RBD deployments |

**Note:** OpenStack CephFS/Manila support requires MDS enabled.

### Var File Override Examples

#### Override PG Count for Custom Cluster Size

If you have an R810 cluster with more VMs (e.g., 16 instead of 6):
```bash
ansible-playbook playbooks/reused/deploy_ceph_rook.yml \
  -i inventory/hosts.yml \
  -e "@cd/vars/ceph-values-r810-kvm.yml" \
  -e "rook_ceph_pool_pg_num=256" \  # Override 128 → 256
  -v
```

#### Enable MDS for R810 Lab CephFS Testing

```bash
ansible-playbook playbooks/reused/deploy_ceph_rook.yml \
  -i inventory/hosts.yml \
  -e "@cd/vars/ceph-values-r810-kvm.yml" \
  -e "ceph_mds_enabled=true" \  # Override false → true
  -v
```

#### Use Production Settings on Real Hardware with Only 18 OSDs (Pre-Production)

```bash
# Start with prod baseline, then adjust PGs down for smaller cluster
# 18 OSDs, 3-way: (18 × 100) / 3 = 600 → use 256 instead of 512
ansible-playbook playbooks/reused/deploy_ceph_rook.yml \
  -i inventory/hosts.yml \
  -e "@cd/vars/ceph-values-prod.yml" \
  -e "rook_ceph_pool_pg_num=256" \  # Smaller cluster adjustment
  -v
```

### Post-Deployment Validation

After deploying with a var file, verify the settings took effect:

```bash
# Check MON count
kubectl get pod -n rook-ceph -l app=rook-ceph-mon

# Check pool PG count
kubectl exec -n rook-ceph <toolbox-pod> -- ceph osd pool get kube-rbd pg_num

# Check pool replication size
kubectl exec -n rook-ceph <toolbox-pod> -- ceph osd pool get kube-rbd size

# Check MDS status
kubectl get pod -n rook-ceph -l app=rook-ceph-mds

# Monitor etcd latency (should be <100ms)
kubectl describe pod -n kube-system -l component=etcd
```

---

## Complete File Structure

```
cd/vars/
├── README.md                              # Complete var file selector guide
├── ceph-values-dev.yml                    # Dev/lab — minimal resources
├── ceph-values-test.yml                   # Test/QA — production-like
├── ceph-values-prod.yml                   # Production — enterprise
├── ceph-values-dr.yml                     # DR/failover — balanced
├── ceph-values-r810-kvm.yml               # R810 KVM lab — 12 OSDs
├── ceph-values-r620-kvm.yml               # R620 KVM lab — 6 OSDs
└── ceph-values-real-hardware.yml          # Real hardware — 36+ OSDs

inventory/group_vars/
├── ceph_mon.yml                           # MON/MGR/MDS config (cluster identity)
└── ceph_osd.yml                           # OSD device config (device discovery)

playbooks/reused/
├── deploy_ceph_rook.yml                   # Rook deployment (loads var files)
├── deploy_ceph_infra_pool.yml             # Infra pool creation
└── deploy_ceph.yml                        # Cephadm alternative

roles/ceph/
├── defaults/main.yml                      # Fallback defaults (vars_files override these)
└── templates/
    └── rook-ceph-cluster-values.yml.j2    # Helm values template (references vars)
```

---

## Change Log

| Date | Change | Reasoning |
|------|--------|-----------|
| 2026-06-03 | Phase count updated from 5 → 6 | Phase 3 (rook_dashboard) added as dedicated phase for NodePort exposure + credential retrieval. Phases: 0=prepare, 1=operator, 2=cluster, 3=dashboard, 4=validate, 5=teardown. |
| 2026-06-03 | Architecture diagram MON count: x2 → x1 | R810 KVM lab uses `rook_ceph_mon_count: 1` (single MON reduces etcd pressure). Previous value (2) was never deployed. |
| 2026-06-03 | Infra-storage pool: size 3/PG 64 → size 2/PG 32 | Lab uses 2-way replication (6 nodes). PG 32 is conservative to prevent etcd pressure. |
| 2026-06-03 | KVM Optimizations table: MON count 2 → 1 | Aligned with `ceph-values-r810-kvm.yml` and `ceph_mon.yml` which both specify 1 MON. |
| 2026-06-03 | Added troubleshooting: "0 OSDs" and "rbd pool init hangs" | Most common KVM lab failures when virtual disks not yet attached. Playbook now handles both gracefully. |
| 2026-06-03 | Storage_Server_HDD/SSD removed from ceph_osd group | Unreachable in KVM lab ("No route to host"). Commented out; re-enable for real_hardware profile. |
| 2026-06-03 | Helm deploy: removed `--wait` flag | `--wait` blocks 15 min if OSD pods never start (no disks). OSD readiness check now handles 0-OSD gracefully. |
| 2026-06-03 | Dashboard patch: strategic merge patch | Previous JSON patch (`op: add`) fails on re-run if nodePort exists. Strategic merge is idempotent. |
| 2026-06-03 | Teardown: enhanced to full scorched-earth (Phase 5 + 5b) | Previous teardown left disks dirty and `/var/lib/rook` intact, causing re-deploy failures: (1) Rook finalizers blocked namespace deletion indefinitely, (2) stale BlueStore signatures prevented OSD re-creation, (3) leftover `/var/lib/rook` confused cluster detection. Now adds: finalizer removal, CR cleanup, disk wipe (wipefs+dd+sgdisk) on all ceph_osd nodes, `/var/lib/rook` removal. |
| 2026-06-03 | Teardown: disk wipe integrated as Phase 5b | Previously required manual `ansible ceph_osd -m shell` after teardown. Now fully automated — no separate command needed for complete reset. |
