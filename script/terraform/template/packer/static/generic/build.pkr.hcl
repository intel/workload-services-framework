
source "null" "default" {
  communicator = "none"
}

build {
  name = "wsf-ansible-playbook"
  sources = [
    "sources.null.default"
  ]

  provisioner "shell-local" {
    inline = [
      format("echo '%s' | tee /tmp/inventory-packer.yaml", templatefile("template/inventory.yaml.tpl", {
        hosts = split(",", var.public_ip)
        private_ips = split(",", var.private_ip)
        users = split(",", var.user_name)
        ports = split(",", var.ssh_port)
        connections = [for u in split(",", var.public_ip): u!="127.0.0.1"?"ssh":"local"]
      })),
      "ANSIBLE_CONFIG=${dirname(abspath(var.ansible_playbook))}/ansible.cfg ansible-playbook -i /tmp/inventory-packer.yaml -e image_name=${var.image_name} -vv ${var.ansible_playbook}",
    ]
  }
}
