I’ve narrowed this to the remaining control plane issue, not cabling or IP reachability. I’m checking RouterOS BGP semantics so the next step is a clean, correct reset instead of another blind retry.

Fetched https://help.mikrotik.com/docs/spaces/ROS/pages/331612228/routing+bgp
Diagnosed router settings and analyzed BGP session issues
The failure is no longer in OVS, interface wiring, IP addressing, or basic reachability. Those are now proven good.

What we know from your logs:

BL1 and BL2 both have the correct /31 on Ethernet0
BL1 can ping 10.0.253.1, BL2 can ping 10.0.253.3
ER1 and ER2 firewall rules allow TCP/179 from 10.0.253.0/24
ER2’s wrong interface issue is fixed
BL FRR neighbor config is correct on both sides
What is still broken:

RouterOS still shows BGP session state like remote.as=0 and hold-time=infinity
BL shows Connect with MsgRcvd=0 MsgSent=0
That combination means the problem is now specifically the RouterOS BGP control plane state. It is not completing a clean OPEN exchange, even though transport is reachable. In plain terms: the links work, the IPs work, but the CHR BGP process is still carrying stale or malformed session state from the earlier broken attempts.

The clean fix now is to fully reset BGP on both MikroTiks, including session state, then recreate the connection with the default instance/template explicitly set.

Run this on 172.16.2.98:


/routing bgp session reset [find]/routing bgp connection remove [find]/routing bgp template set default as=65253 router-id=10.0.253.1 hold-time=3m keepalive-time=1m afi=ip/routing bgp instance set default as=65253 router-id=10.0.253.1/routing bgp connection add name=to-BL1 templates=default local.address=10.0.253.1 local.role=ebgp remote.address=10.0.253.0/32 remote.as=65021 connect=yes listen=yes/routing bgp connection print detail/routing bgp session print detail
Run this on 172.16.2.99:


/routing bgp session reset [find]/routing bgp connection remove [find]/routing bgp template set default as=65254 router-id=10.0.253.3 hold-time=3m keepalive-time=1m afi=ip/routing bgp instance set default as=65254 router-id=10.0.253.3/routing bgp connection add name=to-BL2 templates=default local.address=10.0.253.3 local.role=ebgp remote.address=10.0.253.2/32 remote.as=65022 connect=yes listen=yes/routing bgp connection print detail/routing bgp session print detail
Then wait 10-15 seconds and verify:


sshpass -p amolla01 ssh admin@172.16.2.31 "docker exec bgp vtysh -c 'show bgp summary'"sshpass -p amolla01 ssh admin@172.16.2.32 "docker exec bgp vtysh -c 'show bgp summary'"
If either side still stays in Connect after that, the next step is not more config guessing. It is a live TCP capture on BL Ethernet0 and a RouterOS BGP session reset or CHR reboot. But at this point the most likely remaining cause is stale RouterOS BGP state, not network wiring.

GPT-5.4 • 1x

/routing bgp session reset [find]
/routing bgp connection remove [find]
/routing bgp template set default as=65253 router-id=10.0.253.1 hold-time=3m keepalive-time=1m afi=ip
/routing bgp instance set default as=65253 router-id=10.0.253.1
/routing bgp connection add name=to-BL1 templates=default local.address=10.0.253.1 local.role=ebgp remote.address=10.0.253.0/32 remote.as=65021 connect=yes listen=yes
/routing bgp connection print detail
/routing bgp session print detail

Run this on 172.16.2.99:

/routing bgp session reset [find]
/routing bgp connection remove [find]
/routing bgp template set default as=65254 router-id=10.0.253.3 hold-time=3m keepalive-time=1m afi=ip
/routing bgp instance set default as=65254 router-id=10.0.253.3
/routing bgp connection add name=to-BL2 templates=default local.address=10.0.253.3 local.role=ebgp remote.address=10.0.253.2/32 remote.as=65022 connect=yes listen=yes
/routing bgp connection print detail
/routing bgp session print detail

Then wait 10-15 seconds and verify:


sshpass -p amolla01 ssh admin@172.16.2.31 "docker exec bgp vtysh -c 'show bgp summary'"
sshpass -p amolla01 ssh admin@172.16.2.32 "docker exec bgp vtysh -c 'show bgp summary'"

  If either side still stays in Connect after that, the next step is not more config guessing. It is a live TCP capture on BL Ethernet0 and a RouterOS BGP session reset or CHR reboot. But at this point the most likely remaining cause is stale RouterOS BGP state, not network wiring.
