create_cloud_init_iso() {
    local vm_name="$1" user="$2" pass="$3"
    local iso="$CLOUD_INIT_DIR/${vm_name}-cidata.iso"
    [[ -f "$iso" ]] && return 0
    local ci_tmp="$TMP_DIR/ci-${vm_name}"
    mkdir -p "$ci_tmp"
    local md="$ci_tmp/meta-data"
    local ud="$ci_tmp/user-data"

    # =========================================================================
    # STEP 1: COMPILE CORE BASE METADATA BLOCK
    # =========================================================================
    cat > "$md" << 'EOF'
instance-id: ${vm_name}
local-hostname: ${vm_name}
EOF

    # =========================================================================
    # STEP 2: COMPILE UNIFORM USER DATA HEADER LAYER
    # =========================================================================
    cat > "$ud" << EOF
#cloud-config
hostname: ${vm_name}
manage_etc_hosts: true
users:
  - name: ${user}
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    plain_text_passwd: '${pass}'
    shell: /bin/bash
ssh_pwauth: true
disable_root: false
chpasswd:
  expire: false
  list: |
    ${user}:${pass}
package_update: false
growpart:
  mode: auto
  devices: ['/']
  ignore_growroot_disabled: false
resize_rootfs: true
write_files:
  - path: /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
    content: |
      network: {config: disabled}
    permissions: '0644'
EOF

    # Enforce lowercase name transformation to match core orchestration values
    local clean_lc_name
    clean_lc_name=$(echo "$vm_name" | tr '[:upper:]' '[:lower:]')
    local mgmt_mac
    mgmt_mac=$(gen_mac "$clean_lc_name" "mgmt")

    # =========================================================================
    # STEP 3: DATA-DRIVEN INTERFACE PROVISIONING CONDITIONS (DYNAMIC INJECTION)
    # =========================================================================
    if [[ "$vm_name" == "Exit_Router1" || "$vm_name" == "Exit_Router2" ]]; then
        local clean_slot="40"
        [[ "$vm_name" == "Exit_Router2" ]] && clean_slot="39"
        local target_ip="10.10.1.${clean_slot}"
        
        # UNQUOTED HEREDOCS ALLOW ${target_ip} TO VALUE EXPAND DYNAMICALLY HERE
        cat >> "$ud" << UDROUTEREOF
runcmd:
  - systemctl enable serial-getty@ttyS0.service || true
  - mkdir -p /etc/netplan
  - chmod 600 /etc/netplan
  - |
    cat << NETEOF > /etc/netplan/00-oob-management.yaml
    network:
      version: 2
      renderer: networkd
      ethernets:
        enp1s0:
          match:
            name: enp1s0
          set-name: mgtport
          dhcp4: false
          addresses: [${target_ip}/24]
          routes:
            - to: default
              via: 10.10.1.1
              metric: 10
    NETEOF
  - rm -f /etc/netplan/50-cloud-init.yaml
  - chmod 600 /etc/netplan/00-oob-management.yaml
  - netplan generate
  - netplan apply
  - |
    nohup bash -c "
      until ping -c 1 -W 1 10.10.1.1 &>/dev/null; do sleep 2; done
      apt-get update && apt-get install -y linux-modules-extra-generic
      modprobe vrf
      echo 'vrf' >> /etc/modules
      cat << 'VRFEOF' > /etc/netplan/00-oob-management.yaml
      network:
        version: 2
        renderer: networkd
        vrfs:
          mgmt-vrf:
            table: 1000
            interfaces: [mgtport]
        ethernets:
          mgtport:
            match:
              name: enp1s0
            set-name: mgtport
            dhcp4: false
            addresses: [${target_ip}/24]
            routes:
              - to: 10.10.1.0/24
                via: 10.10.1.1
                metric: 10
                table: 1000
          enp2s0: { dhcp4: false, optional: true }
          enp3s0: { dhcp4: false, optional: true }
      VRFEOF
      netplan generate && netplan apply
      systemctl stop systemd-resolved || true
      systemctl disable systemd-resolved || true
      rm -f /etc/resolv.conf
      echo 'nameserver 8.8.8.8' > /etc/resolv.conf
      echo 'nameserver 1.1.1.1' >> /etc/resolv.conf
      chattr +i /etc/resolv.conf || true
      ip route add default via 10.10.1.1 dev mgtport metric 20 || true
      echo 'USER_PLACEHOLDER ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/90-cloud-init-users
      chmod 0440 /etc/sudoers.d/90-cloud-init-users
    " >/var/log/vrf-bootstrap.log 2>&1 &
  - touch /etc/cloud/cloud-init.disabled
UDROUTEREOF

    elif [[ "$vm_name" =~ ^Host ]]; then
        local target_ip="${VM_MGMT_IP[$vm_name]}"
        
        cat >> "$ud" << UDHOSTEOF
runcmd:
  - systemctl enable serial-getty@ttyS0.service || true
  - mkdir -p /etc/netplan
  - |
    cat << NETEOF > /etc/netplan/00-oob-management.yaml
    network:
      version: 2
      renderer: networkd
      ethernets:
        enp1s0:
          match:
            name: enp1s0
          set-name: mgtport
          dhcp4: false
          addresses: [${target_ip}/24]
          routes:
            - to: 10.10.1.0/24
              via: 10.10.1.1
              metric: 10
    NETEOF
  - rm -f /etc/netplan/50-cloud-init.yaml
  - chmod 600 /etc/netplan/00-oob-management.yaml
  - netplan generate
  - netplan apply
  - |
    nohup bash -c "
      until ping -c 1 -W 1 10.10.1.1 &>/dev/null; do sleep 2; done
      apt-get update && apt-get install -y linux-modules-extra-generic
      modprobe vrf
      echo 'vrf' >> /etc/modules
      cat << 'VRFEOF' > /etc/netplan/00-oob-management.yaml
      network:
        version: 2
        renderer: networkd
        vrfs:
          mgmt-vrf:
            table: 1000
            interfaces: [mgtport]
        ethernets:
          mgtport:
            match:
              name: enp1s0
            set-name: mgtport
            dhcp4: false
            addresses: [${target_ip}/24]
            routes:
              - to: 10.10.1.0/24
                via: 10.10.1.1
                metric: 10
                table: 1000
          enp2s0: { dhcp4: false, optional: true }
          enp3s0: { dhcp4: false, optional: true }
      VRFEOF
      netplan generate && netplan apply
      systemctl stop systemd-resolved || true
      systemctl disable systemd-resolved || true
      rm -f /etc/resolv.conf
      echo 'nameserver 8.8.8.8' > /etc/resolv.conf
      echo 'nameserver 1.1.1.1' >> /etc/resolv.conf
      chattr +i /etc/resolv.conf || true
      ip route add default via 10.10.1.1 dev mgtport metric 20 || true
      echo 'USER_PLACEHOLDER ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/90-cloud-init-users
      chmod 0440 /etc/sudoers.d/90-cloud-init-users
    " >/var/log/vrf-bootstrap.log 2>&1 &
  - touch /etc/cloud/cloud-init.disabled
UDHOSTEOF

    elif [[ "$vm_name" == "MonitorSrv" ]]; then
        local target_ip="${VM_MGMT_IP[MonitorSrv]}"
        
        cat >> "$ud" << UDMONEOF
runcmd:
  - systemctl enable serial-getty@ttyS0.service || true
  - mkdir -p /etc/netplan
  - |
    cat << NETEOF > /etc/netplan/00-oob-management.yaml
    network:
      version: 2
      renderer: networkd
      ethernets:
        enp1s0:
          match:
            name: enp1s0
          set-name: mgtport
          dhcp4: false
          addresses: [${target_ip}/24]
          routes:
            - to: 10.10.1.0/24
              via: 10.10.1.1
              metric: 10
    NETEOF
  - rm -f /etc/netplan/50-cloud-init.yaml
  - chmod 600 /etc/netplan/00-oob-management.yaml
  - netplan generate
  - netplan apply
  - |
    nohup bash -c "
      until ping -c 1 -W 1 10.10.1.1 &>/dev/null; do sleep 2; done
      apt-get update && apt-get install -y linux-modules-extra-generic
      modprobe vrf
      echo 'vrf' >> /etc/modules
      cat << 'VRFEOF' > /etc/netplan/00-oob-management.yaml
      network:
        version: 2
        renderer: networkd
        vrfs:
          mgmt-vrf:
            table: 1000
            interfaces: [mgtport]
        ethernets:
          mgtport:
            match:
              name: enp1s0
            set-name: mgtport
            dhcp4: false
            addresses: [${target_ip}/24]
            routes:
              - to: 10.10.1.0/24
                via: 10.10.1.1
                metric: 10
                table: 1000
          enp2s0: { dhcp4: false, optional: true }
          enp3s0: { dhcp4: false, optional: true }
      VRFEOF
      netplan generate && netplan apply
      systemctl stop systemd-resolved || true
      systemctl disable systemd-resolved || true
      rm -f /etc/resolv.conf
      echo 'nameserver 8.8.8.8' > /etc/resolv.conf
      echo 'nameserver 1.1.1.1' >> /etc/resolv.conf
      chattr +i /etc/resolv.conf || true
      ip route add default via 10.10.1.1 dev mgtport metric 20 || true
      echo 'USER_PLACEHOLDER ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/90-cloud-init-users
      chmod 0440 /etc/sudoers.d/90-cloud-init-users
    " >/var/log/vrf-bootstrap.log 2>&1 &
  - touch /etc/cloud/cloud-init.disabled
UDMONEOF

    else
        cat >> "$ud" << 'EOF'
runcmd:
  - systemctl enable serial-getty@ttyS0.service || true
  - touch /etc/cloud/cloud-init.disabled
  - echo "Cloud-init complete for \${vm_name}" > /var/log/cloud-init-done
EOF
    fi

    # =========================================================================
    # STEP 4: PACKAGE AND COMPILE FINAL SEED IMAGE DISK
    # =========================================================================
    local nc="$ci_tmp/network-config"
    cat > "$nc" << 'EOF'
version: 2
config: disabled
EOF

    genisoimage -output "$iso" -volid cidata -joliet -rock "$ud" "$md" "$nc" 2>/dev/null
    rm -rf "$ci_tmp"
    sudo chmod o+r "$iso"
}

