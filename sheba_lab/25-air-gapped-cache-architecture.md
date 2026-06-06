# 25 — Air-Gapped Cache Architecture

## Overview

Documents how the `/opt/fabric-cache/` directory (populated by `preflight_download.yml`) is consumed by every subsequent playbook in the deployment chain. All playbooks use a **cache-first** pattern: check for local artifacts before attempting internet downloads.

| Attribute | Value |
|-----------|-------|
| Scope | All deployment playbooks |
| Category | Infrastructure Build |
| Profiles | KVM (air-gapped via tinyproxy) + Real Hardware |
| Prerequisites | `preflight_download.yml` has been run with internet access |
| Design Principle | **Never hit the internet if the cache has the artifact** |

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│  DEPLOYER (Lab-ControlNode / WSL2)                                   │
│  /opt/fabric-cache/                                                  │
│  ├── binaries/       helm, kubectl, cephadm, yq, k9s, argocd        │
│  ├── helm-charts/    38+ .tgz chart tarballs                         │
│  ├── images/         cirros, ubuntu cloud images                     │
│  ├── apt-packages/   .deb files for offline apt                      │
│  ├── pip-packages/   .whl files for offline pip                      │
│  └── kubespray/                                                      │
│      ├── src/        kubespray v2.25.0 git clone                     │
│      ├── venv/       python venv with all deps                       │
│      └── download-cache/  container images for download_localhost     │
└──────────────┬──────────────────────────────────────────────────────┘
               │  ansible.builtin.copy / scp / piped transfer
               ▼
┌─────────────────────────────────────────────────────────────────────┐
│  R810 HYPERVISOR (172.16.2.1)                                        │
│  ├── NAT gateway for 172.16.2.0/24 → internet                       │
│  ├── ip_forward=1 + iptables MASQUERADE                              │
│  └── tinyproxy @ :8888 (available but NOT required)                  │
└──────────────┬──────────────────────────────────────────────────────┘
               │  default via 172.16.2.1 (set by Phase 3 netplan)
               ▼
