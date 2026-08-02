#!/usr/bin/env python3
"""Customize config_db.json after sonic-cfggen generates it from port_config.ini."""
import json
from collections import defaultdict

with open('/tmp/port_data.json') as f:
    data = json.load(f)

switch_ports = data['switch_ports']
access_ports = data['access_ports']
meta = data['metadata']

with open('/etc/sonic/config_db.json') as f:
    db = json.load(f)

# Set our DEVICE_METADATA (keep platform as x86_64-kvm_x86_64-r0 from sonic-cfggen)
db['DEVICE_METADATA']['localhost'].update({
    'hostname': meta['hostname'],
    'type': meta['type'],
    'router_id': meta['router_id'],
    'bgp_asn': meta['bgp_asn'],
    'frr_mgmt_framework_config': 'true',
    'docker_routing_config_mode': 'unified'
})

# Remove preset-generated sections we don't need
for key in ['BGP_NEIGHBOR', 'DEVICE_NEIGHBOR', 'INTERFACE', 'LOOPBACK_INTERFACE']:
    db.pop(key, None)

# Handle breakout: multiple access_ports sharing same index = breakout children
idx_groups = defaultdict(list)
for port_name, cfg in access_ports.items():
    idx_groups[str(cfg['index'])].append(port_name)

breakout_cfg = {}
for idx, ports in idx_groups.items():
    if len(ports) > 1:
        # Find and remove the parent port from PORT
        parent_name = None
        for pname, pcfg in list(db['PORT'].items()):
            if str(pcfg.get('index')) == idx:
                parent_name = pname
                break
        if parent_name and parent_name in db['PORT']:
            del db['PORT'][parent_name]

        # Add breakout children to PORT
        first_child = sorted(ports, key=lambda x: int(x.replace('Ethernet', '')))[0]
        child_speed = access_ports[ports[0]].get('speed', '10000')
        speed_g = int(child_speed) // 1000
        breakout_cfg[first_child] = {
            'brkout_mode': '%dx%dG[%dG]' % (len(ports), speed_g, speed_g)
        }
        for child in ports:
            ccfg = access_ports[child]
            db['PORT'][child] = {
                'lanes': str(ccfg.get('lanes', '')),
                'speed': str(ccfg.get('speed', '10000')),
                'index': idx,
                'admin_status': 'up',
                'alias': child,
                'mtu': '9100'
            }

if breakout_cfg:
    db['BREAKOUT_CFG'] = breakout_cfg

with open('/etc/sonic/config_db.json', 'w') as f:
    json.dump(db, f, indent=4)
