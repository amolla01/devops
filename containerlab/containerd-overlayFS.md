TASK [kubernetes/control-plane : Kubeadm | Create kubeadm config] **************
changed: [k8s-master-02]
changed: [k8s-master-03]
changed: [k8s-master-01]
Tuesday 15 September 2026  08:43:36 -0500 (0:00:15.633)       2:49:24.208 *****
Tuesday 15 September 2026  08:43:36 -0500 (0:00:00.192)       2:49:24.400 *****
Tuesday 15 September 2026  08:43:36 -0500 (0:00:00.176)       2:49:24.577 *****
Tuesday 15 September 2026  08:43:36 -0500 (0:00:00.201)       2:49:24.778 *****
Tuesday 15 September 2026  08:43:40 -0500 (0:00:03.691)       2:49:28.470 *****
Tuesday 15 September 2026  08:43:44 -0500 (0:00:03.624)       2:49:32.095 *****
Tuesday 15 September 2026  08:43:44 -0500 (0:00:00.195)       2:49:32.291 *****
Tuesday 15 September 2026  08:43:44 -0500 (0:00:00.178)       2:49:32.470 *****

TASK [kubernetes/control-plane : Kubeadm | Initialize first control plane node (1st try)] ***
fatal: [k8s-master-01]: FAILED! => {"changed": true, "cmd": ["timeout", "-k", "300s", "300s", "/usr/local/bin/kubeadm", "init", "--config=/etc/kubernetes/kubeadm-config.yaml", "--ignore-preflight-errors=", "--skip-phases=addon/coredns", "--upload-certs"], "delta": "0:04:04.832709", "end": "2026-09-15 15:47:53.055159", "failed_when_result": true, "msg": "non-zero return code", "rc": 1, "start": "2026-09-15 15:43:48.222450", "stderr": "W0915 15:43:48.305578   55673 initconfiguration.go:361] [config] WARNING: Ignored configuration document with GroupVersionKind kubeadm.k8s.io/v1beta4, Kind=UpgradeConfiguration\nW0915 15:43:48.310255   55673 utils.go:69] The recommended value for \"clusterDNS\" in \"KubeletConfiguration\" is: [10.233.0.10]; the provided value is: [169.254.25.10]\nerror: error execution phase wait-control-plane: failed while waiting for the control plane to start: [kube-scheduler check failed at https://[::]:10259/livez: Get \"https://[::]:10259/livez\": dial tcp [::]:10259: connect: connection refused, kube-apiserver check failed at https://10.0.10.1:6443/livez: client rate limiter Wait returned an error: rate: Wait(n=1) would exceed context deadline, kube-controller-manager check failed at https://[::]:10257/healthz: Get \"https://[::]:10257/healthz\": dial tcp [::]:10257: connect: connection refused]\nTo see the stack trace of this error execute with --v=5 or higher", "stderr_lines": ["W0915 15:43:48.305578   55673 initconfiguration.go:361] [config] WARNING: Ignored configuration document with GroupVersionKind kubeadm.k8s.io/v1beta4, Kind=UpgradeConfiguration", "W0915 15:43:48.310255   55673 utils.go:69] The recommended value for \"clusterDNS\" in \"KubeletConfiguration\" is: [10.233.0.10]; the provided value is: [169.254.25.10]", "error: error execution phase wait-control-plane: failed while waiting for the control plane to start: [kube-scheduler check failed at https://[::]:10259/livez: Get \"https://[::]:10259/livez\": dial tcp [::]:10259: connect: connection refused, kube-apiserver check failed at https://10.0.10.1:6443/livez: client rate limiter Wait returned an error: rate: Wait(n=1) would exceed context deadline, kube-controller-manager check failed at https://[::]:10257/healthz: Get \"https://[::]:10257/healthz\": dial tcp [::]:10257: connect: connection refused]", "To see the stack trace of this error execute with --v=5 or higher"], "stdout": "[init] Using Kubernetes version: v1.35.4\n[preflight] Running pre-flight checks\n[preflight] Pulling images required for setting up a Kubernetes cluster\n[preflight] This might take a minute or two, depending on the speed of your internet connection\n[preflight] You can also perform this action beforehand using 'kubeadm config images pull'\n[certs] Using certificateDir folder \"/etc/kubernetes/ssl\"\n[certs] Generating \"ca\" certificate and key\n[certs] Generating \"apiserver\" certificate and key\n[certs] apiserver serving cert is signed for DNS names [k8s-master-01 k8s-master-01.cluster.local k8s-master-02 k8s-master-02.cluster.local k8s-master-03 k8s-master-03.cluster.local kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local localhost] and IPs [10.233.0.1 10.0.10.1 127.0.0.1 ::1 10.0.20.1 10.0.30.1 10.0.0.15 fe80::a8c1:abff:fe65:129c fe80::a8c1:abff:fe9c:1ca1 fe80::a8c1:abff:fee8:840b]\n[certs] Generating \"apiserver-kubelet-client\" certificate and key\n[certs] Generating \"front-proxy-ca\" certificate and key\n[certs] Generating \"front-proxy-client\" certificate and key\n[certs] External etcd mode: Skipping etcd/ca certificate authority generation\n[certs] External etcd mode: Skipping etcd/server certificate generation\n[certs] External etcd mode: Skipping etcd/peer certificate generation\n[certs] External etcd mode: Skipping etcd/healthcheck-client certificate generation\n[certs] External etcd mode: Skipping apiserver-etcd-client certificate generation\n[certs] Generating \"sa\" key and public key\n[kubeconfig] Using kubeconfig folder \"/etc/kubernetes\"\n[kubeconfig] Writing \"admin.conf\" kubeconfig file\n[kubeconfig] Writing \"super-admin.conf\" kubeconfig file\n[kubeconfig] Writing \"kubelet.conf\" kubeconfig file\n[kubeconfig] Writing \"controller-manager.conf\" kubeconfig file\n[kubeconfig] Writing \"scheduler.conf\" kubeconfig file\n[control-plane] Using manifest folder \"/etc/kubernetes/manifests\"\n[control-plane] Creating static Pod manifest for \"kube-apiserver\"\n[control-plane] Creating static Pod manifest for \"kube-controller-manager\"\n[control-plane] Creating static Pod manifest for \"kube-scheduler\"\n[kubelet-start] Writing kubelet environment file with flags to file \"/var/lib/kubelet/kubeadm-flags.env\"\n[kubelet-start] Writing kubelet configuration to file \"/var/lib/kubelet/instance-config.yaml\"\n[patches] Applied patch of type \"application/strategic-merge-patch+json\" to target \"kubeletconfiguration\"\n[kubelet-start] Writing kubelet configuration to file \"/var/lib/kubelet/config.yaml\"\n[kubelet-start] Starting the kubelet\n[wait-control-plane] Waiting for the kubelet to boot up the control plane as static Pods from directory \"/etc/kubernetes/manifests\"\n[kubelet-check] Waiting for a healthy kubelet at http://127.0.0.1:10248/healthz. This can take up to 4m0s\n[kubelet-check] The kubelet is healthy after 502.713958ms\n[control-plane-check] Waiting for healthy control plane components. This can take up to 4m0s\n[control-plane-check] Checking kube-apiserver at https://10.0.10.1:6443/livez\n[control-plane-check] Checking kube-controller-manager at https://[::]:10257/healthz\n[control-plane-check] Checking kube-scheduler at https://[::]:10259/livez\n[control-plane-check] kube-scheduler is not healthy after 4m0.000296749s\n[control-plane-check] kube-apiserver is not healthy after 4m0.000493868s\n[control-plane-check] kube-controller-manager is not healthy after 4m0.001774784s\n\nA control plane component may have crashed or exited when started by the container runtime.\nTo troubleshoot, list all containers using your preferred container runtimes CLI.\nHere is one example how you may list all running Kubernetes containers by using crictl:\n\t- 'crictl --runtime-endpoint unix:///var/run/containerd/containerd.sock ps -a | grep kube | grep -v pause'\n\tOnce you have found the failing container, you can inspect its logs with:\n\t- 'crictl --runtime-endpoint unix:///var/run/containerd/containerd.sock logs CONTAINERID'", "stdout_lines": ["[init] Using Kubernetes version: v1.35.4", "[preflight] Running pre-flight checks", "[preflight] Pulling images required for setting up a Kubernetes cluster", "[preflight] This might take a minute or two, depending on the speed of your internet connection", "[preflight] You can also perform this action beforehand using 'kubeadm config images pull'", "[certs] Using certificateDir folder \"/etc/kubernetes/ssl\"", "[certs] Generating \"ca\" certificate and key", "[certs] Generating \"apiserver\" certificate and key", "[certs] apiserver serving cert is signed for DNS names [k8s-master-01 k8s-master-01.cluster.local k8s-master-02 k8s-master-02.cluster.local k8s-master-03 k8s-master-03.cluster.local kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local localhost] and IPs [10.233.0.1 10.0.10.1 127.0.0.1 ::1 10.0.20.1 10.0.30.1 10.0.0.15 fe80::a8c1:abff:fe65:129c fe80::a8c1:abff:fe9c:1ca1 fe80::a8c1:abff:fee8:840b]", "[certs] Generating \"apiserver-kubelet-client\" certificate and key", "[certs] Generating \"front-proxy-ca\" certificate and key", "[certs] Generating \"front-proxy-client\" certificate and key", "[certs] External etcd mode: Skipping etcd/ca certificate authority generation", "[certs] External etcd mode: Skipping etcd/server certificate generation", "[certs] External etcd mode: Skipping etcd/peer certificate generation", "[certs] External etcd mode: Skipping etcd/healthcheck-client certificate generation", "[certs] External etcd mode: Skipping apiserver-etcd-client certificate generation", "[certs] Generating \"sa\" key and public key", "[kubeconfig] Using kubeconfig folder \"/etc/kubernetes\"", "[kubeconfig] Writing \"admin.conf\" kubeconfig file", "[kubeconfig] Writing \"super-admin.conf\" kubeconfig file", "[kubeconfig] Writing \"kubelet.conf\" kubeconfig file", "[kubeconfig] Writing \"controller-manager.conf\" kubeconfig file", "[kubeconfig] Writing \"scheduler.conf\" kubeconfig file", "[control-plane] Using manifest folder \"/etc/kubernetes/manifests\"", "[control-plane] Creating static Pod manifest for \"kube-apiserver\"", "[control-plane] Creating static Pod manifest for \"kube-controller-manager\"", "[control-plane] Creating static Pod manifest for \"kube-scheduler\"", "[kubelet-start] Writing kubelet environment file with flags to file \"/var/lib/kubelet/kubeadm-flags.env\"", "[kubelet-start] Writing kubelet configuration to file \"/var/lib/kubelet/instance-config.yaml\"", "[patches] Applied patch of type \"application/strategic-merge-patch+json\" to target \"kubeletconfiguration\"", "[kubelet-start] Writing kubelet configuration to file \"/var/lib/kubelet/config.yaml\"", "[kubelet-start] Starting the kubelet", "[wait-control-plane] Waiting for the kubelet to boot up the control plane as static Pods from directory \"/etc/kubernetes/manifests\"", "[kubelet-check] Waiting for a healthy kubelet at http://127.0.0.1:10248/healthz. This can take up to 4m0s", "[kubelet-check] The kubelet is healthy after 502.713958ms", "[control-plane-check] Waiting for healthy control plane components. This can take up to 4m0s", "[control-plane-check] Checking kube-apiserver at https://10.0.10.1:6443/livez", "[control-plane-check] Checking kube-controller-manager at https://[::]:10257/healthz", "[control-plane-check] Checking kube-scheduler at https://[::]:10259/livez", "[control-plane-check] kube-scheduler is not healthy after 4m0.000296749s", "[control-plane-check] kube-apiserver is not healthy after 4m0.000493868s", "[control-plane-check] kube-controller-manager is not healthy after 4m0.001774784s", "", "A control plane component may have crashed or exited when started by the container runtime.", "To troubleshoot, list all containers using your preferred container runtimes CLI.", "Here is one example how you may list all running Kubernetes containers by using crictl:", "\t- 'crictl --runtime-endpoint unix:///var/run/containerd/containerd.sock ps -a | grep kube | grep -v pause'", "\tOnce you have found the failing container, you can inspect its logs with:", "\t- 'crictl --runtime-endpoint unix:///var/run/containerd/containerd.sock logs CONTAINERID'"]}
Tuesday 15 September 2026  08:59:46 -0500 (0:16:02.278)       3:05:34.749 *****


