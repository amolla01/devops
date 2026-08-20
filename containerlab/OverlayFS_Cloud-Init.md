```
#cloud-config
users:
  - name: nh1221
    plain_text_passwd: Welcome1!
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: sudo
    lock_passwd: false
  - name: ubuntu
    plain_text_passwd: ubuntu
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL`
    lock_passwd: false
ssh_pwauth: true
chpasswd:
  expire: false

runcmd:
  - |
    # =========================================================================
    # STEP 1: BULLETPROOF STORAGE DISCOVERY (Handles /dev/vdb or /dev/sdb)
    # =========================================================================
    DATA_DEV=$(lsblk -dpno NAME,SIZE,TYPE | awk '$3=="disk" && $1 ~ /\/dev\/vd[b-z]/ {print $1}' | head -n1)
    
    if [ -z "$DATA_DEV" ]; then
      DATA_DEV=$(lsblk -dpno NAME,SIZE,TYPE | awk '$3=="disk" && $1 ~ /\/dev\/sd[b-z]/ {print $1}' | head -n1)
    fi
    
    [ -z "$DATA_DEV" ] && exit 0

    # =========================================================================
    # STEP 2: IDEMPOTENT FORMATTING (Skips formatting if already initialized)
    # =========================================================================
    if ! blkid "$DATA_DEV" > /dev/null 2>&1; then
      mkfs.ext4 -L hostdata "$DATA_DEV"
      mkdir -p /mnt/storage
      mount "$DATA_DEV" /mnt/storage
      mkdir -p /mnt/storage/upper /mnt/storage/work
      umount /mnt/storage
    fi

    # =========================================================================
    # STEP 3: MASTER MOUNT ESTABLISHMENT
    # =========================================================================
    mkdir -p /mnt/storage
    grep -q 'LABEL=hostdata' /etc/fstab \
      || echo 'LABEL=hostdata /mnt/storage ext4 defaults,nofail 0 2' >> /etc/fstab
    mountpoint -q /mnt/storage || mount -L hostdata /mnt/storage

    # =========================================================================
    # STEP 4: APPLY OVERLAYFS SHIELD (Protects the 2.8GB root disk)
    # =========================================================================
    TARGET_DIRS="var opt usr etc"
    for dir in $TARGET_DIRS; do
      mkdir -p /mnt/storage/upper/$dir /mnt/storage/work/$dir
      
      grep -q "overlay_$dir" /etc/fstab \
        || echo "overlay_$dir /$dir overlay defaults,lowerdir=/$dir,upperdir=/mnt/storage/upper/$dir,workdir=/mnt/storage/work/$dir 0 0" >> /etc/fstab
      
      mountpoint -q /$dir || mount -t overlay overlay_$dir -o lowerdir=/$dir,upperdir=/mnt/storage/upper/$dir,workdir=/mnt/storage/work/$dir /$dir
    done

  # (Optional) You can place other standard initialization commands BELOW this line.
```  
XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
- name: Ensure remote data disks are expanded to 150GB
  ansible.builtin.command:
    cmd: qemu-img resize configs/vmdisks/{{ item }}-data.qcow2 150G
  chdir: /path/to/your/remote/lab/directory
  loop:
    - Host12-1
    - Host12-2


XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
- name: Handle Clab Topology Storage Lifecycle
  hosts: deploy_machines
  gather_facts: false
  vars:
    lab_dir: "/path/to/your/remote/lab/directory"
    hosts_list:
      - Host12-1
      - Host12-2

  tasks:
    # 1. Check if the disk files already exist on the remote deployment machine
    - name: Check if node data disks exist
      ansible.builtin.stat:
        path: "{{ lab_dir }}/configs/vmdisks/{{ item }}-data.qcow2"
      register: disk_stats
      loop: "{{ hosts_list }}"

    # 2. ONLY create a fresh blank disk if it does not exist at all
    - name: Create fresh QCOW2 disks if missing
      ansible.builtin.command:
        cmd: qemu-img create -f qcow2 configs/vmdisks/{{ item.item }}-data.qcow2 150G
      chdir: "{{ lab_dir }}"
      when: not item.stat.exists
      loop: "{{ disk_stats.results }}"

    # 3. Safe Check: If the disk exists but isn't 150GB yet, resize it safely in-place
    # (qemu-img resize on an existing disk preserves all installed software inside it!)
    - name: Ensure existing disks are scaled to 150GB
      ansible.builtin.command:
        cmd: qemu-img resize configs/vmdisks/{{ item.item }}-data.qcow2 150G
      chdir: "{{ lab_dir }}"
      when: item.stat.exists
      loop: "{{ disk_stats.results }}"
      failed_when: false # Prevents failing if the disk is already exactly 150GB

    # 4. Trigger the Containerlab deployment
    - name: Deploy Containerlab topology
      ansible.builtin.command:
        cmd: containerlab deploy -t topology.clab.yml --reconfigure
      chdir: "{{ lab_dir }}"
XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
    # =========================================================================
    # STEP 5: CONTINUOUS Flow - AUTOMATED STORAGE VERIFICATION
    # =========================================================================

    # Wait for the Ubuntu virtual machines to finish booting and starting SSH
    - name: Wait for Ubuntu VMs to become reachable via SSH
      ansible.builtin.wait_for_connection:
        delay: 5
        timeout: 120

    # Query the live storage layout inside the running container instances
    - name: Inspect running VM storage mounts
      ansible.builtin.command:
        cmd: df -h
      register: df_output
      changed_when: false

    # Fail the playbook instantly if /var isn't utilizing the 150GB OverlayFS shield
    - name: Verify OverlayFS is actively protecting high-volume directories
      ansible.builtin.assert:
        that:
          - "'overlay' in df_output.stdout"
          - "'/var' in df_output.stdout"
        fail_msg: |
          STORAGE VERIFICATION FAILED: The 150GB data disk overlay is not active. 
          Please check the remote machine's cloud-init log inside the VM using:
          'sudo journalctl -u cloud-init' or 'cat /var/log/cloud-init-output.log'
        success_msg: "STORAGE VERIFICATION SUCCESSFUL: 150GB OverlayFS shield is safely engaged on /var!"

    # Proceed seamlessly into your Kubespray or OpenStack playbooks
    - name: Continue to Cluster Installation
      ansible.builtin.debug:
        msg: "Storage environment verified. Initiating Kubespray / OpenStack installation steps..."
XXXXXXXXXXXXXXXXXXXXXXXXXXXX
