
source "googlecompute" "default" {
  project_id = var.project_id
  region     = var.region
  zone       = var.zone

  ssh_username   = local.os_image_user[var.os_type]
  ssh_proxy_host = var.ssh_proxy_host
  ssh_proxy_port = var.ssh_proxy_port

  subnetwork = var.subnet_id
  instance_name  = "wsf-${var.job_id}-builder"
  machine_type        = local.instance_type
  source_image_family = local.os_image_family[var.os_type]
  labels = merge(var.common_tags, {
    "owner": var.owner
  })

  image_name        = "wsf-ami-${var.os_type}-${local.architecture_name}-${local.image_name}"
  image_family      = "wsf-ami-${var.os_type}-${local.architecture_name}-${local.image_name}"
  image_description = "${var.os_type} ${local.architecture_name} with ${var.image_name}"
  image_labels = merge(var.common_tags, {
    "owner"         = var.owner
  })

  tags = [ for r in var.firewall_rules: reverse(split("/", r))[0] ]

  disk_size = var.os_disk_size
  disk_type = var.os_disk_type
}

build {
  name = "wsf-${var.job_id}-packer"

  sources = [
    "sources.googlecompute.default"
  ]

  provisioner "ansible" {
    playbook_file = var.ansible_playbook
    extra_arguments = ["--extra-vars", "csp=gcp"]
    use_proxy = false
  }
}

