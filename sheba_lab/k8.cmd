Why it may produce no files:

apt-get download only downloads the package itself, not its dependencies — if conntrack depends on libnetfilter-conntrack3, that dep won't be cached
The deployer's apt index is stale — apt-get download needs an up-to-date package index to resolve package names. If you haven't run sudo apt update on Lab-ControlNode recently, it may not find the packages
Architecture mismatch — Lab-ControlNode is likely the same arch (amd64) so this shouldn't be an issue
The || true swallows errors silently — you won't see failures
How to resolve — run this manually on Lab-ControlNode first:

# 1. Update apt index on the deployer (it HAS internet)
sudo apt update

# 2. Create the cache directory
sudo mkdir -p /opt/fabric-cache/apt-packages

# 3. Download packages WITH dependencies
cd /opt/fabric-cache/apt-packages
sudo apt-get download conntrack socat ipset ipvsadm lsb-release \
  apt-transport-https ca-certificates curl gnupg

# 4. Also grab dependencies (the key step most miss)
apt-cache depends --recurse --no-recommends --no-suggests \
  --no-conflicts --no-breaks --no-replaces --no-enhances \
  conntrack socat ipset ipvsadm | \
  grep "^\w" | sort -u | \
  xargs sudo apt-get download -o Dir::Cache::archives=/opt/fabric-cache/apt-packages/ 2>/dev/null || true

# 5. Verify what got downloaded
ls /opt/fabric-cache/apt-packages/*.deb | wc -l

The realistic shortcut — since Lab-ControlNode has internet and is the same Ubuntu version as the KVM hosts, just install the packages there and copy the cached debs:

# Install packages on deployer (they'll be in /var/cache/apt/archives/)
sudo apt install -y conntrack socat ipset ipvsadm

# Copy from apt cache to preflight cache
sudo mkdir -p /opt/fabric-cache/apt-packages
sudo cp /var/cache/apt/archives/{conntrack,socat,ipset,ipvsadm,libipset*,libnetfilter*}*.deb \
  /opt/fabric-cache/apt-packages/ 2>/dev/null || true

# Verify
ls /opt/fabric-cache/apt-packages/

^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

This is the same root cause documented in your repo memory. The fix is already known:

Problem: download_run_once: true with download_localhost: false means host12-1 is delegated to download images, 
but the -> localhost delegation is trying to use ctr on the deployer (Lab-ControlNode), which doesn't have containerd installed.

Immediate fix — install ctr on the deployer:

# On Lab-ControlNode (WSL):
cd /tmp
curl -fsSL https://github.com/containerd/containerd/releases/download/v1.7.16/containerd-1.7.16-linux-amd64.tar.gz | sudo tar -xz -C /usr/local
sudo ctr --version

This is the same containerd v1.7.16 that KubeSpray already downloaded and deployed to your nodes 
— you just need the ctr binary locally so the deployer can pull and cache images before distributing them.

Then re-run:

ansible-playbook -i inventory/hosts.yml playbooks/reused/deploy_kubespray.yml -v

KubeSpray is idempotent — it will skip all 360 completed tasks and resume at the calico_cni image pull.

Alternative (if you don't want containerd on the deployer): Update your all.yml to set download_localhost: false 
- so host12-1 itself pulls images directly rather than delegating to localhost. Based on your repo memory, this was already the intended production fix.
