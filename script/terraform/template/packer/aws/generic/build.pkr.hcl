
locals {
  architecture_name = lower(replace(var.architecture, "_", "-"))
  image_name = replace(lower(var.image_name), "_", "-")
}

source "amazon-ebs" "on_demand" {
  ami_name              = "wsf-ami-${var.os_type}-${local.architecture_name}-${local.image_name}"
  ami_description       = "${var.os_type} ${local.architecture_name} with ${var.image_name}"

  availability_zone     = var.zone
  region                = var.region
  instance_type         = var.instance_type
  subnet_id             = var.subnet_id
  security_group_id = var.security_group_id

  force_deregister      = true
  force_delete_snapshot = true

  ssh_username   = local.os_image_user[var.os_type]
  ssh_proxy_host = var.ssh_proxy_host
  ssh_proxy_port = var.ssh_proxy_port

  source_ami_filter {
    filters = {
      name = local.os_image_filter[var.os_type]
      root-device-type    = "ebs"
      virtualization-type = "hvm"
      architecture        = "${var.architecture}"
    }
    most_recent = true
    owners = [local.os_image_owner[var.os_type]]
  }

  run_volume_tags = merge(var.common_tags, {
    owner = var.owner
    Name = "wsf-${var.job_id}-packer"
  })

  tags = merge(var.common_tags, {
    owner = var.owner
    Name = "wsf-${var.job_id}-packer"
  })

  run_tags = merge(var.common_tags, {
    owner = var.owner
    Name = "wsf-${var.job_id}-packer"
  })

  launch_block_device_mappings {
    device_name = local.os_image_root_device[var.os_type]
    volume_size = var.os_disk_size
    volume_type = var.os_disk_type
    delete_on_termination = true
  }
}

build {
  name = "wsf-${var.job_id}-packer"
  sources = [
    "sources.amazon-ebs.on_demand"
  ]

  provisioner "ansible" {
    playbook_file = var.ansible_playbook
    extra_arguments = ["--extra-vars", "csp=aws"]
    use_proxy = false
  }
}
