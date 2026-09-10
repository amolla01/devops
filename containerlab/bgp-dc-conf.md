admin@Border-Leaf1:~$ show runningconfiguration bgp
Building configuration...
```
Current configuration:
!
frr version 10.5.4
frr defaults traditional
hostname Border-Leaf1
agentx
service integrated-vtysh-config
!
ip prefix-list PL-HOST-IN seq 10 permit 10.10.255.0/24 ge 32 le 32
ip prefix-list PL-HOST-IN seq 20 permit 10.233.64.0/18
ip prefix-list PL-HOST-IN seq 30 permit 10.10.200.0/24 ge 32 le 32
ip prefix-list PL-HOST-IN seq 40 deny 10.233.0.0/18 le 32
ip prefix-list PL-HOST-IN seq 50 deny 172.16.2.0/24 le 32
ip prefix-list PL-HOST-IN seq 60 deny 172.16.2.200/29 le 32
ip prefix-list PL-HOST-IN seq 70 deny 20.0.56.0/24 le 32
ip prefix-list PL-HOST-OUT seq 10 permit 0.0.0.0/0
ip prefix-list PL-HOST-OUT seq 20 permit 10.10.255.0/24 ge 32 le 32
ip prefix-list PL-HOST-OUT seq 30 permit 10.10.200.0/24 ge 32 le 32
ip prefix-list PL-HOST-OUT seq 40 deny 10.233.0.0/18 le 32
ip prefix-list PL-HOST-OUT seq 50 deny 172.16.2.0/24 le 32
ip prefix-list PL-HOST-OUT seq 60 deny 172.16.2.200/29 le 32
ip prefix-list PL-HOST-OUT seq 70 deny 20.0.56.0/24 le 32
!
route-map RM-HOST-IN permit 10
 match ip address prefix-list PL-HOST-IN
exit
!
route-map RM-HOST-IN deny 100
exit
!
route-map RM-HOST-OUT permit 10
 match ip address prefix-list PL-HOST-OUT
exit
!
route-map RM-HOST-OUT deny 100
exit
!
password zebra
enable password zebra
!
vrf Vrf-storage
exit-vrf
!
router bgp 65031 vrf Vrf-storage
 bgp router-id 10.0.2.4
 bgp log-neighbor-changes
 no bgp ebgp-requires-policy
 no bgp default ipv4-unicast
 neighbor Ethernet2.100 interface remote-as 65231
 neighbor Ethernet2.100 description STORAGE-To-k8s-master-03
 neighbor Ethernet2.100 bfd
 no neighbor Ethernet2.100 capability link-local
 neighbor Ethernet3.100 interface remote-as 65232
 neighbor Ethernet3.100 description STORAGE-To-k8s-db-03
 neighbor Ethernet3.100 bfd
 no neighbor Ethernet3.100 capability link-local
 neighbor Ethernet4.100 interface remote-as 65233
 neighbor Ethernet4.100 description STORAGE-To-osh-ctrl-03
 neighbor Ethernet4.100 bfd
 no neighbor Ethernet4.100 capability link-local
 neighbor Ethernet5.100 interface remote-as 65223
 neighbor Ethernet5.100 description STORAGE-To-MonSrv
 neighbor Ethernet5.100 bfd
 no neighbor Ethernet5.100 capability link-local
 neighbor Ethernet6.100 interface remote-as 65235
 neighbor Ethernet6.100 description STORAGE-To-osh-comp-03
 neighbor Ethernet6.100 bfd
 no neighbor Ethernet6.100 capability link-local
 neighbor Ethernet120.100 interface remote-as 65000
 neighbor Ethernet120.100 description STORAGE-To-Spine-S2
 neighbor Ethernet120.100 bfd
 no neighbor Ethernet120.100 capability link-local
 neighbor Ethernet124.100 interface remote-as 65000
 neighbor Ethernet124.100 description STORAGE-To-Spine-S1
 neighbor Ethernet124.100 bfd
 no neighbor Ethernet124.100 capability link-local
 !
 address-family ipv4 unicast
  redistribute connected
  neighbor Ethernet2.100 activate
  neighbor Ethernet3.100 activate
  neighbor Ethernet4.100 activate
  neighbor Ethernet5.100 activate
  neighbor Ethernet6.100 activate
  neighbor Ethernet120.100 activate
  neighbor Ethernet124.100 activate
  maximum-paths 64
 exit-address-family
 !
 address-family ipv6 unicast
  neighbor Ethernet2.100 activate
  neighbor Ethernet3.100 activate
  neighbor Ethernet4.100 activate
  neighbor Ethernet5.100 activate
  neighbor Ethernet6.100 activate
  neighbor Ethernet120.100 activate
  neighbor Ethernet124.100 activate
  maximum-paths 64
 exit-address-family
exit
!
router bgp 65031
 bgp router-id 10.0.2.4
 bgp log-neighbor-changes
 no bgp ebgp-requires-policy
 no bgp default ipv4-unicast
 neighbor Ethernet0 interface remote-as external
 neighbor Ethernet0 description Exit-Router1
 neighbor Ethernet0 bfd
 no neighbor Ethernet0 capability link-local
 neighbor Ethernet1 interface remote-as external
 neighbor Ethernet1 description Exit-Router2
 neighbor Ethernet1 bfd
 no neighbor Ethernet1 capability link-local
 neighbor Ethernet2 interface remote-as external
 neighbor Ethernet2 description k8s-master-03
 neighbor Ethernet2 bfd
 no neighbor Ethernet2 capability link-local
 neighbor Ethernet3 interface remote-as external
 neighbor Ethernet3 description k8s-db-03
 neighbor Ethernet3 bfd
 no neighbor Ethernet3 capability link-local
 neighbor Ethernet4 interface remote-as external
 neighbor Ethernet4 description osh-ctrl-03
 neighbor Ethernet4 bfd
 no neighbor Ethernet4 capability link-local
 neighbor Ethernet5 interface remote-as external
 neighbor Ethernet5 description MonSrv
 neighbor Ethernet5 bfd
 no neighbor Ethernet5 capability link-local
 neighbor Ethernet6 interface remote-as external
 neighbor Ethernet6 description osh-comp-03
 neighbor Ethernet6 bfd
 no neighbor Ethernet6 capability link-local
 neighbor Ethernet120 interface remote-as external
 neighbor Ethernet120 description Spine-S2
 neighbor Ethernet120 bfd
 no neighbor Ethernet120 capability link-local
 neighbor Ethernet124 interface remote-as external
 neighbor Ethernet124 description Spine-S1
 neighbor Ethernet124 bfd
 no neighbor Ethernet124 capability link-local
 !
 address-family ipv4 unicast
  neighbor Ethernet0 activate
  neighbor Ethernet0 route-map RM-HOST-IN in
  neighbor Ethernet0 route-map RM-HOST-OUT out
  neighbor Ethernet1 activate
  neighbor Ethernet1 route-map RM-HOST-IN in
  neighbor Ethernet1 route-map RM-HOST-OUT out
  neighbor Ethernet2 activate
  neighbor Ethernet2 route-map RM-HOST-IN in
  neighbor Ethernet2 route-map RM-HOST-OUT out
  neighbor Ethernet3 activate
  neighbor Ethernet3 route-map RM-HOST-IN in
  neighbor Ethernet3 route-map RM-HOST-OUT out
  neighbor Ethernet4 activate
  neighbor Ethernet4 route-map RM-HOST-IN in
  neighbor Ethernet4 route-map RM-HOST-OUT out
  neighbor Ethernet5 activate
  neighbor Ethernet5 route-map RM-HOST-IN in
  neighbor Ethernet5 route-map RM-HOST-OUT out
  neighbor Ethernet6 activate
  neighbor Ethernet6 route-map RM-HOST-IN in
  neighbor Ethernet6 route-map RM-HOST-OUT out
  neighbor Ethernet120 activate
  neighbor Ethernet124 activate
  maximum-paths 64
  maximum-paths ibgp 64
 exit-address-family
 !
 address-family ipv6 unicast
  neighbor Ethernet0 activate
  neighbor Ethernet1 activate
  neighbor Ethernet2 activate
  neighbor Ethernet3 activate
  neighbor Ethernet4 activate
  neighbor Ethernet5 activate
  neighbor Ethernet6 activate
  neighbor Ethernet120 activate
  neighbor Ethernet124 activate
  maximum-paths 64
  maximum-paths ibgp 64
 exit-address-family
exit
!
end
```
admin@Border-Leaf1:~$
admin@Border-Leaf1:~$ show ip bgp summary
```
IPv4 Unicast Summary:
BGP router identifier 10.0.2.4, local AS number 65031 vrf-id 0
BGP table version 120
RIB entries 0, using 0 bytes of memory
Peers 9, using 216648 KiB of memory
Peer groups 0, using 0 bytes of memory


Neighbhor      V     AS    MsgRcvd    MsgSent    TblVer    InQ    OutQ  Up/Down      State/PfxRcd  NeighborName
-----------  ---  -----  ---------  ---------  --------  -----  ------  ---------  --------------  --------------
Ethernet0      4  65251       1131       1096       120      0       0  00:50:35                0  Exit-Router1
Ethernet1      4  65252       1139       1101       120      0       0  00:50:35                0  Exit-Router2
Ethernet2      4  65231       1117       1118       120      0       0  00:19:58                0  k8s-master-03
Ethernet3      4  65232       1117       1117       120      0       0  00:19:41                0  k8s-db-03
Ethernet4      4  65233       1119       1117       120      0       0  00:19:10                0  osh-ctrl-03
Ethernet5      4  65234       1123       1116       120      0       0  00:18:56                0  MonSrv
Ethernet6      4  65235       1126       1118       120      0       0  00:18:30                0  osh-comp-03
Ethernet120    4  65000        129        145       120      0       0  00:50:36                0  Spine-S2
Ethernet124    4  65000        129        145       120      0       0  00:50:36                0  Spine-S1

Total number of neighbors 9
```
admin@Border-Leaf1:~$

