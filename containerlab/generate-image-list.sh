#!/usr/bin/env bash
# =============================================================================
# generate-image-list.sh — Populate /opt/fabric-cache for air-gapped deployment
#
# Downloads EVERYTHING needed for a full Sheba DC lab deployment:
#   - Container images  (docker save → tarballs)
#   - Helm chart tarballs
#   - Helm binary
#   - Kubespray repository clone
#   - Kubespray Python wheel cache
#
# Run ONCE on the WSL control-node while it has internet.
# Afterwards, ansible-playbook playbooks/site.yml works completely offline.
#
# Usage:
#   chmod +x scripts/generate-image-list.sh
#   FABRIC_CACHE_ROOT=/opt/fabric-cache ./scripts/generate-image-list.sh
#   ./scripts/generate-image-list.sh --list   # print manifests, do not download
#   ./scripts/generate-image-list.sh --clean  # remove entire cache (start fresh)
# =============================================================================
set -euo pipefail

CACHE_DIR="${FABRIC_CACHE_ROOT:-/opt/fabric-cache}"
IMAGE_DIR="${CACHE_DIR}/images"
CHART_DIR="${CACHE_DIR}/charts"
BIN_DIR="${CACHE_DIR}/bin"
PIP_DIR="${CACHE_DIR}/pip"
REPO_DIR="${CACHE_DIR}/repos"

# ── Version pins — keep in sync with group_vars/ ─────────────────────────────
# K8s stack
K8S_VERSION="${K8S_VERSION:-v1.33.3}"
KUBESPRAY_VERSION="${KUBESPRAY_VERSION:-v2.31.0}"
CALICO_VERSION="${CALICO_VERSION:-v3.29.2}"
COREDNS_VERSION="${COREDNS_VERSION:-v1.12.0}"
METRICS_SERVER_VERSION="${METRICS_SERVER_VERSION:-v0.8.0}"
PAUSE_VERSION="${PAUSE_VERSION:-3.10}"      # 3.11 not yet published; K8s 1.33 uses 3.10
ETCD_VERSION="${ETCD_VERSION:-v3.5.17}"
# K8s add-ons
METALLB_VERSION="${METALLB_VERSION:-v0.14.9}"
ROOK_VERSION="${ROOK_VERSION:-v1.15.5}"
CEPH_VERSION="${CEPH_VERSION:-v19.2.0}"
PROM_STACK_VERSION="${PROM_STACK_VERSION:-v0.78.2}"
INGRESS_NGINX_VERSION="${INGRESS_NGINX_VERSION:-v1.12.0}"
CERT_MANAGER_VERSION="${CERT_MANAGER_VERSION:-v1.16.2}"
DASHBOARD_VERSION="${DASHBOARD_VERSION:-v2.7.0}"
# OpenStack
OPENSTACK_VERSION="${OPENSTACK_VERSION:-2026.1}"
OPENSTACK_IMG_TAG="${OPENSTACK_IMG_TAG:-${OPENSTACK_VERSION}-ubuntu_noble}"
OSH_INFRA_MARIADB="${OSH_INFRA_MARIADB:-10.11}"
OSH_INFRA_RABBITMQ="${OSH_INFRA_RABBITMQ:-3.13}"
OSH_INFRA_MEMCACHED="${OSH_INFRA_MEMCACHED:-1.6}"

