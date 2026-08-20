To structure this deployment according to production-grade Ansible standards, we will break the architecture down into a formal Ansible Role pattern. This separates your structural data configurations, automated tasks, template logic, and lifecycle triggers into clean, maintainable modular layers.
Here is the complete standard directory structure and file contents for the clab_deploy role.
------------------------------
## 1. The Standard Ansible Workspace Directory Tree
Organize your files on your Ansible Controller exactly like this:

site.yml                       # The main master playbook entry point
inventory.yml                  # Your infrastructure host definition file
roles/
  clab_deploy/
    defaults/
      main.yml                 # Default directory and path variables
    tasks/
      main.yml                 # Sequential automation tasks
    templates/
      topology.clab.yml.j2     # The verified dynamic topology blueprint

------------------------------
## 2. File Implementation Layout## Role Variables: roles/clab_deploy/defaults/main.yml
Define global defaults so you don't hardcode system workspace paths across multiple tasks.

---# Workspace path defaults for the remote deployment engine hostclab_workspace_dir: "/opt/clab-labs/sheba"clab_config_dir: "{{ clab_workspace_dir }}/configs"clab_vmdisks_dir: "{{ clab_config_dir }}/vmdisks"clab_cloudinit_dir: "{{ clab_config_dir }}/cloud-init"

## Role Automation: roles/clab_deploy/tasks/main.yml
This is your standard task sequence. It manages remote workspace storage paths, formats empty baseline operating canvasses, renders the blueprint, and triggers Containerlab.

---# =========================================================================# STEP 1: WORKSPACE PATH INITIALIZATION# =========================================================================
- name: Ensure target laboratory directory structures exist on remote host
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    mode: '0755'
  loop:
    - "{{ clab_workspace_dir }}"
    - "{{ clab_vmdisks_dir }}"
    - "{{ clab_cloudinit_dir }}"
# =========================================================================# STEP 2: FRAMEWORK CANVAS DRIVE PROVISIONING# =========================================================================
- name: Audit framework canvas storage allocation files
  ansible.builtin.stat:
    path: "{{ clab_vmdisks_dir }}/{{ item }}-data.qcow2"
  register: system_canvas_stats
  loop: "{{ groups['all_lab_hosts'] }}"

- name: Allocate 150GB system-overlay disks in-place safely if missing
  ansible.builtin.command:
    cmd: "qemu-img create -f qcow2 {{ clab_vmdisks_dir }}/{{ item.item }}-data.qcow2 150G"
  when: not item.stat.exists
  loop: "{{ system_canvas_stats.results }}"
  changed_when: true
# =========================================================================# STEP 3: TEMPLATE COMPILATION & ENGINES DEPLOYMENT# =========================================================================
- name: Generate finalized topology configuration from Jinja2 template
  ansible.builtin.template:
    src: topology.clab.yml.j2
    dest: "{{ clab_workspace_dir }}/topology.clab.yml"
    mode: '0644'

- name: Launch Containerlab network fabric deployment matrix
  ansible.builtin.command:
    cmd: "containerlab deploy -t topology.clab.yml --reconfigure"
  chdir: "{{ clab_workspace_dir }}"
  register: clab_execution_telemetry
  changed_when: true

- name: Output deployment telemetry logs to terminal console
  ansible.builtin.debug:
    var: clab_execution_telemetry.stdout_lines

(Place the topology.clab.yml.j2 code generated in the previous step into roles/clab_deploy/templates/topology.clab.yml.j2 unchanged).
------------------------------
## 3. Executing the Master Playbook Matrix## The Global Production Inventory File: inventory.yml

---all:
  hosts:
    # Remote host server that runs the containerlab service engine
    clab-hypervisor-node:
      ansible_host: 10.0.0.100  # The real IP of the host machine where clab is installed
      ansible_user: root

  children:
    # Virtual host structural properties mapped as internal inventory data
    all_lab_hosts:
      hosts:
        Host12-1: { physical_ceph_disk_a: "/dev/sdb" }
        Host12-2: { physical_ceph_disk_a: "/dev/sdc" }
        MonSrv:   { physical_ceph_disk_a: "/dev/sdb", physical_ceph_disk_b: "/dev/sdc" }
        HostB12-1:{ physical_ceph_disk_a: "/dev/sdb" }
        HostB12-2:{ physical_ceph_disk_a: "/dev/sdc" }
        Host12-3:
        Host34-1:
        Host34-2:

    # Explicit role markers for Jinja template boolean validation loops
    ceph_storage_nodes:
      hosts:
        Host12-1:
        Host12-2:
        MonSrv:
        HostB12-1:
        HostB12-2:

## The Master Playbook Trigger: site.yml
This is your clean, standard top-level playbook that ties your deployment server targets to your operational roles.

---
- name: Orchestrate Sheba Laboratory Cloud Architecture Environment
  hosts: clab-hypervisor-node
  gather_facts: true  # Gathers remote host facts to help dynamic tracking
  roles:
    - role: clab_deploy

To run this complete production framework from your controller machine terminal, use the standard command:

ansible-playbook -i inventory.yml site.yml

To complete this modular standard workflow, would you like to build out a companion role named clab_destroy inside this playbook structure to cleanly tear down the network infrastructure when your testing rounds finish?