┌─────────────────────────────────────────────────────────────────────┐
│  TARGET NODES (KVM VMs on R810)                                      │
│  172.16.2.0/24 — Internet via R810 NAT + default gateway             │
│                                                                      │
│  Default route: via 172.16.2.1 dev enp1s0 (set by deploy_kubespray) │
│  DNS: 8.8.8.8, 1.1.1.1 (set via netplan)                            │
│  /tmp/infra-charts/*.tgz      ──→ helm install source                │
│  /tmp/sdlc-charts/*.tgz       ──→ helm install source                │
│  /tmp/monitoring-charts/*.tgz ──→ helm install source                │
│  /usr/local/bin/helm          ──→ from /opt/fabric-cache/binaries/   │
│  /usr/local/bin/cephadm       ──→ from /opt/fabric-cache/binaries/   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Network Connectivity for KVM Nodes

### The Default Gateway Problem (Critical)

KVM guest VMs created by libvirt/QEMU on the 172.16.2.0/24 bridge network are
provisioned **without a default gateway**. Their routing table contains only:

```
172.16.2.0/24 dev enp1s0 proto kernel scope link src 172.16.2.40
```

Without `default via 172.16.2.1`, the nodes:
- ❌ Cannot reach ANY IP outside 172.16.2.0/24
- ❌ Cannot ping 8.8.8.8 ("Network is unreachable")
- ❌ Cannot resolve DNS (systemd-resolved can't reach upstream forwarders)
- ❌ apt-get fails with "Temporary failure resolving archive.ubuntu.com"
- ✅ CAN reach 172.16.2.1 (R810 hypervisor) on the local subnet

### Why Tinyproxy Alone Didn't Work

We originally tried using tinyproxy on R810 (172.16.2.1:8888) as the sole
internet path for nodes. This was configured via `/etc/apt/apt.conf.d/90proxy`:

```
Acquire::http::Proxy "http://172.16.2.1:8888";
Acquire::https::Proxy "http://172.16.2.1:8888";
```

**This failed despite the proxy being reachable on the local subnet.** Root cause analysis:

1. **apt's HTTP method still performs DNS resolution** — Even with `Acquire::http::Proxy` 
   configured, apt's internal HTTP client attempts to resolve the target hostname 
   (`archive.ubuntu.com`) via the system DNS before initiating the proxy connection. 
   This is a known behavior in apt's acquire subsystem.

2. **systemd-resolved has no path to upstream DNS** — The nodes' systemd-resolved 
   service needs to reach an upstream DNS server (like 8.8.8.8 or the ISP's resolver). 
   Without a default gateway, it cannot forward DNS queries, causing resolution to fail.

3. **apt aborts before reaching the proxy** — When hostname resolution fails, apt 
   reports "Temporary failure resolving" and never actually sends the request through 
   the proxy. The proxy connection opportunity is lost at the DNS stage.

4. **KubeSpray's `package` module amplifies the problem** — KubeSpray's 
   `Install packages requirements` task uses the `package` module with 4 retries 
   and random delays, turning a simple failure into a 47-minute hang.

**TL;DR**: A tinyproxy cannot substitute for a default gateway. apt requires
working DNS even when a proxy is configured. DNS requires network reachability
to upstream resolvers. Reachability requires a default route.

### The Correct Fix: Default Gateway via R810

R810 already performs NAT for 172.16.2.0/24 (confirmed: adding `default via 172.16.2.1`
on any node immediately gives it full internet — `ping 8.8.8.8` and
`curl -I https://google.com` both succeed).

Phase 3 of `deploy_kubespray.yml` now automates this:

```yaml
# 1. Add temporary default route (immediate effect)
sudo ip route add default via 172.16.2.1 dev enp1s0

# 2. Make permanent via netplan (survives reboot)
network:
  version: 2
  ethernets:
    enp1s0:
      addresses:
        - 172.16.2.40/24
      routes:
        - to: default
          via: 172.16.2.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 1.1.1.1

# 3. Verify connectivity
ping -c 1 -W 3 8.8.8.8  # Must succeed before proceeding
```

### When Is Tinyproxy Still Useful?

Tinyproxy remains useful for:
- **Environments where NAT is not available** on the hypervisor (e.g., strict corporate firewalls)
- **Selective access control** (Allow/Deny lists for specific subnets)
- **Traffic auditing** (tinyproxy logs all proxied requests)

But it is **NOT a replacement for basic L3 connectivity**. The nodes need either:
1. A default gateway (preferred — simple, reliable), OR
2. A SOCKS5 proxy + a DNS proxy (complex, fragile — apt doesn't natively support SOCKS)

---

## KubeSpray Patches (Air-Gapped Safety)

Even with internet access via the default gateway, we patch KubeSpray to skip
apt operations as a safety net. If internet is flaky or slow, these patches
prevent 47-minute hangs:

```yaml
# Patched in Phase 4 of deploy_kubespray.yml:
- name: Update package management cache (APT)
  apt:
    update_cache: yes
    cache_valid_time: 3600
  when: false  # PATCHED_SKIP_APT_UPDATE — packages pre-installed in Phase 3

- name: Install packages requirements
  when: false  # PATCHED_SKIP_PKG_INSTALL — packages pre-installed in Phase 3
```

Phase 3 pre-installs ALL packages KubeSpray needs (the full list from
`roles/kubernetes/preinstall/vars/main.yml`), making KubeSpray's own
package installation redundant.

---

## Cache-First Pattern

Every helm install task follows this pattern:

```bash
CHART_SRC=$(ls /tmp/<stage>-charts/<chartname>-*.tgz 2>/dev/null | head -1)
if [ -z "$CHART_SRC" ]; then
  CHART_SRC="<repo>/<chart>"     # online fallback
fi
helm upgrade --install <release> "$CHART_SRC" \
  --namespace <ns> --values <values> --wait
```

Every binary install follows:

```bash
if [ -f /opt/fabric-cache/binaries/<binary> ]; then
  cp /opt/fabric-cache/binaries/<binary> /usr/local/bin/<binary>
elif <fallback-curl>; then
  ...  # internet fallback
fi
```

---

## Proxy Configuration (KVM Profiles) — DEPRECATED

> **NOTE**: The tinyproxy approach described below has been **superseded** by the
> default gateway fix (see "Network Connectivity for KVM Nodes" above). The
> 90proxy file is now **removed** by Phase 3 since nodes have direct internet.

~~For KVM-based air-gapped nodes, apt proxy was configured before any `apt-get update`:~~

```
# /etc/apt/apt.conf.d/90proxy (NO LONGER USED)
Acquire::http::Proxy "http://172.16.2.1:8888";
Acquire::https::Proxy "http://172.16.2.1:8888";
```

~~**Applied by**: `deploy_kubespray.yml` Phase 3, `extend_topology.yml`~~  
~~**Condition**: `automation_profile in ['ubuntu_r810_kvm', 'ubuntu_r620_kvm', 'win11_kvm']`~~  
~~**Why**: Ansible's `apt` module does NOT inherit shell `http_proxy` env vars. It needs apt's native proxy config.~~

**Why it failed**: See "Why Tinyproxy Alone Didn't Work" section above.

---

## Playbook-by-Playbook Cache Usage

### Fully Cache-Aware (No Internet Required)

| # | Playbook | Helm Charts | Binaries | Network |
|---|----------|-------------|----------|---------|
| 01 | `preflight_download.yml` | Downloads all → cache | Downloads all → cache | N/A (deployer) |
| 12 | `deploy_kubespray.yml` | via KubeSpray download_localhost | helm from cache | ✅ default gw + netplan |
| 12b | MetalLB (role) | `/opt/fabric-cache/helm-charts/metallb-*.tgz` | — | — |
| 13 | `deploy_ceph_rook.yml` | rook-ceph from cache | cephadm from cache | — |
| 14 | `deploy_postgresql.yml` | postgresql from cache | helm from cache | — |
| 15 | OpenStack Helm (role) | All OSH charts → `/tmp/osh-charts/` | helm-diff plugin from cache | — |
| 16 | `extend_topology.yml` | — | cephadm from cache | ✅ default gw |
| — | `deploy_maas.yml` | maas chart from cache | — | — |
| — | `deploy_sheba_infra_services.yml` | 6 charts → `/tmp/infra-charts/` | — | — |
| — | `deploy_sheba_sdlc_services.yml` | 7 charts → `/tmp/sdlc-charts/` | — | — |
| — | Monitoring (role) | prometheus-stack → `/tmp/monitoring-charts/` | — | — |

---

## Preflight Download — Complete Artifact Inventory

### Binaries (`/opt/fabric-cache/binaries/`)

| Binary | Version | Used By |
|--------|---------|---------|
| `helm` | latest | deploy_kubespray, deploy_postgresql, all helm playbooks |
| `kubectl` | matches kubespray version | deploy_kubespray |
| `cephadm` | reef | deploy_ceph_rook, extend_topology |
| `yq` | v4.x | inventory generation |
| `k9s` | latest | operator tooling |
| `argocd` | latest | argocd CLI |
| `packer` | latest | build_packer_images |
| `node_exporter` | latest | monitoring |
| `prometheus` | latest | monitoring |
| `alertmanager` | latest | monitoring |

### Helm Charts (`/opt/fabric-cache/helm-charts/`)

| Chart | Consumer Playbook |
|-------|-------------------|
| `postgresql-*.tgz` | deploy_postgresql, deploy_sheba_infra_services |
| `postgresql-ha-*.tgz` | HA PostgreSQL deployments |
| `redis-*.tgz` | deploy_sheba_infra_services |
| `metallb-*.tgz` | roles/metallb |
| `rook-ceph-*.tgz` | deploy_ceph_rook |
| `kube-prometheus-stack-*.tgz` | roles/monitoring |
| `grafana-*.tgz` | deploy_sheba_sdlc_services, roles/monitoring |
| `loki-*.tgz` | deploy_sheba_sdlc_services |
| `tempo-*.tgz` | roles/monitoring |
| `promtail-*.tgz` | roles/monitoring |
| `ingress-*.tgz` | roles/openstack_helm |
| `mariadb-*.tgz` | roles/openstack_helm |
| `rabbitmq-*.tgz` | roles/openstack_helm |
| `memcached-*.tgz` | roles/openstack_helm |
| `keystone-*.tgz` | roles/openstack_helm |
| `glance-*.tgz` | roles/openstack_helm |
| `cinder-*.tgz` | roles/openstack_helm |
| `placement-*.tgz` | roles/openstack_helm |
| `nova-*.tgz` | roles/openstack_helm |
| `neutron-*.tgz` | roles/openstack_helm |
| `horizon-*.tgz` | roles/openstack_helm |
| `heat-*.tgz` | roles/openstack_helm |
| `openvswitch-*.tgz` | roles/openstack_helm |
| `cert-manager-*.tgz` | cert management |
| `gitea-*.tgz` | deploy_sheba_infra_services |
| `harbor-*.tgz` | deploy_sheba_infra_services |
| `openbao-*.tgz` | deploy_sheba_infra_services |
| `minio-*.tgz` | deploy_sheba_infra_services |
| `plane-ce-*.tgz` | deploy_sheba_sdlc_services |
| `argo-cd-*.tgz` | deploy_sheba_sdlc_services |
| `sonarqube-*.tgz` | deploy_sheba_sdlc_services |
| `mattermost-team-edition-*.tgz` | deploy_sheba_sdlc_services |
| `jaeger-*.tgz` | deploy_sheba_sdlc_services |
| `maas-*.tgz` | deploy_maas |
| `mongodb-*.tgz` | various |
| `elasticsearch-*.tgz` | various |
| `keycloak-*.tgz` | auth services |
| `minio-*.tgz` | deploy_sheba_infra_services |

### APT Packages (`/opt/fabric-cache/apt-packages/`)

Core packages cached for offline install:
- `conntrack`, `socat`, `ipset`, `ipvsadm`, `libipset13`
- `openvswitch-switch`, `frr`, `frr-pythontools`, `lldpd`
- `qemu-kvm`, `libvirt-daemon-system`, `chrony`
- `apt-transport-https`, `ca-certificates`, `curl`
- `lvm2`, `gdisk` (Ceph OSD prerequisites)

### Pip Packages (`/opt/fabric-cache/pip-packages/`)

- `kolla-ansible`, `python-openstackclient`, `python-heatclient`
- `docker`, `ansible-core`, `netaddr`, `jinja2`

---

## KubeSpray Offline Mode

KubeSpray uses a special mechanism via `kubespray_all.yml.j2`:

```yaml
download_localhost: true          # Download images ON deployer
download_cache_dir: /opt/fabric-cache/kubespray/download-cache
download_force_cache: true        # Always prefer cache over pull
```

**Key Insight**: KubeSpray's `http_proxy`/`https_proxy` vars in `all.yml` work
for container runtime pulls (containerd/docker) but are insufficient for apt
because apt requires both working DNS AND the `Acquire::` config. Since we now
give nodes a default gateway + DNS via netplan, apt works directly without any
proxy configuration.

---

## Troubleshooting

### `apt-get update` hangs for 60+ minutes / "Temporary failure resolving"
**Cause**: KVM nodes have no default gateway → no DNS → no internet. Tinyproxy alone is NOT sufficient (see "Why Tinyproxy Alone Didn't Work" above).  
**Fix**: Ensure the `Ensure default gateway is set` and `Make default gateway permanent via netplan` tasks run in Phase 3 of `deploy_kubespray.yml`. Verify with: `ssh <node> "ping -c 1 8.8.8.8"`

### KubeSpray's "Install packages requirements" fails with DNS errors
**Cause**: Same root cause — no default gateway on nodes. Even with `Acquire::http::Proxy` configured, apt still needs working DNS.  
**Fix**: Default gateway fix (above). Additionally, Phase 3 now pre-installs all KubeSpray-required packages (`ebtables`, `unzip`, `conntrack`, `socat`, etc.) and Phase 4 patches KubeSpray to skip its own package installation.

### Helm chart not found in cache
**Cause**: `preflight_download.yml` was run without the relevant tag, or chart name doesn't match glob.  
**Fix**: Re-run preflight with the specific tag, e.g. `--tags helm_charts`. Verify chart exists: `ls /opt/fabric-cache/helm-charts/<name>-*.tgz`

### Binary not in `/opt/fabric-cache/binaries/`
**Cause**: Preflight skipped binary download or version mismatch.  
**Fix**: Re-run `ansible-playbook preflight_download.yml --tags binaries -v`

### `helm repo add` still runs despite cache
**Cause**: The `delegate_to: localhost` find task can't see `/opt/fabric-cache/helm-charts/` (wrong path or permissions).  
**Fix**: Verify the cache dir exists on the deployer: `ls /opt/fabric-cache/helm-charts/*.tgz | wc -l`

---

## Design Decisions

1. **Cache on deployer, copy to nodes** — avoids needing shared NFS or direct internet from nodes
2. **`delegate_to: localhost` for discovery** — the deployer always has the cache; nodes may not
3. **Glob matching for chart versions** — `postgresql-*.tgz` allows version bumps without playbook edits
4. **Conditional `helm repo add`** — only hits internet if no cache found (graceful degradation)
5. **Separate staging dirs per playbook** — `/tmp/infra-charts/`, `/tmp/sdlc-charts/`, `/tmp/monitoring-charts/`, `/tmp/osh-charts/` prevent collisions
6. **Default gateway over proxy** — apt requires working DNS even with proxy configured; a default route via R810 (which already NATs) is simpler and more reliable than tinyproxy
7. **Pre-install + patch KubeSpray** — Phase 3 installs all packages, Phase 4 patches KubeSpray to skip redundant apt operations (safety net against flaky internet)
