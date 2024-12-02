
locals {
  image_name = replace(lower(var.image_name), "_", "-")
  credentials = jsondecode(file("~/.tccli/default.credential"))
}

source "tencentcloud-cvm" "default" {
  region = var.region
  zone = var.zone
  secret_id = var.secret_id!=null?var.secret_id:local.credentials["secretId"]
  secret_key = var.secret_key!=null?var.secret_key:local.credentials["secretKey"]
  
  source_image_id = var.os_image_id
  image_name = local.image_name
  image_description = local.image_name

  associate_public_ip_address = true
  internet_max_bandwidth_out = 100

  instance_name = "wsf-${var.job_id}-builder"
  instance_type = var.instance_type
  disk_type = var.os_disk_type
  disk_size = var.os_disk_size

  vpc_id = var.vpc_id
  subnet_id = var.subnet_id
  security_group_id = var.security_group_id

  host_name = "wsf"
  run_tags = merge(var.common_tags, {
    owner = var.owner
    Name = "wsf-${var.job_id}-packer"
  })

  ssh_username   = local.os_image_user[var.os_type]
  ssh_proxy_host = var.ssh_proxy_host
  ssh_proxy_port = var.ssh_proxy_port
}

build {
  name = "wsf-${var.job_id}-packer"
  sources = [
    "sources.tencentcloud-cvm.default"
  ]

  provisioner "ansible" {
    playbook_file = var.ansible_playbook
    extra_arguments = ["-e", "csp=tencent", "-e", "image_name=${local.image_name}", "-vv"]
    ansible_env_vars = ["ANSIBLE_CONFIG=${dirname(abspath(var.ansible_playbook))}/ansible.cfg"]
    use_proxy = false
  }
}
