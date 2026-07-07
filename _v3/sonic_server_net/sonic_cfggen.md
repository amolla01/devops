### sonic_cfggen tutorial

sonic-cfggen is a backend command-line utility used in SONiC switches to translate, generate, and load network configurations. It parses configuration files (typically JSON) or input templates and commits these states to the SONiC Redis Configuration Database. [1, 2, 3, 4, 5] 
## Key Syntax and Options
You can use sonic-cfggen from the Linux shell of your SONiC switch with the following flags: [1, 2, 3] 

| Option [1, 5, 6, 7] | Description |
|---|---|
| -j <file> | Specifies the JSON configuration file to process. |
| -d | Dumps the current configuration in JSON format. |
| --write-to-db | Pushes the parsed configuration directly into the Redis ConfigDB. |
| -H | Parses information from the hardware and environment for switch profiles. |
| --preset <type> | Uses built-in configuration templates (e.g., l1, l2). |

## Common Use Cases & Examples
1. Pushing a Configuration to the Database
To apply a custom JSON configuration file and write it to the ConfigDB, run: [6, 8] 

sudo sonic-cfggen -H -j /etc/sonic/init_cfg.json --write-to-db

2. Generating/Loading Factory Defaults
If you need to restore or push the default switch settings from the factory JSON into the ConfigDB, use: [6] 

sudo sonic-cfggen -H -j /etc/sonic/init_cfg.json --write-to-db

3. Dumping the Current Running Config
To view or export the active ConfigDB settings in a standard JSON format, execute:

sudo sonic-cfggen -d

4. Loading Layer 2 Switch Mode
If you are repurposing a SONiC router as a Layer 2 switch, you can generate and apply the required L2 profile using: [7] 

sudo sonic-cfggen --preset l2 -p -H -k <Platform-Name>

## Important Execution Notes

* Restarting Services: After making changes via sonic-cfggen, you may need to restart the corresponding SONiC containers (e.g., sudo systemctl restart swss or sudo systemctl restart bgp) or trigger sudo config reload to apply the pushed changes to the data plane. [9, 10] 
* File vs Database: Older versions of SONiC relied on an XML minigraph file. Modern implementations write directly to the ConfigDB via sonic-cfggen and compile configuration files into /etc/sonic/config_db.json. [4, 9, 11, 12] 

Would you like to know how to restore factory defaults, or do you have a specific feature configuration (like BGP or VLANs) you need a JSON example for?

