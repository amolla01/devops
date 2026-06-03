Problem Summary
Lens needs a kubeconfig file (typically at ~/.kube/config) to authenticate and connect to your Kubernetes cluster. Kubespray creates this file on the control plane nodes, but it's not in Lens's expected location on your Windows machine.

Solution: 4-Step Setup
Step 1: Get the kubeconfig from a K8s Control Node
SSH to one of your control plane nodes (Host12_1, Host34_1, or HostB12_1) and locate the kubeconfig:

# SSH to control node (e.g., Host12_1)
ssh -i <private-key> ubuntu@<Host12_1-IP>

# Verify kubeconfig location
cat /etc/kubernetes/admin.conf

# If it exists, get its content
cat /etc/kubernetes/admin.conf | head -20

Expected output: YAML file with:
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: https://<controller-IP>:6443
    ...

Step 2: Copy kubeconfig to Your Windows Machine
On Windows (Lab-ControlNode), create the .kube directory and copy the file:

# Create .kube directory if it doesn't exist
mkdir "C:\Users\nh1221\.kube" -Force

# Copy kubeconfig from control node (replace values)
scp -i <private-key> ubuntu@<Host12_1-IP>:/etc/kubernetes/admin.conf "C:\Users\nh1221\.kube\config"

Or use PSCp (PuTTY):

pscp.exe -i <putty-key> ubuntu@<Host12_1-IP>:/etc/kubernetes/admin.conf C:\Users\nh1221\.kube\config

Step 3: Verify the kubeconfig
Test connectivity from Windows using kubectl:

# Install kubectl if not already installed (via scoop or Chocolatey)
scoop install kubectl
# OR
choco install kubernetes-cli

# Test connection
kubectl --kubeconfig="C:\Users\nh1221\.kube\config" cluster-info
kubectl --kubeconfig="C:\Users\nh1221\.kube\config" get nodes

Expected output:

NAME       STATUS   ROLES                  AGE     VERSION
Host12_1   Ready    control-plane,master   XXd     v1.XX.X
Host12_2   Ready    <none>                 XXd     v1.XX.X
Host12_3   Ready    <none>                 XXd     v1.XX.X
Host34_1   Ready    control-plane,master   XXd     v1.XX.X
Host34_2   Ready    <none>                 XXd     v1.XX.X
HostB12_1  Ready    control-plane,master   XXd     v1.XX.X


Step 4: Configure Lens
Open Lens
Go to Catalog → Add Cluster
Choose Add Cluster from Kubeconfig
Select: C:\Users\nh1221\.kube\config
Lens should auto-discover your cluster and nodes
Troubleshooting
If Lens still doesn't connect:

# Check if kubeconfig syntax is valid
kubectl --kubeconfig="C:\Users\nh1221\.kube\config" config view

# Check cluster connectivity
kubectl --kubeconfig="C:\Users\nh1221\.kube\config" -n kube-system get pods

# Check RBAC permissions (admin context)
kubectl --kubeconfig="C:\Users\nh1221\.kube\config" auth can-i get pods --all-namespaces  
