#!/usr/bin/env bash
# Read-only ECMP / per-leaf route-propagation diagnostic.
set -u
cd /mnt/c/dc-lab/clab/sonic-clab
export ANSIBLE_CONFIG=/mnt/c/dc-lab/clab/sonic-clab/ansible.cfg

LEAVES="Leaf-L1,Leaf-L2,Leaf-L3,Leaf-L4,Border-Leaf1,Border-Leaf2"

echo "########## 1) Established host BGP sessions per leaf ##########"
ansible -i inventory.yml "$LEAVES" -m shell -a \
  'docker exec bgp vtysh -c "show ip bgp ipv4 unicast summary" 2>/dev/null | grep -c Established' \
  2>&1 | grep -E "CHANGED|SUCCESS|=>|^[0-9]|rc="

echo
echo "########## 2) Is each dark /32 present on BOTH leaves of its pair? ##########"
# rack1 (Leaf-L1/L2): 10.0.10.1 (master-01) 10.0.10.5 (comp-01) 10.0.10.6 (comp-04)
for p in 10.0.10.1/32 10.0.10.5/32 10.0.10.6/32; do
  echo "----- $p on rack1 leaves -----"
  ansible -i inventory.yml Leaf-L1,Leaf-L2 -m shell -a \
    "docker exec bgp vtysh -c \"show ip bgp ipv4 unicast $p\" 2>/dev/null | grep -E 'BGP routing|not in table|Paths|from' | head -4" \
    2>&1 | grep -E "CHANGED|Paths|not in table|from|BGP routing"
done
# rack2 (Leaf-L3/L4): 10.0.20.1 (master-02) 10.0.20.5 (comp-02)
for p in 10.0.20.1/32 10.0.20.5/32; do
  echo "----- $p on rack2 leaves -----"
  ansible -i inventory.yml Leaf-L3,Leaf-L4 -m shell -a \
    "docker exec bgp vtysh -c \"show ip bgp ipv4 unicast $p\" 2>/dev/null | grep -E 'BGP routing|not in table|Paths|from' | head -4" \
    2>&1 | grep -E "CHANGED|Paths|not in table|from|BGP routing"
done