admin@Leaf-L1:~$
admin@Leaf-L1:~$
admin@Leaf-L1:~$
admin@Leaf-L1:~$
admin@Leaf-L1:~$ show runningconfiguration bgp
Building configuration...
```
Current configuration:
!
frr version 10.5.4
frr defaults traditional
hostname Leaf-L1
agentx
service integrated-vtysh-config
!
ip prefix-list PL-HOST-IN seq 10 permit 10.10.255.0/24 ge 32 le 32
ip prefix-list PL-HOST-IN seq 20 permit 10.233.64.0/18
ip prefix-list PL-HOST-IN seq 30 permit 10.10.200.0/24 ge 32 le 32
ip prefix-list PL-HOST-IN seq 40 deny 10.233.0.0/18 le 32
ip prefix-list PL-HOST-IN seq 50 deny 172.16.2.0/24 le 32
ip prefix-list PL-HOST-IN seq 60 deny 172.16.2.200/29 le 32
ip prefix-list PL-HOST-IN seq 70 deny 20.0.56.0/24 le 32
ip prefix-list PL-HOST-OUT seq 10 permit 0.0.0.0/0
ip prefix-list PL-HOST-OUT seq 20 permit 10.10.255.0/24 ge 32 le 32
ip prefix-list PL-HOST-OUT seq 30 permit 10.10.200.0/24 ge 32 le 32
ip prefix-list PL-HOST-OUT seq 40 deny 10.233.0.0/18 le 32
ip prefix-list PL-HOST-OUT seq 50 deny 172.16.2.0/24 le 32
ip prefix-list PL-HOST-OUT seq 60 deny 172.16.2.200/29 le 32
ip prefix-list PL-HOST-OUT seq 70 deny 20.0.56.0/24 le 32
!
route-map RM-HOST-IN permit 10
 match ip address prefix-list PL-HOST-IN
exit
!
route-map RM-HOST-IN deny 100
exit
!
route-map RM-HOST-OUT permit 10
 match ip address prefix-list PL-HOST-OUT
exit
!
route-map RM-HOST-OUT deny 100
exit
!
password zebra
enable password zebra
!
router bgp 65011
 bgp router-id 10.0.2.1
 bgp log-neighbor-changes
 no bgp ebgp-requires-policy
 no bgp default ipv4-unicast
 neighbor Ethernet0 interface remote-as external
 neighbor Ethernet0 description k8s-master-01
 neighbor Ethernet0 bfd
 neighbor Ethernet0 bfd check-control-plane-failure
 no neighbor Ethernet0 capability link-local
 neighbor Ethernet1 interface remote-as external
 neighbor Ethernet1 description k8s-db-01
 neighbor Ethernet1 bfd
 neighbor Ethernet1 bfd check-control-plane-failure
 no neighbor Ethernet1 capability link-local
 neighbor Ethernet2 interface remote-as external
 neighbor Ethernet2 description osh-ctrl-01
 neighbor Ethernet2 bfd
 neighbor Ethernet2 bfd check-control-plane-failure
 no neighbor Ethernet2 capability link-local
 neighbor Ethernet3 interface remote-as external
 neighbor Ethernet3 description osh-net-01
 neighbor Ethernet3 bfd
 neighbor Ethernet3 bfd check-control-plane-failure
 no neighbor Ethernet3 capability link-local
 neighbor Ethernet4 interface remote-as external
 neighbor Ethernet4 description osh-comp-01
 neighbor Ethernet4 bfd
 neighbor Ethernet4 bfd check-control-plane-failure
 no neighbor Ethernet4 capability link-local
 neighbor Ethernet5 interface remote-as external
 neighbor Ethernet5 description osh-comp-04
 neighbor Ethernet5 bfd
 neighbor Ethernet5 bfd check-control-plane-failure
 no neighbor Ethernet5 capability link-local
 neighbor Ethernet64 interface remote-as external
 neighbor Ethernet64 description Spine-S2
 neighbor Ethernet64 bfd
 neighbor Ethernet64 bfd check-control-plane-failure
 no neighbor Ethernet64 capability link-local
 neighbor Ethernet68 interface remote-as external
 neighbor Ethernet68 description Spine-S1
 neighbor Ethernet68 bfd
 neighbor Ethernet68 bfd check-control-plane-failure
 no neighbor Ethernet68 capability link-local
 !
 address-family ipv4 unicast
  neighbor Ethernet0 activate
  neighbor Ethernet0 route-map RM-HOST-IN in
  neighbor Ethernet0 route-map RM-HOST-OUT out
  neighbor Ethernet1 activate
  neighbor Ethernet1 route-map RM-HOST-IN in
  neighbor Ethernet1 route-map RM-HOST-OUT out
  neighbor Ethernet2 activate
  neighbor Ethernet2 route-map RM-HOST-IN in
  neighbor Ethernet2 route-map RM-HOST-OUT out
  neighbor Ethernet3 activate
  neighbor Ethernet3 route-map RM-HOST-IN in
  neighbor Ethernet3 route-map RM-HOST-OUT out
  neighbor Ethernet4 activate
  neighbor Ethernet4 route-map RM-HOST-IN in
  neighbor Ethernet4 route-map RM-HOST-OUT out
  neighbor Ethernet5 activate
  neighbor Ethernet5 route-map RM-HOST-IN in
  neighbor Ethernet5 route-map RM-HOST-OUT out
  neighbor Ethernet64 activate
  neighbor Ethernet68 activate
  maximum-paths 64
  maximum-paths ibgp 64
 exit-address-family
 !
 address-family ipv6 unicast
  neighbor Ethernet0 activate
  neighbor Ethernet1 activate
  neighbor Ethernet2 activate
  neighbor Ethernet3 activate
  neighbor Ethernet4 activate
  neighbor Ethernet5 activate
  neighbor Ethernet64 activate
  neighbor Ethernet68 activate
  maximum-paths 64
  maximum-paths ibgp 64
 exit-address-family
exit
!
end
```
admin@Leaf-L1:~$
admin@Leaf-L1:~$ show ip bgp summary
```
IPv4 Unicast Summary:
BGP router identifier 10.0.2.1, local AS number 65011 vrf-id 0
BGP table version 255
RIB entries 0, using 0 bytes of memory
Peers 8, using 192576 KiB of memory
Peer groups 0, using 0 bytes of memory


Neighbhor      V     AS    MsgRcvd    MsgSent    TblVer    InQ    OutQ  Up/Down      State/PfxRcd  NeighborName
-----------  ---  -----  ---------  ---------  --------  -----  ------  ---------  --------------  --------------
Ethernet0      4  65211       1242       1222       255      0       0  00:19:15                0  k8s-master-01
Ethernet1      4  65212       1242       1221       255      0       0  00:19:00                0  k8s-db-01
Ethernet2      4  65213        380        378       255      0       0  00:18:33                0  osh-ctrl-01
Ethernet3      4  65214       1238       1220       255      0       0  00:18:16                0  osh-net-01
Ethernet4      4  65215       1229       1219       255      0       0  00:17:52                0  osh-comp-01
Ethernet5      4  65216       1237       1219       255      0       0  00:17:25                0  osh-comp-04
Ethernet64     4  65000        201        206       255      0       0  00:49:56                0  Spine-S2
Ethernet68     4  65000        206        205       255      0       0  00:49:54                0  Spine-S1

Total number of neighbors 8
```
admin@Leaf-L1:~$

