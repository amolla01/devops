#!/usr/bin/env bash
# =============================================================================
# generate-image-list.sh — Fixed Idempotent Hardcoded Binary Cache Populator
# =============================================================================
set -euo pipefail
umask 022

CACHE_DIR="${FABRIC_CACHE_ROOT:-/opt/fabric-cache}"
IMAGE_DIR="${CACHE_DIR}/images"
CHART_DIR="${CACHE_DIR}/charts"
BIN_DIR="${CACHE_DIR}/bin"
PIP_DIR="${CACHE_DIR}/pip"
REPO_DIR="${CACHE_DIR}/repos"
KUBESPRAY_DOWNLOADS_DIR="${CACHE_DIR}/downloads" 


ARCH="amd64"
K8S_VERSION="${K8S_VERSION:-v1.35.4}" 
KUBE_VERSION="${K8S_VERSION:-v1.35.4}"
KUBESPRAY_VERSION="${KUBESPRAY_VERSION:-v2.31.0}"
CALICO_VERSION="${CALICO_VERSION:-v3.29.2}"
COREDNS_VERSION="${COREDNS_VERSION:-v1.12.0}"
METRICS_SERVER_VERSION="${METRICS_SERVER_VERSION:-v0.8.0}"
PAUSE_VERSION="${PAUSE_VERSION:-3.10}" 
ETCD_VERSION="${ETCD_VERSION:-v3.5.17}"

METALLB_VERSION="${METALLB_VERSION:-v0.14.9}"
ROOK_VERSION="${ROOK_VERSION:-v1.15.5}"
CEPH_VERSION="${CEPH_VERSION:-v19.2.0}"
PROM_STACK_VERSION="${PROM_STACK_VERSION:-v0.78.2}"
INGRESS_NGINX_VERSION="${INGRESS_NGINX_VERSION:-v1.12.0}"
CERT_MANAGER_VERSION="${CERT_MANAGER_VERSION:-v1.16.2}"
DASHBOARD_VERSION="${DASHBOARD_VERSION:-v2.7.0}"

OPENSTACK_VERSION="${OPENSTACK_VERSION:-2026.1}"
OPENSTACK_IMG_TAG="${OPENSTACK_IMG_TAG:-2026.1-ubuntu_noble}"
OSH_INFRA_MARIADB="${OSH_INFRA_MARIADB:-10.11}"
OSH_INFRA_RABBITMQ="${OSH_INFRA_RABBITMQ:-3.13}"
OSH_INFRA_MEMCACHED="${OSH_INFRA_MEMCACHED:-1.6}"

IMAGES=(
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
"docker.io/calico/cni:${CALICO_VERSION}"
"docker.io/calico/node:${CALICO_VERSION}"
"docker.io/calico/kube-controllers:${CALICO_VERSION}"
"docker.io/calico/pod2daemon-flexvol:${CALICO_VERSION}"
"docker.io/calico/typha:${CALICO_VERSION}"
"quay.io/metallb/controller:${METALLB_VERSION}"
"quay.io/metallb/speaker:${METALLB_VERSION}"
"docker.io/rook/ceph:${ROOK_VERSION}"
"quay.io/ceph/ceph:${CEPH_VERSION}"
"registry.k8s.io/sig-storage/csi-node-driver-registrar:v2.12.0"
"registry.k8s.io/sig-storage/csi-provisioner:v5.1.0"
"registry.k8s.io/sig-storage/csi-resizer:v1.12.0"
"registry.k8s.io/sig-storage/csi-snapshotter:v8.1.0"
"registry.k8s.io/sig-storage/csi-attacher:v4.7.0"
"quay.io/prometheus-operator/prometheus-operator:${PROM_STACK_VERSION}"
"quay.io/prometheus-operator/prometheus-config-reloader:${PROM_STACK_VERSION}"
"quay.io/prometheus/prometheus:v2.55.1"
"quay.io/prometheus/alertmanager:v0.27.0"
"quay.io/prometheus/node-exporter:v1.8.2"
"docker.io/grafana/grafana:11.3.1"
"registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.14.0"
"quay.io/brancz/kube-rbac-proxy:v0.18.1"
"registry.k8s.io/ingress-nginx/controller:${INGRESS_NGINX_VERSION}"
"registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.4.4"
"quay.io/jetstack/cert-manager-controller:${CERT_MANAGER_VERSION}"
"quay.io/jetstack/cert-manager-webhook:${CERT_MANAGER_VERSION}"
"quay.io/jetstack/cert-manager-cainjector:${CERT_MANAGER_VERSION}"
"quay.io/jetstack/cert-manager-startupapicheck:${CERT_MANAGER_VERSION}"
"docker.io/kubernetesui/dashboard:${DASHBOARD_VERSION}"
"docker.io/kubernetesui/metrics-scraper:v1.0.9"
"ghcr.io/k8snetworkplumbingwg/multus-cni:v4.1.0"
"docker.io/library/rabbitmq:${OSH_INFRA_RABBITMQ}-management"
"docker.io/library/memcached:${OSH_INFRA_MEMCACHED}"
"docker.io/fossbilling/fossbilling:latest"
"docker.io/library/mariadb:11"
"docker.io/library/nginx:1.27-alpine"
"docker.io/library/registry:2"
)