# ── Container image manifest ──────────────────────────────────────────────────
IMAGES=(
  # ── Kubernetes core ──────────────────────────────────────────────────────
  "registry.k8s.io/kube-apiserver:${K8S_VERSION}"
  "registry.k8s.io/kube-controller-manager:${K8S_VERSION}"
  "registry.k8s.io/kube-scheduler:${K8S_VERSION}"
  "registry.k8s.io/kube-proxy:${K8S_VERSION}"
  "registry.k8s.io/pause:${PAUSE_VERSION}"
  "registry.k8s.io/coredns/coredns:${COREDNS_VERSION}"
  "registry.k8s.io/etcd:${ETCD_VERSION}"
  "registry.k8s.io/dns/k8s-dns-node-cache:1.23.1"
  "registry.k8s.io/metrics-server/metrics-server:${METRICS_SERVER_VERSION}"
  "registry.k8s.io/cpa/cluster-proportional-autoscaler:v1.9.0"

  # ── Calico CNI (none-backend: node + kube-controllers only needed) ────────
  "docker.io/calico/cni:${CALICO_VERSION}"
  "docker.io/calico/node:${CALICO_VERSION}"
  "docker.io/calico/kube-controllers:${CALICO_VERSION}"
  "docker.io/calico/pod2daemon-flexvol:${CALICO_VERSION}"
  "docker.io/calico/typha:${CALICO_VERSION}"

  # ── MetalLB ──────────────────────────────────────────────────────────────
  "quay.io/metallb/controller:${METALLB_VERSION}"
  "quay.io/metallb/speaker:${METALLB_VERSION}"

  # ── Rook-Ceph ────────────────────────────────────────────────────────────
  "docker.io/rook/ceph:${ROOK_VERSION}"
  "quay.io/ceph/ceph:${CEPH_VERSION}"
  "registry.k8s.io/sig-storage/csi-node-driver-registrar:v2.12.0"
  "registry.k8s.io/sig-storage/csi-provisioner:v5.1.0"
  "registry.k8s.io/sig-storage/csi-resizer:v1.12.0"
  "registry.k8s.io/sig-storage/csi-snapshotter:v8.1.0"
  "registry.k8s.io/sig-storage/csi-attacher:v4.7.0"

  # ── kube-prometheus-stack ────────────────────────────────────────────────
  "quay.io/prometheus-operator/prometheus-operator:${PROM_STACK_VERSION}"
  "quay.io/prometheus-operator/prometheus-config-reloader:${PROM_STACK_VERSION}"
  "quay.io/prometheus/prometheus:v2.55.1"
  "quay.io/prometheus/alertmanager:v0.27.0"
  "quay.io/prometheus/node-exporter:v1.8.2"
  "docker.io/grafana/grafana:11.3.1"
  "registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.14.0"
  "quay.io/brancz/kube-rbac-proxy:v0.18.1"

  # ── ingress-nginx ────────────────────────────────────────────────────────
  "registry.k8s.io/ingress-nginx/controller:${INGRESS_NGINX_VERSION}"
  "registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.4.4"

  # ── cert-manager ─────────────────────────────────────────────────────────
  "quay.io/jetstack/cert-manager-controller:${CERT_MANAGER_VERSION}"
  "quay.io/jetstack/cert-manager-webhook:${CERT_MANAGER_VERSION}"
  "quay.io/jetstack/cert-manager-cainjector:${CERT_MANAGER_VERSION}"
  "quay.io/jetstack/cert-manager-startupapicheck:${CERT_MANAGER_VERSION}"

  # ── Kubernetes Dashboard ─────────────────────────────────────────────────
  "docker.io/kubernetesui/dashboard:${DASHBOARD_VERSION}"
  "docker.io/kubernetesui/metrics-scraper:v1.0.9"

  # ── Multus CNI (meta-CNI for secondary pod NICs) ─────────────────────────
  "ghcr.io/k8snetworkplumbingwg/multus-cni:v4.1.0"

  # ── OpenStack-Helm infra (MariaDB, RabbitMQ, Memcached) ──────────────────────────────────
  # bitnami/mariadb-galera is pulled by the OSH mariadb Helm chart at deploy time;
  # tag '10.11' alone doesn't exist (requires full semver like 10.11.9-debian-12-r0).
  # Standard library images that DO have clean tags:
  "docker.io/library/rabbitmq:${OSH_INFRA_RABBITMQ}-management"
  "docker.io/library/memcached:${OSH_INFRA_MEMCACHED}"

  # ── OpenStack Kolla images ────────────────────────────────────────────────
  # NOTE: OpenStack 2026.1 (Gazpacho) does NOT publish pre-built images to any
  # public registry (quay.io/openstack.kolla or docker.io/kolla). You MUST build
  # them with kolla-build. Run: ./scripts/generate-image-list.sh --kolla-build
  # The kolla-build step pushes images directly to airgap_registry_host; they do
  # not go through the /opt/fabric-cache/images tarball mechanism.

  # ── OVN BGP Agent ────────────────────────────────────────────────────────
  # Built by kolla-build — see --kolla-build flag.

  # ── Skyline (modern OpenStack dashboard) ────────────────────────────────
  # Built by kolla-build — see --kolla-build flag.

  # ── CloudKitty (rating / showback engine) ──────────────────────────────
  # Built by kolla-build — see --kolla-build flag.

  # ── FOSSBilling (standalone PHP billing portal) ───────────────────────
  "docker.io/fossbilling/fossbilling:latest"
  "docker.io/library/mariadb:11"

  # ── Storefront + registry mirror ─────────────────────────────────────────
  "docker.io/library/nginx:1.27-alpine"
  "docker.io/library/registry:2"
)