admin@Leaf-L3:~$
admin@Leaf-L3:~$
admin@Leaf-L3:~$ show runningconfiguration bgp
Building configuration...
```
Current configuration:
!
frr version 10.5.4
frr defaults traditional
hostname Leaf-L3
agentx
service integrated-vtysh-config
!
ip prefix-list PL-HOST-IN seq 10 permit 10.10.255.0/24 ge 32 le 32
ip prefix-list PL-HOST-IN seq 20 permit 10.233.64.0/18
ip prefix-list PL-HOST-IN seq 30 permit 10.10.200.0/24 ge 32 le 32
ip prefix-list PL-HOST-IN seq 40 deny 10.233.0.0/18 le 32
ip prefix-list PL-HOST-IN seq 50 deny 172.16.2.0/24 le 32
ip prefix-list PL-HOST-IN seq 60 deny 172.16.2.200/29 le 32
ip prefix-list PL-HOST-IN seq 70 deny 20.0.56.0/24 le 32
ip prefix-list PL-HOST-OUT seq 10 permit 0.0.0.0/0
ip prefix-list PL-HOST-OUT seq 20 permit 10.10.255.0/24 ge 32 le 32
ip prefix-list PL-HOST-OUT seq 30 permit 10.10.200.0/24 ge 32 le 32
ip prefix-list PL-HOST-OUT seq 40 deny 10.233.0.0/18 le 32
ip prefix-list PL-HOST-OUT seq 50 deny 172.16.2.0/24 le 32
ip prefix-list PL-HOST-OUT seq 60 deny 172.16.2.200/29 le 32
ip prefix-list PL-HOST-OUT seq 70 deny 20.0.56.0/24 le 32
!
route-map RM-HOST-IN permit 10
 match ip address prefix-list PL-HOST-IN
exit
!
route-map RM-HOST-IN deny 100
exit
!
route-map RM-HOST-OUT permit 10
 match ip address prefix-list PL-HOST-OUT
exit
!
route-map RM-HOST-OUT deny 100
exit
!
password zebra
enable password zebra
!
vrf Vrf-storage
exit-vrf
!
router bgp 65021 vrf Vrf-storage
 bgp router-id 10.0.2.3
 bgp log-neighbor-changes
 no bgp ebgp-requires-policy
 no bgp default ipv4-unicast
 neighbor Ethernet8.100 interface remote-as 65223
 neighbor Ethernet8.100 description STORAGE-To-osh-ctrl-02
 neighbor Ethernet8.100 bfd
 no neighbor Ethernet8.100 capability link-local
 neighbor Ethernet12.100 interface remote-as 65224
 neighbor Ethernet12.100 description STORAGE-To-osh-net-02
 neighbor Ethernet12.100 bfd
 no neighbor Ethernet12.100 capability link-local
 neighbor Ethernet16.100 interface remote-as 65225
 neighbor Ethernet16.100 description STORAGE-To-osh-comp-02
 neighbor Ethernet16.100 bfd
 no neighbor Ethernet16.100 capability link-local
 neighbor Ethernet120.100 interface remote-as 65000
 neighbor Ethernet120.100 description STORAGE-To-Spine-S2
 neighbor Ethernet120.100 bfd
 no neighbor Ethernet120.100 capability link-local
 neighbor Ethernet124.100 interface remote-as 65000
 neighbor Ethernet124.100 description STORAGE-To-Spine-S1
 neighbor Ethernet124.100 bfd
 no neighbor Ethernet124.100 capability link-local
 !
 address-family ipv4 unicast
  redistribute connected
  neighbor Ethernet8.100 activate
  neighbor Ethernet12.100 activate
  neighbor Ethernet16.100 activate
  neighbor Ethernet120.100 activate
  neighbor Ethernet124.100 activate
  maximum-paths 64
 exit-address-family
 !
 address-family ipv6 unicast
  neighbor Ethernet8.100 activate
  neighbor Ethernet12.100 activate
  neighbor Ethernet16.100 activate
  neighbor Ethernet120.100 activate
  neighbor Ethernet124.100 activate
  maximum-paths 64
 exit-address-family
exit
!
router bgp 65021
 bgp router-id 10.0.2.3
 bgp log-neighbor-changes
 no bgp ebgp-requires-policy
 no bgp default ipv4-unicast
 neighbor Ethernet0 interface remote-as external
 neighbor Ethernet0 description k8s-master-02
 neighbor Ethernet0 bfd
 no neighbor Ethernet0 capability link-local
 neighbor Ethernet1 interface remote-as external
 neighbor Ethernet1 description k8s-db-02
 neighbor Ethernet1 bfd
 no neighbor Ethernet1 capability link-local
 neighbor Ethernet2 interface remote-as external
 neighbor Ethernet2 description osh-ctrl-02
 neighbor Ethernet2 bfd
 no neighbor Ethernet2 capability link-local
 neighbor Ethernet3 interface remote-as external
 neighbor Ethernet3 description osh-net-02
 neighbor Ethernet3 bfd
 no neighbor Ethernet3 capability link-local
 neighbor Ethernet4 interface remote-as external
 neighbor Ethernet4 description osh-comp-02
 neighbor Ethernet4 bfd
 no neighbor Ethernet4 capability link-local
 neighbor Ethernet120 interface remote-as external
 neighbor Ethernet120 description Spine-S2
 neighbor Ethernet120 bfd
 no neighbor Ethernet120 capability link-local
 neighbor Ethernet124 interface remote-as external
 neighbor Ethernet124 description Spine-S1
 neighbor Ethernet124 bfd
 no neighbor Ethernet124 capability link-local
 !
 address-family ipv4 unicast
  neighbor Ethernet0 activate
  neighbor Ethernet0 route-map RM-HOST-IN in
  neighbor Ethernet0 route-map RM-HOST-OUT out
  neighbor Ethernet1 activate
  neighbor Ethernet1 route-map RM-HOST-IN in
  neighbor Ethernet1 route-map RM-HOST-OUT out
  neighbor Ethernet2 activate
  neighbor Ethernet2 route-map RM-HOST-IN in
  neighbor Ethernet2 route-map RM-HOST-OUT out
  neighbor Ethernet3 activate
  neighbor Ethernet3 route-map RM-HOST-IN in
  neighbor Ethernet3 route-map RM-HOST-OUT out
  neighbor Ethernet4 activate
  neighbor Ethernet4 route-map RM-HOST-IN in
  neighbor Ethernet4 route-map RM-HOST-OUT out
  neighbor Ethernet120 activate
  neighbor Ethernet124 activate
  maximum-paths 64
  maximum-paths ibgp 64
 exit-address-family
 !
 address-family ipv6 unicast
  neighbor Ethernet0 activate
  neighbor Ethernet1 activate
  neighbor Ethernet2 activate
  neighbor Ethernet3 activate
  neighbor Ethernet4 activate
  neighbor Ethernet120 activate
  neighbor Ethernet124 activate
  maximum-paths 64
  maximum-paths ibgp 64
 exit-address-family
exit
!
end
```
admin@Leaf-L3:~$
admin@Leaf-L3:~$ show ip bgp summary
```
IPv4 Unicast Summary:
BGP router identifier 10.0.2.3, local AS number 65021 vrf-id 0
BGP table version 231
RIB entries 0, using 0 bytes of memory
Peers 7, using 168504 KiB of memory
Peer groups 0, using 0 bytes of memory


Neighbhor      V     AS    MsgRcvd    MsgSent    TblVer    InQ    OutQ  Up/Down      State/PfxRcd  NeighborName
-----------  ---  -----  ---------  ---------  --------  -----  ------  ---------  --------------  --------------
Ethernet0      4  65221       1079       1068       231      0       0  00:18:37                0  k8s-master-02
Ethernet1      4  65222       1071       1063       231      0       0  00:18:07                0  k8s-db-02
Ethernet2      4  65223        424        405       231      0       0  00:17:55                0  osh-ctrl-02
Ethernet3      4  65224       1084       1071       231      0       0  00:17:24                0  osh-net-02
Ethernet4      4  65225       1067       1067       231      0       0  00:17:05                0  osh-comp-02
Ethernet120    4  65000        118        132       231      0       0  00:49:18                0  Spine-S2
Ethernet124    4  65000        123        127       231      0       0  00:49:18                0  Spine-S1

Total number of neighbors 7
```
admin@Leaf-L3:~$




XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
Server Hosts:
ubuntu@Exit-Router1:~$ sudo vtysh

