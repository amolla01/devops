nh1221@PowerEdge-R810:~$ docker images
permission denied while trying to connect to the docker API at unix:///var/run/docker.sock
nh1221@PowerEdge-R810:~$ sudo docker images
                                                                                                                                                                                          i Info →   U  In Use
IMAGE                                                                    ID             DISK USAGE   CONTENT SIZE   EXTRA
127.0.0.1:5000/brancz/kube-rbac-proxy:v0.18.1                            0e66baf34f64        107MB         32.1MB        
127.0.0.1:5000/calico/cni:v3.28.2                                        04bd5d80c32a        304MB         94.7MB        
127.0.0.1:5000/calico/cni:v3.29.2                                        5c7827667dab        319MB         99.3MB        
127.0.0.1:5000/calico/kube-controllers:v3.28.2                           7de855fcbff8        114MB         34.9MB        
127.0.0.1:5000/calico/kube-controllers:v3.29.2                           4313495b1ce8        119MB         36.3MB        
127.0.0.1:5000/calico/node:v3.28.2                                       856ac0c26116        499MB          120MB        
127.0.0.1:5000/calico/node:v3.29.2                                       97dfd69511ab        520MB          142MB        
127.0.0.1:5000/calico/pod2daemon-flexvol:v3.28.2                         884a37672683       20.3MB         6.63MB        
127.0.0.1:5000/calico/pod2daemon-flexvol:v3.29.2                         ba44244500bf       20.9MB         6.86MB        
127.0.0.1:5000/calico/typha:v3.28.2                                      58c09de1af1c        102MB         30.9MB        
127.0.0.1:5000/calico/typha:v3.29.2                                      54134801a39c        106MB         31.9MB        
127.0.0.1:5000/ceph/ceph:v19.2.0                                         200087c35811       1.81GB          457MB        
127.0.0.1:5000/coredns/coredns:v1.11.3                                   9caabbf6238b       85.1MB         18.6MB        
127.0.0.1:5000/coredns/coredns:v1.12.0                                   2c3f515bffd2       93.8MB         20.8MB        
127.0.0.1:5000/cpa/cluster-proportional-autoscaler:v1.9.0                8f3b4e4beb62       64.2MB         13.4MB        
127.0.0.1:5000/dns/k8s-dns-node-cache:1.23.1                             e3dccb1a21d1        117MB         35.1MB        
127.0.0.1:5000/etcd:v3.5.16                                              1bd8edbbdb21       85.2MB         21.7MB        
127.0.0.1:5000/etcd:v3.5.17                                              ac1bfd8985f4       85.2MB         21.7MB        
127.0.0.1:5000/fossbilling/fossbilling:latest                            81eea9624261        952MB          231MB        
127.0.0.1:5000/grafana/grafana:11.3.1                                    fa801ab6e1ae        646MB          133MB        
127.0.0.1:5000/ingress-nginx/controller:v1.12.0                          e6b8de175acd        415MB          108MB        
127.0.0.1:5000/ingress-nginx/kube-webhook-certgen:v1.4.4                 3f6f0a764592       92.9MB           26MB        
127.0.0.1:5000/jetstack/cert-manager-cainjector:v1.16.2                  b72b33172d09       71.4MB         15.4MB        
127.0.0.1:5000/jetstack/cert-manager-controller:v1.16.2                  4705286cd4e5       96.8MB         21.2MB        
127.0.0.1:5000/jetstack/cert-manager-startupapicheck:v1.16.2             2ae926cbcd0b       59.8MB         14.1MB        
127.0.0.1:5000/jetstack/cert-manager-webhook:v1.16.2                     2ba472fab666       82.7MB         18.2MB        
127.0.0.1:5000/k8snetworkplumbingwg/multus-cni:v4.1.0                    189f6955481b        598MB          182MB        
127.0.0.1:5000/kube-apiserver:v1.31.4                                    ace6a943b058        125MB           28MB        
127.0.0.1:5000/kube-apiserver:v1.33.3                                    125a8b488def        135MB         30.1MB        
127.0.0.1:5000/kube-controller-manager:v1.31.4                           4bd1d4a449e7        118MB         26.1MB        
127.0.0.1:5000/kube-controller-manager:v1.33.3                           96091626e37c        126MB         27.6MB        
127.0.0.1:5000/kube-proxy:v1.31.4                                        1739b3febca3        126MB         30.2MB        
127.0.0.1:5000/kube-proxy:v1.33.3                                        c69929cfba9e        134MB         31.9MB        
127.0.0.1:5000/kube-scheduler:v1.31.4                                    1a3081cb7d21       90.8MB         20.1MB        
127.0.0.1:5000/kube-scheduler:v1.33.3                                    f3a2ffdd7483       98.5MB         21.8MB        
127.0.0.1:5000/kube-state-metrics/kube-state-metrics:v2.14.0             37d841299325       69.9MB         15.4MB        
127.0.0.1:5000/kubernetesui/dashboard:v2.7.0                             2e500d29e9d5        334MB         75.8MB        
127.0.0.1:5000/kubernetesui/metrics-scraper:v1.0.9                       92a7659b554e       63.6MB         19.7MB        
127.0.0.1:5000/mariadb:10.11                                             de61fed4a40d        458MB          109MB        
127.0.0.1:5000/mariadb:11                                                d9f7eb263729        466MB          111MB        
127.0.0.1:5000/memcached:1.6                                             eeb9eaa939ff        128MB         34.2MB        
127.0.0.1:5000/metallb/controller:v0.14.9                                4cd4edf97021        103MB           29MB        
127.0.0.1:5000/metallb/speaker:v0.14.9                                   de0829bd1fb7        186MB         55.1MB        
127.0.0.1:5000/metrics-server/metrics-server:v0.7.2                      ffcb2bf004d6       89.8MB         19.5MB        
127.0.0.1:5000/metrics-server/metrics-server:v0.8.0                      89258156d0e9        108MB         22.5MB        
127.0.0.1:5000/nginx:1.27-alpine                                         65645c7bb6a0       74.5MB         21.9MB        
127.0.0.1:5000/pause:3.10                                                bb8c9648cc56       1.08MB          318kB        
127.0.0.1:5000/prometheus-operator/prometheus-config-reloader:v0.78.2    944b2c67345c       61.7MB         14.7MB        
127.0.0.1:5000/prometheus-operator/prometheus-operator:v0.78.2           bfcc5d6058be       86.2MB         18.8MB        
127.0.0.1:5000/prometheus/alertmanager:v0.27.0                           e13b6ed5cb92        106MB         32.4MB        
127.0.0.1:5000/prometheus/node-exporter:v1.8.2                           4032c6d5bfd7       38.2MB           12MB        
127.0.0.1:5000/prometheus/prometheus:v2.55.1                             2659f4c2ebb7        407MB          114MB        
127.0.0.1:5000/rabbitmq:3.13-management                                  e582c0bc7766        392MB          118MB        
127.0.0.1:5000/registry:2                                                a3d8aaa63ed8       37.4MB         10.3MB    U   
127.0.0.1:5000/rook/ceph:v1.15.5                                         b94b23ecaf32       1.89GB          471MB        
127.0.0.1:5000/sig-storage/csi-attacher:v4.7.0                           6e54dae32284        109MB           31MB        
127.0.0.1:5000/sig-storage/csi-node-driver-registrar:v2.12.0             0d23a6fd60c4       45.9MB           14MB        
127.0.0.1:5000/sig-storage/csi-provisioner:v5.1.0                        672e45d6a556        113MB         32.2MB        
127.0.0.1:5000/sig-storage/csi-resizer:v1.12.0                           ab774734705a        109MB         30.9MB        
127.0.0.1:5000/sig-storage/csi-snapshotter:v8.1.0                        b3e90b337816        108MB         30.6MB        
172.16.2.1:5000/brancz/kube-rbac-proxy:v0.18.1                           20f297c4cf6f        107MB         32.1MB        
172.16.2.1:5000/calico/cni:v3.28.2                                       04bd5d80c32a        304MB         94.7MB        
172.16.2.1:5000/calico/cni:v3.29.2                                       5c7827667dab        319MB         99.3MB        
172.16.2.1:5000/calico/kube-controllers:v3.28.2                          7de855fcbff8        114MB         34.9MB        
172.16.2.1:5000/calico/kube-controllers:v3.29.2                          4313495b1ce8        119MB         36.3MB        
172.16.2.1:5000/calico/node:v3.28.2                                      856ac0c26116        499MB          120MB        
172.16.2.1:5000/calico/node:v3.29.2                                      97dfd69511ab        520MB          142MB        
172.16.2.1:5000/calico/pod2daemon-flexvol:v3.28.2                        884a37672683       20.3MB         6.63MB        
172.16.2.1:5000/calico/pod2daemon-flexvol:v3.29.2                        ba44244500bf       20.9MB         6.86MB        
172.16.2.1:5000/calico/typha:v3.28.2                                     58c09de1af1c        102MB         30.9MB        
172.16.2.1:5000/calico/typha:v3.29.2                                     54134801a39c        106MB         31.9MB        
172.16.2.1:5000/ceph/ceph:v19.2.0                                        200087c35811       1.81GB          457MB        
172.16.2.1:5000/coredns/coredns:v1.11.3                                  9caabbf6238b       85.1MB         18.6MB        
172.16.2.1:5000/coredns/coredns:v1.12.0                                  f5e03bc00912       93.8MB         20.8MB        
172.16.2.1:5000/cpa/cluster-proportional-autoscaler:v1.8.8               69bf675e3567         54MB         11.6MB        
172.16.2.1:5000/cpa/cluster-proportional-autoscaler:v1.9.0               8f3b4e4beb62       64.2MB         13.4MB        
172.16.2.1:5000/dns/k8s-dns-node-cache:1.23.1                            e3dccb1a21d1        117MB         35.1MB        
172.16.2.1:5000/dns/k8s-dns-node-cache:1.25.0                            c10362235fc2        126MB         37.8MB        
172.16.2.1:5000/etcd:v3.5.16                                             88ae68f558b8       85.2MB         21.7MB        
172.16.2.1:5000/etcd:v3.5.17                                             329f6ea0dcdd       85.2MB         21.7MB        
172.16.2.1:5000/fossbilling/fossbilling:latest                           81eea9624261        952MB          231MB        
172.16.2.1:5000/grafana/grafana:11.3.1                                   fa801ab6e1ae        646MB          133MB        
172.16.2.1:5000/ingress-nginx/controller:v1.12.0                         e6b8de175acd        415MB          108MB        
172.16.2.1:5000/ingress-nginx/kube-webhook-certgen:v1.4.4                a21358af9f10       92.9MB           26MB        
172.16.2.1:5000/jetstack/cert-manager-cainjector:v1.16.2                 b453439c7f32       71.4MB         15.4MB        
172.16.2.1:5000/jetstack/cert-manager-controller:v1.16.2                 db778c9a9be4       96.8MB         21.2MB        
172.16.2.1:5000/jetstack/cert-manager-startupapicheck:v1.16.2            17398546a4bd       59.8MB         14.1MB        
172.16.2.1:5000/jetstack/cert-manager-webhook:v1.16.2                    ac3eebb05f95       82.7MB         18.2MB        
172.16.2.1:5000/k8snetworkplumbingwg/multus-cni:v4.1.0                   80b1139b833f        598MB          182MB        
172.16.2.1:5000/kube-apiserver:v1.31.4                                   ace6a943b058        125MB           28MB        
172.16.2.1:5000/kube-apiserver:v1.33.3                                   125a8b488def        135MB         30.1MB        
172.16.2.1:5000/kube-apiserver:v1.35.4                                   06b4bb208634        121MB         27.6MB        
172.16.2.1:5000/kube-apiserver:v1.36.4                                   cfcdb0165330        129MB         29.8MB        
172.16.2.1:5000/kube-controller-manager:v1.31.4                          4bd1d4a449e7        118MB         26.1MB        
172.16.2.1:5000/kube-controller-manager:v1.33.3                          96091626e37c        126MB         27.6MB        
172.16.2.1:5000/kube-controller-manager:v1.35.4                          7b036c805d57        102MB           23MB        
172.16.2.1:5000/kube-controller-manager:v1.36.4                          232878d552ad        115MB         26.5MB        
172.16.2.1:5000/kube-proxy:v1.31.4                                       1739b3febca3        126MB         30.2MB        
172.16.2.1:5000/kube-proxy:v1.33.3                                       c69929cfba9e        134MB         31.9MB        
172.16.2.1:5000/kube-proxy:v1.35.4                                       c5daa23c7247       99.9MB         25.7MB        
172.16.2.1:5000/kube-proxy:v1.36.4                                       b33fcdd83192        114MB         30.1MB        
172.16.2.1:5000/kube-scheduler:v1.31.4                                   1a3081cb7d21       90.8MB         20.1MB        
172.16.2.1:5000/kube-scheduler:v1.33.3                                   f3a2ffdd7483       98.5MB         21.8MB        
172.16.2.1:5000/kube-scheduler:v1.35.4                                   9054fecb4fa0       72.2MB         17.1MB        
172.16.2.1:5000/kube-scheduler:v1.36.4                                   7d84d58f091f       83.6MB         20.5MB        
172.16.2.1:5000/kube-state-metrics/kube-state-metrics:v2.14.0            37d841299325       69.9MB         15.4MB        
172.16.2.1:5000/kubernetesui/dashboard:v2.7.0                            2e500d29e9d5        334MB         75.8MB        
172.16.2.1:5000/kubernetesui/metrics-scraper:v1.0.9                      92a7659b554e       63.6MB         19.7MB        
172.16.2.1:5000/library/nginx:1.28.2-alpine                              db35bfc6b295       94.2MB         27.2MB    U   
172.16.2.1:5000/mariadb:10.11                                            de61fed4a40d        458MB          109MB        
172.16.2.1:5000/mariadb:11                                               d9f7eb263729        466MB          111MB        
172.16.2.1:5000/memcached:1.6                                            eeb9eaa939ff        128MB         34.2MB        
172.16.2.1:5000/metallb/controller:v0.13.9                               c9ffd7215dcf       92.6MB         27.8MB        
172.16.2.1:5000/metallb/controller:v0.14.9                               b6a224a3e827        103MB           29MB        
172.16.2.1:5000/metallb/speaker:v0.13.9                                  ed242e213112        165MB         50.1MB        
172.16.2.1:5000/metallb/speaker:v0.14.9                                  997d3f3c09db        186MB         55.1MB        
172.16.2.1:5000/metrics-server/metrics-server:v0.7.2                     ffcb2bf004d6       89.8MB         19.5MB        
172.16.2.1:5000/metrics-server/metrics-server:v0.8.0                     89258156d0e9        108MB         22.5MB        
172.16.2.1:5000/nginx:1.27-alpine                                        65645c7bb6a0       74.5MB         21.9MB        
172.16.2.1:5000/nginx:1.28.2-alpine                                      db35bfc6b295       94.2MB         27.2MB    U   
172.16.2.1:5000/pause:3.10                                               f65dd6a8a8d9       1.08MB          318kB        
172.16.2.1:5000/pause:3.10.1                                             278fb9dbcca9       1.06MB          318kB        
172.16.2.1:5000/prometheus-operator/prometheus-config-reloader:v0.78.2   944b2c67345c       61.7MB         14.7MB        
172.16.2.1:5000/prometheus-operator/prometheus-operator:v0.78.2          bfcc5d6058be       86.2MB         18.8MB        
172.16.2.1:5000/prometheus/alertmanager:v0.27.0                          e13b6ed5cb92        106MB         32.4MB        
172.16.2.1:5000/prometheus/node-exporter:v1.8.2                          4032c6d5bfd7       38.2MB           12MB        
172.16.2.1:5000/prometheus/prometheus:v2.55.1                            2659f4c2ebb7        407MB          114MB        
172.16.2.1:5000/rabbitmq:3.13-management                                 e582c0bc7766        392MB          118MB        
172.16.2.1:5000/registry.k8s.io/k8snetworkplumbingwg/multus-cni:v4.1.0   8133d5ff41bd        598MB          182MB        
172.16.2.1:5000/registry:2                                               a3d8aaa63ed8       37.4MB         10.3MB    U   
172.16.2.1:5000/rook/ceph:v1.15.5                                        b94b23ecaf32       1.89GB          471MB        
172.16.2.1:5000/sig-storage/csi-attacher:v4.7.0                          6e54dae32284        109MB           31MB        
172.16.2.1:5000/sig-storage/csi-node-driver-registrar:v2.12.0            0d23a6fd60c4       45.9MB           14MB        
172.16.2.1:5000/sig-storage/csi-provisioner:v5.1.0                       672e45d6a556        113MB         32.2MB        
172.16.2.1:5000/sig-storage/csi-resizer:v1.12.0                          ab774734705a        109MB         30.9MB        
172.16.2.1:5000/sig-storage/csi-snapshotter:v8.1.0                       b3e90b337816        108MB         30.6MB        
calico/cni:v3.28.2                                                       04bd5d80c32a        304MB         94.7MB        
calico/cni:v3.29.2                                                       5c7827667dab        319MB         99.3MB        
calico/kube-controllers:v3.28.2                                          7de855fcbff8        114MB         34.9MB        
calico/kube-controllers:v3.29.2                                          4313495b1ce8        119MB         36.3MB        
calico/node:v3.28.2                                                      856ac0c26116        499MB          120MB        
calico/node:v3.29.2                                                      97dfd69511ab        520MB          142MB        
calico/pod2daemon-flexvol:v3.28.2                                        884a37672683       20.3MB         6.63MB        
calico/pod2daemon-flexvol:v3.29.2                                        ba44244500bf       20.9MB         6.86MB        
calico/typha:v3.28.2                                                     58c09de1af1c        102MB         30.9MB        
calico/typha:v3.29.2                                                     54134801a39c        106MB         31.9MB        
fossbilling/fossbilling:latest                                           81eea9624261        952MB          231MB        
ghcr.io/hellt/network-multitool:latest                                   a8d96c19e593        274MB         6.86kB        
grafana/grafana:11.3.1                                                   fa801ab6e1ae        646MB          133MB        
kubernetesui/dashboard:v2.7.0                                            2e500d29e9d5        334MB         75.8MB        
kubernetesui/metrics-scraper:v1.0.9                                      92a7659b554e       63.6MB         19.7MB        
mariadb:10.11                                                            de61fed4a40d        458MB          109MB        
mariadb:11                                                               d9f7eb263729        466MB          111MB        
memcached:1.6                                                            eeb9eaa939ff        128MB         34.2MB        
nginx:1.27-alpine                                                        65645c7bb6a0       74.5MB         21.9MB        
nginx:alpine                                                             db35bfc6b295       94.2MB         27.2MB    U   
quay.io/ceph/ceph:v19.2.0                                                200087c35811       1.81GB          457MB        
quay.io/frrouting/frr:10.0.1                                             8ab9fe2ded0b        169MB         4.59kB    U   
quay.io/metallb/controller:v0.13.9                                       c9ffd7215dcf       92.6MB         27.8MB        
quay.io/metallb/speaker:v0.13.9                                          ed242e213112        165MB         50.1MB        
quay.io/prometheus-operator/prometheus-config-reloader:v0.78.2           944b2c67345c       61.7MB         14.7MB        
quay.io/prometheus-operator/prometheus-operator:v0.78.2                  bfcc5d6058be       86.2MB         18.8MB        
quay.io/prometheus/alertmanager:v0.27.0                                  e13b6ed5cb92        106MB         32.4MB        
quay.io/prometheus/node-exporter:v1.8.2                                  4032c6d5bfd7       38.2MB           12MB        
quay.io/prometheus/prometheus:v2.55.1                                    2659f4c2ebb7        407MB          114MB        
rabbitmq:3.13-management                                                 e582c0bc7766        392MB          118MB        
registry.k8s.io/coredns/coredns:v1.11.3                                  9caabbf6238b       85.1MB         18.6MB        
registry.k8s.io/cpa/cluster-proportional-autoscaler:v1.8.8               69bf675e3567         54MB         11.6MB        
registry.k8s.io/cpa/cluster-proportional-autoscaler:v1.9.0               8f3b4e4beb62       64.2MB         13.4MB        
registry.k8s.io/dns/k8s-dns-node-cache:1.23.1                            e3dccb1a21d1        117MB         35.1MB        
registry.k8s.io/dns/k8s-dns-node-cache:1.25.0                            c10362235fc2        126MB         37.8MB        
registry.k8s.io/ingress-nginx/controller:v1.12.0                         e6b8de175acd        415MB          108MB        
registry.k8s.io/kube-apiserver:v1.31.4                                   ace6a943b058        125MB           28MB        
registry.k8s.io/kube-apiserver:v1.33.3                                   125a8b488def        135MB         30.1MB        
registry.k8s.io/kube-apiserver:v1.35.4                                   06b4bb208634        121MB         27.6MB        
registry.k8s.io/kube-apiserver:v1.36.4                                   cfcdb0165330        129MB         29.8MB        
registry.k8s.io/kube-controller-manager:v1.31.4                          4bd1d4a449e7        118MB         26.1MB        
registry.k8s.io/kube-controller-manager:v1.33.3                          96091626e37c        126MB         27.6MB        
registry.k8s.io/kube-controller-manager:v1.35.4                          7b036c805d57        102MB           23MB        
registry.k8s.io/kube-controller-manager:v1.36.4                          232878d552ad        115MB         26.5MB        
registry.k8s.io/kube-proxy:v1.31.4                                       1739b3febca3        126MB         30.2MB        
registry.k8s.io/kube-proxy:v1.33.3                                       c69929cfba9e        134MB         31.9MB        
registry.k8s.io/kube-proxy:v1.35.4                                       c5daa23c7247       99.9MB         25.7MB        
registry.k8s.io/kube-proxy:v1.36.4                                       b33fcdd83192        114MB         30.1MB        
registry.k8s.io/kube-scheduler:v1.31.4                                   1a3081cb7d21       90.8MB         20.1MB        
registry.k8s.io/kube-scheduler:v1.33.3                                   f3a2ffdd7483       98.5MB         21.8MB        
registry.k8s.io/kube-scheduler:v1.35.4                                   9054fecb4fa0       72.2MB         17.1MB        
registry.k8s.io/kube-scheduler:v1.36.4                                   7d84d58f091f       83.6MB         20.5MB        
registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.14.0            37d841299325       69.9MB         15.4MB        
registry.k8s.io/metrics-server/metrics-server:v0.7.2                     ffcb2bf004d6       89.8MB         19.5MB        
registry.k8s.io/metrics-server/metrics-server:v0.8.0                     89258156d0e9        108MB         22.5MB        
registry.k8s.io/pause:3.10.1                                             278fb9dbcca9       1.06MB          318kB        
registry.k8s.io/sig-storage/csi-attacher:v4.7.0                          6e54dae32284        109MB           31MB        
registry.k8s.io/sig-storage/csi-node-driver-registrar:v2.12.0            0d23a6fd60c4       45.9MB           14MB        
registry.k8s.io/sig-storage/csi-provisioner:v5.1.0                       672e45d6a556        113MB         32.2MB        
registry.k8s.io/sig-storage/csi-resizer:v1.12.0                          ab774734705a        109MB         30.9MB        
registry.k8s.io/sig-storage/csi-snapshotter:v8.1.0                       b3e90b337816        108MB         30.6MB        
registry:2                                                               a3d8aaa63ed8       37.4MB         10.3MB    U   
rook/ceph:v1.15.5                                                        b94b23ecaf32       1.89GB          471MB        
vrnetlab/canonical_ubuntu:resolute                                       cd8a41eb9024        3.2GB          1.3GB    U   
vrnetlab/sonic_sonic-vs:202605                                           c25d55237da0       10.3GB         2.47GB    U   
nh1221@PowerEdge-R810:~$ 
nh1221@PowerEdge-R810:~$ 
nh1221@PowerEdge-R810:~$ 
nh1221@PowerEdge-R810:~$ curl -fsSI http://172.16.2.1:8080/
HTTP/1.1 200 OK
Server: nginx/1.31.4
Date: Tue, 15 Sep 2026 21:32:32 GMT
Content-Type: text/html
Connection: keep-alive

