Everything looks correct on paper — IPs, ASNs, firewall rules, update-source all match. The problem is at the TCP level: BL1 keeps sending SYN to ER1:179 but never gets SYN-ACK back (or SONiC's own iptables drops it). Let's see exactly what's happening on the wire:
# 1. TCP-level packet capture on BL1's Ethernet0 (10 seconds)
sshpass -p amolla01 ssh admin@172.16.2.31 "sudo timeout 15 tcpdump -nn -i Ethernet0 port 179 -c 20 2>&1"

# 2. Check SONiC's own iptables rules on BL1 for port 179
sshpass -p amolla01 ssh admin@172.16.2.31 "sudo iptables -L INPUT -n -v --line-numbers 2>&1" | head -40

# 3. Direct TCP test from BL1 to ER1:179
sshpass -p amolla01 ssh admin@172.16.2.31 "sudo bash -c '(echo > /dev/tcp/10.0.253.1/179) 2>&1 && echo TCP_OK || echo TCP_FAIL'"

  
Everything looks correct on paper — IPs, ASNs, firewall rules, update-source all match. The problem is at the TCP level: BL1 keeps sending SYN to ER1:179 but never gets SYN-ACK back (or SONiC's own iptables drops it). Let's see exactly what's happening on the wire:

The tcpdump output will tell us exactly where the TCP handshake is failing — whether SYNs go out, whether SYN-ACKs come back, or if SONiC's iptables is silently dropping them.
