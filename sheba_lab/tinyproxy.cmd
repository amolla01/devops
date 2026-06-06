Kubespray playbook Yes. Phase 1 runs on localhost (your laptop/Lab-ControlNode) and the tinyproxy task does:

ssh nh1221@R810 → installs tinyproxy → allows 172.16.2.0/24 → restarts service

Then Phase 2 regenerates the KubeSpray inventory with http_proxy: "http://172.16.2.1:8888", and Phase 4 KubeSpray uses that proxy for apt updates.

One thing to verify — make sure your SSH to R810 from Lab-ControlNode works without a password prompt (key-based auth). Test with:

ssh nh1221@R810 "echo OK"

If that prompts for a password, the playbook task will hang. If it does prompt, you have two options:

Set up SSH key auth: ssh-copy-id nh1221@R810
Or just install tinyproxy manually on R810 first:

ssh nh1221@R810
sudo apt install -y tinyproxy
sudo sed -i '/^Allow 127.0.0.1/a Allow 172.16.2.0/24' /etc/tinyproxy/tinyproxy.conf
sudo sed -i 's/^#\?Listen .*/Listen 0.0.0.0/' /etc/tinyproxy/tinyproxy.conf
sudo systemctl restart tinyproxy && sudo systemctl enable tinyproxy