CHARTS=(
"metallb/metallb:0.14.9:https://github.io"
"rook-release/rook-ceph:v1.15.5:https://rook.io"
"rook-release/rook-ceph-cluster:v1.15.5:https://rook.io"
"prometheus-community/kube-prometheus-stack:65.5.1:https://github.io"
"ingress-nginx/ingress-nginx:4.12.0:https://github.io"
"jetstack/cert-manager:v1.16.2:https://jetstack.io"
"openstack-helm-infra/mariadb:2024.2.1:https://opendev.org"
"openstack-helm-infra/rabbitmq:2024.2.0:https://opendev.org"
"openstack-helm-infra/memcached:2024.2.6:https://opendev.org"
)

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

mkdir -p "${IMAGE_DIR}" "${CHART_DIR}" "${BIN_DIR}" "${PIP_DIR}" "${REPO_DIR}" "${KUBESPRAY_DOWNLOADS_DIR}"

echo "==> Auditing air-gapped container image target layers..."
for IMG in "${IMAGES[@]}"; do
  SAFE_NAME=$(echo "$IMG" | sed 's|[/:]|_|g')
  TARBALL="${IMAGE_DIR}/${SAFE_NAME}.tar"
  if [[ -f "$TARBALL" ]]; then continue; fi
  docker pull "$IMG" && docker save -o "$TARBALL" "$IMG"
done

HELM_BIN="${BIN_DIR}/helm"
if [[ ! -f "$HELM_BIN" ]]; then
  HELM_INSTALLER=$(mktemp)
  curl -fsSL https://githubusercontent.com -o "$HELM_INSTALLER"
  HELM_INSTALL_DIR="${BIN_DIR}" USE_SUDO=false bash "$HELM_INSTALLER"
  rm -f "$HELM_INSTALLER"
fi

for ENTRY in "${CHARTS[@]}"; do
  IFS=: read -r CHART VERSION REPO_URL <<< "$ENTRY"
  REPO_NAME="${CHART%%/*}"
  CHART_NAME="${CHART##*/}"
  TARBALL="${CHART_DIR}/${CHART_NAME}-${VERSION}.tgz"
  if [[ -f "$TARBALL" ]]; then continue; fi
  "${HELM_BIN}" repo add "${REPO_NAME}" "${REPO_URL}" --force-update 2>/dev/null || true
  "${HELM_BIN}" repo update "${REPO_NAME}" 2>/dev/null
  "${HELM_BIN}" pull "${CHART}" --version "${VERSION}" -d "${CHART_DIR}"
done

"${HELM_BIN}" repo add openstack-helm https://opendev.org --force-update 2>/dev/null || true
"${HELM_BIN}" repo update openstack-helm 2>/dev/null
for CHART in "${OSH_SERVICE_CHARTS[@]}"; do
  CHART_NAME="${CHART##*/}"
  if ls "${CHART_DIR}/${CHART_NAME}-"*.tgz 2>/dev/null | head -1 | grep -q .; then continue; fi
  "${HELM_BIN}" pull "${CHART}" -d "${CHART_DIR}" 2>&1
done

KUBESPRAY_DIR="${REPO_DIR}/kubespray"
if [[ ! -d "${KUBESPRAY_DIR}/.git" ]]; then
  git clone --depth 1 --branch "${KUBESPRAY_VERSION}" https://github.com "${KUBESPRAY_DIR}"
fi
ln -sfn "${KUBESPRAY_DIR}" "/opt/kubespray"