XXXXXXXXXXXXXXXXXXXXXXXXXX
ubuntu@ubuntu:~$ sudo ls -al /etc/netplan
total 12
drw-------   2 root root 4096 Jul  7 16:01 .
drwxr-xr-x 106 root root 4096 Jul  7 16:01 ..
-rw-------   1 root root  978 Jul  7 16:01 00-oob-management.yaml
ubuntu@ubuntu:~$ sudo cat /etc/netplan/00-oob-management.yaml
  network:
    version: 2
    renderer: networkd
    vrfs:
      mgmt-vrf:
        table: 1000
        interfaces: [mgtport]
    ethernets:
      mgtport:
        match:
          name: enp1s0
        set-name: mgtport
        dhcp4: false
        addresses: [10.10.1.40/24]
        routes:
          - to: 10.10.1.0/24
            via: 10.10.1.1
            metric: 10
            table: 1000
      enp2s0: { dhcp4: false, optional: true }
      enp3s0: { dhcp4: false, optional: true }
  VRFEOF
  netplan generate && netplan apply
  systemctl stop systemd-resolved || true
  systemctl disable systemd-resolved || true
  rm -f /etc/resolv.conf
  echo 'nameserver 8.8.8.8' > /etc/resolv.conf
  echo 'nameserver 1.1.1.1' >> /etc/resolv.conf
  chattr +i /etc/resolv.conf || true
  ip route add default via 10.10.1.1 dev mgtport metric 20 || true
  echo 'USER_PLACEHOLDER ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/90-cloud-init-users
  chmod 0440 /etc/sudoers.d/90-cloud-init-users
ubuntu@ubuntu:~$