# ── Helm chart manifest ───────────────────────────────────────────────────────
# Format: "repo/chart:version:repo_url"
CHARTS=(
  # K8s add-ons
  "metallb/metallb:0.14.9:https://metallb.github.io/metallb"
  "rook-release/rook-ceph:v1.15.5:https://charts.rook.io/release"
  "rook-release/rook-ceph-cluster:v1.15.5:https://charts.rook.io/release"
  "prometheus-community/kube-prometheus-stack:65.5.1:https://prometheus-community.github.io/helm-charts"
  "ingress-nginx/ingress-nginx:4.12.0:https://kubernetes.github.io/ingress-nginx"
  "jetstack/cert-manager:v1.16.2:https://charts.jetstack.io"

  # OpenStack-Helm infra — cycle-based versioning confirmed from helm repo
  # (log showed: mariadb-2024.2.1, rabbitmq-2024.2.0, memcached-2024.2.6)
  "openstack-helm-infra/mariadb:2024.2.1:https://tarballs.opendev.org/openstack/openstack-helm-infra"
  "openstack-helm-infra/rabbitmq:2024.2.0:https://tarballs.opendev.org/openstack/openstack-helm-infra"
  "openstack-helm-infra/memcached:2024.2.6:https://tarballs.opendev.org/openstack/openstack-helm-infra"
  # ingress chart removed: version 0.4.5 not found. OSH uses ingress-nginx (above) instead.
)

# OpenStack-Helm service charts: pulled without a pinned version because the
# repo uses 2024.2.x cycle versioning; exact patch is not predictable in advance.
# Each is pulled once and cached as <chart>-<whatever-version-exists>.tgz.
OSH_SERVICE_CHARTS=(
  openstack-helm/keystone
  openstack-helm/glance
  openstack-helm/placement
  openstack-helm/nova
  openstack-helm/neutron
  openstack-helm/horizon
  openstack-helm/skyline
  openstack-helm/cloudkitty
)

# ── Flags ────────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--list" ]]; then
  echo "=== Container images (${#IMAGES[@]}) ==="
  printf '%s\n' "${IMAGES[@]}"
  echo ""
  echo "=== Helm charts (${#CHARTS[@]}) ==="
  printf '%s\n' "${CHARTS[@]}"
  echo ""
  echo "=== Kubespray ==="
  echo "  git clone --branch ${KUBESPRAY_VERSION} https://github.com/kubernetes-sigs/kubespray.git ${REPO_DIR}/kubespray"
  exit 0
fi

if [[ "${1:-}" == "--clean" ]]; then
  echo "WARNING: This will delete ${CACHE_DIR}. Press Ctrl+C to cancel, Enter to proceed."
  read -r
  rm -rf "${CACHE_DIR}"
  echo "Cache deleted."
  exit 0
fi

