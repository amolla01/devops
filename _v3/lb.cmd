ALL profiles (ubuntu_r810_kvm, ubuntu_r620_kvm, real_hardware):
  → L3 CLOS fabric with BGP on every host
  → MetalLB uses BGP mode (always)
  → Service IPs announced as /32 routes into the fabric
  → Reachable from anywhere on the network via standard L3 routing
  → No L2/ARP, no NodePort hacks



    --- binaries/ ---
    total 492M
    -rw-r--r-- 1 root root  30M May 31 18:52 alertmanager-0.27.0.linux-amd64.tar.gz
    -rwxr-xr-x 1 root root 155M May 31 18:22 argocd-v2.11.3
    -rwxr-xr-x 1 root root 208K May 31 18:32 cephadm-18.2.2
    -rwxr-xr-x 1 1001  127  49M Apr 10  2024 helm
    -rw-r--r-- 1 root root  29M May 31 18:22 k9s-v0.32.4.tar.gz
    -rwxr-xr-x 1 root root  48M May 31 18:22 kubectl-v1.29.4
    -rw-r--r-- 1 root root  22M May 31 18:52 loki-3.0.0-linux-amd64.zip
    -rw-r--r-- 1 root root  11M May 31 18:52 node_exporter-1.8.1.linux-amd64.tar.gz
    -rw-r--r-- 1 root root  16M May 31 18:50 packer_1.10.3_linux_amd64.zip
    -rw-r--r-- 1 root root 100M May 31 18:52 prometheus-2.52.0.linux-amd64.tar.gz
    -rw-r--r-- 1 root root  27M May 31 18:53 promtail-3.0.0-linux-amd64.zip
    -rwxr-xr-x 1 root root 9.6M May 31 18:22 yq-v4.44.1

    --- images/ ---
    total 1.3G
    -rw-r--r-- 1 root root    0 May 31 18:22 cirros-0.6.2-x86_64-disk.img
    -rw-r--r-- 1 root root 663M May 31 18:33 ubuntu-22.04-server-cloudimg-amd64.img
    -rw-r--r-- 1 root root 599M May 31 18:50 ubuntu-24.04-server-cloudimg-amd64.img

    --- kubespray/ ---
    1.1G    /opt/fabric-cache/kubespray/

    --- helm-charts/ ---
    27 charts cached

    --- apt-packages/ ---
    14 .deb files cached

    --- pip-packages/ ---
    84 pip wheels cached

    Total cache size: 3.8G
stdout_lines: <omitted>

To diagnose on your lab node:

# Check if API server pod restarted around that time
kubectl get pods -n kube-system -l component=kube-apiserver -o wide
journalctl -u kubelet --since "22:26:00" --until "22:30:00" | grep -i "apiserver\|refused\|restart"

For right now on your lab, you can unblock manually with:
# Option A: Delete the stuck release secret (pods stay running)
kubectl delete secret -n metallb-system -l owner=helm,name=metallb,status=pending-install

# Then re-run the playbook — helm will adopt the existing resources
ansible-playbook playbooks/reused/deploy_metallb.yml -i inventory/hosts.yml -v

Or if you want a clean slate since pods are healthy:

