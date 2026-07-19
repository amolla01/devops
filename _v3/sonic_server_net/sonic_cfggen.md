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
```
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
```
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
```
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
```
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
```
## Data Center & Layer 3 Routing Features
## 1. EVPN-VXLAN
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
```
Would you like assistance in generating an Ansible playbook template to automate updating these exact JSON fragments across multiple switches, or do you need a bash verification script to query the status of these entries in the Redis database?

[1] [https://www.ciscolive.com](https://www.ciscolive.com/c/dam/r/ciscolive/global-event/docs/2025/pdf/DEVNET-2990.pdf)
[2] [https://github.com](https://github.com/sonic-net/sonic-buildimage/blob/master/src/sonic-config-engine/sonic-cfggen)
[3] [https://developer.cisco.com](https://developer.cisco.com/docs/sonic/configuration-management/)
[4] [https://stordis.com](https://stordis.com/mclag-and-link-state-tracking-in-enterprise-sonic/)
[5] [https://github.com](https://github.com/sonic-net/SONiC/wiki/Configuration)
[6] [https://github.com](https://github.com/sonic-net/SONiC/blob/master/doc/config-generic-update-rollback/SONiC_Generic_Config_Update_and_Rollback_Design.md)
[7] [https://www.supermicro.com](https://www.supermicro.com/manuals/network/Supermicro_Datacenter_SONiC_Configuration_Guide.pdf)


## what is the company default startup configuration of SONiC for Celestica DX010

The default company startup configuration of SONiC on the Celestica DX010 is fundamentally a Layer 3 fabric configuration featuring pre-configured BGP peers on each interface. [1] 
## Default Credentials & Access

* Username: admin
* Password: YourPaSsWoRd
* Console Baud Rate: 9600 [2, 3] 

## Configuration File Location
The system stores its baseline startup settings inside the primary JSON configuration database file: [4] 

* /etc/sonic/config_db.json [4] 

## Pre-configured Keys
When the switch boots up using the factory profile, the config_db.json automatically populates with hardware-specific database keys, which include: [4] 

* DEVICE_METADATA (Hostname, platform type)
* PORT (Default 32 x 100GbE configurations mapping to Broadcom ASICs)
* DEVICE_NEIGHBOR (Layer 3 neighbor profiles)
* NTP_SERVER
* CABLE_LENGTH
* MGMT_INTERFACE (Set to obtain a management IP via DHCP by default)
* QoS and Buffer Profiles: PORT_QOS_MAP, BUFFER_QUEUE, BUFFER_PROFILE, WRED_PROFILE, DSCP_TO_TC_MAP, TC_TO_QUEUE_MAP [4, 5, 6, 7] 

## Viewing or Resetting the Configuration

* View current config: Run show runningconfiguration all from the CLI.
* Revert to default: Execute config-setup factory via the Linux shell to recreate the original company setup template. [4, 8] 

Are you looking to reconfigure this switch into Layer 2 mode for your network topology?

[1] [https://www.reddit.com](https://www.reddit.com/r/homelab/comments/n5opo2/initial_configuration_of_a_celestica_dx010_100ge/)
[2] [https://github.com](https://github.com/sonic-net/SONiC/wiki/Quick-Start)
[3] [https://documentationportal.celestica.com](https://documentationportal.celestica.com/en/software/sonic/user-manual/introduction)
[4] [https://documentationportal.celestica.com](https://documentationportal.celestica.com/en/software/sonic/user-manual/basic-configuration-and-show/startup-configuration/default-startup-configuration)
[5] [https://github.com](https://github.com/sonic-net/sonic-buildimage/blob/master/device/celestica/x86_64-cel_seastone-r0/Celestica-DX010-C32/th-seastone-dx010-32x100G-t0.config.bcm)
[6] [https://github.com](https://github.com/sonic-net/SONiC/blob/master/doc/user-manual/SONiC-User-Manual.md)
[7] [https://www.celestica.com](https://www.celestica.com/SONiC_user_manual-v1)
[8] [https://github.com](https://github.com/sonic-net/SONiC/blob/master/doc/ztp/SONiC-config-setup.md)


## Provide me a complete default factory setup config_db.json for the all discussed model below: Arista 7050QX-32, Arista 7050QX-32S, Accton AS5712-X54, Celestica-DX010

In SONiC (Software for Open Networking in the Cloud), the config_db.json layout dictates the system setup. A single static file cannot be universally shared across all four switches. Each hardware platform maps interfaces, port IDs, lane distributions, and internal Broadcom ASIC pipelines completely differently. [1] 
Instead of a generic template, SONiC generates optimized, model-specific config_db.json files on the device using its internal host and platform profiles. Below are the structural templates, unique key configurations, and precise platform generation commands required to build or recover the exact factory-default startup settings for each of these switch models. [2, 3] 
------------------------------
## 1. Unified Base Startup Structure
While port speeds and lane mappings differ, all four platforms generate the exact same basic config_db.json block for default Layer 3 factory behavior. Any custom setup starts with this framework:

{
    "DEVICE_METADATA": {
        "localhost": {
            "bgp_asn": "65100",
            "buffer_model": "traditional",
            "hostname": "sonic",
            "hwsku": "<MODEL_SPECIFIC_HWSKU>",
            "mac": "00:01:02:03:04:05",
            "platform": "<MODEL_SPECIFIC_PLATFORM_DIR>",
            "type": "Leaf"
        }
    },
    "MGMT_INTERFACE": {
        "eth0|192.168.1.2/24": {
            "gwaddr": "192.168.1.1"
        }
    },
    "PORT": {
        "Ethernet0": {
            "alias": "et1",
            "lanes": "<MODEL_SPECIFIC_LANES>",
            "speed": "<MODEL_SPECIFIC_SPEED>",
            "index": "1",
            "admin_status": "up"
        }
    }
}

------------------------------
## 2. Platform-Specific Variations & Generating Commands
Rather than writing thousand-line JSON mappings manually, you should trigger SONiC's hardware compiler sonic-cfggen using the default HWSKU flags to generate the complete, production-ready config_db.json: [2, 3] 

| Switch Model | Platform Directory (-p) | Hardware SKU (-v) | Default Port Mapping Profile | Factory Database Generation Command |
|---|---|---|---|---|
| Arista 7050QX-32 | x86_64-arista_7050_qx32 | Arista-7050QX-32 | 32 Ports × 40GbE (QSFP+) | sudo sonic-cfggen -H -p x86_64-arista_7050_qx32 -v Arista-7050QX-32 > /etc/sonic/config_db.json |
| Arista 7050QX-32S | x86_64-arista_7050_qx32s | Arista-7050QX-32S | 32 Ports × 40GbE + 4x10GbE SFP+ | sudo sonic-cfggen -H -p x86_64-arista_7050_qx32s -v Arista-7050QX-32S > /etc/sonic/config_db.json |
| Accton AS5712-X54 | x86_64-accton_as5712_54x-r0 | Accton-AS5712-54X | 48 Ports × 10GbE + 6x40GbE QSFP+ | sudo sonic-cfggen -H -p x86_64-accton_as5712_54x-r0 -v Accton-AS5712-54X > /etc/sonic/config_db.json |
| Celestica DX010 | x86_64-cel_seastone-r0 | Celestica-DX010 | 32 Ports × 100GbE (QSFP28) | sudo sonic-cfggen -H -p x86_64-cel_seastone-r0 -v Celestica-DX010 > /etc/sonic/config_db.json |

------------------------------
## 3. Recovering Factory Defaults on an Existing Device
If you have broken configs or missing keys on any of these four specific units, you can entirely bypass template syntax issues by forcing SONiC to regenerate its factory baseline setup profile directly out of its system memory: [3] 

   1. Purge Existing Changes:
   
   sudo config factory-default -y
   
   2. Verify or Manually Generate Layer 2 Presets (Optional for Homelabs):
   If your environment requires standard bridging rather than the default BGP fabric mode, inject the standard L2 switch profile during the rebuild:
   
   sudo sonic-cfggen -H -k Celestica-DX010 --preset=l2 > /etc/sonic/config_db.json
   sudo config reload /etc/sonic/config_db.json -y
   
   (Swap Celestica-DX010 for Arista-7050QX-32 or Accton-AS5712-54X based on the targeted machine).
   3. Commit the Validated JSON Configuration State to Flash:
   
   sudo config save -y
   
   [3, 4] 

Would you like the specific port lane assignments or breakout configuration syntax for any of these individual models?

[1] [https://forums.servethehome.com](https://forums.servethehome.com/index.php?threads/azure-sonic-on-the-arista-7050qx-32.17206/)
[2] [https://forums.servethehome.com](https://forums.servethehome.com/index.php?threads/psa-new-builds-of-older-sonic-versions-no-longer-work-on-the-celestica-dx010.41603/page-2)
[3] [https://forums.servethehome.com](https://forums.servethehome.com/index.php?threads/celestica-seastone-dx010-sonic-in-l2-mode-need-your-help.32209/)
[4] [https://www.reddit.com](https://www.reddit.com/r/homelab/comments/n5opo2/initial_configuration_of_a_celestica_dx010_100ge/)


## why there is no /usr/share/sonic/templates/config_db.json.j2 in sonic-vs image?

The config_db.json.j2 file is absent from the sonic-vs image because platform-specific default configurations are generally generated using minigraph.xml or handled through factory-default setup scripts during the initial boot, rather than relying on a global static Jinja2 template for all hardware variants. [1, 2] 
To configure a virtual switch, sonic-cfggen takes the hardware configuration profile and generates the active config_db.json file. [1, 3] 
Are you trying to generate a new configuration from scratch for your virtual switch or trying to locate the initial settings for your environment?

[1] [https://github.com](https://github.com/sonic-net/SONiC/blob/master/doc/ztp/SONiC-config-setup.md)
[2] [https://github.com](https://github.com/sonic-net/SONiC/wiki/Configuration)
[3] [https://hackmd.io](https://hackmd.io/@octobersky/BJO0EdtNO)


## So, how can I generate a factory default for sonic celestica dx010

To generate the factory default configuration for a Celestica DX010 switch running SONiC, you must execute the native device initialization command. SONiC does not use raw templates for this; instead, it reads the hardware platform profile embedded in the image and writes a clean configuration directly to the database.
## Step-by-Step Initialization
Run the following command directly from the SONiC CLI with root privileges:

sudo sonic-cfggen -H -p -v

## How This Command Works

* -H: Instructs the system to read the specific hardware platform profile (in this case, the Celestica DX010 definition files).
* -p: Generates the default port and interface configurations mapped specifically to that hardware's front-panel layout.
* -v: Outputs the freshly generated, valid JSON structure directly to your terminal screen for verification.

## Saving the Configuration
If the generated configuration looks correct and matches your hardware layout, overwrite your existing configuration database file and restart the services by running:

sudo sonic-cfggen -H -p > /etc/sonic/config_db.json
sudo systemctl restart sonic.target

Alternatively, on newer SONiC releases, you can completely wipe the current configuration database and restore the factory profile using the unified setup tool:

sudo config factory-default -y

Are you planning to deploy this switch using a static configuration, or will you be loading topology details via a minigraph XML file?

## since I will be executing this 'sudo sonic-cfggen -H -p -v' inside sonic-vs in a virtual lab environment, how would I pass the param values for celestica that is available ?

To generate the configuration for a hardware platform while inside the virtual sonic-vs environment, you must explicitly feed the hardware SKU identifier into sonic-cfggen using the -k (or --hwsku) parameter flag. [1, 2] 
Because sonic-vs detects its native platform environment as a virtual KVM appliance, simply typing -H alone causes it to look up virtual port maps. Forcing a physical switch's footprint requires mocking the targeted profiles. [2] 
## Step 1: Pass the Specific Hardware SKU
For the Celestica DX010, the identifier template recognized inside the SONiC repository is Seastone-DX010 (or Celestica-DX010 depending on your version's compiled submodules). You also must define a network routing topology profile (such as L2 or L3) using the --preset flag: [1, 2, 3] 

sudo sonic-cfggen -H -k Seastone-DX010 --preset=l2 -p


* -k Seastone-DX010: Overrides the local container detection and forces the script to generate metadata using the Celestica front-panel mappings.
* --preset=l2: Sets a Layer 2 profile (use t1 or l3 if you want standard Top-of-Rack Layer 3 routing configuration instead). [1, 2, 4] 

## Step 2: Route Around Missing Directory Maps
If you hit an error indicating the directory path or port_config.ini file is missing inside sonic-vs, it means the physical platform profiles were trimmed out of your specific virtual image variant to save space. You can manually feed the tool the source files directly by pointing to the file path:

sudo sonic-cfggen -H -k Seastone-DX010 --preset=l2 -p /usr/share/sonic/device/x86_64-cel_seastone-r0/Seastone-DX010/port_config.ini

## Save directly to your working file

sudo sonic-cfggen -H -k Seastone-DX010 --preset=l2 -p > /etc/sonic/config_db.json

Are you planning to run routing protocols like BGP on these interfaces inside your lab topology, or are you just testing basic VLAN and L2 data-plane connectivity? [5] 

[1] [https://forums.servethehome.com](https://forums.servethehome.com/index.php?threads/help-with-seastone-dx010.33822/)
[2] [https://configif.wordpress.com](https://configif.wordpress.com/2021/12/06/eve-ng-adding-a-sonic-switch/)
[3] [https://forums.servethehome.com](https://forums.servethehome.com/index.php?threads/celestica-seastone-dx010-sonic-in-l2-mode-need-your-help.32209/)
[4] [https://github.com](https://github.com/sonic-net/SONiC/wiki/L2-Switch-mode)
[5] [https://github.com](https://github.com/sonic-net/SONiC/wiki/L2-Switch-mode)


-k Seastone-DX010: Overrides the local container detection and forces the script to generate metadata using the Celestica front-panel mappings.--preset=l2: Sets a Layer 2 profile (use t1 or l3 if you want standard Top-of-Rack Layer 3 routing configuration instead).

## You said: I intend to go with L3, so what should be the --preset value..

To generate a Layer 3 routing configuration, the --preset value should be set to l3.
Depending on your specific SONiC build or repository version, the tool also maps L3 datacenter topologies using data-center role abbreviations. [1, 2] 
## Valid L3 Preset Options

* l3: The universal, baseline Layer 3 configuration profile used across modern SONiC builds to allocate clean routed ports.
* t1: The specific architectural preset representing a Top-of-Rack (Leaf) switch in a standard Spine-Leaf topology. This populates Layer 3 interfaces alongside automated BGP peering structures.
* t0: The architectural preset representing a Spine level configuration profile. [1, 2] 

## Your Final Command for L3
To structure your virtual Celestica DX010 with a default Layer 3 framework inside sonic-vs, run:

sudo sonic-cfggen -H -k Seastone-DX010 --preset=l3 -p > /etc/sonic/config_db.json

(If l3 is rejected by your current utility version, substitute it with --preset=t1 to pull the core standard L3 Top-of-Rack profile). [1] 
## Apply the Changes
After writing the profile, reload the database backend to initialize your Layer 3 routed interfaces:

sudo config reload -y

Do you need help defining the IP addresses or setting up the BGP neighbors on these newly generated Layer 3 interfaces?

[1] [https://qiita.com](https://qiita.com/masru0714/items/e7e8be321919e9210209)
[2] [https://configif.wordpress.com](https://configif.wordpress.com/2022/03/11/sonic-switch-configuration-via-cli/)


## what doe 'sudo sonic-cfggen -H -k Seastone-DX010 --preset=l3 -p /usr/share/sonic/device/x86_64-cel_seastone-r0/Seastone-DX010/port_config.ini' cmd do and what is the difference with the above?

The command sudo sonic-cfggen -H -k Seastone-DX010 --preset=l3 -p /usr/share/sonic/device/x86_64-cel_seastone-r0/Seastone-DX010/port_config.ini instructs the SONiC configuration generator tool to build a Layer 3 base configuration by explicitly reading a local physical port-mapping file instead of relying on the system's local hardware auto-discovery. [1] 
## Breakdown of the Command

* sudo sonic-cfggen: Runs the SONiC configuration engine with root access. [2] 
* -H: Tells the engine to generate default initialization files based on hardware profiles. [3] 
* -k Seastone-DX010: Mocks the hardware platform to appear as a physical Celestica DX010. [3] 
* --preset=l3: Populates a native, routed Layer 3 network architecture template. [4] 
* -p: Flags that the utility should explicitly process a physical port_config.ini layout. [3, 5] 
* /usr/share/sonic/.../port_config.ini: The direct, literal system path where the specific physical port configurations (mapping front panel interfaces to ASIC SerDes lanes) are stored. [5, 6] 

------------------------------
## The Functional Differences

| Feature | The Bare Command (... --preset=l3 -p) | The Targeted Command (... -p /path/to/port_config.ini) |
|---|---|---|
| Port Map Source | Expects the operating system to natively discover the local platform directory layout. | Overrides the system's automated path checks by pointing straight to a hardcoded layout directory. |
| Virtual Environment Success | Fails inside virtual labs (sonic-vs) because a VS appliance natively looks for virtual port layouts rather than hardware folders. | Succeeds inside virtual labs by bypassing environmental checks and using targeted files to mock real switches. |
| Output Type | Safely routes the generated layout variables onto your standard shell stdout stream for immediate verification. | Safely routes the generated layout variables onto your standard shell stdout stream for immediate verification. |

The critical difference is environment execution. The bare version is intended for an operating system natively sitting on physical Celestica iron. The second variation forces a virtual laboratory environment (sonic-vs) to generate configurations for hardware it cannot physically touch by explicitly feeding it the template. [3, 4] 
Would you like to learn how to change interface breakout speeds (e.g., splitting a 100G port into 4x25G) using that file inside your simulation environment? [5, 7] 

[1] [https://forums.servethehome.com](https://forums.servethehome.com/index.php?threads/celestica-seastone-dx010-sonic-in-l2-mode-need-your-help.32209/)
[2] [https://developer.cisco.com](https://developer.cisco.com/docs/sonic/configuration-management/)
[3] [https://github.com](https://github.com/sonic-net/SONiC/wiki/L2-Switch-mode)
[4] [https://configif.wordpress.com](https://configif.wordpress.com/2022/03/11/sonic-switch-configuration-via-cli/)
[5] [https://www.supermicro.com](https://www.supermicro.com/manuals/network/Supermicro_Datacenter_SONiC_Configuration_Guide.pdf)
[6] [https://github.com](https://github.com/sonic-net/SONiC/wiki/Porting-Guide)
[7] [https://github.com](https://github.com/sonic-net/sonic-utilities/blob/master/doc/Command-Reference.md)


## like to learn how to change interface breakout speeds to 4x10G for Arista 7050QX-32S 

On Arista hardware running SONiC, changing an interface breakout speed depends on whether your build includes the Dynamic Port Breakout CLI or if you are running an older image where you must modify the port_config.ini layout template. [1, 2] 
The Arista 7050QX-32S supports 4x10G breakout configurations on its first 24 QSFP+ ports (interfaces 1 through 24). [3] 
------------------------------
## Method 1: Using the Modern SONiC CLI (Dynamic Breakout)
If your SONiC version supports dynamic changes, enter the SONiC CLI environment and execute the configuration directly. [4, 5] 

   1. Enter the configuration console:
   
   sonic-cli
   
   2. Navigate to configuration terminal mode:
   
   switch# configure terminal
   
   3. Break out the target physical interface (e.g., Slot 1, Port 5) to 4x10G:
   
   switch(config)# interface breakout port 1/5 mode 4x10G
   
   4. Verify the change:
   
   switch(config)# do show interface breakout port 1/5
   
   [4, 6, 7] 

------------------------------
## Method 2: Manual Profile Modification (For Lab/sonic-vs or Older Images)
If you are inside your virtual laboratory mockup or running a traditional SONiC distribution that lacks dynamic execution, you must explicitly modify the platform configuration file. [1, 2] 
## Step 1: Open the Port Layout Mapping File
Find and edit the specific layout file belonging to your platform: [1] 

sudo nano /usr/share/sonic/device/x86_64-arista_7050qx_32s-r0/Arista-7050QX-32S/port_config.ini

## Step 2: Update the Active Speed Lines
Inside this file, you will find lines detailing the channel lanes and port speeds. To transition a single 40G interface into a 4x10G array, change the mapped port speed and separate the lanes. [2] 

* Original 40G Line Representation:

# name       lanes        speed
Ethernet16   61,62,63,64  40000

* Updated 4x10G Breakout Lines Representation:

# name         lanes  speed
Ethernet16/1   61     10000
Ethernet16/2   62     10000
Ethernet16/3   63     10000
Ethernet16/4   64     10000


## Step 3: Regenerate and Reload Your OS Configuration
Once the layout values are saved to disk, reload the hardware map generation engine using the syntax established earlier to reset your local system database: [1] 

sudo sonic-cfggen -H -k Arista-7050QX-32S -p /usr/share/sonic/device/x86_64-arista_7050qx_32s-r0/Arista-7050QX-32S/port_config.ini > /etc/sonic/config_db.json
sudo config reload -y

Are you seeing any syntax or lane mapping errors on your terminal when you try to parse the updated layout definitions?

[1] [https://netbergtw.com](https://netbergtw.com/top-support/netberg-sonic/port-breakout/)
[2] [https://github.com](https://github.com/sonic-net/SONiC/wiki/Port-Breakout-and-Speed-Requirements)
[3] [https://forums.servethehome.com](https://forums.servethehome.com/index.php?threads/arista-7050qx-32-no-link-in-ports-1-24.46940/)
[4] [https://www.dell.com](https://www.dell.com/support/kbdoc/en-us/000218535/dell-networking-sonic-how-to-configure-how-to-configure-breakout-ports)
[5] [https://github.com](https://github.com/sonic-net/SONiC/blob/master/doc/dynamic-port-breakout/sonic-dynamic-port-breakout-HLD.md)
[6] [https://www.dell.com](https://www.dell.com/support/kbdoc/en-us/000226710/dell-networking-sonic-how-to-configure-breakout-port-4x100g)
[7] [https://www.reddit.com](https://www.reddit.com/r/Arista/comments/1egjzrj/odd_question_can_you_split_a_100gb_qsfp_port_into/)


## Why 'sudo sonic-cfggen -H -k Seastone-DX010 --preset=l3 -p > /etc/sonic/config_db.json' in sonic-vs throwing permission denied but ''sudo sonic-cfggen -H -k Seastone-DX010 --preset=l3 -p' prints json in the console

The Permission denied error happens because bash redirection (>) is executed by your current shell, not by the sudo command. [1] 
When you run sudo sonic-cfggen ... > /etc/sonic/config_db.json:

* sudo gives root privileges only to the sonic-cfggen process.
* The output redirection (>) is handled by your normal user shell, which does not have permission to write directly to the restricted /etc/sonic/ directory. [2] 

The first part successfully generates the JSON data, but your unprivileged shell blocks it from being written to the file. When you omit the > redirection, the tool simply prints the output directly to the screen (stdout), which does not require disk write permissions.
## How to Fix It
To write the file with root privileges, choose one of these three standard approaches:
## Option 1: Use tee (Recommended)
Pipe the output to sudo tee. This forces the file-writing process to run with root permissions: [3] 

sudo sonic-cfggen -H -k Seastone-DX010 --preset=l3 -p | sudo tee /etc/sonic/config_db.json > /dev/null

## Option 2: Run the entire string in a root shell
Pass the entire command string inside a root shell invocation (sudo sh -c):

sudo sh -c 'sonic-cfggen -H -k Seastone-DX010 --preset=l3 -p > /etc/sonic/config_db.json'

## Option 3: Switch to the root user first
Drop into a root shell before running your generation tasks:

sudo su
sonic-cfggen -H -k Seastone-DX010 --preset=l3 -p > /etc/sonic/config_db.json
exit

After writing this configuration successfully, do you need help using config reload -y to verify that your virtual interfaces initialize correctly inside the lab?

[1] [https://www.adamsdesk.com](https://www.adamsdesk.com/posts/sudo-echo-permission-denied/)
[2] [https://www.adamsdesk.com](https://www.adamsdesk.com/posts/sudo-echo-permission-denied/)
[3] [https://www.adamsdesk.com](https://www.adamsdesk.com/posts/sudo-echo-permission-denied/)


## Then how to run this 'sudo sonic-cfggen -H -k Arista-7050QX-32S -p /usr/share/sonic/device/x86_64-arista_7050qx_32s-r0/Arista-7050QX-32S/port_config.ini > /etc/sonic/config_db.json'

To run this command without getting a Permission denied error, you need to ensure the file-writing process has root privileges.
Use one of these three standard methods:
## Method 1: Use tee (Recommended)
Pipe the output to sudo tee. This allows the text-writing mechanism to run with elevated root permissions:

sudo sonic-cfggen -H -k Arista-7050QX-32S -p /usr/share/sonic/device/x86_64-arista_7050qx_32s-r0/Arista-7050QX-32S/port_config.ini | sudo tee /etc/sonic/config_db.json > /dev/null

(The > /dev/null at the end cleanly hides the JSON from spilling onto your terminal screen).
## Method 2: Execute within a Root Shell String
Wrap the entire command inside a root shell invocation (sudo sh -c) so the redirection (>) inherits root access:

sudo sh -c 'sonic-cfggen -H -k Arista-7050QX-32S -p /usr/share/sonic/device/x86_64-arista_7050qx_32s-r0/Arista-7050QX-32S/port_config.ini > /etc/sonic/config_db.json'

## Method 3: Switch to Root User First
Temporarily drop completely into a root environment before executing the redirection: [1] 

sudo su
sonic-cfggen -H -k Arista-7050QX-32S -p /usr/share/sonic/device/x86_64-arista_7050qx_32s-r0/Arista-7050QX-32S/port_config.ini > /etc/sonic/config_db.json
exit

Once you have written the file, would you like the commands to restart the SONiC services or check the port operational status?

[1] [https://www.voxfor.com](https://www.voxfor.com/how-to-check-superuser-privileges-in-linux-using-syscalls/)