# ── kolla-build mode: build OpenStack images locally and push to the registry ─
# OpenStack 2026.1 (Gazpacho) does NOT publish pre-built images to any public
# registry. You must build them with kolla-build from the openstack/kolla project.
#
# IMPORTANT — two different registry addresses are used:
#   Push (from WSL control node) : 192.168.9.198:5000  (R810 external IP — direct TCP)
#   Pull (from K8s VMs)          : 172.16.2.1:5000      (R810 bridge IP — reachable inside clab)
# Both point to the SAME registry container on R810. WSL cannot reach 172.16.2.1
# directly because that address lives on the containerlab management bridge; Docker
# push does NOT go through the SOCKS proxy, so it would time out.
if [[ "${1:-}" == "--kolla-build" ]]; then
  # Push to R810 external IP so WSL Docker reaches it without SOCKS proxy
  KOLLA_REGISTRY="${KOLLA_REGISTRY:-192.168.9.198:5000}"
  KOLLA_NAMESPACE="${KOLLA_NAMESPACE:-openstack.kolla}"
  command -v pip3 >/dev/null 2>&1 || { echo "ERROR: pip3 not found — install python3-pip"; exit 1; }
  command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not found"; exit 1; }

  # Ask Docker what it actually has loaded — more reliable than parsing daemon.json
  # because Docker must have restarted and read the file for the change to take effect.
  # Set SKIP_REGISTRY_CHECK=1 to bypass this gate if you know Docker is configured.
  if [[ "${SKIP_REGISTRY_CHECK:-}" != "1" ]] && ! docker info 2>/dev/null | grep -q "${KOLLA_REGISTRY}"; then
    echo ""
    echo "WARNING: ${KOLLA_REGISTRY} is NOT in Docker's active insecure-registries."
    echo "kolla-build will fail to push. Fix steps:"
    echo ""
    echo "  1. Write the config:"
    echo '     sudo tee /etc/docker/daemon.json <<'"'"'EOF'"'"
    echo '     {"insecure-registries": ["'"${KOLLA_REGISTRY}"'", "172.16.2.1:5000"]}'
    echo '     EOF'
    echo ""
    echo "  2. Restart Docker (try BOTH — one works depending on your WSL setup):"
    echo "     sudo service docker restart          # WSL without systemd"
    echo "     sudo systemctl restart docker        # WSL with systemd"
    echo ""
    echo "  3. Verify Docker loaded the config:"
    echo "     docker info | grep -A5 'Insecure Registries'"
    echo "     # ${KOLLA_REGISTRY} must appear in the output"
    echo ""
    echo "  4. Re-run: sudo ./scripts/generate-image-list.sh --kolla-build"
    echo ""
    echo "  Or bypass this check (only if you know Docker is configured correctly):"
    echo "     SKIP_REGISTRY_CHECK=1 sudo ./scripts/generate-image-list.sh --kolla-build"
    exit 1
  fi

  echo "==> Installing kolla pinned to OpenStack ${OPENSTACK_VERSION} constraints ..."
  # Ubuntu 22+/24+ restricts system pip; use a dedicated venv to avoid errors.
  KOLLA_VENV="/opt/kolla-venv"
  python3 -m venv "${KOLLA_VENV}"
  "${KOLLA_VENV}/bin/pip" install --quiet kolla \
    --constraint "https://releases.openstack.org/constraints/upper/${OPENSTACK_VERSION}"
  # kolla-build requires the 'docker' Python SDK to communicate with the Docker daemon
  "${KOLLA_VENV}/bin/pip" install --quiet docker
  echo "==> kolla version: $(${KOLLA_VENV}/bin/pip show kolla | grep '^Version')"
  echo "==> Building and pushing Kolla images"
  echo "    Push registry:  ${KOLLA_REGISTRY} (R810 external — reachable from WSL)"
  echo "    Pull registry:  172.16.2.1:5000   (R810 bridge — reachable from K8s VMs)"
  echo "    Namespace:      ${KOLLA_NAMESPACE}"
  echo "    Tag:            ${OPENSTACK_IMG_TAG}"
  echo "    Estimated build time: 1-4 hours depending on CPU and internet speed."
  # --openstack-release is NOT a valid kolla-build flag; release = kolla version installed
  "${KOLLA_VENV}/bin/kolla-build" \
    --base ubuntu \
    --base-tag noble \
    --tag "${OPENSTACK_IMG_TAG}" \
    --registry "${KOLLA_REGISTRY}" \
    --namespace "${KOLLA_NAMESPACE}" \
    --push \
    heat-api heat-engine \
    keystone \
    glance-api \
    placement-api \
    nova-api nova-compute nova-conductor nova-scheduler nova-novncproxy nova-libvirt \
    neutron-server neutron-ovn-metadata-agent \
    ovn-controller ovn-northd ovn-nb-db-server ovn-sb-db-server \
    horizon \
    openvswitch-db-server openvswitch-vswitchd \
    ovn-bgp-agent \
    skyline-apiserver skyline-console \
    cloudkitty-api cloudkitty-processor
  echo "==> kolla-build complete."
  echo "    Images pushed to: ${KOLLA_REGISTRY}/${KOLLA_NAMESPACE}/<service>:${OPENSTACK_IMG_TAG}"
  echo "    Containerd mirror (quay.io → ${KOLLA_REGISTRY}) serves them to K8s nodes automatically."
  echo "    No fabric-cache re-seeding required — images are already in the registry."
  exit 0
fi

# ── Prerequisites ─────────────────────────────────────────────────────────────
command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not found"; exit 1; }
command -v git    >/dev/null 2>&1 || { echo "ERROR: git not found"; exit 1; }
command -v curl   >/dev/null 2>&1 || { echo "ERROR: curl not found"; exit 1; }

echo "==> Creating cache directories under ${CACHE_DIR}"
mkdir -p "${IMAGE_DIR}" "${CHART_DIR}" "${BIN_DIR}" "${PIP_DIR}" "${REPO_DIR}"

# ── 1. Pull and save container images ────────────────────────────────────────
echo ""
echo "==> Pulling and saving ${#IMAGES[@]} container images ..."
PULL_ERRORS=0
for IMG in "${IMAGES[@]}"; do
  SAFE_NAME=$(echo "$IMG" | sed 's|[/:]|_|g')
  TARBALL="${IMAGE_DIR}/${SAFE_NAME}.tar"
  if [[ -f "$TARBALL" ]]; then
    echo "  [cached] $IMG"
    continue
  fi
  echo "  [pull]   $IMG"
  if docker pull "$IMG"; then
    docker save -o "$TARBALL" "$IMG"
    echo "  [saved]  $TARBALL"
  else
    echo "  [WARN]   Failed to pull $IMG — skipping"
    PULL_ERRORS=$((PULL_ERRORS + 1))
  fi
done
[[ $PULL_ERRORS -gt 0 ]] && echo "WARNING: $PULL_ERRORS image(s) could not be pulled — verify manually."

# ── 2. Download Helm binary ───────────────────────────────────────────────────
HELM_BIN="${BIN_DIR}/helm"
if [[ ! -f "$HELM_BIN" ]]; then
  echo ""
  echo "==> Downloading Helm binary ..."
  HELM_INSTALLER=$(mktemp)
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o "$HELM_INSTALLER"
  HELM_INSTALL_DIR="${BIN_DIR}" USE_SUDO=false bash "$HELM_INSTALLER"
  rm -f "$HELM_INSTALLER"
else
  echo ""
  echo "==> Helm binary already cached at ${HELM_BIN}"
fi

# ── 3. Download Helm charts ───────────────────────────────────────────────────
echo ""
echo "==> Downloading ${#CHARTS[@]} Helm charts ..."
for ENTRY in "${CHARTS[@]}"; do
  IFS=: read -r CHART VERSION REPO_URL <<< "$ENTRY"
  REPO_NAME="${CHART%%/*}"
  CHART_NAME="${CHART##*/}"
  TARBALL="${CHART_DIR}/${CHART_NAME}-${VERSION}.tgz"
  if [[ -f "$TARBALL" ]]; then
    echo "  [cached] ${CHART}:${VERSION}"
    continue
  fi
  "${HELM_BIN}" repo add "${REPO_NAME}" "${REPO_URL}" --force-update 2>/dev/null || true
  "${HELM_BIN}" repo update "${REPO_NAME}" 2>/dev/null
  "${HELM_BIN}" pull "${CHART}" --version "${VERSION}" -d "${CHART_DIR}"
  echo "  [saved]  ${TARBALL}"
done

# ── 3b. Download OSH service charts (pull latest — version is not pinnable) ──
echo ""
echo "==> Downloading OpenStack-Helm service charts (latest available version) ..."
"${HELM_BIN}" repo add openstack-helm \
  https://tarballs.opendev.org/openstack/openstack-helm --force-update 2>/dev/null || true
