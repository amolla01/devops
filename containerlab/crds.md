# one-time, while the WSL laptop still has internet, OR copy it in by hand:
curl -fsSL https://github.com/projectcalico/calico/raw/v3.29.2/manifests/crds.yaml \
  -o /opt/fabric-cache/downloads/calico-crds-3.29.2.yaml
# verify nginx serves it:
curl -fsSI http://172.16.2.1:8080/calico-crds-3.29.2.yaml
