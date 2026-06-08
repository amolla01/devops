You must run the destruction steps on every single host (nodes and control planes) that belongs to the cluster [3]:

However, you should NOT run the initialization command (kubeadm init) on every machine.
Here is the exact workflow to completely clean and rebuild your cluster across multiple hosts.


🧹 Step 1: Run on EVERY Host (Control Planes & Worker Nodes)

# Tear down running components
sudo kubeadm reset -f

# Purge configurations and state directories
sudo rm -rf /etc/kubernetes/
sudo rm -rf /var/lib/kubelet/
sudo rm -rf /var/lib/etcd/
sudo rm -rf /etc/cni/net.d/
sudo rm -rf $HOME/.kube/

# Flush the runtime interface
sudo systemctl restart containerd

🚀 Step 2: Run ONLY on the Main Control Plane (host12-1)
Once all hosts are completely wiped, pick your primary node (host12-1) and initialize the new cluster [1]:
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=172.16.2.40

📋 Save the Join Token!When the initialization completes successfully, 
the terminal will print out a kubeadm join command at the very bottom [1]. 
It will look something like this:

kubeadm join 172.16.2.40:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>

Copy this token string to a temporary notepad file. You will need it in Step 4.

🔑 Step 3: Run ONLY on the Control Plane to Enable kubectlTo use kubectl commands as your normal user account on host12-1,
  link up your new configuration profile:

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config


🛰️ Step 4: Run ONLY on the Worker Hosts (Your Node Pool)Log into your other worker nodes and paste 
the exact kubeadm join command string you saved from the output of Step 2:

sudo kubeadm join 172.16.2.40:6443 --token <YOUR_TOKEN> --discovery-token-ca-cert-hash sha256:<YOUR_HASH>

🌐 Step 5: Install your Network Plugin (CNI)Back on the main control plane (host12-1), 
your nodes will show up as NotReady until you add a cluster network driver. 
  Since we initialized the cluster with the --pod-network-cidr=10.244.0.0/16 flag, 
  Flannel is the easiest option to deploy:

kubectl apply -f https://github.com


# Apply MTU 1500 to enp1s0 on all three masters
sshpass -p 'amolla01' ssh ubuntu@172.16.2.40 "sudo ip link set dev enp1s0 mtu 1500" & \
sshpass -p 'amolla01' ssh ubuntu@172.16.2.43 "sudo ip link set dev enp1s0 mtu 1500" & \
sshpass -p 'amolla01' ssh ubuntu@172.16.2.45 "sudo ip link set dev enp1s0 mtu 1500"

# Clear out-of-sync cluster states completely
sshpass -p 'amolla01' ssh ubuntu@172.16.2.40 "sudo systemctl stop etcd; sudo rm -rf /var/lib/etcd/*" & \
sshpass -p 'amolla01' ssh ubuntu@172.16.2.43 "sudo systemctl stop etcd; sudo rm -rf /var/lib/etcd/*" & \
sshpass -p 'amolla01' ssh ubuntu@172.16.2.45 "sudo systemctl stop etcd; sudo rm -rf /var/lib/etcd/*"

sshpass -p 'amolla01' ssh ubuntu@172.16.2.40 "sudo systemctl start etcd" & \
sshpass -p 'amolla01' ssh ubuntu@172.16.2.43 "sudo systemctl start etcd" & \
sshpass -p 'amolla01' ssh ubuntu@172.16.2.45 "sudo systemctl start etcd" &

sudo cat << 'EOF' | sudo tee /etc/netplan/60-fabric-bgp.yaml
network:
  version: 2
  ethernets:
    enp1s0:
      addresses:
        - 172.16.2.42/24
      routes:
        - to: default
          via: 172.16.2.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 1.1.1.1
EOF


ubuntu@hostb12-1:~$ sudo ip link set enp1s0 up
ubuntu@hostb12-1:~$ sudo ip link set enp2s0 up
ubuntu@hostb12-1:~$ sudo ip link set enp3s0 up



(venv) nh1221@Lab-ControlNode:/opt/fabric-cache/kubespray/src$ ansible-playbook -i /opt/fabric-cache/kubespray/src/inventory/dc-lab/hosts.yml cluster.yml \
  --become --become-user=root \
  -e "ansible_user=ubuntu" \
  -e "ansible_ssh_pass=amolla01" \
  -e "ansible_become_pass=amolla01" \
  --timeout=180

ansible-playbook -i /opt/fabric-cache/kubespray/src/inventory/dc-lab/hosts.yml reset.yml \
  --become --become-user=root \
  -e "ansible_user=ubuntu" \
  -e "ansible_ssh_pass=amolla01" \
  -e "ansible_become_pass=amolla01" \
  -e "reset_confirmation=yes" \
  --timeout=180



