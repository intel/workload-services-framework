
locals {
  image_name = replace(lower(var.image_name), "_", "-")
  profiles = [
    for p in jsondecode(file(var.config_file))["profiles"] : p
      if p["name"] == var.profile
  ]
}

source "alicloud-ecs" "default" {
  instance_name = "wsf-${var.job_id}-builder"
  description = local.image_name

  access_key = local.profiles.0.access_key_id
  secret_key = local.profiles.0.access_key_secret
  region = var.region
  zone_id = var.zone

  associate_public_ip_address = true
  io_optimized = true
  instance_type = var.instance_type

  source_image = var.os_image_id
  image_name = local.image_name
  image_description = local.image_name
  image_version = var.image_version

  system_disk_mapping {
    disk_description = local.image_name
    disk_category = var.os_disk_type
    disk_size = var.os_disk_size
  }

  run_tags = merge(var.common_tags, {
    owner = var.owner
    Name = "wsf-${var.job_id}-packer"
  })

  resource_group_id = var.resource_group_id
  security_group_id = var.security_group_id
  vpc_id = var.vpc_id
  vswitch_id = var.vswitch_id

  internet_charge_type = "PayByTraffic"
  internet_max_bandwidth_out = var.internet_bandwidth
  user_data = templatefile("${path.root}/templates/cloud-init.sh", {
    user_name = local.os_image_user[var.os_type]
    public_key = file("${path.root}/ssh_access.key.pub")
  })

  image_force_delete = true
  image_force_delete_snapshots = true
  image_force_delete_instances = true

  ssh_username = local.os_image_user[var.os_type]
  ssh_proxy_host = var.ssh_proxy_host
  ssh_proxy_port = var.ssh_proxy_port
  ssh_private_key_file = "${path.root}/ssh_access.key"

  tags = merge(var.common_tags, {
    owner = var.owner
    Name = "wsf-${var.job_id}-packer"
  })
}

build {
  name = "wsf-${var.job_id}-packer"
  sources = [
    "sources.alicloud-ecs.default"
  ]

  provisioner "ansible" {
    playbook_file = var.ansible_playbook
    extra_arguments = ["-e", "csp=alicloud", "-e", "image_name=${local.image_name}", "-vv"]
    ansible_env_vars = ["ANSIBLE_CONFIG=${dirname(abspath(var.ansible_playbook))}/ansible.cfg"]
    use_proxy = false
  }
}