NOTES:

ubuntu@k8s-master-01:~$ 
ubuntu@k8s-master-01:~$ 
ubuntu@k8s-master-01:~$ nc -zv 10.0.10.2 2379
Connection to 10.0.10.2 2379 port [tcp/*] succeeded!
ubuntu@k8s-master-01:~$ nc -zv 10.0.20.2 2379
Connection to 10.0.20.2 2379 port [tcp/*] succeeded!
ubuntu@k8s-master-01:~$ nc -zv 10.0.30.2 2379
Connection to 10.0.30.2 2379 port [tcp/*] succeeded!
ubuntu@k8s-master-01:~$ 
ubuntu@k8s-master-01:~$ 

ubuntu@k8s-master-01:~$ 
ubuntu@k8s-master-01:~$ 

ubuntu@k8s-master-01:~$ 
ubuntu@k8s-master-01:~$ 
ubuntu@k8s-master-01:~$ 
ubuntu@k8s-master-01:~$ 
ubuntu@k8s-master-01:~$ # 1. View all running and crashed static core containers
sudo crictl --runtime-endpoint unix:///var/run/containerd/containerd.sock ps -a | grep kube

# 2. Extract the last 50 error tracking lines from the crashed api-server
sudo crictl --runtime-endpoint unix:///var/run/containerd/containerd.sock logs $(sudo crictl --runtime-endpoint unix:///var/run/containerd/containerd.sock ps -a | grep kube-apiserver | awk '{print $1}')
FATA[0000] ID cannot be empty                           
ubuntu@k8s-master-01:~$ 
ubuntu@k8s-master-01:~$ 
ubuntu@k8s-master-01:~$ sudo crictl --runtime-endpoint unix:///var/run/containerd/containerd.sock ps -a
CONTAINER           IMAGE               CREATED             STATE               NAME                ATTEMPT             POD ID              POD                 NAMESPACE
ubuntu@k8s-master-01:~$ 
ubuntu@k8s-master-01:~$ 
ubuntu@k8s-master-01:~$ 
ubuntu@k8s-master-01:~$ sudo journalctl -xeu kubelet --no-pager | tail -n 50
Sep 15 16:13:46 k8s-master-01 kubelet[63249]: E0915 16:13:46.489569   63249 pod_workers.go:1324] "Error syncing pod, skipping" err="failed to \"CreatePodSandbox\" for \"kube-controller-manager-k8s-master-01_kube-system(b16ee36491c3feab12bc3156f80862f5)\" with CreatePodSandboxError: \"Failed to create sandbox for pod \\\"kube-controller-manager-k8s-master-01_kube-system(b16ee36491c3feab12bc3156f80862f5)\\\": rpc error: code = Unknown desc = failed to start sandbox \\\"944c04cd79441759bf6572b0edb8cca1af443f8dc3b9716c6faa5792c2fba5cb\\\": failed to create containerd task: failed to create shim task: failed to mount rootfs component: mount source: \\\"overlay\\\", target: \\\"/run/containerd/io.containerd.runtime.v2.task/k8s.io/944c04cd79441759bf6572b0edb8cca1af443f8dc3b9716c6faa5792c2fba5cb/rootfs\\\", fstype: overlay, flags: 0, data: \\\"workdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/449/work,upperdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/449/fs,lowerdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/7/fs,index=off\\\", err: invalid argument\"" pod="kube-system/kube-controller-manager-k8s-master-01" podUID="b16ee36491c3feab12bc3156f80862f5"
Sep 15 16:13:46 k8s-master-01 kubelet[63249]: I0915 16:13:46.696133   63249 csi_plugin.go:990] Failed to contact API server when waiting for CSINode publishing: Get "https://10.0.10.1:6443/apis/storage.k8s.io/v1/csinodes/k8s-master-01?resourceVersion=0": dial tcp 10.0.10.1:6443: connect: connection refused
Sep 15 16:13:47 k8s-master-01 kubelet[63249]: I0915 16:13:47.575477   63249 kubelet_node_status.go:343] "Setting node annotation to enable volume controller attach/detach"
Sep 15 16:13:47 k8s-master-01 kubelet[63249]: I0915 16:13:47.577430   63249 kubelet_node_status.go:633] "Recording event message for node" node="k8s-master-01" event="NodeHasSufficientMemory"
Sep 15 16:13:47 k8s-master-01 kubelet[63249]: I0915 16:13:47.577510   63249 kubelet_node_status.go:633] "Recording event message for node" node="k8s-master-01" event="NodeHasNoDiskPressure"
Sep 15 16:13:47 k8s-master-01 kubelet[63249]: I0915 16:13:47.577561   63249 kubelet_node_status.go:633] "Recording event message for node" node="k8s-master-01" event="NodeHasSufficientPID"
Sep 15 16:13:47 k8s-master-01 kubelet[63249]: I0915 16:13:47.577660   63249 kubelet_node_status.go:74] "Attempting to register node" node="k8s-master-01"
Sep 15 16:13:47 k8s-master-01 kubelet[63249]: E0915 16:13:47.578509   63249 kubelet_node_status.go:106] "Unable to register node with API server" err="Post \"https://10.0.10.1:6443/api/v1/nodes\": dial tcp 10.0.10.1:6443: connect: connection refused" node="k8s-master-01"
Sep 15 16:13:47 k8s-master-01 kubelet[63249]: I0915 16:13:47.696008   63249 csi_plugin.go:990] Failed to contact API server when waiting for CSINode publishing: Get "https://10.0.10.1:6443/apis/storage.k8s.io/v1/csinodes/k8s-master-01?resourceVersion=0": dial tcp 10.0.10.1:6443: connect: connection refused
Sep 15 16:13:48 k8s-master-01 kubelet[63249]: I0915 16:13:48.696158   63249 csi_plugin.go:990] Failed to contact API server when waiting for CSINode publishing: Get "https://10.0.10.1:6443/apis/storage.k8s.io/v1/csinodes/k8s-master-01?resourceVersion=0": dial tcp 10.0.10.1:6443: connect: connection refused
Sep 15 16:13:49 k8s-master-01 kubelet[63249]: I0915 16:13:49.698401   63249 csi_plugin.go:990] Failed to contact API server when waiting for CSINode publishing: Get "https://10.0.10.1:6443/apis/storage.k8s.io/v1/csinodes/k8s-master-01?resourceVersion=0": dial tcp 10.0.10.1:6443: connect: connection refused
Sep 15 16:13:50 k8s-master-01 kubelet[63249]: I0915 16:13:50.696499   63249 csi_plugin.go:990] Failed to contact API server when waiting for CSINode publishing: Get "https://10.0.10.1:6443/apis/storage.k8s.io/v1/csinodes/k8s-master-01?resourceVersion=0": dial tcp 10.0.10.1:6443: connect: connection refused
Sep 15 16:13:51 k8s-master-01 kubelet[63249]: I0915 16:13:51.695406   63249 csi_plugin.go:990] Failed to contact API server when waiting for CSINode publishing: Get "https://10.0.10.1:6443/apis/storage.k8s.io/v1/csinodes/k8s-master-01?resourceVersion=0": dial tcp 10.0.10.1:6443: connect: connection refused
Sep 15 16:13:52 k8s-master-01 kubelet[63249]: E0915 16:13:52.552164   63249 controller.go:201] "Failed to ensure lease exists, will retry" err="Get \"https://10.0.10.1:6443/apis/coordination.k8s.io/v1/namespaces/kube-node-lease/leases/k8s-master-01?timeout=10s\": dial tcp 10.0.10.1:6443: connect: connection refused" interval="7s"
Sep 15 16:13:52 k8s-master-01 kubelet[63249]: I0915 16:13:52.696617   63249 csi_plugin.go:990] Failed to contact API server when waiting for CSINode publishing: Get "https://10.0.10.1:6443/apis/storage.k8s.io/v1/csinodes/k8s-master-01?resourceVersion=0": dial tcp 10.0.10.1:6443: connect: connection refused
Sep 15 16:13:53 k8s-master-01 kubelet[63249]: I0915 16:13:53.696105   63249 csi_plugin.go:990] Failed to contact API server when waiting for CSINode publishing: Get "https://10.0.10.1:6443/apis/storage.k8s.io/v1/csinodes/k8s-master-01?resourceVersion=0": dial tcp 10.0.10.1:6443: connect: connection refused
Sep 15 16:13:53 k8s-master-01 kubelet[63249]: E0915 16:13:53.889875   63249 eviction_manager.go:297] "Eviction manager: failed to get summary stats" err="failed to get node info: node \"k8s-master-01\" not found"
Sep 15 16:13:54 k8s-master-01 kubelet[63249]: I0915 16:13:54.579486   63249 kubelet_node_status.go:343] "Setting node annotation to enable volume controller attach/detach"
Sep 15 16:13:54 k8s-master-01 kubelet[63249]: I0915 16:13:54.581249   63249 kubelet_node_status.go:633] "Recording event message for node" node="k8s-master-01" event="NodeHasSufficientMemory"
Sep 15 16:13:54 k8s-master-01 kubelet[63249]: I0915 16:13:54.581338   63249 kubelet_node_status.go:633] "Recording event message for node" node="k8s-master-01" event="NodeHasNoDiskPressure"
Sep 15 16:13:54 k8s-master-01 kubelet[63249]: I0915 16:13:54.581376   63249 kubelet_node_status.go:633] "Recording event message for node" node="k8s-master-01" event="NodeHasSufficientPID"
Sep 15 16:13:54 k8s-master-01 kubelet[63249]: I0915 16:13:54.581466   63249 kubelet_node_status.go:74] "Attempting to register node" node="k8s-master-01"
Sep 15 16:13:54 k8s-master-01 kubelet[63249]: E0915 16:13:54.582304   63249 kubelet_node_status.go:106] "Unable to register node with API server" err="Post \"https://10.0.10.1:6443/api/v1/nodes\": dial tcp 10.0.10.1:6443: connect: connection refused" node="k8s-master-01"
Sep 15 16:13:54 k8s-master-01 kubelet[63249]: I0915 16:13:54.696133   63249 csi_plugin.go:990] Failed to contact API server when waiting for CSINode publishing: Get "https://10.0.10.1:6443/apis/storage.k8s.io/v1/csinodes/k8s-master-01?resourceVersion=0": dial tcp 10.0.10.1:6443: connect: connection refused
Sep 15 16:13:55 k8s-master-01 kubelet[63249]: E0915 16:13:55.033574   63249 event.go:368] "Unable to write event (may retry after sleeping)" err="Patch \"https://10.0.10.1:6443/api/v1/namespaces/default/events/k8s-master-01.18d5834d063e1b13\": dial tcp 10.0.10.1:6443: connect: connection refused" event="&Event{ObjectMeta:{k8s-master-01.18d5834d063e1b13  default    0 0001-01-01 00:00:00 +0000 UTC <nil> <nil> map[] map[] [] [] []},InvolvedObject:ObjectReference{Kind:Node,Namespace:,Name:k8s-master-01,UID:,APIVersion:v1,ResourceVersion:,FieldPath:,},Reason:NodeHasSufficientPID,Message:Node k8s-master-01 status is now: NodeHasSufficientPID,Source:EventSource{Component:kubelet,Host:k8s-master-01,},FirstTimestamp:2026-09-15 15:59:53.790094099 +0200 CEST m=+0.241234733,LastTimestamp:2026-09-15 15:59:53.797902093 +0200 CEST m=+0.249042746,Count:2,Type:Normal,EventTime:0001-01-01 00:00:00 +0000 UTC,Series:nil,Action:,Related:nil,ReportingController:kubelet,ReportingInstance:k8s-master-01,}"
Sep 15 16:13:55 k8s-master-01 kubelet[63249]: I0915 16:13:55.696308   63249 csi_plugin.go:990] Failed to contact API server when waiting for CSINode publishing: Get "https://10.0.10.1:6443/apis/storage.k8s.io/v1/csinodes/k8s-master-01?resourceVersion=0": dial tcp 10.0.10.1:6443: connect: connection refused
Sep 15 16:13:56 k8s-master-01 kubelet[63249]: I0915 16:13:55.746728   63249 util.go:34] "No sandbox for pod can be found. Need to start a new one" pod="kube-system/kube-scheduler-k8s-master-01"
Sep 15 16:13:56 k8s-master-01 kubelet[63249]: I0915 16:13:55.746868   63249 kubelet_node_status.go:343] "Setting node annotation to enable volume controller attach/detach"
Sep 15 16:13:56 k8s-master-01 kubelet[63249]: I0915 16:13:55.750466   63249 kubelet_node_status.go:633] "Recording event message for node" node="k8s-master-01" event="NodeHasSufficientMemory"
Sep 15 16:13:56 k8s-master-01 kubelet[63249]: I0915 16:13:55.750521   63249 kubelet_node_status.go:633] "Recording event message for node" node="k8s-master-01" event="NodeHasNoDiskPressure"
Sep 15 16:13:56 k8s-master-01 kubelet[63249]: I0915 16:13:55.750569   63249 kubelet_node_status.go:633] "Recording event message for node" node="k8s-master-01" event="NodeHasSufficientPID"
Sep 15 16:13:56 k8s-master-01 kubelet[63249]: I0915 16:13:55.755315   63249 util.go:34] "No sandbox for pod can be found. Need to start a new one" pod="kube-system/kube-apiserver-k8s-master-01"
Sep 15 16:13:56 k8s-master-01 kubelet[63249]: I0915 16:13:55.756307   63249 kubelet_node_status.go:343] "Setting node annotation to enable volume controller attach/detach"
Sep 15 16:13:56 k8s-master-01 kubelet[63249]: I0915 16:13:55.772989   63249 kubelet_node_status.go:633] "Recording event message for node" node="k8s-master-01" event="NodeHasSufficientMemory"
Sep 15 16:13:56 k8s-master-01 kubelet[63249]: I0915 16:13:55.773060   63249 kubelet_node_status.go:633] "Recording event message for node" node="k8s-master-01" event="NodeHasNoDiskPressure"
Sep 15 16:13:56 k8s-master-01 kubelet[63249]: I0915 16:13:55.773097   63249 kubelet_node_status.go:633] "Recording event message for node" node="k8s-master-01" event="NodeHasSufficientPID"
Sep 15 16:13:56 k8s-master-01 kubelet[63249]: E0915 16:13:55.785129   63249 kubelet.go:3344] "No need to create a mirror pod, since failed to get node info from the cluster" err="node \"k8s-master-01\" not found" node="k8s-master-01"
Sep 15 16:13:56 k8s-master-01 kubelet[63249]: I0915 16:13:55.785293   63249 util.go:34] "No sandbox for pod can be found. Need to start a new one" pod="kube-system/kube-scheduler-k8s-master-01"
Sep 15 16:13:56 k8s-master-01 kubelet[63249]: E0915 16:13:55.800929   63249 kubelet.go:3344] "No need to create a mirror pod, since failed to get node info from the cluster" err="node \"k8s-master-01\" not found" node="k8s-master-01"
Sep 15 16:13:56 k8s-master-01 kubelet[63249]: I0915 16:13:55.801046   63249 util.go:34] "No sandbox for pod can be found. Need to start a new one" pod="kube-system/kube-apiserver-k8s-master-01"
Sep 15 16:13:56 k8s-master-01 kubelet[63249]: E0915 16:13:56.479333   63249 log.go:32] "RunPodSandbox from runtime service failed" err="rpc error: code = Unknown desc = failed to start sandbox \"4f38b85717ed70d13927a956da02f42e8f31d224513d5b8def2c67fb735959e9\": failed to create containerd task: failed to create shim task: failed to mount rootfs component: mount source: \"overlay\", target: \"/run/containerd/io.containerd.runtime.v2.task/k8s.io/4f38b85717ed70d13927a956da02f42e8f31d224513d5b8def2c67fb735959e9/rootfs\", fstype: overlay, flags: 0, data: \"workdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/450/work,upperdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/450/fs,lowerdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/7/fs,index=off\", err: invalid argument"
Sep 15 16:13:56 k8s-master-01 kubelet[63249]: E0915 16:13:56.479500   63249 kuberuntime_sandbox.go:71] "Failed to create sandbox for pod" err="rpc error: code = Unknown desc = failed to start sandbox \"4f38b85717ed70d13927a956da02f42e8f31d224513d5b8def2c67fb735959e9\": failed to create containerd task: failed to create shim task: failed to mount rootfs component: mount source: \"overlay\", target: \"/run/containerd/io.containerd.runtime.v2.task/k8s.io/4f38b85717ed70d13927a956da02f42e8f31d224513d5b8def2c67fb735959e9/rootfs\", fstype: overlay, flags: 0, data: \"workdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/450/work,upperdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/450/fs,lowerdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/7/fs,index=off\", err: invalid argument" pod="kube-system/kube-scheduler-k8s-master-01"
Sep 15 16:13:56 k8s-master-01 kubelet[63249]: E0915 16:13:56.479572   63249 kuberuntime_manager.go:1558] "CreatePodSandbox for pod failed" err="rpc error: code = Unknown desc = failed to start sandbox \"4f38b85717ed70d13927a956da02f42e8f31d224513d5b8def2c67fb735959e9\": failed to create containerd task: failed to create shim task: failed to mount rootfs component: mount source: \"overlay\", target: \"/run/containerd/io.containerd.runtime.v2.task/k8s.io/4f38b85717ed70d13927a956da02f42e8f31d224513d5b8def2c67fb735959e9/rootfs\", fstype: overlay, flags: 0, data: \"workdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/450/work,upperdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/450/fs,lowerdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/7/fs,index=off\", err: invalid argument" pod="kube-system/kube-scheduler-k8s-master-01"
Sep 15 16:13:56 k8s-master-01 kubelet[63249]: E0915 16:13:56.479740   63249 pod_workers.go:1324] "Error syncing pod, skipping" err="failed to \"CreatePodSandbox\" for \"kube-scheduler-k8s-master-01_kube-system(812591c0e1f630ca4c772c61428230e0)\" with CreatePodSandboxError: \"Failed to create sandbox for pod \\\"kube-scheduler-k8s-master-01_kube-system(812591c0e1f630ca4c772c61428230e0)\\\": rpc error: code = Unknown desc = failed to start sandbox \\\"4f38b85717ed70d13927a956da02f42e8f31d224513d5b8def2c67fb735959e9\\\": failed to create containerd task: failed to create shim task: failed to mount rootfs component: mount source: \\\"overlay\\\", target: \\\"/run/containerd/io.containerd.runtime.v2.task/k8s.io/4f38b85717ed70d13927a956da02f42e8f31d224513d5b8def2c67fb735959e9/rootfs\\\", fstype: overlay, flags: 0, data: \\\"workdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/450/work,upperdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/450/fs,lowerdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/7/fs,index=off\\\", err: invalid argument\"" pod="kube-system/kube-scheduler-k8s-master-01" podUID="812591c0e1f630ca4c772c61428230e0"
Sep 15 16:13:56 k8s-master-01 kubelet[63249]: E0915 16:13:56.498708   63249 log.go:32] "RunPodSandbox from runtime service failed" err="rpc error: code = Unknown desc = failed to start sandbox \"3b280e8899830562562e9559779b9a91490b15b879ba6e2ee6ddaef01ef68547\": failed to create containerd task: failed to create shim task: failed to mount rootfs component: mount source: \"overlay\", target: \"/run/containerd/io.containerd.runtime.v2.task/k8s.io/3b280e8899830562562e9559779b9a91490b15b879ba6e2ee6ddaef01ef68547/rootfs\", fstype: overlay, flags: 0, data: \"workdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/451/work,upperdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/451/fs,lowerdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/7/fs,index=off\", err: invalid argument"
Sep 15 16:13:56 k8s-master-01 kubelet[63249]: E0915 16:13:56.498814   63249 kuberuntime_sandbox.go:71] "Failed to create sandbox for pod" err="rpc error: code = Unknown desc = failed to start sandbox \"3b280e8899830562562e9559779b9a91490b15b879ba6e2ee6ddaef01ef68547\": failed to create containerd task: failed to create shim task: failed to mount rootfs component: mount source: \"overlay\", target: \"/run/containerd/io.containerd.runtime.v2.task/k8s.io/3b280e8899830562562e9559779b9a91490b15b879ba6e2ee6ddaef01ef68547/rootfs\", fstype: overlay, flags: 0, data: \"workdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/451/work,upperdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/451/fs,lowerdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/7/fs,index=off\", err: invalid argument" pod="kube-system/kube-apiserver-k8s-master-01"
Sep 15 16:13:56 k8s-master-01 kubelet[63249]: E0915 16:13:56.498865   63249 kuberuntime_manager.go:1558] "CreatePodSandbox for pod failed" err="rpc error: code = Unknown desc = failed to start sandbox \"3b280e8899830562562e9559779b9a91490b15b879ba6e2ee6ddaef01ef68547\": failed to create containerd task: failed to create shim task: failed to mount rootfs component: mount source: \"overlay\", target: \"/run/containerd/io.containerd.runtime.v2.task/k8s.io/3b280e8899830562562e9559779b9a91490b15b879ba6e2ee6ddaef01ef68547/rootfs\", fstype: overlay, flags: 0, data: \"workdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/451/work,upperdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/451/fs,lowerdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/7/fs,index=off\", err: invalid argument" pod="kube-system/kube-apiserver-k8s-master-01"
Sep 15 16:13:56 k8s-master-01 kubelet[63249]: E0915 16:13:56.499004   63249 pod_workers.go:1324] "Error syncing pod, skipping" err="failed to \"CreatePodSandbox\" for \"kube-apiserver-k8s-master-01_kube-system(2b3b4f82223a5ae2289d2274f1e7b559)\" with CreatePodSandboxError: \"Failed to create sandbox for pod \\\"kube-apiserver-k8s-master-01_kube-system(2b3b4f82223a5ae2289d2274f1e7b559)\\\": rpc error: code = Unknown desc = failed to start sandbox \\\"3b280e8899830562562e9559779b9a91490b15b879ba6e2ee6ddaef01ef68547\\\": failed to create containerd task: failed to create shim task: failed to mount rootfs component: mount source: \\\"overlay\\\", target: \\\"/run/containerd/io.containerd.runtime.v2.task/k8s.io/3b280e8899830562562e9559779b9a91490b15b879ba6e2ee6ddaef01ef68547/rootfs\\\", fstype: overlay, flags: 0, data: \\\"workdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/451/work,upperdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/451/fs,lowerdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/7/fs,index=off\\\", err: invalid argument\"" pod="kube-system/kube-apiserver-k8s-master-01" podUID="2b3b4f82223a5ae2289d2274f1e7b559"
Sep 15 16:13:56 k8s-master-01 kubelet[63249]: I0915 16:13:56.696057   63249 csi_plugin.go:990] Failed to contact API server when waiting for CSINode publishing: Get "https://10.0.10.1:6443/apis/storage.k8s.io/v1/csinodes/k8s-master-01?resourceVersion=0": dial tcp 10.0.10.1:6443: connect: connection refused
Sep 15 16:13:56 k8s-master-01 kubelet[63249]: I0915 16:13:56.696837   63249 reflector.go:724] "watch-list failed - backing off" reflector="k8s.io/client-go/informers/factory.go:161" type="*v1.CSIDriver" err="Get \"https://10.0.10.1:6443/apis/storage.k8s.io/v1/csidrivers?allowWatchBookmarks=true&resourceVersionMatch=NotOlderThan&sendInitialEvents=true&timeout=9m59s&timeoutSeconds=599&watch=true\": dial tcp 10.0.10.1:6443: connect: connection refused"
ubuntu@k8s-master-01:~$ 
ubuntu@k8s-master-01:~$ 
ubuntu@k8s-master-01:~$ 
ubuntu@k8s-master-01:~$ mount
tmpfs on /run type tmpfs (rw,nosuid,nodev,size=800916k,nr_inodes=819200,mode=755,inode64)
/dev/sda1 on /run/rootfsbase type ext4 (ro,relatime)
/dev/vda on /run/overlayfs-backing type ext4 (rw,relatime)
LiveOS_rootfs on / type overlay (rw,relatime,lowerdir=/run/rootfsbase,upperdir=/run/overlayfs,workdir=/run/ovlwork,uuid=on,nouserxattr)
devtmpfs on /dev type devtmpfs (rw,nosuid,size=1565608k,nr_inodes=391402,mode=755,inode64)
tmpfs on /dev/shm type tmpfs (rw,nosuid,nodev,inode64,usrquota)
devpts on /dev/pts type devpts (rw,nosuid,noexec,relatime,gid=5,mode=600,ptmxmode=000)
sysfs on /sys type sysfs (rw,nosuid,nodev,noexec,relatime)
securityfs on /sys/kernel/security type securityfs (rw,nosuid,nodev,noexec,relatime)
cgroup2 on /sys/fs/cgroup type cgroup2 (rw,nosuid,nodev,noexec,relatime,nsdelegate,memory_recursiveprot,memory_hugetlb_accounting)
none on /sys/fs/pstore type pstore (rw,nosuid,nodev,noexec,relatime)
bpf on /sys/fs/bpf type bpf (rw,nosuid,nodev,noexec,relatime,mode=700)
configfs on /sys/kernel/config type configfs (rw,nosuid,nodev,noexec,relatime)
proc on /proc type proc (rw,nosuid,nodev,noexec,relatime)
systemd-1 on /proc/sys/fs/binfmt_misc type autofs (rw,relatime,fd=35,pgrp=1,timeout=0,minproto=5,maxproto=5,direct,pipe_ino=7171)
debugfs on /sys/kernel/debug type debugfs (rw,nosuid,nodev,noexec,relatime)
hugetlbfs on /dev/hugepages type hugetlbfs (rw,nosuid,nodev,relatime,pagesize=2M)
mqueue on /dev/mqueue type mqueue (rw,nosuid,nodev,noexec,relatime)
tracefs on /sys/kernel/tracing type tracefs (rw,nosuid,nodev,noexec,relatime)
tmpfs on /tmp type tmpfs (rw,nosuid,nodev,nr_inodes=1048576,inode64,usrquota)
none on /run/credentials/systemd-journald.service type tmpfs (ro,nosuid,nodev,noexec,relatime,nosymfollow,size=1024k,nr_inodes=1024,mode=700,inode64,noswap)
fusectl on /sys/fs/fuse/connections type fusectl (rw,nosuid,nodev,noexec,relatime)
/dev/sda13 on /boot type ext4 (rw,relatime)
/dev/sda15 on /boot/efi type vfat (rw,relatime,fmask=0077,dmask=0077,codepage=437,iocharset=iso8859-1,shortname=mixed,errors=remount-ro)
binfmt_misc on /proc/sys/fs/binfmt_misc type binfmt_misc (rw,nosuid,nodev,noexec,relatime)
none on /run/credentials/systemd-networkd.service type tmpfs (ro,nosuid,nodev,noexec,relatime,nosymfollow,size=1024k,nr_inodes=1024,mode=700,inode64,noswap)
none on /run/credentials/getty@tty1.service type tmpfs (ro,nosuid,nodev,noexec,relatime,nosymfollow,size=1024k,nr_inodes=1024,mode=700,inode64,noswap)
none on /run/credentials/serial-getty@ttyS0.service type tmpfs (ro,nosuid,nodev,noexec,relatime,nosymfollow,size=1024k,nr_inodes=1024,mode=700,inode64,noswap)
none on /run/credentials/systemd-resolved.service type tmpfs (ro,nosuid,nodev,noexec,relatime,nosymfollow,size=1024k,nr_inodes=1024,mode=700,inode64,noswap)
tmpfs on /run/user/1000 type tmpfs (rw,nosuid,nodev,relatime,size=400456k,nr_inodes=100114,mode=700,uid=1000,gid=1000,inode64)
ubuntu@k8s-master-01:~$ 
ubuntu@k8s-master-01:~$ 
ubuntu@k8s-master-01:~$ 
ubuntu@k8s-master-01:~$ 
ubuntu@k8s-master-01:~$ 
ubuntu@k8s-master-01:~$ sudo vi /etc/containerd/config.toml
ubuntu@k8s-master-01:~$ sudo cat /etc/containerd/config.toml
version = 3

root = "/var/lib/containerd"
state = "/run/containerd"
oom_score = 0



[grpc]
  max_recv_message_size = 16777216
  max_send_message_size = 16777216

[debug]
  address = ""
  level = "info"
  format = ""
  uid = 0
  gid = 0

[metrics]
  address = ""
  grpc_histogram = false

[plugins]
  [plugins."io.containerd.cri.v1.runtime"]
    max_container_log_line_size = 16384
    enable_unprivileged_ports = false
    enable_unprivileged_icmp = false
    enable_selinux = false
    disable_apparmor = false
    tolerate_missing_hugetlb_controller = true
    disable_hugetlb_controller = true

   [plugins."io.containerd.cri.v1.runtime".containerd]
     default_runtime_name = "runc"
     [plugins."io.containerd.cri.v1.runtime".containerd.runtimes]
       [plugins."io.containerd.cri.v1.runtime".containerd.runtimes.runc]
         runtime_type = "io.containerd.runc.v2"
         base_runtime_spec = "/etc/containerd/cri-base.json"

         [plugins."io.containerd.cri.v1.runtime".containerd.runtimes.runc.options]
           Root = ""
           SystemdCgroup = true
           BinaryName = "/usr/local/bin/runc"

  [plugins."io.containerd.cri.v1.images"]
    snapshotter = "overlayfs"
    image_pull_progress_timeout = "5m"
  [plugins."io.containerd.cri.v1.images".pinned_images]
    sandbox = "172.16.2.1:5000/pause:3.10.1"
  [plugins."io.containerd.cri.v1.images".registry]
    config_path = "/etc/containerd/certs.d"

  [plugins."io.containerd.nri.v1.nri"]
    disable = false

ubuntu@k8s-master-01:~$ 

NOTES:
The journal logs have revealed the exact low-level filesystem driver error causing the bootstrap process to crash.
Look at the very first line of your log output:

failed to mount rootfs component: mount source: "overlay", target: ... err: invalid argument

## 🔍 The Root Cause Analysis
Your k8s-master-01 virtual machine is running an absolute bleeding-edge Linux kernel version 7.0.0-28-generic (as seen in your SSH login banner).
In modern 6.x and 7.x kernels, the Linux Storage subsystem changed how it enforces parameters for the OverlayFS snapshotter engine. The version of containerd deployed by your playbook is attempting to mount container layers using an outdated flag format (index=off), which the new v7.0 kernel strictly rejects as an invalid argument. Because containerd cannot mount the filesystem root for the Pod sandboxes, no containers can be born, leading to the connection refused API server loops.
------------------------------
## The Definitive Solution: Fix the Containerd Snapshotter
To fix this filesystem mounting error, you must modify containerd's configuration inside k8s-master-01 to use the standardized, updated overlay parameters.
Execute these commands inside your k8s-master-01 terminal console:
## Step 1: Update the containerd Configuration File

   1. Open the core configuration layout file:
   
   sudo vi /etc/containerd/config.toml
   
   2. Search for the [plugins."io.containerd.snapshotter.v1.overlayfs"] configuration block.
   3. If it does not exist, or inside it, locate or add the line to disable the deprecated index verification parameters completely. Change the block to look exactly like this:
   
   [plugins."io.containerd.snapshotter.v1.overlayfs"]
     mount_options = []
   
   (Ensure any legacy strings like index=off are completely removed from the mount_options array).

## Step 2: Alternative Fix (If the parameter above is missing)
If your config.toml was automatically generated by Kubespray and is heavily abstracted, you can explicitly force containerd to fall back on a cleaner execution driver by executing a fresh configuration generation string:

# Backup old config
sudo mv /etc/containerd/config.toml /etc/containerd/config.toml.bak
# Generate a fresh config matching your kernel specs
sudo containerd config default | sudo tee /etc/containerd/config.toml

------------------------------
## Step 3: Flush and Restart the Services
Once the configuration is modified, flush the corrupted container memory space from the host disk and restart the services to rebuild the mount paths:

# Clear out partial, corrupted container sandbox mount links
sudo rm -rf /var/lib/containerd/io.containerd.runtime.v2.task/k8s.io/*
# Restart the runtimes
sudo systemctl restart containerd
sudo systemctl restart kubelet

------------------------------
## Step 4: Resume Verification
Give it 15 seconds to sync with the disk, then run your local runtime inspection tool again:

sudo crictl --runtime-endpoint unix:///var/run/containerd/containerd.sock ps -a

The container instances (kube-apiserver, kube-scheduler, etc.) will immediately clear the CreatePodSandboxError mount barrier, transition into an active Running state, and automatically open up port 6443 for your cluster architecture.
Once you update the containerd overlayfs settings and restart the services, does crictl ps finally print out your active running control plane containers?


The journal logs have revealed the exact low-level filesystem driver error causing the bootstrap process to crash.
Look at the very first line of your log output:

failed to mount rootfs component: mount source: "overlay", target: ... err: invalid argument

## 🔍 The Root Cause Analysis
Your k8s-master-01 virtual machine is running an absolute bleeding-edge Linux kernel version 7.0.0-28-generic (as seen in your SSH login banner).
In modern 6.x and 7.x kernels, the Linux Storage subsystem changed how it enforces parameters for the OverlayFS snapshotter engine. The version of containerd deployed by your playbook is attempting to mount container layers using an outdated flag format (index=off), which the new v7.0 kernel strictly rejects as an invalid argument. Because containerd cannot mount the filesystem root for the Pod sandboxes, no containers can be born, leading to the connection refused API server loops.
------------------------------
## The Definitive Solution: Fix the Containerd Snapshotter
To fix this filesystem mounting error, you must modify containerd's configuration inside k8s-master-01 to use the standardized, updated overlay parameters.
Execute these commands inside your k8s-master-01 terminal console:
## Step 1: Update the containerd Configuration File

   1. Open the core configuration layout file:
   
   sudo vi /etc/containerd/config.toml
   
   2. Search for the [plugins."io.containerd.snapshotter.v1.overlayfs"] configuration block.
   3. If it does not exist, or inside it, locate or add the line to disable the deprecated index verification parameters completely. Change the block to look exactly like this:
   
   [plugins."io.containerd.snapshotter.v1.overlayfs"]
     mount_options = []
   
   (Ensure any legacy strings like index=off are completely removed from the mount_options array).

## Step 2: Alternative Fix (If the parameter above is missing)
If your config.toml was automatically generated by Kubespray and is heavily abstracted, you can explicitly force containerd to fall back on a cleaner execution driver by executing a fresh configuration generation string:

# Backup old config
sudo mv /etc/containerd/config.toml /etc/containerd/config.toml.bak
# Generate a fresh config matching your kernel specs
sudo containerd config default | sudo tee /etc/containerd/config.toml

------------------------------
## Step 3: Flush and Restart the Services
Once the configuration is modified, flush the corrupted container memory space from the host disk and restart the services to rebuild the mount paths:

# Clear out partial, corrupted container sandbox mount links
sudo rm -rf /var/lib/containerd/io.containerd.runtime.v2.task/k8s.io/*
# Restart the runtimes
sudo systemctl restart containerd
sudo systemctl restart kubelet

------------------------------
## Step 4: Resume Verification
Give it 15 seconds to sync with the disk, then run your local runtime inspection tool again:

sudo crictl --runtime-endpoint unix:///var/run/containerd/containerd.sock ps -a

The container instances (kube-apiserver, kube-scheduler, etc.) will immediately clear the CreatePodSandboxError mount barrier, transition into an active Running state, and automatically open up port 6443 for your cluster architecture.
Once you update the containerd overlayfs settings and restart the services, does crictl ps finally print out your active running control plane containers?





The control plane failure in the nested QEMU/KVM virtual machine environment is caused by the overlayfs snapshotter in the containerd configuration, which the underlying virtual partition filesystem does not support. To resolve the resulting kernel mount failures, containerd must be configured to use the native snapshotter storage driver by setting containerd_snapshotter: "native" in the Kubespray configuration variables. After updating the configuration, reset the cluster storage states, apply the containerd playbook tags, and resume the master bootstrapping loop. For more information, consult the Kubespray documentation.



Once you incorporate the fix , Can I start by running "ansible-playbook -i inventory.yml playbooks/lab/overlay-k8s.yml --start-at-task="Kubeadm | Create kubeadm config"???

CLAUDIO:

This is a misdiagnosis in those pasted notes — the kernel version is a red herring. Let me confirm the real cause and find where to fix it in the codebase. 

Searched for regex `containerd_snapshotter|snapshotter|containerd_storage_dir|overlayfs|LiveOS|containerd_root`, 97 results

Confirmed the real root cause: the VM root is a **dracut LiveOS overlay** (`LiveOS_rootfs on / type overlay`), and `/var/lib/containerd` sits on it. containerd's **overlayfs snapshotter cannot mount overlay-on-overlay** → `invalid argument`. The kernel-7.0/`index=off` theory is wrong. The correct, reproducible fix is the **native snapshotter**. Let me wire it into the codebase.    

Read [](file:///c%3A/dc-lab/clab/sonic-clab/group_vars/k8s_cluster.yml#90-90), lines 90 to 105

Read [](file:///c%3A/dc-lab/clab/sonic-clab/roles/kubespray_prep/templates/kubespray-group-vars.yaml.j2#1-1), lines 1 to 45

Replacing 6 lines with 22 lines in [](file:///c%3A/dc-lab/clab/sonic-clab/group_vars/k8s_cluster.yml), [](file:///c%3A/dc-lab/clab/sonic-clab/roles/kubespray_prep/templates/kubespray-group-vars.yaml.j2)


```

```

```

```
Let me record this in repo memory since it's a common, easily-misdiagnosed failure.   

Updated memory file [](file:///c%3A/Users/nh4134/AppData/Roaming/Code/User/workspaceStorage/77d38b8fb836138bdc64636f049387ed/GitHub.copilot-chat/memory-tool/memories/repo/notes.md)

Fix incorporated. Here's the correct diagnosis and the answer to your resume question.

## Real root cause (the pasted notes misdiagnose it)
Your `mount` output shows the VM root is a **dracut LiveOS overlay**:
```
LiveOS_rootfs on / type overlay (rw,...,lowerdir=/run/rootfsbase,upperdir=/run/overlayfs,...)
/dev/vda on /run/overlayfs-backing type ext4
```
`/var/lib/containerd` lives on that overlay root. containerd's default **overlayfs snapshotter cannot stack an overlay mount on top of an overlay filesystem** — the kernel returns `invalid argument`, so every control-plane Pod sandbox fails (`CreatePodSandboxError`), the apiserver never binds `6443`, and `kubeadm init` times out on `wait-control-plane`.

- It is **not** the kernel 7.0 / `index=off` issue, and **not** etcd — you proved etcd is fine (`nc 10.0.10.2/20.2/30.2 2379` all succeeded, external-etcd mode working).
- The `mount_options = []` edit will **not** help; overlay-on-overlay stays rejected. Relocating containerd root to `/opt` also won't help (it's on the same overlay).

## Fix shipped (reproducible)
Set the **native snapshotter** (bind/copy layers — works on any filesystem):
- group_vars/k8s_cluster.yml — `containerd_snapshotter: "native"`
- kubespray-group-vars.yaml.j2 — `containerd_snapshotter: "{{ containerd_snapshotter | default('native') }}"`

Tradeoff: native has no layer dedup (more disk), which is fine on your 147 GB overlay canvas.

## Can you resume with `--start-at-task="Kubeadm | Create kubeadm config"`?
**No.** Two reasons:
1. That task is in the control-plane role — it **skips the `container-engine` role**, so the new `native` snapshotter never gets written to `/etc/containerd/config.toml` (which still says `snapshotter = "overlayfs"`). The runtime would fail exactly the same way.
2. The failed `kubeadm init` left partial state (certs, manifests, kubelet config, stale snapshots) that a re-init will trip over.

### Correct sequence
```bash
# 1. Re-render overrides with the new snapshotter
ansible-playbook -i inventory.yml playbooks/kubespray-prep.yml

# 2. Reconfigure + restart containerd across the cluster (rewrites config.toml to native)
ansible-playbook -i inventory.yml playbooks/kubespray.yml --tags container-engine

# 3. Reset the half-initialized control plane, then re-run the K8s deploy
ansible -i inventory.yml kube_control_plane -b -m shell -a "kubeadm reset -f"
ansible-playbook -i inventory.yml playbooks/lab/overlay-k8s.yml
```

If you want to unblock **one node right now** to confirm before a full re-run, on each master:
```bash
sudo sed -i 's/snapshotter = "overlayfs"/snapshotter = "native"/' /etc/containerd/config.toml
sudo kubeadm reset -f
sudo rm -rf /var/lib/containerd/io.containerd.runtime.v2.task/k8s.io/* /etc/kubernetes/* /var/lib/kubelet/*
sudo systemctl restart containerd kubelet
sudo crictl ps -a   # sandboxes should now start (no overlay mount error)
```
Note the manual `sed` is temporary — Kubespray regenerates `config.toml` from its template, so the durable fix is the group-vars change above followed by the `container-engine` tag.

One aside: kubeadm also warned `clusterDNS ... 169.254.25.10` vs recommended `10.233.0.10` — that's just the nodelocaldns cache IP (`enable_nodelocaldns: true`), a warning only, unrelated to this failure.

Made changes.
Compacted conversationLet me check what reset-related playbooks already exist.  

Searched for files matching `**/sonic-clab/playbooks/**/*.yml`, 20 matches

Searched for regex `kubeadm reset|reset\.yml|kubespray.*reset|containerd_snapshotter|overlay-k8s`, 22 results

No reset playbook exists. Let me look at how the overlay/kubespray playbooks are structured so the reset playbook fits the existing conventions.  

Read [](file:///c%3A/dc-lab/clab/sonic-clab/playbooks/lab/overlay-k8s.yml)

Read [](file:///c%3A/dc-lab/clab/sonic-clab/playbooks/kubespray-prep.yml#1-1), lines 1 to 80

Let me look at how `kubespray.yml` invokes Kubespray so the reset playbook mirrors the same mechanism. 

Read [](file:///c%3A/dc-lab/clab/sonic-clab/playbooks/kubespray.yml)

Searched for regex `kubespray_dest|kubespray_repo|kubespray_version|kubespray_inventory_dir|kubespray_repo_mirror|local_fabric_cache_root`, 67 results

Now I have the full picture. Kubespray is cloned to `/opt/kubespray` and its `playbooks/reset.yml` is the canonical reset. There is **no reset playbook** in this repo today. Let me view the tail of kubespray-prep.yml to mirror its var/render conventions, then create the reset playbook. 

Read [](file:///c%3A/dc-lab/clab/sonic-clab/playbooks/kubespray-prep.yml#80-80), lines 80 to 115

No reset playbook exists. I'll create `playbooks/kubespray-reset.yml` that runs Kubespray's canonical `reset.yml` non-interactively, then does an overlay-specific cleanup so the next deploy starts pristine on the native snapshotter. It includes a safety gate so it can't nuke a cluster by accident.   

Created [](file:///c%3A/dc-lab/clab/sonic-clab/playbooks/kubespray-reset.yml)

Now syntax-check it via WSL, matching the repo's convention. 

Ran terminal command: wsl.exe -d ubuntu-24.04 bash -lc 'cd /mnt/c/dc-lab/clab/sonic-clab && ANSIBLE_CONFIG=/mnt/c/dc-lab/clab/sonic-clab/ansible.cfg ansible-playbook -i inventory.yml playbooks/kubespray-reset.yml --syntax-check'

Syntax-check passed. Now update the runbook. Let me look at the runbook structure around the K8s section to add a reset entry that matches the existing card format.   

Read [](file:///c%3A/dc-lab/clab/sonic-clab/wiki/runbook-chronological.html#240-240), lines 240 to 278

Replacing 10 lines with 33 lines in [](file:///c%3A/dc-lab/clab/sonic-clab/wiki/runbook-chronological.html)


```

```
Verify the runbook HTML div balance stays intact (the repo convention).  

Ran terminal command: wsl.exe -d ubuntu-24.04 bash -c "cd /mnt/c/dc-lab/clab/sonic-clab/wiki; printf 'div-open: '; grep -o '<div' runbook-chronological.html | wc -l; printf 'div-close: '; grep -o '</div>' runbook-chronological.html | wc -l; printf 'k8s-reset anchor: '; grep -c 'id=.k8s-reset.' runbook-chronological.html"

Balanced 9/9, anchor present. Let me record this in repo memory. 

Updated memory file [](file:///c%3A/Users/nh4134/AppData/Roaming/Code/User/workspaceStorage/77d38b8fb836138bdc64636f049387ed/GitHub.copilot-chat/memory-tool/memories/repo/notes.md)

No — there was no reset target before. I created one and documented it in the runbook.

## New playbook: `playbooks/kubespray-reset.yml`
Purpose-built for a partial/failed K8s deployment (failed `kubeadm init`, `CreatePodSandboxError`, half-built control plane). It:

1. **Guards against accidents** — refuses to run unless you pass `-e k8s_reset_confirm=true`.
2. **Re-renders the Kubespray inventory + overrides** (so reset targets the right hosts, and the subsequent deploy inherits the `native` snapshotter).
3. **Runs Kubespray's own `reset.yml`** non-interactively (`-e reset_confirmation=yes`) — the canonical teardown of kubeadm/etcd/CNI/containerd.
4. **Overlay-specific cleanup** on every node — `kubeadm reset -f`, stop kubelet/containerd, purge `/etc/kubernetes`, `/var/lib/kubelet`, stale `overlayfs` snapshots, `/etc/cni/net.d`, restart containerd — so the next run rebuilds cleanly.

Usage:
```bash
# Destructive — reset the partial cluster
ansible-playbook -i inventory.yml playbooks/kubespray-reset.yml -e k8s_reset_confirm=true

# Then redeploy from the top
ansible-playbook -i inventory.yml playbooks/lab/overlay-k8s.yml
```

Syntax-check passed.

## Runbook updated
Added a **"Reset a Partial / Failed K8s Deployment"** card (anchor `id="k8s-reset"`) to runbook-chronological.html with the commands and the explanation of why `--start-at-task` is not a valid shortcut. HTML div balance verified 9/9.

This is the reset flow I referenced in my earlier answer — now it's a real, guarded, reproducible target instead of manual per-node steps.

Made changes.
