# Step 1 — add insecure-registries for the push endpoint (R810 external IP)
sudo tee /etc/docker/daemon.json <<'EOF'
{"insecure-registries": ["192.168.9.198:5000", "172.16.2.1:5000"]}
EOF
sudo systemctl restart docker

# Step 2 — delete stale venv (was missing the docker SDK when first created)
sudo rm -rf /opt/kolla-venv

# Step 3 — restart the build
sudo ./scripts/generate-image-list.sh --kolla-build

# On WSL (while on fast network — save all built kolla images as tarballs)
for IMG in $(docker images --format '{{.Repository}}:{{.Tag}}' | grep 'openstack.kolla'); do
  SAFE=$(echo "$IMG" | sed 's|[/:]|_|g')
  docker save -o "/opt/fabric-cache/images/${SAFE}.tar" "$IMG"
  echo "Saved: $IMG"
done

# Then later, back on the correct network, push them into the R810 registry
# (the registry_seed role does this automatically — just re-run registry.yml)
ansible-playbook -i inventory.yml playbooks/registry.yml

# Re-push already-built images once the correct network is restored
for IMG in $(docker images --format '{{.Repository}}:{{.Tag}}' | grep '192.168.9.198:5000/openstack.kolla'); do
  docker push "$IMG"
done