[1] [https://developer.cisco.com](https://developer.cisco.com/docs/sonic/configuration-management/)
[2] [https://www.ciscolive.com](https://www.ciscolive.com/c/dam/r/ciscolive/global-event/docs/2024/pdf/DEVNET-1086.pdf)
[3] [https://github.com](https://github.com/sonic-net/SONiC/wiki/Architecture)
[4] [https://netbergtw.com](https://netbergtw.com/top-support/netberg-sonic/configuring-sonic-using-cli-or-editing-json/)
[5] [https://medium.com](https://medium.com/sonic-nos/evpn-route-reflector-with-sonic-using-frr-mgmt-framework-db6d12b85ce7)
[6] [https://github.com](https://github.com/sonic-net/SONiC/wiki/technical_faq)
[7] [https://github.com](https://github.com/sonic-net/SONiC/wiki/L2-Switch-mode)
[8] [https://developer.cisco.com](https://developer.cisco.com/docs/sonic/configuration-management/)
[9] [https://netberg.ru](https://netberg.ru/top-support/netberg-sonic/configuring-sonic-using-cli-or-editing-json/)
[10] [https://github.com](https://github.com/sonic-net/SONiC/wiki/Configuration-with-Minigraph-%28~Sep-2017%29)
[11] [https://github.com](https://github.com/sonic-net/SONiC/wiki/Converting-old-or-creating-new-buffers-config)
[12] [https://github.com](https://github.com/sonic-net/SONiC/wiki/Testing-Guide)


### Looking for SONiC  supported each feature configuration using cli and json and eventually persisting in redis db.


To configure core network features in SONiC, you execute CLI commands or apply JSON configuration files. These inputs instantly rewrite keys in Redis Instance 4 (CONFIG_DB). Once modified, you must explicitly save the running config to /etc/sonic/config_db.json to persist the data across device reboots. [1, 2, 3, 4, 5] 
------------------------------
## Core Configuration Flow

   [ Method A: CLI Commands ] ---------> [  Redis DB 4  ] <--------- [ Method B: Custom JSON ]
  (e.g., config vlan add 10)            | (CONFIG_DB)  |            (via sonic-cfggen / config load)
                                        +--------------+
                                               |
                                    [ sudo config save -y ]
                                               v
                                  [ /etc/sonic/config_db.json ] (Persistent Startup Config)

------------------------------
## 1. VLAN Configuration## CLI Method

# Create VLAN 100
sudo config vlan add 100
# Assign physical port Ethernet4 as tagged
sudo config vlan member add --tagged 100 Ethernet4

## JSON Representation

{
    "VLAN": {
        "Vlan100": {
            "vlanid": 100
        }
    },
    "VLAN_MEMBER": {
        "Vlan100|Ethernet4": {
            "tagging_mode": "tagged"
        }
    }
}

------------------------------
## 2. Interface IP Address Configuration## CLI Method

# Add IP to an interface
sudo config interface ip add Ethernet8 192.168.10.1/24

## JSON Representation

{
    "INTERFACE": {
        "Ethernet8|192.168.10.1/24": {}
    }
}

------------------------------
## 3. Link Aggregation (PortChannel) Configuration## CLI Method

# Create PortChannel
sudo config portchannel add PortChannel01
# Add interface to PortChannel
sudo config portchannel member add PortChannel01 Ethernet12

## JSON Representation

{
    "PORTCHANNEL": {
        "PortChannel01": {
            "admin_status": "up",
            "mtu": 9100
        }
    },
    "PORTCHANNEL_MEMBER": {
        "PortChannel01|Ethernet12": {}
    }
}

------------------------------
## 4. BGP Neighbor Configuration## CLI Method

# Configure local ASN and local neighbor entry
sudo config bgp asn 65001
sudo config bgp neighbor add 10.0.0.2 remote-asn 65002

## JSON Representation

{
    "BGP_NEIGHBOR": {
        "10.0.0.2": {
            "asn": "65002",
            "local_addr": "10.0.0.1",
            "name": "To-Spine1"
        }
    },
    "DEVICE_METADATA": {
        "localhost": {
            "bgp_asn": "65001"
        }
    }
}

------------------------------
## Applying and Persisting to Redis DB
To execute or persist these configurations safely across the environment, run the targeted lifecycle commands from the device shell: [1] 

* Apply a partial JSON schema to live Redis ConfigDB:

sudo sonic-cfggen -j /path/to/my_patch.json --write-to-db

* Overhaul and force-reload running ConfigDB from a target JSON file:

sudo config load -y /path/to/my_config.json

* Persist Redis running states into bootable startup-config:

sudo config save -y

* Inspect specific key structures inside Redis CONFIG_DB directly:

sonic-db-cli CONFIG_DB HGETALL "VLAN|Vlan100"

[6] 

Would you like a production-grade template for Anycast Gateway / EVPN-VXLAN, or do you need the exact syntax to configure ACL Rules via JSON?

[1] [https://netbergtw.com](https://netbergtw.com/top-support/netberg-sonic/configuring-sonic-using-cli-or-editing-json/)
[2] [https://github.com](https://github.com/sonic-net/SONiC/wiki/Configuration)
[3] [https://netbergtw.com](https://netbergtw.com/top-support/netberg-sonic/overview/)
[4] [https://developer.cisco.com](https://developer.cisco.com/docs/sonic/configuration-management/)
[5] [https://www.ciscolive.com](https://www.ciscolive.com/c/dam/r/ciscolive/global-event/docs/2025/pdf/DEVNET-1086.pdf)
[6] [https://github.com](https://github.com/sonic-net/SONiC/blob/master/doc/pic/hld_fpmsyncd.md)


### Is the above a complete list of SONiC feature??


No, the examples provided above represent only a small subset of core networking features. SONiC is a modular, enterprise-grade network operating system that supports a broad range of data center and campus features. [1, 2, 3, 4] 
Below is an expanded list of SONiC features along with their corresponding Redis CONFIG_DB table structures. [5] 
## Data Center & Layer 3 Routing Features

* EVPN-VXLAN: Multi-tenant data center virtualization.
* Tables: VXLAN_TUNNEL, EVPN_NVO [6] 
* MCLAG (Multi-Chassis Link Aggregation): Active-active dual-homing to two distinct switches.
* Tables: MCLAG_DOMAIN, MCLAG_INTERFACE [7, 8] 
* VRF (Virtual Routing and Forwarding): Virtual network segmentation.
* Tables: VRF [9] 
* IPv6 Routing: Full dual-stack support including IPv6 BGP and Neighbor Discovery.
* Tables: INTERFACE (using IPv6 keys) [10, 11, 12, 13] 

## Quality of Service (QoS) & Traffic Management

* QoS Mapping: Classification of traffic into queues using DSCP/802.1p.
* Tables: DSCP_TO_TC_MAP, TC_TO_QUEUE_MAP [14, 15, 16, 17] 
* PFC (Priority Flow Control) & ECN: Lossless Ethernet execution, critical for RoCEv2 (RDMA over Converged Ethernet).
* Tables: WRED_PROFILE, QUEUE [18, 19, 20] 
* Buffer Pools: Fine-tuning hardware memory allocations for asymmetric traffic.
* Tables: BUFFER_POOL, BUFFER_PROFILE [21] 

## Security & System Control

* ACLs (Access Control Lists): Layer 2/3/4 packet filtering.
* Tables: ACL_TABLE, ACL_RULE [22, 23] 
* 802.1X Port Security: Network access control for campus environments.
* Tables: PORT_AUTHENTICATOR [24] 
* AAA (Authentication, Authorization, and Accounting): Managing operator access via TACACS+ or RADIUS.
* Tables: TACACS_SERVER, RADIUS_SERVER [25, 26, 27] 

## Telemetry & Monitoring

* gNMI / Streaming Telemetry: Modern gRPC-based state tracking instead of traditional SNMP polling.
* Tables: Driven primarily by automated mapping of the existing COUNTERS_DB and STATE_DB instances. [28, 29, 30, 31, 32] 
* sFlow / Mirroring: Packet sampling and session port mirroring (SPAN/ERSPAN).
* Tables: SFLOW, MIRROR_SESSION [33, 34] 

------------------------------
## Verifying All Supported Tables on Your System
Because SONiC introduces new features with each community release, the definitive list of supported features on your specific switch image is determined by the schema structures present in its database container. [35] 
You can extract the full inventory of valid config structures by dumping all valid database schema definitions directly on your switch shell:

# View every single active CONFIG_DB table key currently loaded
sonic-db-cli CONFIG_DB KEYS "*" | cut -d'|' -f1 | sort -u

Are you building configurations for a Data Center (Leaf/Spine BGP/VXLAN) deployment or a Campus (802.1X/PoE) environment? I can provide the explicit JSON and DB schemas for those specific features.

[1] [https://stordis.com](https://stordis.com/sonic-cheat-sheet/)
[2] [https://www.linkedin.com](https://www.linkedin.com/pulse/enterprise-sonic-450-released-whats-new-supported-how-%C5%82ukasz-%C5%82ukowski-ov1mf)
[3] [https://stordis.com](https://stordis.com/wp-content/uploads/2023/05/SONiC_Broadcom_4.2.0._DataSheet.pdf)
[4] [https://cloudswit.ch](https://cloudswit.ch/blogs/enterprise-sonic-support-marvell-prestera-based-l2-3-switches/)
[5] [https://admin.salesforce.com](https://admin.salesforce.com/blog/2021/jens-winter-22-salesforce-release-highlights-for-admins-and-users)
[6] [https://www.juniper.net](https://www.juniper.net/documentation/us/en/software/jvd/jvd-campus-fabric-core-distribution-crb-wired-assurance/solution_architecture.html)
[7] [https://stordis.com](https://stordis.com/mclag-and-link-state-tracking-in-enterprise-sonic/)
[8] [https://infohub.delltechnologies.com](https://infohub.delltechnologies.com/l/dell-technologies-enterprise-sonic-edge/network-edge-architecture-overview/)
[9] [https://www.uninets.com](https://www.uninets.com/blog/osi-model-interview-questions-answers)
[10] [https://plvision.eu](https://plvision.eu/white-papers/sonic-capabilities-empowering-networks-with-open-source-solutions)
[11] [https://www.arc-it.net](https://www.arc-it.net/html/standards/standard803.html)
[12] [https://stordis.com](https://stordis.com/how-data-moves-across-the-internet/)
[13] [https://www.networkershome.com](https://www.networkershome.com/fundamentals/network-design/routing-design/)
[14] [https://www.arista.com](https://www.arista.com/en/um-eos/eos-quality-of-service)
[15] [https://phoenixnap.com](https://phoenixnap.com/glossary/quality-of-service-qos)
[16] [https://github.com](https://github.com/sonic-net/SONiC/blob/master/doc/qos/tunnel_dscp_remapping.md)
[17] [https://netbergtw.com](https://netbergtw.com/top-support/netberg-sonic/priority-flow-control-pfc/)
[18] [https://be-net.com](https://be-net.com/sonic-ai/)
[19] [https://www.juniper.net](https://www.juniper.net/documentation/us/en/software/junos/storage/topics/concept/fibre-channel-terminology.html)
[20] [https://www.h3c.com](https://www.h3c.com/en/Support/Resource_Center/EN/Home/Public/00-Public/Technical_Documents/Configure___Deploy/Best_Practices/Lossless_Network_BP-Long/)
[21] [https://github.com](https://github.com/sonic-net/sonic-swss/blob/master/doc/swss-schema.md)
[22] [https://nordlayer.com](https://nordlayer.com/blog/the-role-of-access-control-lists/)
[23] [https://github.com](https://github.com/sonic-net/SONiC/wiki/Configuration)
[24] [https://plvision.eu](https://plvision.eu/sonic-lite)
[25] [https://www.cisco.com](https://www.cisco.com/c/en/us/td/docs/dcn/nx-os/nexus9000/102x/configuration/Security/cisco-nexus-9000-nx-os-security-configuration-guide-102x/m-overview.pdf)
[26] [https://www.cisco.com](https://www.cisco.com/en/US/docs/switches/datacenter/mds9000/sw/6_2/configuration/guides/sec/nx-os/sec_overview.html)
[27] [https://github.com](https://github.com/sonic-net/sonic-buildimage/blob/master/src/sonic-yang-models/doc/Configuration.md)
[28] [https://be-net.com](https://be-net.com/sonic-network-observability-and-monitoring/)
[29] [https://www.kentik.com](https://www.kentik.com/kentipedia/network-monitoring/)
[30] [https://wifihotshots.com](https://wifihotshots.com/services/managed-services/)
[31] [https://www.kentik.com](https://www.kentik.com/blog/how-to-maximize-the-value-of-streaming-telemetry/)
[32] [https://github.com](https://github.com/sonic-net/SONiC/blob/master/doc/system-telemetry/grpc_telemetry.md)
[33] [https://community.juniper.net](https://community.juniper.net/blogs/david-roy/2024/03/01/from-sflow-to-imon-sampling-on-mx10k-platforms)
[34] [https://cloudswit.ch](https://cloudswit.ch/blogs/sflow-in-sonic-for-network-monitoring/)
[35] [https://azure.microsoft.com](https://azure.microsoft.com/en-us/blog/sonic-the-network-innovation-powerhouse-behind-azure/)


### Can we have json snippets for all of this and also the sonic-cggen cmds to apply

To apply configurations in SONiC, saving raw JSON patches into files and executing sonic-cfggen or config load allows you to directly manipulate the Redis CONFIG_DB. [1] 
------------------------------
## Step-by-Step Execution Plan
Follow this exact pattern for every feature listed below: [2, 3] 

   1. Create the patch file: Save the feature's JSON block into a local file (e.g., /tmp/feature.json).
   2. Push directly into live Redis running memory (CONFIG_DB):
   
   sudo sonic-cfggen -j /tmp/feature.json --write-to-db
   
   3. Persist live memory into the startup-config boot file:
   
   sudo config save -y
   
   [1] 

(Note: For complex multi-container adjustments like BGP/EVPN, you can alternative deploy configurations via sudo config load -y /tmp/feature.json to instantly trigger systemic container refreshes.) [1, 3] 
------------------------------
## Data Center & Layer 3 Routing Features## 1. EVPN-VXLAN
Maps Layer 2/3 virtual networks into network virtualization overlay tunnels.

{
    "VXLAN_TUNNEL": {
        "vnet_tunnel": {
            "src_ip": "10.1.1.1"
        }
    },
    "EVPN_NVO": {
        "nvo1": {
            "source_vtep": "vnet_tunnel"
        }
    }
}

## 2. MCLAG (Multi-Chassis Link Aggregation) [4] 
Maintains active-active dual-homing connections across separate hardware platforms.

{
    "MCLAG_DOMAIN": {
        "1": {
            "local_ip": "10.255.1.1",
            "peer_ip": "10.255.1.2",
            "peer_link": "PortChannel10"
        }
    },
    "MCLAG_INTERFACE": {
        "1|PortChannel01": {
            "if_type": "mclag"
        }
    }
}

## 3. VRF (Virtual Routing and Forwarding)
Isolates unique Layer 3 tenant routing instances.

{
    "VRF": {
        "Vrf-TenantA": {
            "fallback": "false"
        }
    },
    "INTERFACE": {
        "Ethernet16|Vrf-TenantA": {}
    }
}

## 4. IPv6 Routing
Enables native dual-stack addressing across physical infrastructure link interfaces.

{
    "INTERFACE": {
        "Ethernet20|2001:db8:1000::1/64": {}
    }
}

------------------------------
## Quality of Service (QoS) & Traffic Management## 5. QoS Mapping
Translates incoming packet DSCP markings directly into physical internal Traffic Classes.

{
    "DSCP_TO_TC_MAP": {
        "DscpMapA": {
            "46": "5",
            "48": "6"
        }
    },
    "PORT_QOS_MAP": {
        "Ethernet0": {
            "dscp_to_tc_map": "DscpMapA"
        }
    }
}

## 6. PFC (Priority Flow Control) & ECN
Stops packet dropping on chosen CoS queues, ensuring reliable data paths for RoCEv2. [5] 

{
    "WRED_PROFILE": {
        "EcnProfile": {
            "ecn": "ecn_all",
            "green_max_threshold": "204800",
            "green_min_threshold": "102400"
        }
    },
    "QUEUE": {
        "Ethernet0|3": {
            "wred_profile": "EcnProfile"
        }
    }
}

## 7. Buffer Pools
Customizes internal switch memory allocations to accommodate bursty traffic profiles. [5] 

{
    "BUFFER_POOL": {
        "ingress_lossless_pool": {
            "mode": "dynamic",
            "size": "4194304",
            "type": "ingress"
        }
    },
    "BUFFER_PROFILE": {
        "LosslessProfile": {
            "pool": "ingress_lossless_pool",
            "size": "1024",
            "dynamic_th": "3"
        }
    }
}

------------------------------
## Security & System Control## 8. ACLs (Access Control Lists)
Provides high-performance Layer 3/4 filtering on the data plane. [6, 7] 

{
    "ACL_TABLE": {
        "Block_Bad_Traffic": {
            "policy_desc": "Drop malicious IPs",
            "ports": ["Ethernet4"],
            "stage": "ingress",
            "type": "L3"
        }
    },
    "ACL_RULE": {
        "Block_Bad_Traffic|Rule1": {
            "PACKET_ACTION": "DROP",
            "PRIORITY": "100",
            "SRC_IP": "198.51.100.45/32"
        }
    }
}

## 9. 802.1X Port Security
Blocks unauthorized infrastructure access via strict port authentication challenges.

{
    "PORT_AUTHENTICATOR": {
        "Ethernet24": {
            "auth_mode": "port-based",
            "host_mode": "single-host",
            "status": "enabled"
        }
    }
}

## 10. AAA (Authentication, Authorization, Accounting)
Ensures centralized administration mapping using TACACS+ infrastructure backends. [5] 

{
    "TACACS_SERVER": {
        "192.168.1.50": {
            "auth_type": "pap",
            "passkey": "SuperSecretKey",
            "priority": "1",
            "tcp_port": "49"
        }
    }
}

------------------------------
## Telemetry & Monitoring## 11. gNMI / Streaming Telemetry
Configures telemetry daemons to stream real-time operational metrics via gRPC channels.

{
    "TELEMETRY": {
        "gnmi": {
            "port": "50051",
            "status": "true"
        }
    }
}

## 12. sFlow / Mirroring
Captures and forwards targeted traffic flows to security or analytical monitoring systems. [5] 

{
    "SFLOW": {
        "global": {
            "admin_state": "up"
        }
    },
    "SFLOW_COLLECTOR": {
        "CollectorA": {
            "collector_ip": "10.99.1.5",
            "collector_port": "6343"
        }
    }
}

Would you like assistance in generating an Ansible playbook template to automate updating these exact JSON fragments across multiple switches, or do you need a bash verification script to query the status of these entries in the Redis database?

[1] [https://www.ciscolive.com](https://www.ciscolive.com/c/dam/r/ciscolive/global-event/docs/2025/pdf/DEVNET-2990.pdf)
[2] [https://github.com](https://github.com/sonic-net/sonic-buildimage/blob/master/src/sonic-config-engine/sonic-cfggen)
[3] [https://developer.cisco.com](https://developer.cisco.com/docs/sonic/configuration-management/)
[4] [https://stordis.com](https://stordis.com/mclag-and-link-state-tracking-in-enterprise-sonic/)
[5] [https://github.com](https://github.com/sonic-net/SONiC/wiki/Configuration)
[6] [https://github.com](https://github.com/sonic-net/SONiC/blob/master/doc/config-generic-update-rollback/SONiC_Generic_Config_Update_and_Rollback_Design.md)
[7] [https://www.supermicro.com](https://www.supermicro.com/manuals/network/Supermicro_Datacenter_SONiC_Configuration_Guide.pdf)
