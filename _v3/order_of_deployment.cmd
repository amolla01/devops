Here's your deployment order. It's documented in '02-deployment-operations.md:69':

Phase 0: KVM Topology         → deploy_lab_v3.sh
Phase 1: Day-0 Base           → deploy_day0.yml
Phase 2: Day-1 Fabric (BGP)   → deploy_day1.yml
Phase 3: Leaf↔Server BGP      → deploy_leaf_server_bgp.yml → deploy_server_networking.yml
Phase 4: EVPN Overlay         → deploy_sonic_evpn.yml → deploy_evpn_overlay.yml
Phase 5: Infrastructure       → deploy_kubespray.yml → deploy_postgresql.yml → deploy_maas.yml
                               → deploy_ceph.yml → deploy_openstack_helm.yml → deploy_monitoring.yml
Phase 6: Application          → deploy_openstack_gateways.yml → deploy_premium_firewall.yml
                               → deploy_sheba_cloud_infra.yml
Phase 7: OVN BGP Agent        → deploy_bgp_agent.yml (after OpenStack is running)



Found it — 51-deployment-chronology-kvm-vs-real-hardware.html. Let me read the KVM-specific order:

Read 51-deployment-chronology-kvm-vs-real-hardware.html, lines 475 to 600

Here it is — 51-deployment-chronology-kvm-vs-real-hardware.html:480. The KVM-specific order explicitly skips MaaS:


Phase 0: KVM Topology          → deploy_lab_v13.sh kvm-deploy
Phase 1: Day-0 Base            → deploy_day0.yml
Phase 2: Day-1 Fabric BGP      → deploy_day1.yml
Phase 3: Leaf↔Server + EVPN    → deploy_leaf_server_bgp.yml → deploy_server_networking.yml
                                → deploy_sonic_evpn.yml → deploy_evpn_overlay.yml
Phase 4: Kubernetes (Kubespray) → deploy_kubespray.yml
Phase 5: PostgreSQL             → deploy_postgresql.yml
Phase 6: 🚫 MaaS — SKIP IN KVM (bare-metal PXE provisioning, useless in virtual lab)
Phase 7: Ceph Storage           → deploy_ceph.yml
Phase 8: OpenStack (Helm)       → deploy_openstack_helm.yml
Phase 9: Monitoring             → deploy_monitoring.yml
Phase 10: Premium Firewall      → deploy_premium_firewall.yml


Key difference from the generic order: MaaS is entirely skipped in KVM profiles because all nodes already exist as VMs — there's nothing to PXE boot or commission.

In the past we discussed, the network topology, we are building, we do not require to deploy evpn for different use - cases we want to handle because we are running bgp on the host and totally adopting routed networking, please, list those phases and playbooks to execute as outline structure:

Here's the relevant discussion. It was documented in 09-multi-tenant-architecture-host-overlay.html:1808:

EVPN playbooks are optional — design artifacts, not requirements for your architecture. Your topology uses pure L3 routed fabric with BGP on the host (BGP ECMP multi-homing). Multi-tenancy is handled by OVN/Calico overlay on the servers, NOT by EVPN on the switches.

KVM Profile — Correct Deployment Order (no EVPN, no MaaS):

Phase 0: KVM Topology   → deploy_lab_v13.sh kvm-deploy

Phase 1: Day-0 Base Provisioning  → deploy_day0.yml

Phase 2: Day-1 Fabric Wiring (BGP underlay + Exit Routers)  → deploy_day1.yml

Phase 3: Leaf ↔ Server BGP + Server Networking   → deploy_leaf_server_bgp.yml  → deploy_server_networking.yml

Phase 4: 🚫 EVPN — SKIP (pure L3 routed fabric; overlay handled by OVN/Calico on hosts)
                                                 → deploy_sonic_evpn.yml      ← DO NOT RUN
                                                 → deploy_evpn_overlay.yml    ← DO NOT RUN

Phase 5: Kubernetes (Kubespray)  → deploy_kubespray.yml

Phase 6: PostgreSQL    → deploy_postgresql.yml

Phase 7: 🚫 MaaS — SKIP (no bare-metal PXE in KVM)  → deploy_maas.yml            ← DO NOT RUN

Phase 8: Ceph Storage  → deploy_ceph.yml

Phase 9: OpenStack (Helm on K8s)  → deploy_openstack_helm.yml

Phase 10: Monitoring  → deploy_monitoring.yml

Phase 11: OVN BGP Agent (dynamic tenant route advertisement)  → deploy_bgp_agent.yml
||

  Phase 0: KVM Topology
         → deploy_lab_v13.sh kvm-deploy

Phase 1: Day-0 Base Provisioning
         → deploy_day0.yml

Phase 2: Day-1 Fabric Wiring (BGP underlay + Exit Routers)
         → deploy_day1.yml

Phase 3: Leaf ↔ Server BGP + Server Networking
         → deploy_leaf_server_bgp.yml
         → deploy_server_networking.yml

Phase 4: 🚫 EVPN — SKIP (pure L3 routed fabric; overlay handled by OVN/Calico on hosts)
         → deploy_sonic_evpn.yml      ← DO NOT RUN
         → deploy_evpn_overlay.yml    ← DO NOT RUN

Phase 5: Kubernetes (Kubespray)
         → deploy_kubespray.yml

Phase 6: PostgreSQL
         → deploy_postgresql.yml

Phase 7: 🚫 MaaS — SKIP (no bare-metal PXE in KVM)
         → deploy_maas.yml            ← DO NOT RUN

Phase 8: Ceph Storage
         → deploy_ceph.yml

Phase 9: OpenStack (Helm on K8s)
         → deploy_openstack_helm.yml

Phase 10: Monitoring
          → deploy_monitoring.yml

Phase 11: OVN BGP Agent (dynamic tenant route advertisement)
          → deploy_bgp_agent.yml

The fabric RIB stays simple (~8-10 routes = server loopbacks only). Tenant isolation scales via OVN logical networks on the hosts, not switch-level EVPN state.


  
