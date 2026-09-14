# one-time, while the WSL laptop still has internet, OR copy it in by hand:
curl -fsSL https://github.com/projectcalico/calico/raw/v3.29.2/manifests/crds.yaml \
  -o /opt/fabric-cache/downloads/calico-crds-3.29.2.yaml
# verify nginx serves it:
curl -fsSI http://172.16.2.1:8080/calico-crds-3.29.2.yaml
Searched for regex `r810_binary_server|binary_server|8080|etcd_download_url|/opt/registry|nginx|file server|fileserver`, 497 results

Read [](file:///c%3A/dc-lab/clab/sonic-clab/roles/kubespray_prep/templates/kubespray-group-vars.yaml.j2#130-130), lines 130 to 150

No matches found. Your search pattern might be excluded completely by either the search.exclude settings or .*ignore files.
If you believe that it should have results, you can check into the .*ignore files and the exclude setting (here are some excluded patterns for reference:[**/node_modules,**/bower_components,**/*.code-search]).
Then if you want to include those files you can call the tool again by setting "includeIgnoredFiles" to true.

Searched for regex `8080:80|/usr/share/nginx|:/usr/share/nginx|docker run.*nginx|fabric-cache/files|/opt/fabric-cache|files_dir|web root|document root`, 377 results

Read [](file:///c%3A/dc-lab/clab/sonic-clab/roles/registry_deploy/tasks/main.yml#55-55), lines 55 to 78

Everything needed is now pinned down. The next run will request this **exact** URL (from `etcd_download_url` with your new `etcd_version: 3.5.24`):

```
http://172.16.2.1:8080/etcd-v3.5.24-linux-amd64.tar.gz
```

That file server (`sheba-file-server`, nginx:alpine) serves **`/opt/fabric-cache/downloads/`** on the R810 (`volumes: /opt/fabric-cache/downloads:/usr/share/nginx/html:ro`, `8080:80`). So the tarball just has to land in that directory with that exact name.

## Run on the R810 host

```bash
cd /opt/fabric-cache/downloads

# Pull the upstream etcd v3.5.24 release, naming it exactly as the run expects
sudo curl -fL -o etcd-v3.5.24-linux-amd64.tar.gz \
  https://github.com/etcd-io/etcd/releases/download/v3.5.24/etcd-v3.5.24-linux-amd64.tar.gz

# (optional) grab the official checksum to verify integrity
sudo curl -fL -O \
  https://github.com/etcd-io/etcd/releases/download/v3.5.24/etcd-v3.5.24-linux-amd64.tar.gz.sha256sum
sha256sum -c etcd-v3.5.24-linux-amd64.tar.gz.sha256sum
```

## Verify the node-facing URL resolves (serve it through nginx)

```bash
curl -fsSI http://172.16.2.1:8080/etcd-v3.5.24-linux-amd64.tar.gz
```
A `200 OK` here means the db nodes' `etcd : Download etcd binary` task will succeed.

## Two caveats

1. **Kubespray checksum gate.** `download_file` validates the tarball against the sha256 baked into kubespray's `checksums.yml` (the old entry was `...94edd` for 3.5.17). Confirm your kubespray tree (`/opt/fabric-cache/repos/kubespray`) has a 3.5.24 entry:
   ```bash
   grep -rn "3.5.24\|etcd_binary_checksum" /opt/fabric-cache/repos/kubespray/roles/kubespray_defaults/vars/ 2>/dev/null
   ```
   If it's absent, add the amd64 sha256 there, or kubespray will reject the download despite the file being present.

2. **`etcd_deployment_type: host`** means only this **binary tarball** is used to run etcd — you do *not* also need to mirror an `etcd:v3.5.24` image into the `:5000` registry for etcd itself. (If any other component still references the etcd image, mirror it separately, but it's not on the etcd startup path here.)
