
locals {
  image_name = replace(lower(var.image_name), "_", "-")
  os_image = var.os_image!=null?replace(lower(var.os_image), "_", "-"):null
}

source "googlecompute" "default" {
  project_id = var.project_id
  region     = var.region
  zone       = var.zone

  ssh_username   = local.os_image_user[var.os_type]
  ssh_proxy_host = var.ssh_proxy_host
  ssh_proxy_port = var.ssh_proxy_port

  subnetwork = var.subnet_id
  instance_name = "wsf-${var.job_id}-builder"
  machine_type = local.instance_type
  source_image_family = local.os_image!=null?local.os_image:local.os_image_family[var.os_type]
  labels = merge(var.common_tags, {
    "owner": var.owner
  })

  image_name        = local.image_name
  image_family      = local.image_name
  image_description = local.image_name
  image_labels = merge(var.common_tags, {
    "owner"         = var.owner
  })

  tags = [ for r in var.firewall_rules: reverse(split("/", r))[0] ]

  disk_size = var.os_disk_size
  disk_type = var.os_disk_type

  state_timeout = var.state_timeout
}

build {
  name = "wsf-${var.job_id}-packer"

  sources = [
    "sources.googlecompute.default"
  ]

  provisioner "ansible" {
    playbook_file = var.ansible_playbook
    extra_arguments = ["-e", "csp=gcp", "-e", "image_name=${local.image_name}", "-vv"]
    ansible_env_vars = ["ANSIBLE_CONFIG=${dirname(abspath(var.ansible_playbook))}/ansible.cfg"]
    use_proxy = false
  }
}