Hello, this is FRRouting (version 10.5.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

Exit-Router1# show running-config bgpd
Building configuration...
```
Current configuration:
!
frr version 10.5.1
frr defaults datacenter
hostname Exit-Router1
service integrated-vtysh-config
!
ip prefix-list PL-NO-MGMT seq 5 deny 172.16.2.0/24
ip prefix-list PL-NO-MGMT seq 10 permit 0.0.0.0/0 le 32
!
route-map RM-REDIST-CONN permit 10
 match ip address prefix-list PL-NO-MGMT
exit
!
vrf vrf-internet
exit-vrf
!
router bgp 65251
 bgp router-id 10.255.255.1
 no bgp default ipv4-unicast
 bgp bestpath as-path multipath-relax
 neighbor ens2 interface remote-as 65031
 neighbor ens2 description To-Border-Leaf1-Ethernet0
 no neighbor ens2 capability link-local
 neighbor ens3 interface remote-as 65032
 neighbor ens3 description To-Border-Leaf2-Ethernet1
 no neighbor ens3 capability link-local
 !
 address-family ipv4 unicast
  network 10.255.255.1/32
  neighbor ens2 activate
  neighbor ens2 next-hop-self
  neighbor ens2 default-originate
  neighbor ens3 activate
  neighbor ens3 next-hop-self
  neighbor ens3 default-originate
  maximum-paths 2
  import vrf vrf-internet
 exit-address-family
exit
!
router bgp 65251 vrf vrf-internet
 bgp router-id 10.255.255.1
 no bgp default ipv4-unicast
 neighbor ens4 interface remote-as 65401
 neighbor ens4 description To-ISP_1
 no neighbor ens4 capability link-local
 neighbor ens5 interface remote-as 65402
 neighbor ens5 description To-ISP_2
 no neighbor ens5 capability link-local
 !
 address-family ipv4 unicast
  redistribute connected route-map RM-REDIST-CONN
  redistribute static
  neighbor ens4 activate
  neighbor ens5 activate
  import vrf default
 exit-address-family
exit
!
end
```
Exit-Router1# show ip bgp summary
```
IPv4 Unicast Summary:
BGP router identifier 10.255.255.1, local AS number 65251 VRF default vrf-id 0
BGP table version 249
RIB entries 41, using 5248 bytes of memory
Peers 2, using 47 KiB of memory

Neighbor           V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt Desc
Border-Leaf1(ens2) 4      65031      1294      1366      249    0    0 00:52:47            0       13 To-Border-Leaf1-Ethe
Border-Leaf2(ens3) 4      65032      1337      1389      249    0    0 00:52:47            0       13 To-Border-Leaf2-Ethe

Total number of neighbors 2
Exit-Router1#
Exit-Router1# show ip route
Codes: K - kernel route, C - connected, L - local, S - static,
       R - RIP, O - OSPF, I - IS-IS, B - BGP, E - EIGRP, N - NHRP,
       T - Table, v - VNC, V - VNC-Direct, A - Babel, F - PBR,
       f - OpenFabric, t - Table-Direct,
       > - selected route, * - FIB route, q - queued, r - rejected, b - backup
       t - trapped, o - offload failure

IPv4 unicast VRF default:
B   0.0.0.0/0 [250/0] via 192.0.2.1, ens4 (vrf vrf-internet), weight 1, 04:30:04
K * 0.0.0.0/0 [0/200] via 172.16.2.254, enp1s0, weight 1, 04:30:04
K * 0.0.0.0/0 [0/100] via 10.0.0.2, enp1s0, weight 1, 04:30:04
K>* 0.0.0.0/0 [0/0] via 10.0.0.2, enp1s0, weight 1, 04:30:04
C>* 10.0.0.0/24 is directly connected, enp1s0, weight 1, 04:30:04
L>* 10.0.0.15/32 is directly connected, enp1s0, weight 1, 04:30:04
C>* 10.254.0.0/24 is directly connected, wg0, weight 1, 04:29:45
L>* 10.254.0.1/32 is directly connected, wg0, weight 1, 04:29:45
L * 10.255.255.1/32 is directly connected, lo, weight 1, 04:30:04
C>* 10.255.255.1/32 is directly connected, lo, weight 1, 04:30:04
B>* 10.255.255.2/32 [20/0] via 192.0.2.1, ens4 (vrf vrf-internet), weight 1, 03:48:45
  *                        via 198.51.100.1, ens5 (vrf vrf-internet), weight 1, 03:48:45
B>* 10.255.255.11/32 [20/0] via 192.0.2.1, ens4 (vrf vrf-internet), weight 1, 04:27:16
B>* 10.255.255.12/32 [20/0] via 198.51.100.1, ens5 (vrf vrf-internet), weight 1, 04:27:16
B>* 100.64.0.0/30 [20/0] via 192.0.2.1, ens4 (vrf vrf-internet), weight 1, 04:27:16
B>* 100.64.0.4/30 [20/0] via 198.51.100.1, ens5 (vrf vrf-internet), weight 1, 04:27:16
B>* 100.64.100.10/32 [1/0] unreachable (blackhole), weight 1, 04:30:04
C>* 172.16.2.0/24 is directly connected, enp1s0, weight 1, 04:30:04
L>* 172.16.2.41/32 is directly connected, enp1s0, weight 1, 04:30:04
B>* 192.0.2.0/30 [20/0] is directly connected, vrf-internet (vrf vrf-internet), weight 1, 04:29:59
B>* 192.0.2.4/30 [20/0] via 192.0.2.1, ens4 (vrf vrf-internet), weight 1, 04:27:16
B>* 192.168.254.0/30 [20/0] via 192.0.2.1, ens4 (vrf vrf-internet), weight 1, 04:27:16
  *                         via 198.51.100.1, ens5 (vrf vrf-internet), weight 1, 04:27:16
B>* 198.51.100.0/30 [20/0] is directly connected, vrf-internet (vrf vrf-internet), weight 1, 04:29:59
B>* 198.51.100.4/30 [20/0] via 198.51.100.1, ens5 (vrf vrf-internet), weight 1, 04:27:16
Exit-Router1#
Exit-Router1#
```

XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
ubuntu@Exit-Router2:~$ sudo vtysh

Hello, this is FRRouting (version 10.5.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

Exit-Router2# show running-config bgpd
Building configuration...
```
Current configuration:
!
frr version 10.5.1
frr defaults datacenter
hostname Exit-Router2
service integrated-vtysh-config
!
ip prefix-list PL-NO-MGMT seq 5 deny 172.16.2.0/24
ip prefix-list PL-NO-MGMT seq 10 permit 0.0.0.0/0 le 32
!
route-map RM-REDIST-CONN permit 10
 match ip address prefix-list PL-NO-MGMT
exit
!
vrf vrf-internet
exit-vrf
!
router bgp 65252
 bgp router-id 10.255.255.2
 no bgp default ipv4-unicast
 bgp bestpath as-path multipath-relax
 neighbor ens2 interface remote-as 65031
 neighbor ens2 description To-Border-Leaf1-Ethernet1
 no neighbor ens2 capability link-local
 neighbor ens3 interface remote-as 65032
 neighbor ens3 description To-Border-Leaf2-Ethernet0
 no neighbor ens3 capability link-local
 !
 address-family ipv4 unicast
  network 10.255.255.2/32
  neighbor ens2 activate
  neighbor ens2 next-hop-self
  neighbor ens2 default-originate
  neighbor ens3 activate
  neighbor ens3 next-hop-self
  neighbor ens3 default-originate
  maximum-paths 2
  import vrf vrf-internet
 exit-address-family
exit
!
router bgp 65252 vrf vrf-internet
 bgp router-id 10.255.255.2
 no bgp default ipv4-unicast
 neighbor ens4 interface remote-as 65401
 neighbor ens4 description To-ISP_1
 no neighbor ens4 capability link-local
 neighbor ens5 interface remote-as 65402
 neighbor ens5 description To-ISP_2
 no neighbor ens5 capability link-local
 !
 address-family ipv4 unicast
  redistribute connected route-map RM-REDIST-CONN
  redistribute static
  neighbor ens4 activate
  neighbor ens5 activate
  import vrf default
 exit-address-family
exit
!
end
```
Exit-Router2#
Exit-Router2# show ip bgp summary
```
IPv4 Unicast Summary:
BGP router identifier 10.255.255.2, local AS number 65252 VRF default vrf-id 0
BGP table version 287
RIB entries 57, using 7296 bytes of memory
Peers 2, using 47 KiB of memory

Neighbor           V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt Desc
Border-Leaf1(ens2) 4      65031      1332      1385      287    0    0 00:54:24            0       13 To-Border-Leaf1-Ethe
Border-Leaf2(ens3) 4      65032      1367      1409      287    0    0 00:54:24            0       13 To-Border-Leaf2-Ethe

Total number of neighbors 2
```
Exit-Router2#

Exit-Router2#
Exit-Router2# show ip route
```
Codes: K - kernel route, C - connected, L - local, S - static,
       R - RIP, O - OSPF, I - IS-IS, B - BGP, E - EIGRP, N - NHRP,
       T - Table, v - VNC, V - VNC-Direct, A - Babel, F - PBR,
       f - OpenFabric, t - Table-Direct,
       > - selected route, * - FIB route, q - queued, r - rejected, b - backup
       t - trapped, o - offload failure

IPv4 unicast VRF default:
B   0.0.0.0/0 [250/0] via 192.0.2.5, ens4 (vrf vrf-internet), weight 1, 04:31:48
K * 0.0.0.0/0 [0/200] via 172.16.2.254, enp1s0, weight 1, 04:31:49
K * 0.0.0.0/0 [0/100] via 10.0.0.2, enp1s0, weight 1, 04:31:49
K>* 0.0.0.0/0 [0/0] via 10.0.0.2, enp1s0, weight 1, 04:31:49
C>* 10.0.0.0/24 is directly connected, enp1s0, weight 1, 04:31:49
L>* 10.0.0.15/32 is directly connected, enp1s0, weight 1, 04:31:49
C>* 10.254.0.0/24 is directly connected, wg0, weight 1, 04:31:30
L>* 10.254.0.2/32 is directly connected, wg0, weight 1, 04:31:30
B>* 10.255.255.1/32 [20/0] via 192.0.2.5, ens4 (vrf vrf-internet), weight 1, 03:50:30
  *                        via 198.51.100.5, ens5 (vrf vrf-internet), weight 1, 03:50:30
L * 10.255.255.2/32 is directly connected, lo, weight 1, 04:31:48
C>* 10.255.255.2/32 is directly connected, lo, weight 1, 04:31:48
B>* 10.255.255.11/32 [20/0] via 192.0.2.5, ens4 (vrf vrf-internet), weight 1, 04:29:01
B>* 10.255.255.12/32 [20/0] via 198.51.100.5, ens5 (vrf vrf-internet), weight 1, 04:29:01
B>* 100.64.0.0/30 [20/0] via 192.0.2.5, ens4 (vrf vrf-internet), weight 1, 04:29:01
B>* 100.64.0.4/30 [20/0] via 198.51.100.5, ens5 (vrf vrf-internet), weight 1, 04:29:01
B>* 100.64.100.10/32 [1/0] unreachable (blackhole), weight 1, 04:31:48
C>* 172.16.2.0/24 is directly connected, enp1s0, weight 1, 04:31:49
L>* 172.16.2.42/32 is directly connected, enp1s0, weight 1, 04:31:49
B>* 192.0.2.0/30 [20/0] via 192.0.2.5, ens4 (vrf vrf-internet), weight 1, 04:29:01
B>* 192.0.2.4/30 [20/0] is directly connected, vrf-internet (vrf vrf-internet), weight 1, 04:31:43
B>* 192.168.254.0/30 [20/0] via 192.0.2.5, ens4 (vrf vrf-internet), weight 1, 03:50:30
  *                         via 198.51.100.5, ens5 (vrf vrf-internet), weight 1, 03:50:30
B>* 198.51.100.0/30 [20/0] via 198.51.100.5, ens5 (vrf vrf-internet), weight 1, 04:29:01
B>* 198.51.100.4/30 [20/0] is directly connected, vrf-internet (vrf vrf-internet), weight 1, 04:31:43
Exit-Router2#
```

XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
ubuntu@k8s-master-01:~$ sudo vtysh

Hello, this is FRRouting (version 10.5.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

k8s-master-01# show running-config bgpd
Building configuration...
```
Current configuration:
!
frr version 10.5.1
frr defaults datacenter
hostname k8s-master-01
service integrated-vtysh-config
!
ip prefix-list METALLB-POOL seq 10 permit 10.10.200.0/24 le 32
ip prefix-list METALLB-POOL seq 20 permit 172.16.2.200/29 le 32
!
route-map ACCEPT-METALLB permit 10
 match ip address prefix-list METALLB-POOL
exit
!
route-map DENY-ALL deny 10
exit
!
router bgp 65211
 bgp router-id 10.0.10.1
 no bgp default ipv4-unicast
 bgp bestpath as-path multipath-relax
 neighbor ens2 interface remote-as 65011
 neighbor ens2 description To-Leaf-L1-Ethernet0
 neighbor ens2 bfd
 neighbor ens2 bfd profile FABRIC-BFD
 no neighbor ens2 capability link-local
 neighbor ens3 interface remote-as 65012
 neighbor ens3 description To-Leaf-L2-Ethernet0
 neighbor ens3 bfd
 neighbor ens3 bfd profile FABRIC-BFD
 no neighbor ens3 capability link-local
 neighbor 127.0.0.1 remote-as 64512
 neighbor 127.0.0.1 description MetalLB-speaker
 neighbor 127.0.0.1 update-source 127.0.0.1
 bgp allow-martian-nexthop
 !
 address-family ipv4 unicast
  network 10.0.10.1/32
  network 192.168.20.11/32
  neighbor ens2 activate
  neighbor ens3 activate
  neighbor 127.0.0.1 activate
  neighbor 127.0.0.1 route-map ACCEPT-METALLB in
  neighbor 127.0.0.1 route-map DENY-ALL out
  maximum-paths 2
  maximum-paths ibgp 2
 exit-address-family
exit
!
end
```
k8s-master-01#
k8s-master-01#
k8s-master-01# show ip bgp summary
```
IPv4 Unicast Summary:
BGP router identifier 10.0.10.1, local AS number 65211 VRF default vrf-id 0
BGP table version 6
RIB entries 3, using 384 bytes of memory
Peers 3, using 71 KiB of memory

Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt Desc
Leaf-L1(ens2)   4      65011       518       521        6    0    0 00:25:36            0        2 To-Leaf-L1-Ethernet0
Leaf-L2(ens3)   4      65012       520       523        6    0    0 00:25:40            0        2 To-Leaf-L2-Ethernet0
127.0.0.1       4      64512         0         0        0    0    0    never       Active        0 MetalLB-speaker

Total number of neighbors 3
```
k8s-master-01#
XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
osh-ctrl-01# show running-config bgpd
Building configuration...
```
Current configuration:
!
frr version 10.5.1
frr defaults datacenter
hostname osh-ctrl-01
service integrated-vtysh-config
!
ip prefix-list METALLB-POOL seq 10 permit 10.10.200.0/24 le 32
ip prefix-list METALLB-POOL seq 20 permit 172.16.2.200/29 le 32
!
route-map ACCEPT-METALLB permit 10
 match ip address prefix-list METALLB-POOL
exit
!
route-map DENY-ALL deny 10
exit
!
router bgp 65213
 bgp router-id 10.0.10.3
 no bgp default ipv4-unicast
 bgp bestpath as-path multipath-relax
 neighbor ens2 interface remote-as 65011
 neighbor ens2 description To-Leaf-L1-Ethernet2
 neighbor ens2 bfd
 neighbor ens2 bfd profile FABRIC-BFD
 no neighbor ens2 capability link-local
 neighbor ens3 interface remote-as 65012
 neighbor ens3 description To-Leaf-L2-Ethernet2
 neighbor ens3 bfd
 neighbor ens3 bfd profile FABRIC-BFD
 no neighbor ens3 capability link-local
 neighbor 127.0.0.1 remote-as 64512
 neighbor 127.0.0.1 description MetalLB-speaker
 neighbor 127.0.0.1 update-source 127.0.0.1
 bgp allow-martian-nexthop
 !
 address-family ipv4 unicast
  network 10.0.10.3/32
  network 192.168.20.13/32
  neighbor ens2 activate
  neighbor ens3 activate
  neighbor 127.0.0.1 activate
  neighbor 127.0.0.1 route-map ACCEPT-METALLB in
  neighbor 127.0.0.1 route-map DENY-ALL out
  maximum-paths 2
  maximum-paths ibgp 2
 exit-address-family
exit
!
end
```
osh-ctrl-01#
osh-ctrl-01# show ip bgp summary
```
IPv4 Unicast Summary:
BGP router identifier 10.0.10.3, local AS number 65213 VRF default vrf-id 0
BGP table version 5
RIB entries 3, using 384 bytes of memory
Peers 3, using 71 KiB of memory

Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt Desc
Leaf-L1(ens2)   4      65011       531       534        5    0    0 00:26:15            0        2 To-Leaf-L1-Ethernet2
Leaf-L2(ens3)   4      65012       531       534        5    0    0 00:26:15            0        2 To-Leaf-L2-Ethernet2
127.0.0.1       4      64512         0         0        0    0    0    never       Active        0 MetalLB-speaker

Total number of neighbors 3
```
osh-ctrl-01#
XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
ubuntu@osh-net-01:~$ sudo vtysh

Hello, this is FRRouting (version 10.5.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

osh-net-01# show running-config bgpd
Building configuration...

Current configuration:
!
frr version 10.5.1
frr defaults datacenter
hostname osh-net-01
service integrated-vtysh-config
!
ip prefix-list METALLB-POOL seq 10 permit 10.10.200.0/24 le 32
ip prefix-list METALLB-POOL seq 20 permit 172.16.2.200/29 le 32
!
route-map ACCEPT-METALLB permit 10
 match ip address prefix-list METALLB-POOL
exit
!
route-map DENY-ALL deny 10
exit
!
router bgp 65214
 bgp router-id 10.0.10.4
 no bgp default ipv4-unicast
 bgp bestpath as-path multipath-relax
 neighbor ens2 interface remote-as 65011
 neighbor ens2 description To-Leaf-L1-Ethernet3
 neighbor ens2 bfd
 neighbor ens2 bfd profile FABRIC-BFD
 no neighbor ens2 capability link-local
 neighbor ens3 interface remote-as 65012
 neighbor ens3 description To-Leaf-L2-Ethernet3
 neighbor ens3 bfd
 neighbor ens3 bfd profile FABRIC-BFD
 no neighbor ens3 capability link-local
 neighbor 127.0.0.1 remote-as 64512
 neighbor 127.0.0.1 description MetalLB-speaker
 neighbor 127.0.0.1 update-source 127.0.0.1
 bgp allow-martian-nexthop
 !
 address-family ipv4 unicast
  network 10.0.10.4/32
  network 192.168.20.14/32
  neighbor ens2 activate
  neighbor ens3 activate
  neighbor 127.0.0.1 activate
  neighbor 127.0.0.1 route-map ACCEPT-METALLB in
  neighbor 127.0.0.1 route-map DENY-ALL out
  maximum-paths 2
  maximum-paths ibgp 2
 exit-address-family
exit
!
end
osh-net-01#
osh-net-01# show ip bgp summary

IPv4 Unicast Summary:
BGP router identifier 10.0.10.4, local AS number 65214 VRF default vrf-id 0
BGP table version 6
RIB entries 3, using 384 bytes of memory
Peers 3, using 71 KiB of memory

Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt Desc
Leaf-L1(ens2)   4      65011       558       561        6    0    0 00:27:36            0        2 To-Leaf-L1-Ethernet3
Leaf-L2(ens3)   4      65012       558       561        6    0    0 00:27:34            0        2 To-Leaf-L2-Ethernet3
127.0.0.1       4      64512         0         0        0    0    0    never       Active        0 MetalLB-speaker

Total number of neighbors 3
osh-net-01#
XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
ubuntu@osh-comp-01:~$ sudo vtysh

Hello, this is FRRouting (version 10.5.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

osh-comp-01# show running-config bgpd
Building configuration...

Current configuration:
!
frr version 10.5.1
frr defaults datacenter
hostname osh-comp-01
service integrated-vtysh-config
!
ip prefix-list METALLB-POOL seq 10 permit 10.10.200.0/24 le 32
ip prefix-list METALLB-POOL seq 20 permit 172.16.2.200/29 le 32
!
route-map ACCEPT-METALLB permit 10
 match ip address prefix-list METALLB-POOL
exit
!
route-map DENY-ALL deny 10
exit
!
router bgp 65215
 bgp router-id 10.0.10.5
 no bgp default ipv4-unicast
 bgp bestpath as-path multipath-relax
 neighbor ens2 interface remote-as 65011
 neighbor ens2 description To-Leaf-L1-Ethernet4
 neighbor ens2 bfd
 neighbor ens2 bfd profile FABRIC-BFD
 no neighbor ens2 capability link-local
 neighbor ens3 interface remote-as 65012
 neighbor ens3 description To-Leaf-L2-Ethernet4
 neighbor ens3 bfd
 neighbor ens3 bfd profile FABRIC-BFD
 no neighbor ens3 capability link-local
 neighbor 127.0.0.1 remote-as 64512
 neighbor 127.0.0.1 description MetalLB-speaker
 neighbor 127.0.0.1 update-source 127.0.0.1
 bgp allow-martian-nexthop
 !
 address-family ipv4 unicast
  network 10.0.10.5/32
  network 192.168.20.15/32
  neighbor ens2 activate
  neighbor ens3 activate
  neighbor 127.0.0.1 activate
  neighbor 127.0.0.1 route-map ACCEPT-METALLB in
  neighbor 127.0.0.1 route-map DENY-ALL out
  maximum-paths 2
  maximum-paths ibgp 2
 exit-address-family
exit
!
end
osh-comp-01#
osh-comp-01# show ip bgp summary

IPv4 Unicast Summary:
BGP router identifier 10.0.10.5, local AS number 65215 VRF default vrf-id 0
BGP table version 5
RIB entries 3, using 384 bytes of memory
Peers 3, using 71 KiB of memory

Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt Desc
Leaf-L1(ens2)   4      65011       595       598        5    0    0 00:29:26            0        2 To-Leaf-L1-Ethernet4
Leaf-L2(ens3)   4      65012       595       598        5    0    0 00:29:26            0        2 To-Leaf-L2-Ethernet4
127.0.0.1       4      64512         0         0        0    0    0    never       Active        0 MetalLB-speaker

Total number of neighbors 3
osh-comp-01#
XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
ubuntu@osh-comp-04:~$ sudo vtysh

Hello, this is FRRouting (version 10.5.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

osh-comp-04# show running-config bgpd
Building configuration...

Current configuration:
!
frr version 10.5.1
frr defaults datacenter
hostname osh-comp-04
service integrated-vtysh-config
!
ip prefix-list METALLB-POOL seq 10 permit 10.10.200.0/24 le 32
ip prefix-list METALLB-POOL seq 20 permit 172.16.2.200/29 le 32
!
route-map ACCEPT-METALLB permit 10
 match ip address prefix-list METALLB-POOL
exit
!
route-map DENY-ALL deny 10
exit
!
router bgp 65216
 bgp router-id 10.0.10.6
 no bgp default ipv4-unicast
 bgp bestpath as-path multipath-relax
 neighbor ens2 interface remote-as 65011
 neighbor ens2 description To-Leaf-L1-Ethernet5
 neighbor ens2 bfd
 neighbor ens2 bfd profile FABRIC-BFD
 no neighbor ens2 capability link-local
 neighbor ens3 interface remote-as 65012
 neighbor ens3 description To-Leaf-L2-Ethernet5
 neighbor ens3 bfd
 neighbor ens3 bfd profile FABRIC-BFD
 no neighbor ens3 capability link-local
 neighbor 127.0.0.1 remote-as 64512
 neighbor 127.0.0.1 description MetalLB-speaker
 neighbor 127.0.0.1 update-source 127.0.0.1
 bgp allow-martian-nexthop
 !
 address-family ipv4 unicast
  network 10.0.10.6/32
  network 192.168.20.16/32
  neighbor ens2 activate
  neighbor ens3 activate
  neighbor 127.0.0.1 activate
  neighbor 127.0.0.1 route-map ACCEPT-METALLB in
  neighbor 127.0.0.1 route-map DENY-ALL out
  maximum-paths 2
  maximum-paths ibgp 2
 exit-address-family
exit
!
end
osh-comp-04#
osh-comp-04# show ip bgp summary

IPv4 Unicast Summary:
BGP router identifier 10.0.10.6, local AS number 65216 VRF default vrf-id 0
BGP table version 6
RIB entries 3, using 384 bytes of memory
Peers 3, using 71 KiB of memory

Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt Desc
Leaf-L1(ens2)   4      65011       672       675        6    0    0 00:33:17            0        2 To-Leaf-L1-Ethernet5
Leaf-L2(ens3)   4      65012       672       675        6    0    0 00:33:18            0        2 To-Leaf-L2-Ethernet5
127.0.0.1       4      64512         0         0        0    0    0    never       Active        0 MetalLB-speaker

Total number of neighbors 3
osh-comp-04#

XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
ubuntu@k8s-master-02:~$ sudo vtysh

Hello, this is FRRouting (version 10.5.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

k8s-master-02# show running-config bgpd
Building configuration...

Current configuration:
!
frr version 10.5.1
frr defaults datacenter
hostname k8s-master-02
service integrated-vtysh-config
!
ip prefix-list METALLB-POOL seq 10 permit 10.10.200.0/24 le 32
ip prefix-list METALLB-POOL seq 20 permit 172.16.2.200/29 le 32
!
route-map ACCEPT-METALLB permit 10
 match ip address prefix-list METALLB-POOL
exit
!
route-map DENY-ALL deny 10
exit
!
router bgp 65221
 bgp router-id 10.0.20.1
 no bgp default ipv4-unicast
 bgp bestpath as-path multipath-relax
 neighbor ens2 interface remote-as 65021
 neighbor ens2 description To-Leaf-L3-Ethernet0
 neighbor ens2 bfd
 neighbor ens2 bfd profile FABRIC-BFD
 no neighbor ens2 capability link-local
 neighbor ens3 interface remote-as 65022
 neighbor ens3 description To-Leaf-L4-Ethernet0
 neighbor ens3 bfd
 neighbor ens3 bfd profile FABRIC-BFD
 no neighbor ens3 capability link-local
 neighbor 127.0.0.1 remote-as 64512
 neighbor 127.0.0.1 description MetalLB-speaker
 neighbor 127.0.0.1 update-source 127.0.0.1
 bgp allow-martian-nexthop
 !
 address-family ipv4 unicast
  network 10.0.20.1/32
  network 192.168.20.21/32
  neighbor ens2 activate
  neighbor ens3 activate
  neighbor 127.0.0.1 activate
  neighbor 127.0.0.1 route-map ACCEPT-METALLB in
  neighbor 127.0.0.1 route-map DENY-ALL out
  maximum-paths 2
  maximum-paths ibgp 2
 exit-address-family
exit
!
end
k8s-master-02#
k8s-master-02#
k8s-master-02# show ip bgp summary

IPv4 Unicast Summary:
BGP router identifier 10.0.20.1, local AS number 65221 VRF default vrf-id 0
BGP table version 143
RIB entries 3, using 384 bytes of memory
Peers 3, using 71 KiB of memory

Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt Desc
Leaf-L3(ens2)   4      65021      1388      1404      143    0    0 01:06:37            0        2 To-Leaf-L3-Ethernet0
Leaf-L4(ens3)   4      65022      1389      1404      143    0    0 01:06:39            0        2 To-Leaf-L4-Ethernet0
127.0.0.1       4      64512         0         0        0    0    0    never       Active        0 MetalLB-speaker

Total number of neighbors 3
k8s-master-02#

#############################################

ubuntu@k8s-db-02:~$ sudo vtysh

Hello, this is FRRouting (version 10.5.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

k8s-db-02# show running-config bgpd
Building configuration...

Current configuration:
!
frr version 10.5.1
frr defaults datacenter
hostname k8s-db-02
service integrated-vtysh-config
!
ip prefix-list METALLB-POOL seq 10 permit 10.10.200.0/24 le 32
ip prefix-list METALLB-POOL seq 20 permit 172.16.2.200/29 le 32
!
route-map ACCEPT-METALLB permit 10
 match ip address prefix-list METALLB-POOL
exit
!
route-map DENY-ALL deny 10
exit
!
router bgp 65222
 bgp router-id 10.0.20.2
 no bgp default ipv4-unicast
 bgp bestpath as-path multipath-relax
 neighbor ens2 interface remote-as 65021
 neighbor ens2 description To-Leaf-L3-Ethernet1
 neighbor ens2 bfd
 neighbor ens2 bfd profile FABRIC-BFD
 no neighbor ens2 capability link-local
 neighbor ens3 interface remote-as 65022
 neighbor ens3 description To-Leaf-L4-Ethernet1
 neighbor ens3 bfd
 neighbor ens3 bfd profile FABRIC-BFD
 no neighbor ens3 capability link-local
 neighbor 127.0.0.1 remote-as 64512
 neighbor 127.0.0.1 description MetalLB-speaker
 neighbor 127.0.0.1 update-source 127.0.0.1
 bgp allow-martian-nexthop
 !
 address-family ipv4 unicast
  network 10.0.20.2/32
  network 192.168.20.22/32
  neighbor ens2 activate
  neighbor ens3 activate
  neighbor 127.0.0.1 activate
  neighbor 127.0.0.1 route-map ACCEPT-METALLB in
  neighbor 127.0.0.1 route-map DENY-ALL out
  maximum-paths 2
  maximum-paths ibgp 2
 exit-address-family
exit
!
end
k8s-db-02#
k8s-db-02# show ip bgp summary

IPv4 Unicast Summary:
BGP router identifier 10.0.20.2, local AS number 65222 VRF default vrf-id 0
BGP table version 127
RIB entries 3, using 384 bytes of memory
Peers 3, using 71 KiB of memory

Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt Desc
Leaf-L3(ens2)   4      65021      1398      1411      127    0    0 01:07:34            0        2 To-Leaf-L3-Ethernet1
Leaf-L4(ens3)   4      65022      1400      1412      127    0    0 01:07:39            0        2 To-Leaf-L4-Ethernet1
127.0.0.1       4      64512         0         0        0    0    0    never       Active        0 MetalLB-speaker

Total number of neighbors 3
k8s-db-02#

$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
ubuntu@osh-ctrl-02:~$ sudo vtysh

Hello, this is FRRouting (version 10.5.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

osh-ctrl-02# show running-config bgpd
Building configuration...

Current configuration:
!
frr version 10.5.1
frr defaults datacenter
hostname osh-ctrl-02
service integrated-vtysh-config
!
ip prefix-list METALLB-POOL seq 10 permit 10.10.200.0/24 le 32
ip prefix-list METALLB-POOL seq 20 permit 172.16.2.200/29 le 32
!
route-map ACCEPT-METALLB permit 10
 match ip address prefix-list METALLB-POOL
exit
!
route-map DENY-ALL deny 10
exit
!
router bgp 65223
 bgp router-id 10.0.20.3
 no bgp default ipv4-unicast
 bgp bestpath as-path multipath-relax
 neighbor ens2 interface remote-as 65021
 neighbor ens2 description To-Leaf-L3-Ethernet2
 neighbor ens2 bfd
 neighbor ens2 bfd profile FABRIC-BFD
 no neighbor ens2 capability link-local
 neighbor ens3 interface remote-as 65022
 neighbor ens3 description To-Leaf-L4-Ethernet2
 neighbor ens3 bfd
 neighbor ens3 bfd profile FABRIC-BFD
 no neighbor ens3 capability link-local
 neighbor 127.0.0.1 remote-as 64512
 neighbor 127.0.0.1 description MetalLB-speaker
 neighbor 127.0.0.1 update-source 127.0.0.1
 bgp allow-martian-nexthop
 !
 address-family ipv4 unicast
  network 10.0.20.3/32
  network 192.168.20.23/32
  neighbor ens2 activate
  neighbor ens3 activate
  neighbor 127.0.0.1 activate
  neighbor 127.0.0.1 route-map ACCEPT-METALLB in
  neighbor 127.0.0.1 route-map DENY-ALL out
  maximum-paths 2
  maximum-paths ibgp 2
 exit-address-family
exit
!
end
osh-ctrl-02#
osh-ctrl-02#
osh-ctrl-02# show ip bgp summary

IPv4 Unicast Summary:
BGP router identifier 10.0.20.3, local AS number 65223 VRF default vrf-id 0
BGP table version 145
RIB entries 3, using 384 bytes of memory
Peers 3, using 71 KiB of memory

Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt Desc
Leaf-L3(ens2)   4      65021      1427      1447      145    0    0 01:09:05            0        2 To-Leaf-L3-Ethernet2
Leaf-L4(ens3)   4      65022      1428      1445      145    0    0 01:08:59            0        2 To-Leaf-L4-Ethernet2
127.0.0.1       4      64512         0         0        0    0    0    never       Active        0 MetalLB-speaker

Total number of neighbors 3
osh-ctrl-02#

############################
ubuntu@osh-net-02:~$
ubuntu@osh-net-02:~$ sudo vtysh

Hello, this is FRRouting (version 10.5.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

osh-net-02# show running-config bgpd
Building configuration...

Current configuration:
!
frr version 10.5.1
frr defaults datacenter
hostname osh-net-02
service integrated-vtysh-config
!
ip prefix-list METALLB-POOL seq 10 permit 10.10.200.0/24 le 32
ip prefix-list METALLB-POOL seq 20 permit 172.16.2.200/29 le 32
!
route-map ACCEPT-METALLB permit 10
 match ip address prefix-list METALLB-POOL
exit
!
route-map DENY-ALL deny 10
exit
!
router bgp 65224
 bgp router-id 10.0.20.4
 no bgp default ipv4-unicast
 bgp bestpath as-path multipath-relax
 neighbor ens2 interface remote-as 65021
 neighbor ens2 description To-Leaf-L3-Ethernet3
 neighbor ens2 bfd
 neighbor ens2 bfd profile FABRIC-BFD
 no neighbor ens2 capability link-local
 neighbor ens3 interface remote-as 65022
 neighbor ens3 description To-Leaf-L4-Ethernet3
 neighbor ens3 bfd
 neighbor ens3 bfd profile FABRIC-BFD
 no neighbor ens3 capability link-local
 neighbor 127.0.0.1 remote-as 64512
 neighbor 127.0.0.1 description MetalLB-speaker
 neighbor 127.0.0.1 update-source 127.0.0.1
 bgp allow-martian-nexthop
 !
 address-family ipv4 unicast
  network 10.0.20.4/32
  network 192.168.20.24/32
  neighbor ens2 activate
  neighbor ens3 activate
  neighbor 127.0.0.1 activate
  neighbor 127.0.0.1 route-map ACCEPT-METALLB in
  neighbor 127.0.0.1 route-map DENY-ALL out
  maximum-paths 2
  maximum-paths ibgp 2
 exit-address-family
exit
!
end
osh-net-02#
osh-net-02#
osh-net-02# show ip bgp summary

IPv4 Unicast Summary:
BGP router identifier 10.0.20.4, local AS number 65224 VRF default vrf-id 0
BGP table version 126
RIB entries 3, using 384 bytes of memory
Peers 3, using 71 KiB of memory

Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt Desc
Leaf-L3(ens2)   4      65021      1443      1462      126    0    0 01:10:16            0        2 To-Leaf-L3-Ethernet3
Leaf-L4(ens3)   4      65022      1443      1461      126    0    0 01:10:13            0        2 To-Leaf-L4-Ethernet3
127.0.0.1       4      64512         0         0        0    0    0    never       Active        0 MetalLB-speaker

Total number of neighbors 3
osh-net-02#

$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
ubuntu@osh-comp-02:~$ sudo vtysh

Hello, this is FRRouting (version 10.5.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

osh-comp-02# show running-config bgpd
Building configuration...

Current configuration:
!
frr version 10.5.1
frr defaults datacenter
hostname osh-comp-02
service integrated-vtysh-config
!
ip prefix-list METALLB-POOL seq 10 permit 10.10.200.0/24 le 32
ip prefix-list METALLB-POOL seq 20 permit 172.16.2.200/29 le 32
!
route-map ACCEPT-METALLB permit 10
 match ip address prefix-list METALLB-POOL
exit
!
route-map DENY-ALL deny 10
exit
!
router bgp 65225
 bgp router-id 10.0.20.5
 no bgp default ipv4-unicast
 bgp bestpath as-path multipath-relax
 neighbor ens2 interface remote-as 65021
 neighbor ens2 description To-Leaf-L3-Ethernet4
 neighbor ens2 bfd
 neighbor ens2 bfd profile FABRIC-BFD
 no neighbor ens2 capability link-local
 neighbor ens3 interface remote-as 65022
 neighbor ens3 description To-Leaf-L4-Ethernet4
 neighbor ens3 bfd
 neighbor ens3 bfd profile FABRIC-BFD
 no neighbor ens3 capability link-local
 neighbor 127.0.0.1 remote-as 64512
 neighbor 127.0.0.1 description MetalLB-speaker
 neighbor 127.0.0.1 update-source 127.0.0.1
 bgp allow-martian-nexthop
 !
 address-family ipv4 unicast
  network 10.0.20.5/32
  network 192.168.20.25/32
  neighbor ens2 activate
  neighbor ens3 activate
  neighbor 127.0.0.1 activate
  neighbor 127.0.0.1 route-map ACCEPT-METALLB in
  neighbor 127.0.0.1 route-map DENY-ALL out
  maximum-paths 2
  maximum-paths ibgp 2
 exit-address-family
exit
!
end
osh-comp-02#
osh-comp-02#
osh-comp-02# show ip bgp summary

IPv4 Unicast Summary:
BGP router identifier 10.0.20.5, local AS number 65225 VRF default vrf-id 0
BGP table version 95
RIB entries 3, using 384 bytes of memory
Peers 3, using 71 KiB of memory

Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt Desc
Leaf-L3(ens2)   4      65021      1467      1473       95    0    0 01:11:43            0        2 To-Leaf-L3-Ethernet4
Leaf-L4(ens3)   4      65022      1469      1473       95    0    0 01:11:44            0        2 To-Leaf-L4-Ethernet4
127.0.0.1       4      64512         0         0        0    0    0    never       Active        0 MetalLB-speaker

Total number of neighbors 3
osh-comp-02#

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
ubuntu@k8s-master-03:~$ sudo vtysh

Hello, this is FRRouting (version 10.5.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

k8s-master-03# sudo vtysh
% Unknown command: sudo vtysh
k8s-master-03# show running-config bgpd
Building configuration...

Current configuration:
!
frr version 10.5.1
frr defaults datacenter
hostname k8s-master-03
service integrated-vtysh-config
!
ip prefix-list METALLB-POOL seq 10 permit 10.10.200.0/24 le 32
ip prefix-list METALLB-POOL seq 20 permit 172.16.2.200/29 le 32
ip prefix-list STORAGE-ONLY seq 10 permit 20.0.56.31/32
!
route-map ACCEPT-METALLB permit 10
 match ip address prefix-list METALLB-POOL
exit
!
route-map DENY-ALL deny 10
exit
!
route-map EXPORT-STORAGE permit 10
 match ip address prefix-list STORAGE-ONLY
exit
!
vrf vrf-storage
exit-vrf
!
router bgp 65231
 bgp router-id 10.0.30.1
 no bgp default ipv4-unicast
 bgp bestpath as-path multipath-relax
 neighbor ens2 interface remote-as 65031
 neighbor ens2 description To-Border-Leaf1-Ethernet3
 neighbor ens2 bfd
 neighbor ens2 bfd profile FABRIC-BFD
 no neighbor ens2 capability link-local
 neighbor ens3 interface remote-as 65032
 neighbor ens3 description To-Border-Leaf2-Ethernet3
 neighbor ens3 bfd
 neighbor ens3 bfd profile FABRIC-BFD
 no neighbor ens3 capability link-local
 neighbor 127.0.0.1 remote-as 64512
 neighbor 127.0.0.1 description MetalLB-speaker
 neighbor 127.0.0.1 update-source 127.0.0.1
 bgp allow-martian-nexthop
 !
 address-family ipv4 unicast
  network 10.0.30.1/32
  neighbor ens2 activate
  neighbor ens3 activate
  neighbor 127.0.0.1 activate
  neighbor 127.0.0.1 route-map ACCEPT-METALLB in
  neighbor 127.0.0.1 route-map DENY-ALL out
  maximum-paths 2
  maximum-paths ibgp 2
 exit-address-family
exit
!
router bgp 65231 vrf vrf-storage
 bgp router-id 20.0.56.31
 no bgp default ipv4-unicast
 bgp bestpath as-path multipath-relax
 neighbor ens2.100 interface remote-as 65031
 neighbor ens2.100 description STORAGE-To-Border-Leaf1
 no neighbor ens2.100 capability link-local
 neighbor ens3.100 interface remote-as 65032
 neighbor ens3.100 description STORAGE-To-Border-Leaf2
 no neighbor ens3.100 capability link-local
 !
 address-family ipv4 unicast
  redistribute connected route-map EXPORT-STORAGE
  neighbor ens2.100 activate
  neighbor ens3.100 activate
  maximum-paths 2
 exit-address-family
exit
!
end
k8s-master-03#
k8s-master-03# show ip bgp summary

IPv4 Unicast Summary:
BGP router identifier 10.0.30.1, local AS number 65231 VRF default vrf-id 0
BGP table version 115
RIB entries 1, using 128 bytes of memory
Peers 3, using 71 KiB of memory

Neighbor           V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt Desc
Border-Leaf1(ens2) 4      65031      1590      1608      115    0    0 01:16:41            0        1 To-Border-Leaf1-Ethe
Border-Leaf2(ens3) 4      65032      1610      1608      115    0    0 01:16:41            0        1 To-Border-Leaf2-Ethe
127.0.0.1          4      64512         0         0        0    0    0    never       Active        0 MetalLB-speaker

Total number of neighbors 3
k8s-master-03#
%%%%%%%%%%%%%%%%%%%%%%%%%%
ubuntu@k8s-db-03:~$ sudo vtysh

Hello, this is FRRouting (version 10.5.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

k8s-db-03# show running-config bgpd
Building configuration...

Current configuration:
!
frr version 10.5.1
frr defaults datacenter
hostname k8s-db-03
service integrated-vtysh-config
!
ip prefix-list METALLB-POOL seq 10 permit 10.10.200.0/24 le 32
ip prefix-list METALLB-POOL seq 20 permit 172.16.2.200/29 le 32
ip prefix-list STORAGE-ONLY seq 10 permit 20.0.56.32/32
!
route-map ACCEPT-METALLB permit 10
 match ip address prefix-list METALLB-POOL
exit
!
route-map DENY-ALL deny 10
exit
!
route-map EXPORT-STORAGE permit 10
 match ip address prefix-list STORAGE-ONLY
exit
!
vrf vrf-storage
exit-vrf
!
router bgp 65232
 bgp router-id 10.0.30.2
 no bgp default ipv4-unicast
 bgp bestpath as-path multipath-relax
 neighbor ens2 interface remote-as 65031
 neighbor ens2 description To-Border-Leaf1-Ethernet4
 neighbor ens2 bfd
 neighbor ens2 bfd profile FABRIC-BFD
 no neighbor ens2 capability link-local
 neighbor ens3 interface remote-as 65032
 neighbor ens3 description To-Border-Leaf2-Ethernet4
 neighbor ens3 bfd
 neighbor ens3 bfd profile FABRIC-BFD
 no neighbor ens3 capability link-local
 neighbor 127.0.0.1 remote-as 64512
 neighbor 127.0.0.1 description MetalLB-speaker
 neighbor 127.0.0.1 update-source 127.0.0.1
 bgp allow-martian-nexthop
 !
 address-family ipv4 unicast
  network 10.0.30.2/32
  neighbor ens2 activate
  neighbor ens3 activate
  neighbor 127.0.0.1 activate
  neighbor 127.0.0.1 route-map ACCEPT-METALLB in
  neighbor 127.0.0.1 route-map DENY-ALL out
  maximum-paths 2
  maximum-paths ibgp 2
 exit-address-family
exit
!
router bgp 65232 vrf vrf-storage
 bgp router-id 20.0.56.32
 no bgp default ipv4-unicast
 bgp bestpath as-path multipath-relax
 neighbor ens2.100 interface remote-as 65031
 neighbor ens2.100 description STORAGE-To-Border-Leaf1
 no neighbor ens2.100 capability link-local
 neighbor ens3.100 interface remote-as 65032
 neighbor ens3.100 description STORAGE-To-Border-Leaf2
 no neighbor ens3.100 capability link-local
 !
 address-family ipv4 unicast
  redistribute connected route-map EXPORT-STORAGE
  neighbor ens2.100 activate
  neighbor ens3.100 activate
  maximum-paths 2
 exit-address-family
exit
!
end
k8s-db-03#
k8s-db-03# show ip bgp summary

IPv4 Unicast Summary:
BGP router identifier 10.0.30.2, local AS number 65232 VRF default vrf-id 0
BGP table version 146
RIB entries 1, using 128 bytes of memory
Peers 3, using 71 KiB of memory

Neighbor           V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt Desc
Border-Leaf1(ens2) 4      65031      1616      1632      146    0    0 01:18:12            0        1 To-Border-Leaf1-Ethe
Border-Leaf2(ens3) 4      65032      1631      1634      146    0    0 01:18:07            0        1 To-Border-Leaf2-Ethe
127.0.0.1          4      64512         0         0        0    0    0    never       Active        0 MetalLB-speaker

Total number of neighbors 3
k8s-db-03#
k8s-db-03#

##############################
ubuntu@MonSrv:~$
ubuntu@MonSrv:~$
ubuntu@MonSrv:~$ sudo vtysh

Hello, this is FRRouting (version 10.5.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

MonSrv# show running-config bgpd
Building configuration...

Current configuration:
!
frr version 10.5.1
frr defaults datacenter
hostname MonSrv
service integrated-vtysh-config
!
ip prefix-list METALLB-POOL seq 10 permit 10.10.200.0/24 le 32
ip prefix-list METALLB-POOL seq 20 permit 172.16.2.200/29 le 32
ip prefix-list STORAGE-ONLY seq 10 permit 20.0.56.3/32
!
route-map ACCEPT-METALLB permit 10
 match ip address prefix-list METALLB-POOL
exit
!
route-map DENY-ALL deny 10
exit
!
route-map EXPORT-STORAGE permit 10
 match ip address prefix-list STORAGE-ONLY
exit
!
vrf vrf-storage
exit-vrf
!
router bgp 65234
 bgp router-id 10.0.30.4
 no bgp default ipv4-unicast
 bgp bestpath as-path multipath-relax
 neighbor ens2 interface remote-as 65031
 neighbor ens2 description To-Border-Leaf1-Ethernet6
 neighbor ens2 bfd
 neighbor ens2 bfd profile FABRIC-BFD
 no neighbor ens2 capability link-local
 neighbor ens3 interface remote-as 65032
 neighbor ens3 description To-Border-Leaf2-Ethernet6
 neighbor ens3 bfd
 neighbor ens3 bfd profile FABRIC-BFD
 no neighbor ens3 capability link-local
 neighbor 127.0.0.1 remote-as 64512
 neighbor 127.0.0.1 description MetalLB-speaker
 neighbor 127.0.0.1 update-source 127.0.0.1
 bgp allow-martian-nexthop
 !
 address-family ipv4 unicast
  network 10.0.30.4/32
  neighbor ens2 activate
  neighbor ens3 activate
  neighbor 127.0.0.1 activate
  neighbor 127.0.0.1 route-map ACCEPT-METALLB in
  neighbor 127.0.0.1 route-map DENY-ALL out
  maximum-paths 2
  maximum-paths ibgp 2
 exit-address-family
exit
!
router bgp 65234 vrf vrf-storage
 bgp router-id 20.0.56.3
 no bgp default ipv4-unicast
 bgp bestpath as-path multipath-relax
 neighbor ens2.100 interface remote-as 65031
 neighbor ens2.100 description STORAGE-To-Border-Leaf1
 no neighbor ens2.100 capability link-local
 neighbor ens3.100 interface remote-as 65032
 neighbor ens3.100 description STORAGE-To-Border-Leaf2
 no neighbor ens3.100 capability link-local
 !
 address-family ipv4 unicast
  redistribute connected route-map EXPORT-STORAGE
  neighbor ens2.100 activate
  neighbor ens3.100 activate
  maximum-paths 2
 exit-address-family
exit
!
end
MonSrv#
MonSrv#
MonSrv# show ip bgp summary

IPv4 Unicast Summary:
BGP router identifier 10.0.30.4, local AS number 65234 VRF default vrf-id 0
BGP table version 112
RIB entries 1, using 128 bytes of memory
Peers 3, using 71 KiB of memory

Neighbor           V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt Desc
Border-Leaf1(ens2) 4      65031      1650      1671      112    0    0 01:20:14            0        1 To-Border-Leaf1-Ethe
Border-Leaf2(ens3) 4      65032      1669      1674      112    0    0 01:20:14            0        1 To-Border-Leaf2-Ethe
127.0.0.1          4      64512         0         0        0    0    0    never       Active        0 MetalLB-speaker

Total number of neighbors 3
MonSrv#
MonSrv#

&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
ubuntu@osh-ctrl-03:~$ sudo vtysh

Hello, this is FRRouting (version 10.5.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

osh-ctrl-03# show running-config bgpd
Building configuration...

Current configuration:
!
frr version 10.5.1
frr defaults datacenter
hostname osh-ctrl-03
service integrated-vtysh-config
!
ip prefix-list METALLB-POOL seq 10 permit 10.10.200.0/24 le 32
ip prefix-list METALLB-POOL seq 20 permit 172.16.2.200/29 le 32
!
route-map ACCEPT-METALLB permit 10
 match ip address prefix-list METALLB-POOL
exit
!
route-map DENY-ALL deny 10
exit
!
router bgp 65233
 bgp router-id 10.0.30.3
 no bgp default ipv4-unicast
 bgp bestpath as-path multipath-relax
 neighbor ens2 interface remote-as 65031
 neighbor ens2 description To-Border-Leaf1-Ethernet5
 neighbor ens2 bfd
 neighbor ens2 bfd profile FABRIC-BFD
 no neighbor ens2 capability link-local
 neighbor ens3 interface remote-as 65032
 neighbor ens3 description To-Border-Leaf2-Ethernet5
 neighbor ens3 bfd
 neighbor ens3 bfd profile FABRIC-BFD
 no neighbor ens3 capability link-local
 neighbor 127.0.0.1 remote-as 64512
 neighbor 127.0.0.1 description MetalLB-speaker
 neighbor 127.0.0.1 update-source 127.0.0.1
 bgp allow-martian-nexthop
 !
 address-family ipv4 unicast
  network 10.0.30.3/32
  network 192.168.20.33/32
  neighbor ens2 activate
  neighbor ens3 activate
  neighbor 127.0.0.1 activate
  neighbor 127.0.0.1 route-map ACCEPT-METALLB in
  neighbor 127.0.0.1 route-map DENY-ALL out
  maximum-paths 2
  maximum-paths ibgp 2
 exit-address-family
exit
!
end
osh-ctrl-03#
osh-ctrl-03# show ip bgp summary

IPv4 Unicast Summary:
BGP router identifier 10.0.30.3, local AS number 65233 VRF default vrf-id 0
BGP table version 138
RIB entries 3, using 384 bytes of memory
Peers 3, using 71 KiB of memory

Neighbor           V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt Desc
Border-Leaf1(ens2) 4      65031      1689      1708      138    0    0 01:21:54            0        2 To-Border-Leaf1-Ethe
Border-Leaf2(ens3) 4      65032      1708      1710      138    0    0 01:21:51            0        2 To-Border-Leaf2-Ethe
127.0.0.1          4      64512         0         0        0    0    0    never       Active        0 MetalLB-speaker

Total number of neighbors 3
osh-ctrl-03#
osh-ctrl-03#

##########################################
ubuntu@osh-comp-03:~$
ubuntu@osh-comp-03:~$ sudo vtysh

Hello, this is FRRouting (version 10.5.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

osh-comp-03# show running-config bgpd
Building configuration...

Current configuration:
!
frr version 10.5.1
frr defaults datacenter
hostname osh-comp-03
service integrated-vtysh-config
!
ip prefix-list METALLB-POOL seq 10 permit 10.10.200.0/24 le 32
ip prefix-list METALLB-POOL seq 20 permit 172.16.2.200/29 le 32
!
route-map ACCEPT-METALLB permit 10
 match ip address prefix-list METALLB-POOL
exit
!
route-map DENY-ALL deny 10
exit
!
router bgp 65235
 bgp router-id 10.0.30.5
 no bgp default ipv4-unicast
 bgp bestpath as-path multipath-relax
 neighbor ens2 interface remote-as 65031
 neighbor ens2 description To-Border-Leaf1-Ethernet6
 neighbor ens2 bfd
 neighbor ens2 bfd profile FABRIC-BFD
 no neighbor ens2 capability link-local
 neighbor ens3 interface remote-as 65032
 neighbor ens3 description To-Border-Leaf2-Ethernet6
 neighbor ens3 bfd
 neighbor ens3 bfd profile FABRIC-BFD
 no neighbor ens3 capability link-local
 neighbor 127.0.0.1 remote-as 64512
 neighbor 127.0.0.1 description MetalLB-speaker
 neighbor 127.0.0.1 update-source 127.0.0.1
 bgp allow-martian-nexthop
 !
 address-family ipv4 unicast
  network 10.0.30.5/32
  network 192.168.20.35/32
  neighbor ens2 activate
  neighbor ens3 activate
  neighbor 127.0.0.1 activate
  neighbor 127.0.0.1 route-map ACCEPT-METALLB in
  neighbor 127.0.0.1 route-map DENY-ALL out
  maximum-paths 2
  maximum-paths ibgp 2
 exit-address-family
exit
!
end
osh-comp-03#
osh-comp-03#
osh-comp-03# show ip bgp summary

IPv4 Unicast Summary:
BGP router identifier 10.0.30.5, local AS number 65235 VRF default vrf-id 0
BGP table version 98
RIB entries 3, using 384 bytes of memory
Peers 3, using 71 KiB of memory

Neighbor           V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt Desc
Border-Leaf1(ens2) 4      65031      1698      1716       98    0    0 01:22:48            0        2 To-Border-Leaf1-Ethe
Border-Leaf2(ens3) 4      65032      1716      1716       98    0    0 01:22:48            0        2 To-Border-Leaf2-Ethe
127.0.0.1          4      64512         0         0        0    0    0    never       Active        0 MetalLB-speaker

Total number of neighbors 3
osh-comp-03#

&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
