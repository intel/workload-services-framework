
locals {
  architecture_name = lower(replace(var.architecture, "_", "-"))
  image_name = replace(lower(var.image_name), "_", "-")
}

source "azure-arm" "default" {
  temp_resource_group_name = "wsf-${var.job_id}-image-builder"

  location = var.region
  vm_size = var.instance_type
  use_azure_cli_auth = true
  private_virtual_network_with_public_ip = true

  managed_image_name = "wsf-ami-${var.os_type}-${local.architecture_name}-${local.image_name}"
  managed_image_storage_account_type = var.os_disk_type
  managed_image_resource_group_name = var.managed_resource_group_name
  os_disk_size_gb = var.os_disk_size

  os_type         = "Linux"
  image_publisher = local.os_image_publisher[var.os_type]
  image_offer     = local.os_image_offer[var.os_type]
  image_sku       = local.os_image_sku[var.os_type]

  virtual_network_name = var.network_name
  virtual_network_subnet_name = var.subnet_name

  ssh_username   = local.os_image_user[var.os_type]
  ssh_proxy_host = var.ssh_proxy_host
  ssh_proxy_port = var.ssh_proxy_port

  azure_tags = merge(var.common_tags, {
    owner          = var.owner,
  })
}

build {
  name = "wsf-${var.job_id}-packer"

  sources = [
    "sources.azure-arm.default"
  ]

  provisioner "ansible" {
    playbook_file = var.ansible_playbook
    extra_arguments = ["--extra-vars", "csp=azure"]
    use_proxy = false
  }
}

