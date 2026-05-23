# 1. Check FRR is using correct interface names
ssh ubuntu@172.16.2.47 "sudo vtysh -c 'show running-config' | grep -A2 'neighbor'"

# 2. Check IPv6 link-local on fabric interfaces (required for BGP unnumbered)
ssh ubuntu@172.16.2.47 "ip -6 addr show enp2s0; ip -6 addr show enp3s0"

# 3. Check interfaces are up and have carrier
ssh ubuntu@172.16.2.47 "ip link show enp2s0; ip link show enp3s0"

# 4. Check if FRR bgpd is actually running
ssh ubuntu@172.16.2.47 "sudo systemctl status frr | head -15"

# 5. Check FRR BGP neighbor detail for the specific error
ssh ubuntu@172.16.2.47 "sudo vtysh -c 'show bgp neighbor enp2s0' | head -30"

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
# Check failing servers — look for NO-CARRIER
ssh ubuntu@Host34_1 "ip link show enp2s0; ip link show enp3s0"
ssh ubuntu@HostB12_2 "ip link show enp2s0; ip link show enp3s0"
ssh ubuntu@MonitorSrv "ip link show enp2s0; ip link show enp3s0"

# Compare with working server — should show LOWER_UP
ssh ubuntu@Host12_1 "ip link show enp2s0; ip link show enp3s0"

#########################################################
# List all libvirt networks/bridges
virsh net-list --all

# Check which networks each VM's NICs are attached to
virsh domiflist Host34_1
virsh domiflist MonitorSrv
virsh domiflist HostB12_2

# Compare with working VM
virsh domiflist Host12_1
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
