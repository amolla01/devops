# Deployment Operations

## Profile Selection
Set the automation profile before running (defaults to `ubuntu_r810_kvm` if unset):
```
export AUTOMATION_PROFILE=ubuntu_r810_kvm   # or ubuntu_r620_kvm, win11_kvm, real_hardware
```
Or pass `--profile <name>` to deploy_lab_v3.sh.

## KVM VS vs Real Hardware — Port Breakout

**Critical**: SONiC KVM VS (`x86_64-kvm_x86_64-r0`) does **NOT** support port breakout.
Only interface names listed in the platform's `port_config.ini` are valid.

| Platform (hwsku) | Valid port names on KVM VS | Step |
|------------------|---------------------------|------|
| Arista-7050QX-32S | Ethernet0, 4, 8, 12, …, 124 | +4 |
| Arista-7050-QX32 | Ethernet0, 4, 8, 12, …, 124 | +4 |
| Seastone-DX010 | Ethernet0, 4, 8, 12, …, 124 | +4 |
| Accton-AS5712-54X | Ethernet0–47 (SFP+), 48–71 (QSFP+) | +1 |

**Breakout sub-port names like `Ethernet1`, `Ethernet2`, `Ethernet3` are INVALID on KVM VS.**

### Port mapping by mode

**KVM VS mode** (`is_kvm: true`) — uses native QSFP+ ports:
```
Border_Leaf → servers:   Ethernet0, Ethernet4, Ethernet8  (QSFP+5/6/7)
Border_Leaf → exit:      Ethernet12                       (QSFP+8)
Leaf_L3/L4  → servers:   Ethernet0, Ethernet4            (QSFP+1/2)
Leaf_L1/L2  → servers:   Ethernet0, Ethernet1, Ethernet2 (SFP+ native, valid on AS5712)
```

**Real hardware mode** — uses 4×10G breakout sub-ports:
```
Border_Leaf → servers:   Ethernet0, Ethernet1, Ethernet2 (breakout of QSFP+5)
Border_Leaf → exit:      Ethernet3                        (breakout of QSFP+5)
Leaf_L3/L4  → servers:   Ethernet0, Ethernet1            (breakout of QSFP+1)
Leaf_L1/L2  → servers:   Ethernet0, Ethernet1, Ethernet2 (SFP+ native, same as KVM)
```

### Why Ethernet0 works on both modes
`Ethernet0` exists in port_config.ini as the first native QSFP+ port AND is reused as
the first sub-port name after breakout. So it succeeds in both KVM and real hardware.
`Ethernet1/2/3` only exist AFTER breakout creates them — which KVM VS cannot do.

### Diagnosis
If `config interface startup EthernetN` fails with "Interface name is invalid":
1. SSH to the switch: `show interfaces status | grep EthernetN`
2. Check available ports: `sonic-cfggen -d --var-json PORT | python3 -m json.tool | grep name`
3. Verify port_config.ini: `cat /usr/share/sonic/device/x86_64-kvm_x86_64-r0/*/port_config.ini`

## Full Environment Deployment

`ansible-playbook -i ../inventory/hosts.yml ../playbooks/deploy_full_environment.yml`

Orchestrated KVM setup + full services:

`bash ../deploy_lab_v3.sh --profile ubuntu_r810_kvm full`

Phase-by-phase expansion:

`bash ../deploy_lab_v3.sh phase-r620`

`bash ../deploy_lab_v3.sh phase-r810`

`bash ../deploy_lab_v3.sh phased-full`

## Deploy by Category

Fabric and underlay:

`ansible-playbook -i ../inventory/hosts.yml ../playbooks/reused/deploy_day0.yml`

`ansible-playbook -i ../inventory/hosts.yml ../playbooks/reused/deploy_day1.yml`

KVM topology only (initial build):

`bash ../deploy_lab_v3.sh --profile ubuntu_r810_kvm kvm-deploy`

KVM topology only on remote hypervisors:

`bash ../deploy_lab_v3.sh --r620-host admin@10.1.1.20 kvm-deploy-r620`

`bash ../deploy_lab_v3.sh --r810-host admin@10.1.1.21 kvm-deploy-r810`

`bash ../deploy_lab_v3.sh --r620-host admin@10.1.1.20 --r810-host admin@10.1.1.21 kvm-deploy-both`

OpenStack Gateway tier:

`ansible-playbook -i ../inventory/hosts.yml ../playbooks/deploy_openstack_gateways.yml`

Premium Firewall tier:

`ansible-playbook -i ../inventory/hosts.yml ../playbooks/deploy_premium_firewall.yml`

Service catalog deployment validation:

`ansible-playbook -i ../inventory/hosts.yml ../playbooks/deploy_service_catalog.yml`