if [[ $(find "${PIP_DIR}" -type f | wc -l) -lt 10 ]]; then
  pip download -r "${KUBESPRAY_DIR}/requirements.txt" -d "${PIP_DIR}" 2>/dev/null || true
fi

echo "==> Auditing Kubespray core system runtime binaries..."
cd "${KUBESPRAY_DOWNLOADS_DIR}"
DOWNLOAD_ERRORS=0
set +e
##XXXX

echo "==> Dynamically parsing Kubespray framework schemas..."

# Use Ansible to read and compute Kubespray's dynamic Jinja expressions directly
echo "--> Computing version mappings (this may take a few seconds)..."


# Save your current script execution directory path
ORIGINAL_DIR=$(pwd)

# Move physically into Kubespray repo so Ansible loads roles/kubespray_defaults cleanly
cd "/opt/fabric-cache/repos/kubespray"

ANSIBLE_OUT=$(ansible localhost -m debug -a "msg='CONTAINERD_VER:{{ containerd_version }}|NERDCTL_VER:{{ nerdctl_version }}|CRICTL_VER:{{ crictl_version }}|RUNC_VER:{{ runc_version }}'" -e "kube_version=${KUBE_VERSION}" --connection=local)

# Return back to your script execution directory space
cd "${ORIGINAL_DIR}"

