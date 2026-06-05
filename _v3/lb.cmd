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

# Option B: Just rollback to let helm recognize it as deployed
helm rollback metallb 0 -n metallb-system



1. Dashboard Access — Working!
MetalLB assigned IP 172.16.2.201. Access it at:

https://172.16.2.201:8443
Username: admin
Password: (get from secret below)

kubectl get secret rook-ceph-dashboard-password -n rook-ceph -o jsonpath='{.data.password}' | base64 -d; echo


ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ

From my windows 'Lab-ControlNode', I tried 'https://172.16.2.201:8443', times out no access...is there anything specific on routing 
to Windows-->wsl-->R810 --> Host12_1, I need to configure??

The MetalLB IP 172.16.2.201 is a BGP-announced /32 route that exists only inside the L3 fabric. Your Windows browser sits outside the fabric — it has no route to that IP.

Quick diagnosis from WSL:
# Can WSL reach the MetalLB IP?
curl -k https://172.16.2.201:8443 --connect-timeout 5

# Can WSL reach any K8s node directly?
ping -c1 172.16.2.40

# Check what route WSL has for that subnet
ip route get 172.16.2.201

Three options to access the dashboard:

Option 1: SSH Tunnel (quickest, no config changes)
From your WSL terminal:
ssh -L 8443:172.16.2.201:8443 nh1221@172.16.2.40 -N &
Then open in Windows browser: https://localhost:8443

Option 2: Static route on Windows (persistent access)
If your Windows machine can reach the R810 host IP (e.g., 172.16.2.40), add a route so Windows sends MetalLB traffic through it:


# Run as Administrator — replace GATEWAY with R810/node IP that's reachable from Windows
route add 172.16.2.200 mask 255.255.255.240 <GATEWAY_IP> -p

The gateway needs to be a host that IS in the BGP fabric and can forward traffic to the MetalLB IPs.

Option 3: kubectl port-forward (no routing needed at all)
From WSL:
kubectl port-forward svc/rook-ceph-mgr-dashboard -n rook-ceph 8443:8443 --address 0.0.0.0 &

Then from Windows: https://localhost:8443

Why it times out: Your Windows machine (and likely WSL) don't participate in BGP peering with the SONiC leaf switches.
The /32 route for 172.16.2.201 is only known to hosts that peer with the fabric. Unless your Lab-ControlNode runs FRR and peers with a leaf,
it won't know how to reach MetalLB IPs natively.

My recommendation: Option 1 (SSH tunnel) for now — zero infrastructure changes. For long-term, if this Windows box is your daily workstation, 
Option 2 with a static route pointing through one of the K8s nodes as a gateway.