"${HELM_BIN}" repo update openstack-helm 2>/dev/null
for CHART in "${OSH_SERVICE_CHARTS[@]}"; do
  CHART_NAME="${CHART##*/}"
  # Skip if any version of this chart is already cached
  if ls "${CHART_DIR}/${CHART_NAME}-"*.tgz 2>/dev/null | head -1 | grep -q .; then
    echo "  [cached] ${CHART} ($(ls "${CHART_DIR}/${CHART_NAME}-"*.tgz 2>/dev/null | head -1 | xargs basename))"
    continue
  fi
  "${HELM_BIN}" pull "${CHART}" -d "${CHART_DIR}" 2>&1
  SAVED=$(ls "${CHART_DIR}/${CHART_NAME}-"*.tgz 2>/dev/null | head -1)
  [[ -n "$SAVED" ]] && echo "  [saved]  $(basename "$SAVED")" || echo "  [WARN]   ${CHART} — pull failed"
done
KUBESPRAY_DIR="${REPO_DIR}/kubespray"
echo ""
if [[ -d "${KUBESPRAY_DIR}/.git" ]]; then
  CURRENT_TAG=$(git -C "${KUBESPRAY_DIR}" describe --tags --exact-match 2>/dev/null || echo "unknown")
  if [[ "$CURRENT_TAG" == "$KUBESPRAY_VERSION" ]]; then
    echo "==> Kubespray ${KUBESPRAY_VERSION} already cloned at ${KUBESPRAY_DIR}"
  else
    echo "==> Re-cloning Kubespray (was ${CURRENT_TAG}, want ${KUBESPRAY_VERSION}) ..."
    rm -rf "${KUBESPRAY_DIR}"
    git clone --depth 1 --branch "${KUBESPRAY_VERSION}" \
      https://github.com/kubernetes-sigs/kubespray.git "${KUBESPRAY_DIR}"
  fi
else
  echo "==> Cloning Kubespray ${KUBESPRAY_VERSION} ..."
  git clone --depth 1 --branch "${KUBESPRAY_VERSION}" \
    https://github.com/kubernetes-sigs/kubespray.git "${KUBESPRAY_DIR}"
fi
# Symlink so the Ansible deploy playbook finds it at /opt/kubespray
KUBESPRAY_LINK="/opt/kubespray"
if [[ ! -e "$KUBESPRAY_LINK" ]] || [[ "$(readlink -f "$KUBESPRAY_LINK")" != "$(readlink -f "$KUBESPRAY_DIR")" ]]; then
  ln -sfn "${KUBESPRAY_DIR}" "${KUBESPRAY_LINK}"
  echo "==> Symlinked ${KUBESPRAY_LINK} -> ${KUBESPRAY_DIR}"
fi

# ── 5. Pre-download pip packages for Kubespray ───────────────────────────────
echo ""
echo "==> Pre-downloading pip packages for Kubespray ..."
pip download -r "${KUBESPRAY_DIR}/requirements.txt" -d "${PIP_DIR}" \
  2>/dev/null && echo "  [done] pip packages cached" || \
  echo "  [warn] pip download failed — packages will be fetched at deploy time"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "========================================="
echo " Cache population complete"
echo "========================================="
echo " Images:    $(find "${IMAGE_DIR}" -name '*.tar' 2>/dev/null | wc -l) tarballs"
echo " Charts:    $(find "${CHART_DIR}" -name '*.tgz' 2>/dev/null | wc -l) tarballs"
echo " Helm:      ${HELM_BIN}"
echo " Kubespray: ${KUBESPRAY_DIR} (${KUBESPRAY_VERSION})"
echo " Pip:       $(find "${PIP_DIR}" -name '*.whl' -o -name '*.tar.gz' 2>/dev/null | wc -l) packages"
echo ""
echo " Total size: $(du -sh "${CACHE_DIR}" | cut -f1)"
echo ""
echo " IMPORTANT — OpenStack images are NOT included above."
echo " OpenStack 2026.1 (Gazpacho) has no public pre-built images."
echo " Run this next to build them with kolla-build (1-4 hours):"
echo "   ./scripts/generate-image-list.sh --kolla-build"
echo ""
echo " Then deploy:"
echo "   ansible-playbook -i inventory.yml playbooks/site.yml"
echo "========================================="