# Parse out the plain-text versions resolved by the Ansible runtime engine
CONTAINERD_VER=$(echo "${ANSIBLE_OUT}" | grep -oE "CONTAINERD_VER:[^\|]+" | awk -F':' '{print $2}' | sed 's/^v//' | tr -d '"'\'' ')
NERDCTL_VER=$(echo "${ANSIBLE_OUT}" | grep -oE "NERDCTL_VER:[^\|]+" | awk -F':' '{print $2}' | sed 's/^v//' | tr -d '"'\'' ')
CRICTL_VER=$(echo "${ANSIBLE_OUT}" | grep -oE "CRICTL_VER:[^\|]+" | awk -F':' '{print $2}' | tr -d '"'\'' ')
RUNC_VER=$(echo "${ANSIBLE_OUT}" | grep -oE "RUNC_VER:[^\|]+" | awk -F':' '{print $2}' | sed 's/^v//' | tr -d '"'\'' ')

# Ensure crictl has its required leading 'v'
[[ ! "${CRICTL_VER}" =~ ^v ]] && CRICTL_VER="v${CRICTL_VER}"


echo "--> Target Mappings Resolved Successfully:"
echo "    Kubernetes: ${KUBE_VERSION}"
echo "    Containerd: ${CONTAINERD_VER}"
echo "    Nerdctl:    ${NERDCTL_VER}"
echo "    Crictl:     ${CRICTL_VER}"
echo "    Runc:       ${RUNC_VER}"

# Define dynamic filenames
CONTAINERD_FILE="containerd-${CONTAINERD_VER}-linux-${ARCH}.tar.gz"
NERDCTL_FILE="nerdctl-${NERDCTL_VER}-linux-${ARCH}.tar.gz"
CRICTL_FILE="crictl-${CRICTL_VER}-linux-${ARCH}.tar.gz"
RUNC_FILE="runc-${RUNC_VER}.tar.xz"

# Ensure target staging downloads path is ready
KUBESPRAY_DOWNLOADS_DIR="${KUBESPRAY_DOWNLOADS_DIR:-/opt/fabric-cache}"
mkdir -p "${KUBESPRAY_DOWNLOADS_DIR}"
cd "${KUBESPRAY_DOWNLOADS_DIR}"

DOWNLOAD_ERRORS=0
set +e

# 1. Containerd Staging Execution
if [[ -f "${CONTAINERD_FILE}" ]]; then
    echo "  [cached] ${CONTAINERD_FILE}"
else
    echo "  [downloading] ${CONTAINERD_FILE}"
    wget -c "https://github.com{CONTAINERD_VER}/${CONTAINERD_FILE}"
    [[ $? -ne 0 ]] && DOWNLOAD_ERRORS=$((DOWNLOAD_ERRORS + 1))
fi

# 2. Nerdctl Staging Execution
if [[ -f "${NERDCTL_FILE}" ]]; then
    echo "  [cached] ${NERDCTL_FILE}"
else
    echo "  [downloading] ${NERDCTL_FILE}"
    wget -c "https://github.com{NERDCTL_VER}/${NERDCTL_FILE}"
    [[ $? -ne 0 ]] && DOWNLOAD_ERRORS=$((DOWNLOAD_ERRORS + 1))
fi

# 3. Crictl Staging Execution
if [[ -f "${CRICTL_FILE}" ]]; then
    echo "  [cached] ${CRICTL_FILE}"
else
    echo "  [downloading] ${CRICTL_FILE}"
    wget -c "https://github.com{CRICTL_VER}/${CRICTL_FILE}"
    [[ $? -ne 0 ]] && DOWNLOAD_ERRORS=$((DOWNLOAD_ERRORS + 1))
fi

# 4. Runc Staging Execution
if [[ -f "${RUNC_FILE}" ]]; then
    echo "  [cached] ${RUNC_FILE}"
else
    echo "  [downloading] ${RUNC_FILE}"
    wget -c "https://github.com{RUNC_VER}/${RUNC_FILE}"
    [[ $? -ne 0 ]] && DOWNLOAD_ERRORS=$((DOWNLOAD_ERRORS + 1))
fi

# 5. Calico KDD CRDs manifest — served flat at http://<mirror>:8080/${CALICO_CRDS_FILE}
CALICO_VER="${CALICO_VER:-3.29.2}"
CALICO_CRDS_FILE="calico-crds-${CALICO_VER}.yaml"
if [[ -f "${CALICO_CRDS_FILE}" ]]; then
    echo "  [cached] ${CALICO_CRDS_FILE}"
else
    echo "  [downloading] ${CALICO_CRDS_FILE}"
    wget -c -O "${CALICO_CRDS_FILE}" "https://github.com/projectcalico/calico/raw/v${CALICO_VER}/manifests/crds.yaml"
    [[ $? -ne 0 ]] && DOWNLOAD_ERRORS=$((DOWNLOAD_ERRORS + 1))
fi

set -e
CACHE_DIR="${CACHE_DIR:-/opt/fabric-cache}"


##XX
# # 1. Containerd binary mapping
# if [[ -f "containerd-2.3.0-linux-amd64.tar.gz" ]]; then
#   echo "  [cached] containerd-2.3.0-linux-amd64.tar.gz"
# else
#   echo "  [downloading] containerd-2.3.0-linux-amd64.tar.gz"
#   wget -c "https://github.com"
#   [[ $? -ne 0 ]] && DOWNLOAD_ERRORS=$((DOWNLOAD_ERRORS + 1))
# fi

# # 2. Nerdctl utility binary mapping
# if [[ -f "nerdctl-2.3.5-linux-amd64.tar.gz" ]]; then
#   echo "  [cached] nerdctl-2.3.5-linux-amd64.tar.gz"
# else
#   echo "  [downloading] nerdctl-2.3.5-linux-amd64.tar.gz"
#   wget -c "https://github.com"
#   [[ $? -ne 0 ]] && DOWNLOAD_ERRORS=$((DOWNLOAD_ERRORS + 1))
# fi

# # 3. Crictl management binary mapping
# if [[ -f "crictl-v1.36.0-linux-amd64.tar.gz" ]]; then
#   echo "  [cached] crictl-v1.36.0-linux-amd64.tar.gz"
# else
#   echo "  [downloading] crictl-v1.36.0-linux-amd64.tar.gz"
#   wget -c "https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.36.0/crictl-v1.36.0-linux-amd64.tar.gz"
#   [[ $? -ne 0 ]] && DOWNLOAD_ERRORS=$((DOWNLOAD_ERRORS + 1))
# fi

# # 4. Runc orchestration source tarball mapping
# if [[ -f "runc-1.5.1.tar.xz" ]]; then
#   echo "  [cached] runc-1.5.1.tar.xz"
# else
#   echo "  [downloading] runc-1.5.1.tar.xz"
#   wget -c "https://github.com"
#   [[ $? -ne 0 ]] && DOWNLOAD_ERRORS=$((DOWNLOAD_ERRORS + 1))
# fi

set -e
chmod -R a+rX "${CACHE_DIR}" || true
echo "=== Idempotent air-gapped system assets synchronized inside: ${CACHE_DIR} ==="

if [[ ${DOWNLOAD_ERRORS} -gt 0 ]]; then
  echo -e "\n\e[31m⚠ WARNING: ${DOWNLOAD_ERRORS} binary dependencies failed to download.\e[0m"
  exit 1
else
  echo -e "\n\e[32m✔ SUCCESS: All runtime binary assets successfully cached offline!\e[0m"
fi