```
{# 🧠 STAGE 1: INITIALIZE THE BASE DICTIONARY STRUCTURALLY #}
{% set config_db = {
  "DEVICE_METADATA": {
    "localhost": {
      "docker_routing_config_mode": docker_routing_config_mode | default('unified'),
      "frr_mgmt_framework_config": frr_mgmt_framework_config | default('true')
    }
  },
  "BGP_DEVICE_GLOBAL": {
    "localhost": {
      "local_asn": my_local_asn | default(bgp_local_asn),
      "max_path_ibgp": bgp_ecmp_max_paths | default('64') | int,
      "max_path_ebgp": bgp_ecmp_max_paths | default('64') | int,
      "router_id": router_id | default('127.0.0.1')
    }
  },
  "BREAKOUT_CFG": {},
  "PORT": {},
  "PORT_QOS_MAP": {},
  "QUEUE": {},
  "BUFFER_QUEUE": {},
  "BUFFER_PORT_INGRESS_PROFILE_LIST": {},
  "BUFFER_PORT_EGRESS_PROFILE_LIST": {},
  "INTERFACE": {},
  "BGP_NEIGHBOR": {},
  "BGP_NEIGHBOR_AF": {},
  "DEVICE_NEIGHBOR": {},
  "FLEX_COUNTER_TABLE": {},
  "VRF": {},
  "VLAN": {},
  "VLAN_MEMBER": {},
  "VLAN_INTERFACE": {}
} %}

{# 🧠 STAGE 2: BUILD AN ACTIVE POOL OF EXPLICITLY ALLOWED OPERATIONAL PORTS #}
{% set active_ports = [] %}

{# 2.1 Extract from Breakouts (Filter out explicit UNUSED markers) #}
{% for entry in breakout_configurations | default([]) %}
  {% for child in entry.children %}
    {% if child.peer_name is defined and 'UNUSED' not in child.peer_name and 'unused' not in child.peer_name %}
      {% set _ = active_ports.append(child.name) %}
    {% endif %}
  {% endfor %}
{% endfor %}

{# 2.2 Extract from Fabric Links (Spines) #}
{% for face in fabric_interfaces | default([]) %}
  {% set _ = active_ports.append(face.port) %}
{% endfor %}

{# 2.3 Extract from Uplink Links (Leaves/Borders) #}
{% for up in uplink_interfaces | default([]) %}
  {% set _ = active_ports.append(up.port) %}
{% endfor %}

{# 2.4 Extract from Downlink Workload Server Links #}
{% for down in downlink_interfaces | default([]) %}
  {% set _ = active_ports.append(down.port) %}
{% endfor %}

{# 🧠 STAGE 3: PROCESS ACTIVE BREAKOUT CONFIGURATIONS AND CHILDREN #}
{% for entry in breakout_configurations | default([]) %}
  {% set _ = config_db.BREAKOUT_CFG.update({ entry.parent_port: { "brkout_mode": entry.breakout_mode } }) %}
  {% for child in entry.children %}
    {# Only configure operational ports; let Stage 8 explicitly drop down un-peered slots #}
    {% if child.name in active_ports %}
      {% set _ = config_db.PORT.update({ child.name: { "admin_status": "up", "alias": child.alias, "index": child.index | string, "lanes": child.lanes | string, "speed": child.speed | string, "autoneg": "off" } }) %}
      {% set _ = config_db.PORT_QOS_MAP.update({ child.name: { "dscp_to_tc_map": "[DSCP_TO_TC_MAP|AZURE]", "pfc_to_queue_map": "[PFC_TO_QUEUE_MAP|AZURE]", "tc_to_pg_map": "[TC_TO_PRIORITY_GROUP_MAP|AZURE]", "tc_to_queue_map": "[TC_TO_QUEUE_MAP|AZURE]" } }) %}
      {% set _ = config_db.BUFFER_QUEUE.update({ child.name ~ "|0-2": { "profile": "[BUFFER_PROFILE|ingress_lossless_profile]" }, child.name ~ "|3-7": { "profile": "[BUFFER_PROFILE|egress_lossy_profile]" } }) %}
      {% set _ = config_db.BUFFER_PORT_INGRESS_PROFILE_LIST.update({ child.name: { "profile_list": "[BUFFER_PROFILE|ingress_lossy_profile]" } }) %}
      {% set _ = config_db.BUFFER_PORT_EGRESS_PROFILE_LIST.update({ child.name: { "profile_list": "[BUFFER_PROFILE|egress_lossy_profile]" } }) %}
      {% set _ = config_db.FLEX_COUNTER_TABLE.update({ "PORT:" ~ child.name: { "flex_counter_delay_status": "false" } }) %}
      
      {% for q in range(0, 8) %}
        {% set _ = config_db.QUEUE.update({ child.name ~ "|" ~ q: { "scheduler": "[SCHEDULER|Lyra_queue_" ~ q ~ "_scheduler]" } }) %}
      {% endfor %}

      {% set _ = config_db.INTERFACE.update({ child.name: { "ipv6_use_link_local_only": "enable" } }) %}
      {% set _ = config_db.BGP_NEIGHBOR_AF.update({ child.name ~ "|ipv4_unicast": { "admin_status": "up" } }) %}
      
      {% if 'Spine' in child.peer_name or 'spine' in child.peer_name %}{% set derived_asn = spine_asn | default('65000') %}
      {% elif child.peer_name in leaf_asn_map | default({}) %}{% set derived_asn = leaf_asn_map[child.peer_name] %}
      {% elif child.peer_name in border_leaf_asn_map | default({}) %}{% set derived_asn = border_leaf_asn_map[child.peer_name] %}
      {% else %}{% set derived_asn = "65534" %}{% endif %}
      {% set _ = config_db.BGP_NEIGHBOR.update({ child.name: { "asn": derived_asn | string, "name": child.peer_name, "local_asn": (my_local_asn | default(bgp_local_asn)) | string } }) %}
      
      {% if child.rem_port is defined %}
        {% set _ = config_db.DEVICE_NEIGHBOR.update({ child.name: { "name": child.peer_name, "mgmt_addr": "", "local_port": child.name, "port": child.rem_port } }) %}
      {% endif %}
    {% endif %}
  {% endfor %}
{% endfor %}

{# 🧠 STAGE 4: PROCESS ACTIVE FABRIC INTERFACES (SPINES) #}
{% for face in fabric_interfaces | default([]) %}
  {% set _ = config_db.PORT.update({ face.port: { "admin_status": "up", "alias": face.alias, "index": face.index | string, "lanes": face.lanes | string, "speed": face.speed | string, "autoneg": "off" } }) %}
  {% set _ = config_db.PORT_QOS_MAP.update({ face.port: { "dscp_to_tc_map": "[DSCP_TO_TC_MAP|AZURE]", "pfc_to_queue_map": "[PFC_TO_QUEUE_MAP|AZURE]", "tc_to_pg_map": "[TC_TO_PRIORITY_GROUP_MAP|AZURE]", "tc_to_queue_map": "[TC_TO_QUEUE_MAP|AZURE]" } }) %}
  {% set _ = config_db.BUFFER_QUEUE.update({ face.port ~ "|0-2": { "profile": "[BUFFER_PROFILE|ingress_lossless_profile]" }, face.port ~ "|3-7": { "profile": "[BUFFER_PROFILE|egress_lossy_profile]" } }) %}
  {% set _ = config_db.BUFFER_PORT_INGRESS_PROFILE_LIST.update({ face.port: { "profile_list": "[BUFFER_PROFILE|ingress_lossy_profile]" } }) %}
  {% set _ = config_db.BUFFER_PORT_EGRESS_PROFILE_LIST.update({ face.port: { "profile_list": "[BUFFER_PROFILE|egress_lossy_profile]" } }) %}
  {% set _ = config_db.INTERFACE.update({ face.port: { "ipv6_use_link_local_only": "enable" } }) %}
  {% set _ = config_db.BGP_NEIGHBOR_AF.update({ face.port ~ "|ipv4_unicast": { "admin_status": "up" } }) %}
  {% set _ = config_db.FLEX_COUNTER_TABLE.update({ "PORT:" ~ face.port: { "flex_counter_delay_status": "false" } }) %}
  {% set _ = config_db.BGP_NEIGHBOR.update({ face.port: { "asn": face.neighbor_asn | string, "name": face.neighbor, "local_asn": (my_local_asn | default(bgp_local_asn)) | string } }) %}
  {% set _ = config_db.DEVICE_NEIGHBOR.update({ face.port: { "name": face.neighbor, "mgmt_addr": "", "local_port": face.port, "port": face.neighbor_port } }) %}
  {% for q in range(0, 8) %}
    {% set _ = config_db.QUEUE.update({ face.port ~ "|" ~ q: { "scheduler": "[SCHEDULER|Lyra_queue_" ~ q ~ "_scheduler]" } }) %}
  {% endfor %}
{% endfor %}

{# 🧠 STAGE 5: PROCESS ACTIVE UPLINK INTERFACES (LEAVES / BORDERS) #}
{% for up in uplink_interfaces | default([]) %}
  {% set _ = config_db.PORT.update({ up.port: { "admin_status": "up", "alias": up.alias, "index": up.index | string, "lanes": up.lanes | string, "speed": up.speed | string, "autoneg": "off" } }) %}
  {% set _ = config_db.PORT_QOS_MAP.update({ up.port: { "dscp_to_tc_map": "[DSCP_TO_TC_MAP|AZURE]", "pfc_to_queue_map": "[PFC_TO_QUEUE_MAP|AZURE]", "tc_to_pg_map": "[TC_TO_PRIORITY_GROUP_MAP|AZURE]", "tc_to_queue_map": "[TC_TO_QUEUE_MAP|AZURE]" } }) %}
  {% set _ = config_db.BUFFER_QUEUE.update({ up.port ~ "|0-2": { "profile": "[BUFFER_PROFILE|ingress_lossless_profile]" }, up.port ~ "|3-7": { "profile": "[BUFFER_PROFILE|egress_lossy_profile]" } }) %}
  {% set _ = config_db.BUFFER_PORT_INGRESS_PROFILE_LIST.update({ up.port: { "profile_list": "[BUFFER_PROFILE|ingress_lossy_profile]" } }) %}
  {% set _ = config_db.BUFFER_PORT_EGRESS_PROFILE_LIST.update({ up.port: { "profile_list": "[BUFFER_PROFILE|egress_lossy_profile]" } }) %}
  {% set _ = config_db.INTERFACE.update({ up.port: { "ipv6_use_link_local_only": "enable" } }) %}
  {% set _ = config_db.BGP_NEIGHBOR_AF.update({ up.port ~ "|ipv4_unicast": { "admin_status": "up" } }) %}
  {% set _ = config_db.FLEX_COUNTER_TABLE.update({ "PORT:" ~ up.port: { "flex_counter_delay_status": "false" } }) %}
  {% set _ = config_db.BGP_NEIGHBOR.update({ up.port: { "asn": up.neighbor_asn | string, "name": up.neighbor, "local_asn": (my_local_asn | default(bgp_local_asn)) | string } }) %}
  {% set _ = config_db.DEVICE_NEIGHBOR.update({ up.port: { "name": up.neighbor, "mgmt_addr": "", "local_port": up.port, "port": up.neighbor_port } }) %}
  {% for q in range(0, 8) %}
    {% set _ = config_db.QUEUE.update({ up.port ~ "|" ~ q: { "scheduler": "[SCHEDULER|Lyra_queue_" ~ q ~ "_scheduler]" } }) %}
  {% endfor %}
{% endfor %}

{# 🧠 STAGE 6: PROCESS ACTIVE DOWNLINK WORKLOAD INTERFACES #}
{% for down in downlink_interfaces | default([]) %}
  {% set _ = config_db.PORT.update({ down.port: { "admin_status": "up", "alias": down.alias, "index": down.index | default('0') | string, "lanes": down.lanes | string, "speed": down.speed | string, "autoneg": "off" } }) %}
  {% set _ = config_db.PORT_QOS_MAP.update({ down.port: { "dscp_to_tc_map": "[DSCP_TO_TC_MAP|AZURE]", "pfc_to_queue_map": "[PFC_TO_QUEUE_MAP|AZURE]", "tc_to_pg_map": "[TC_TO_PRIORITY_GROUP_MAP|AZURE]", "tc_to_queue_map": "[TC_TO_QUEUE_MAP|AZURE]" } }) %}
  {% set _ = config_db.BUFFER_QUEUE.update({ down.port ~ "|0-2": { "profile": "[BUFFER_PROFILE|ingress_lossless_profile]" }, down.port ~ "|3-7": { "profile": "[BUFFER_PROFILE|egress_lossy_profile]" } }) %}
  {% set _ = config_db.BUFFER_PORT_INGRESS_PROFILE_LIST.update({ down.port: { "profile_list": "[BUFFER_PROFILE|ingress_lossy_profile]" } }) %}
  {% set _ = config_db.BUFFER_PORT_EGRESS_PROFILE_LIST.update({ down.port: { "profile_list": "[BUFFER_PROFILE|egress_lossy_profile]" } }) %}
  {% set _ = config_db.INTERFACE.update({ down.port: { "ipv6_use_link_local_only": "enable" } }) %}
  {% set _ = config_db.BGP_NEIGHBOR_AF.update({ down.port ~ "|ipv4_unicast": { "admin_status": "up" } }) %}
{% set _ = config_db.FLEX_COUNTER_TABLE.update({ "PORT:" ~ down.port: { "flex_counter_delay_status": "false" } }) %}{% set _ = config_db.BGP_NEIGHBOR.update({ down.port: { "asn": down.neighbor_asn | string, "name": down.neighbor, "local_asn": (my_local_asn | default(bgp_local_asn)) | string } }) %}{% set _ = config_db.DEVICE_NEIGHBOR.update({ down.port: { "name": down.neighbor, "mgmt_addr": "", "local_port": down.port, "port": down.neighbor_port } }) %}{% for q in range(0, 8) %}{% set _ = config_db.QUEUE.update({ down.port ~ "|" ~ q: { "scheduler": "[SCHEDULER|Lyra_queue_" ~ q ~ "_scheduler]" } }) %}{% endfor %}{% endfor %}{# 🧠 STAGE 7: RENDER DYNAMIC VIRTUAL OVERLAY DISCOVERY PLANE (VRFs & VLANs) #}{# 7.1 Map VRF Context Instances #}{% for vrf in fabric_vrfs | default([]) %}{% set _ = config_db.VRF.update({ vrf.name: { "enabled": "true" } }) %}{% endfor %}{# 7.2 Map VLAN Domain Profiles #}{% for vlan in fabric_vlans | default([]) %}{% set _ = config_db.VLAN.update({ "Vlan" ~ vlan.id: { "vlanid": vlan.id | string } }) %}{# If the vlan belongs to an isolated routing network, bind the core workspace interface #}{% if vlan.vrf_binding is defined and vlan.vrf_binding != "default" %}{% set _ = config_db.VLAN_INTERFACE.update({ "Vlan" ~ vlan.id: { "vrf_name": vlan.vrf_binding } }) %}{% else %}{% set _ = config_db.VLAN_INTERFACE.update({ "Vlan" ~ vlan.id: {} }) %}{% endif %}{# 7.3 Automatically bind all active downlinks/breakout data planes to trunked members #}{% for trunk_port in active_ports %}{# Guard logic: Do not bind spine fabric uplinks or border inter-router peers to workload trunks #}{% if trunk_port not in (uplink_interfaces | default([]) | map(attribute='port')) and trunk_port not in (fabric_interfaces | default([]) | map(attribute='port')) %}{% set _ = config_db.VLAN_MEMBER.update({ ("Vlan" ~ vlan.id) ~ "|" ~ trunk_port: { "tagging_mode": "tagged" } }) %}{% endif %}{% endfor %}{% endfor %}{# 🧠 STAGE 8: AUTOMATICALLY DISABLE ALL UNLISTED PORTS BASED ON NATIVE ALL_PORTS #}{% for native_name, native_meta in (all_ports | default({})).items() %}{% if native_name not in active_ports %}{% set _ = config_db.PORT.update({native_name: {"admin_status": "down","alias": native_meta.alias | default(native_name),"index": native_meta.index | string,"lanes": native_meta.lanes | string,"speed": native_meta.speed | default('40000') | string,"autoneg": "off"}}) %}{% endif %}{% endfor %}{# 🧠 STAGE 9: RENDER THE ENTIRE OBJECT AS A CLEAN, LEAK-PROOF JSON FILE #}{{ config_db | to_nice_json }}
```
