Read [](file:///c%3A/Users/nh4134/Documents/GitHub-Repository/27438-Kepler-SSOT/apm0015564-kepler-ssot-cicd/data-center/_v3/deploy_lab_v15.sh#2510-2510), lines 2510 to 2540

Found it. Same `set -e` bug at the end of `phase5_6_k8s_prep`:

```bash
[[ $failed -gt 0 ]] && warn "Some servers failed K8s prep. Check SSH and proxy connectivity."
```

When `$failed` is 0, this returns exit code 1, killing the script. Let me also check `phase5_5_server_config` for the same pattern: 

Searched for regex `\[\[ \$failed -gt 0 \]\] && warn|\[\[ \$fail` (`**/data-center/_v3/deploy_lab_v15.sh`), 3 results

Two more instances of the same bug. Let me read around line 2276 for context: 

Read [](file:///c%3A/Users/nh4134/Documents/GitHub-Repository/27438-Kepler-SSOT/apm0015564-kepler-ssot-cicd/data-center/_v3/deploy_lab_v15.sh#2270-2270), lines 2270 to 2280

Now let me fix both remaining instances: 

Replacing 11 lines with 15 lines in [](file:///c%3A/Users/nh4134/Documents/GitHub-Repository/27438-Kepler-SSOT/apm0015564-kepler-ssot-cicd/data-center/_v3/deploy_lab_v15.sh)


```

```
Now let me check if there are any other instances of this pattern anywhere in the script:  

Searched for regex `\[\[.*\]\] && (warn|die|log|echo)` (`**/data-center/_v3/deploy_lab_v15.sh`), 9 results

The remaining instances are safe — they use `&& die` (which exits the script intentionally) or are NOT the last statement in their functions. The `log` and `echo` ones at lines 3021 and 2027 are mid-function, not the final statement.

Now, regarding your **actual connectivity problem from Lab-ControlNode** — here's the diagnosis:

**The deploy script is working correctly.** It got all the way through Phase 5.6 (the early exit after 5.6 was the same `set -e` bug I just fixed — it stopped before Phase 6/inventory). Your keys ARE already distributed to 15/18 VMs.

**The real issue: Lab-ControlNode cannot reach 10.10.1.0/24 directly.** That network lives inside R810's libvirt. You need **ProxyJump through R810** for every connection.

When you run `ssh Spine_S1`, it resolves to 10.10.1.48 and tries a direct TCP connection — WSL2 has no route to 10.10.1.0/24, so you get "Connection refused" (the Windows network stack RSTs the packet).

Your `push_lab_keys_Wel.sh` uses `-J` which is correct, but it fires **18 parallel connections** through R810. R810's SSH `MaxStartups` (default `10:30:60`) drops most of them.

**What you need on Lab-ControlNode** (`~/.ssh/config`):

```
Host R810
    HostName 192.168.9.198
    User nh1221
    IdentityFile /mnt/c/Users/nh1221/.ssh/id_dc_lab

Host Spine_S1 Spine_S2 Leaf_L1 Leaf_L2 Leaf_L3 Leaf_L4 Border_Leaf1 Border_Leaf2
    ProxyJump R810
    User admin
    IdentityFile /mnt/c/Users/nh1221/.ssh/id_dc_lab

Host Exit_Router1 Exit_Router2 Host12_1 Host12_2 Host12_3 Host34_1 Host34_2 HostB12_1 HostB12_2 MonitorSrv
    ProxyJump R810
    User ubuntu
    IdentityFile /mnt/c/Users/nh1221/.ssh/id_dc_lab

Host 10.10.1.*
    ProxyJump R810
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    IdentityFile /mnt/c/Users/nh1221/.ssh/id_dc_lab
```

Once that's in place:
- `ssh Spine_S1` will jump through R810 and use your key (already installed by the deploy script)
- Ansible will work with `ansible_ssh_common_args: '-o ProxyJump=R810'` in the inventory
- No need for `push_lab_keys_Wel.sh` at all — the deploy script already handles key distribution

**Summary of fixes applied:**
1. `phase4_deploy` — fixed last session (you already got past it)
2. `phase5_5_server_config` — fixed now (line 2276)
3. `phase5_6_k8s_prep` — fixed now (line 2530)

All three were the same bug: `[[ $failed -gt 0 ]] && warn "..."` as the last statement in a function under `set -e` — returns exit code 1 when no failures occur, killing the script.

Made changes.
Good — you just need the `ProxyJump` and `Host` entries for the lab VMs. Add this to your `~/.ssh/config`:

```
Host R810
    HostName 192.168.9.198
    User nh1221

Host Spine_S1 Spine_S2 Leaf_L1 Leaf_L2 Leaf_L3 Leaf_L4 Border_Leaf1 Border_Leaf2
    ProxyJump R810
    User admin
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host Exit_Router1 Exit_Router2 Host12_1 Host12_2 Host12_3 Host34_1 Host34_2 HostB12_1 HostB12_2 MonitorSrv
    ProxyJump R810
    User ubuntu
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Match host 10.10.1.*
    ProxyJump R810
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
```

Your `ssh Spine_S1` was getting "Connection refused" because WSL has no route to 10.10.1.0/24 — it needs to tunnel through R810. With `ProxyJump R810`, SSH opens one connection to R810, then R810 forwards to 10.10.1.x internally.

The deploy script already pushed your key (from R810's `~/.ssh/authorized_keys`) to 15 of 18 VMs. Once you add the config above:

```bash
ssh Spine_S1          # should work immediately (key already there)
ssh Host12_1          # same
```

For Ansible, add to your inventory:

```yaml
all:
  vars:
    ansible_ssh_common_args: '-o ProxyJump=R810'
```

No need for `push_lab_keys_Wel.sh` at all — the keys are already distributed by the deploy script.

Two approaches:

**Option 1: Windows route (simplest, if on same subnet as R810)**

```cmd
route add 10.10.1.0 mask 255.255.255.0 192.168.9.198
```

This tells Windows to send 10.10.1.0/24 traffic to R810. **But** it requires R810's iptables to allow forwarding from your laptop subnet into br-mgmt. You'd need to run this on R810:

```bash
sudo iptables -I FORWARD -s 192.168.9.0/24 -d 10.10.1.0/24 -j ACCEPT
```

And verify `ip_forward` is on (likely already is since NAT masquerade needs it).

**Option 2: sshuttle from WSL (no R810 firewall changes needed)**

```bash
sshuttle -r nh1221@192.168.9.198 10.10.1.0/24
```

This tunnels all 10.10.1.0/24 traffic transparently over SSH. Works instantly, no iptables/route changes needed. Install with `pip install sshuttle` or `apt install sshuttle`.

**Option 3: Just use ProxyJump (what you already have)**

SSH config `ProxyJump R810` is the simplest — it works for both `ssh` and Ansible without touching routing tables at all. No tunnel needed.

---

**Recommendation**: Stick with **ProxyJump** for SSH/Ansible (zero setup beyond the config lines I gave you). Only use `route add` or `sshuttle` if you need non-SSH access (like a web browser hitting a VM's port 80).

Two separate issues in that log:

**Issue 1: Proxy `cso.proxy.att.com:8080` can't be resolved**

The VMs are trying to use a corporate proxy that doesn't exist on your home/lab network. They have direct internet via the NAT masquerade on R810. You need to clear the proxy config on the VMs.

SSH to R810 and run on any failing VM to confirm:

```bash
ssh Host12_3   # from R810
env | grep -i proxy
cat /etc/apt/apt.conf.d/*proxy* 2>/dev/null
cat /etc/environment | grep -i proxy
```

Then remove it:

```bash
sudo rm -f /etc/apt/apt.conf.d/*proxy*
sudo sed -i '/[Pp]roxy/d' /etc/environment
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
sudo apt update   # should work now
```

**Issue 2: SSH preflight from Lab-ControlNode can't reach 10.10.1.30 directly**

Your Ansible task delegates to `localhost` for the SSH check, but Lab-ControlNode has no route to 10.10.1.0/24. You need `ansible_ssh_common_args` in your inventory:

```yaml
all:
  vars:
    ansible_ssh_common_args: '-o ProxyJump=R810 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
```

---

**Root cause**: Your Ansible role or the deploy script's cloud-init is injecting a corporate proxy (`cso.proxy.att.com:8080`) that only works on the AT&T corporate network. Since R810 is on a home/lab network with direct NAT internet, the proxy should be **disabled**.

Let me check what's setting it in the deploy script: 

Searched for regex `cso\.proxy|proxy.*8080|http_proxy|apt.*proxy|PROXY_URL` (`**/data-center/_v3/deploy_lab_v15.sh`), 20 results

Read [](file:///c%3A/Users/nh4134/Documents/GitHub-Repository/27438-Kepler-SSOT/apm0015564-kepler-ssot-cicd/data-center/_v3/deploy_lab_v15.sh#70-70), lines 70 to 110

Now let me check line 2080 where it pushes the proxy into VMs:  

Read [](file:///c%3A/Users/nh4134/Documents/GitHub-Repository/27438-Kepler-SSOT/apm0015564-kepler-ssot-cicd/data-center/_v3/deploy_lab_v15.sh#2065-2065), lines 2065 to 2105

There's the problem — **line 2080**. The deploy script's `phase5_5_server_config` pushes the corporate proxy (`cso.proxy.att.com:8080`) into `/etc/apt/apt.conf.d/90proxy` on every Ubuntu VM. Since R810 is on your home network, the VMs can't resolve that hostname.

Now let me also check the Ansible role to see if it's also setting a proxy:  

Searched for files matching `**/roles/server_base/**`, 20 matches

Read [](file:///c%3A/Users/nh4134/Documents/GitHub-Repository/27438-Kepler-SSOT/apm0015564-kepler-ssot-cicd/data-center/_v3/roles/server_base/tasks/day0_provision.yml#1-1), lines 1 to 60

Read [](file:///c%3A/Users/nh4134/Documents/GitHub-Repository/27438-Kepler-SSOT/apm0015564-kepler-ssot-cicd/data-center/_v3/roles/server_base/tasks/day0_provision.yml#60-60), lines 60 to 120

Now let me check the main.yml task ordering and the `preflight` that does the routing:   

Read [](file:///c%3A/Users/nh4134/Documents/GitHub-Repository/27438-Kepler-SSOT/apm0015564-kepler-ssot-cicd/data-center/_v3/roles/server_base/tasks/main.yml)

Read [](file:///c%3A/Users/nh4134/Documents/GitHub-Repository/27438-Kepler-SSOT/apm0015564-kepler-ssot-cicd/data-center/_v3/roles/server_base/tasks/preflight.yml#1-1), lines 1 to 60

Now I can see both problems clearly. Let me also check where the Ansible role sets the routing/DNS:   

Searched for regex `Provision network layer|proxy|apt.*conf` (`**/data-center/_v3/roles/server_base/**`), 6 results

Now let me look at the playbook that calls these roles to see the task ordering:   

Searched for files matching `**/deploy_day0*`, 5 matches

Read [](file:///c%3A/Users/nh4134/Documents/GitHub-Repository/27438-Kepler-SSOT/apm0015564-kepler-ssot-cicd/data-center/_v3/playbooks/reused/deploy_day0.yml#1-1), lines 1 to 80

Searched for regex `servers|server_base|day0_provision|Provision network|network.*routing` (`**/data-center/_v3/playbooks/reused/deploy_day0.yml`), 11 results

Read [](file:///c%3A/Users/nh4134/Documents/GitHub-Repository/27438-Kepler-SSOT/apm0015564-kepler-ssot-cicd/data-center/_v3/playbooks/reused/deploy_day0.yml#271-271), lines 271 to 312

Now let me look for where "Provision network layer routing and DNS resolution" task is defined — it appears in the Ansible output but not in day0_provision.yml:   

Searched for regex `Provision network layer routing` (`**/data-center/_v3/**/*.yml`), no results

Searched for regex `Provision network layer` (`**/data-center/_v3/**"`), no results

Searched for regex `Provision network layer`, no results

Searched for regex `Provision network layer`, no results

That task must be defined on the Lab-ControlNode locally (not in this repo). Regardless, the issues are clear. Here's the full picture:

---

**Two problems, same root cause — your lab has no corporate proxy:**

**Problem 1: `apt update` fails on most VMs**

The deploy script's `phase5_5_server_config` writes `/etc/apt/apt.conf.d/90proxy` with `cso.proxy.att.com:8080` into every Ubuntu VM. Since R810 is on your home network, that proxy hostname is unresolvable → all apt operations fail.

**Fix (immediate, on R810):**

```bash
for vm in Host12_1 Host12_2 Host12_3 Host34_1 Host34_2 HostB12_1 HostB12_2 MonitorSrv Exit_Router1 Exit_Router2; do
    ip=$(virsh domifaddr "$vm" 2>/dev/null | grep -oP '10\.10\.1\.\d+' | head -1)
    [[ -z "$ip" ]] && ip=$(grep "$vm" /var/lib/libvirt/dnsmasq/dc-mgmt.hostsfile 2>/dev/null | cut -d, -f2)
    echo -n "$vm ($ip): "
    ssh -o StrictHostKeyChecking=no "ubuntu@$ip" "sudo rm -f /etc/apt/apt.conf.d/90proxy && sudo apt update -qq" 2>/dev/null && echo "OK" || echo "FAIL"
done
```

**Problem 2: Preflight SSH check from Lab-ControlNode can't reach VMs**

The preflight.yml delegates to `localhost` (Lab-ControlNode) and tries direct SSH to 10.10.1.x. Without ProxyJump in the SSH command, it fails.

**Fix**: Your `~/.ssh/config` on Lab-ControlNode needs the `Match host 10.10.1.*` with `ProxyJump R810` that I provided earlier. The `delegate_to: localhost` SSH will then automatically use the ProxyJump.

---

**Permanent fix in deploy script** — skip the proxy push when running with `--no-proxy`: 

Read [](file:///c%3A/Users/nh4134/Documents/GitHub-Repository/27438-Kepler-SSOT/apm0015564-kepler-ssot-cicd/data-center/_v3/deploy_lab_v15.sh#2075-2075), lines 2075 to 2085

Replacing 6 lines with 12 lines in [](file:///c%3A/Users/nh4134/Documents/GitHub-Repository/27438-Kepler-SSOT/apm0015564-kepler-ssot-cicd/data-center/_v3/deploy_lab_v15.sh)


```

```
Now let me also check if `phase5_6_k8s_prep` has the same proxy injection:   

Searched for regex `90proxy|apt.*proxy|Configuring apt.*proxy` (`**/data-center/_v3/deploy_lab_v15.sh`), 8 results

Read [](file:///c%3A/Users/nh4134/Documents/GitHub-Repository/27438-Kepler-SSOT/apm0015564-kepler-ssot-cicd/data-center/_v3/deploy_lab_v15.sh#2310-2310), lines 2310 to 2370

There it is — `configure_server_k8s_proxy()` doesn't handle `ubuntu_r810_kvm` profile at all. It falls through the `case` without matching, so `proxy_url` stays empty. Let me check how it's called:  

Searched for regex `configure_server_k8s_proxy` (`**/data-center/_v3/deploy_lab_v15.sh`), 2 results

OK, so `configure_server_k8s_proxy` is called with `|| true` so it won't die. But it still pushes an empty proxy or falls through without matching `ubuntu_r810_kvm`. Let me add the R810 profile case: 

Replacing 16 lines with 21 lines in [](file:///c%3A/Users/nh4134/Documents/GitHub-Repository/27438-Kepler-SSOT/apm0015564-kepler-ssot-cicd/data-center/_v3/deploy_lab_v15.sh)


```

```
Now, your deploy_lab_v5.sh wrapper passes `--no-proxy` or a profile. Let me check which flags it uses:    

Searched for regex `ubuntu_r810_kvm` (`**/data-center/_v3/deploy_lab_v15.sh`), 5 results

Read [](file:///c%3A/Users/nh4134/Documents/GitHub-Repository/27438-Kepler-SSOT/apm0015564-kepler-ssot-cicd/data-center/_v3/deploy_lab_v15.sh#205-205), lines 205 to 230

Good. The profile `ubuntu_r810_kvm` doesn't set a proxy mode. The script defaults to `PROXY_MODE=corporate` (line 72). Since R810 has direct internet via NAT, the profile should override to `direct`. Let me fix that:  

Replacing 4 lines with 5 lines in [](file:///c%3A/Users/nh4134/Documents/GitHub-Repository/27438-Kepler-SSOT/apm0015564-kepler-ssot-cicd/data-center/_v3/deploy_lab_v15.sh)


```

```
Now let me verify the `configure_proxy` function is called AFTER the profile is set (in `main()`):   

Read [](file:///c%3A/Users/nh4134/Documents/GitHub-Repository/27438-Kepler-SSOT/apm0015564-kepler-ssot-cicd/data-center/_v3/deploy_lab_v15.sh#3140-3140), lines 3140 to 3160

Problem: `configure_proxy` is called **before** the profile is selected. The profile sets `PROXY_MODE="direct"` later, but `configure_proxy` already ran with the default `corporate` mode. I need to re-call `configure_proxy` after profile selection, or move the call:   

Read [](file:///c%3A/Users/nh4134/Documents/GitHub-Repository/27438-Kepler-SSOT/apm0015564-kepler-ssot-cicd/data-center/_v3/deploy_lab_v15.sh#3158-3158), lines 3158 to 3185

I need to add a second `configure_proxy` call after profile selection: 

Replacing 6 lines with 8 lines in [](file:///c%3A/Users/nh4134/Documents/GitHub-Repository/27438-Kepler-SSOT/apm0015564-kepler-ssot-cicd/data-center/_v3/deploy_lab_v15.sh)


```

```
Now for your **immediate action** (without redeploying), SSH to R810 and run this to clean the proxy from all VMs:

```bash
# From R810 (direct access to 10.10.1.0/24):
for ip in 10.10.1.{30,29,28,27,26,25,24,10,40,39}; do
    echo -n "$ip: "
    ssh -o StrictHostKeyChecking=no "ubuntu@$ip" \
        "sudo rm -f /etc/apt/apt.conf.d/90proxy && sudo sed -i '/proxy/Id' /etc/environment && sudo apt update -qq 2>&1 | tail -1" 2>/dev/null || echo "SKIP"
done
```

Then re-run your Ansible playbook — `apt update` will work since the VMs have direct internet through NAT masquerade.

**Summary of fixes to deploy_lab_v15.sh:**
1. `ubuntu_r810_kvm` profile now sets `PROXY_MODE="direct"` 
2. `configure_proxy` is re-called after profile selection
3. `phase5_5` proxy push is conditional — skipped in `direct` mode (removes stale 90proxy instead)
4. `configure_server_k8s_proxy()` returns early for `ubuntu_r810_kvm` (no proxy needed)

Made changes.
