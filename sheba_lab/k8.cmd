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


