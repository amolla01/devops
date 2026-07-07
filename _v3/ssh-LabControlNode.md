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