nh1221@PowerEdge-R810:~$ sudo docker inspect -f '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}' sheba-file-server
/opt/fabric-cache/downloads -> /usr/share/nginx/html

nh1221@PowerEdge-R810:~$ ls -al /opt/fabric-cache/downloads
total 611684
drwxr-xr-x  3 root   root       4096 Sep 13 19:31 .
drwxr-xr-x  3 root   root       4096 Aug 29 08:04 ..
-rw-r--r--  1 root   root     300047 Sep 13 16:39 calico-crds-3.29.2.yaml
-rwxr-xr-x  1 root   root   70297012 Feb  5  2025 calicoctl-3.29.2-linux-amd64
-rwxr-xr-x  1 nh1221 nh1221 70297012 Aug 29 10:05 calicoctl-linux-amd64-v3.29.2
-rwxr-xr-x  1 nh1221 nh1221 52713273 Aug 29 10:07 cni-plugins-linux-amd64-v1.6.0.tgz
-rwxr-xr-x  1 root   root   55418181 Mar 16  2026 cni-plugins-linux-amd64-v1.9.1.tgz
-rwxr-xr-x  1 root   root   35352990 Apr 14 12:38 containerd-2.2.3-linux-amd64.tar.gz
-rwxr-xr-x  1 nh1221 nh1221 34497346 Aug 29 11:30 containerd-2.3.0-linux-amd64.tar.gz
-rwxr-xr-x  1 root   root   19185064 Dec 10  2025 crictl-v1.35.0-linux-amd64.tar.gz
-rwxr-xr-x  1 nh1221 nh1221 19263420 Aug 29 10:06 crictl-v1.36.0-linux-amd64.tar.gz
-rwxr-xr-x  1 root   root   20488380 Nov 12  2024 etcd-v3.5.17-linux-amd64.tar.gz
-rw-r--r--  1 root   root   22338398 Sep 13 19:31 etcd-v3.5.24-linux-amd64.tar.gz
-rwxr-xr-x  1 nh1221 nh1221 72413368 Aug 29 10:06 kubeadm-v1.35.4-amd64
-rwxr-xr-x  1 nh1221 nh1221 58613944 Aug 29 10:06 kubectl-v1.35.4-amd64
-rwxr-xr-x  1 nh1221 nh1221 58138916 Aug 29 10:07 kubelet-v1.35.4-amd64
-rwxr-xr-x  1 root   root   11373900 Mar 31 04:35 nerdctl-2.2.2-linux-amd64.tar.gz
-rwxr-xr-x  1 root   root   11744522 Jul 20 03:13 nerdctl-2.3.5-linux-amd64.tar.gz
drwxr-xr-x 12 root   root       4096 Jul 13 19:24 runc-1.5.1
-rwxr-xr-x  1 nh1221 nh1221  1634504 Aug 29 11:30 runc-1.5.1.tar.xz
-rwxr-xr-x  1 root   root   12233104 Apr  2 19:16 runc.amd64
nh1221@PowerEdge-R810:~$ curl -s http://172.16.2.1:8080 | awk -F'href="' '/href=/ {split($2,a,"\""); print a[1]}'
../
runc-1.5.1/
calico-crds-3.29.2.yaml
calicoctl-3.29.2-linux-amd64
calicoctl-linux-amd64-v3.29.2
cni-plugins-linux-amd64-v1.6.0.tgz
cni-plugins-linux-amd64-v1.9.1.tgz
containerd-2.2.3-linux-amd64.tar.gz
containerd-2.3.0-linux-amd64.tar.gz
crictl-v1.35.0-linux-amd64.tar.gz
crictl-v1.36.0-linux-amd64.tar.gz
etcd-v3.5.17-linux-amd64.tar.gz
etcd-v3.5.24-linux-amd64.tar.gz
kubeadm-v1.35.4-amd64
kubectl-v1.35.4-amd64
kubelet-v1.35.4-amd64
nerdctl-2.2.2-linux-amd64.tar.gz
nerdctl-2.3.5-linux-amd64.tar.gz
runc-1.5.1.tar.xz
runc.amd64
nh1221@PowerEdge-R810:~$ 
