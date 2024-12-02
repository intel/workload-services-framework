#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
resource "azurerm_linux_virtual_machine" "default" {
  for_each = {
    for k,v in local.vms : k => v if replace(v.os_type,"windows","")==v.os_type
  }

  name                = "wsf-${var.job_id}-vm-${each.key}"
  computer_name       = each.key
  resource_group_name = local.resource_group_name
  location            = local.location
  size                = each.value.instance_type
  admin_username      = local.os_image_user[each.value.os_type]
  source_image_id     = each.value.os_image==null?null:(length(split("/",each.value.os_image))==9?each.value.os_image:tolist(data.azurerm_resources.image[each.key].resources).0.id)
  user_data           = "${data.template_cloudinit_config.default[each.key].rendered}"

  priority            = var.spot_instance?"Spot":"Regular"
  eviction_policy     = var.spot_instance?"Delete":null
  max_bid_price       = var.spot_instance?var.spot_price:null

  zone                = each.value.data_disk_spec!=null?contains(local.speed_adjustable_disk_types, each.value.data_disk_spec.disk_type)?local.availability_zone:null:null
  vtpm_enabled        = (local.os_image_sku_arch[each.key] == "cvm")
  secure_boot_enabled = (local.os_image_sku_arch[each.key] == "cvm")

  network_interface_ids = concat([
    azurerm_network_interface.default[each.key].id,
  ], [
    for k,v in local.networks : azurerm_network_interface.secondary[k].id
      if v.instance == each.key
  ])

  admin_ssh_key {
    username   = local.os_image_user[each.value.os_type]
    public_key = var.ssh_pub_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = each.value.os_disk_type
    disk_size_gb         = each.value.os_disk_size
    disk_encryption_set_id = var.encrypt_disk?(var.disk_encryption_set_name==null?azurerm_disk_encryption_set.default.0.id:data.azurerm_disk_encryption_set.default.0.id):null
    security_encryption_type = (local.os_image_sku_arch[each.key] == "cvm")?var.security_encryption_type:null
  }

  dynamic "source_image_reference" {
    for_each = each.value.os_image == null?[1]:[]

    content {
      publisher = local.os_image_publisher[each.value.os_type]
      offer     = local.os_image_offer[each.value.os_type][local.os_image_sku_arch[each.key]]
      sku       = local.os_image_sku[each.value.os_type][local.os_image_sku_arch[each.key]]
      version   = "latest"
    }
  }

  dynamic "additional_capabilities" {
    for_each = each.value.data_disk_spec!=null?[each.value.data_disk_spec.disk_type]:[]

    content {
      ultra_ssd_enabled = contains(local.speed_adjustable_disk_types, additional_capabilities.value)?true:false
    }
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.common_tags
}

resource "random_password" "default" {
  count = length([
    for k,v in local.vms : 1 if replace(v.os_type,"windows","")!=v.os_type
  ])

  length            = 16
  special           = true
  override_special  = "!#&*()_=+[]?"
  min_special       = 1
  min_numeric       = 1
  min_lower         = 1
  min_upper         = 1
}
  
resource "azurerm_windows_virtual_machine" "default" {
  for_each = { 
    for k,v in local.vms : k => v if replace(v.os_type,"windows","")!=v.os_type
  }

  name = "wsf-${var.job_id}-vm-${each.key}"
  computer_name = each.key
  resource_group_name = local.resource_group_name
  location = local.location
  size = each.value.instance_type
  zone = each.value.data_disk_spec!=null?contains(local.speed_adjustable_disk_types, each.value.data_disk_spec.disk_type)?local.availability_zone:null:null
  vtpm_enabled        = (local.os_image_sku_arch[each.key] == "cvm")
  secure_boot_enabled = (local.os_image_sku_arch[each.key] == "cvm")

  priority = var.spot_instance?"Spot":"Regular"
  max_bid_price = var.spot_instance?var.spot_price:null
  eviction_policy = var.spot_instance?"Delete":null

  enable_automatic_updates = false
  patch_mode = "Manual"

  network_interface_ids = concat([
    azurerm_network_interface.default[each.key].id,
  ], [
    for k,v in local.networks : azurerm_network_interface.secondary[k].id
      if v.instance == each.key
  ])

  os_disk {
    caching = "ReadWrite"
    storage_account_type = each.value.os_disk_type
    disk_size_gb = each.value.os_disk_size
    disk_encryption_set_id = var.encrypt_disk?(var.disk_encryption_set_name==null?azurerm_disk_encryption_set.default.0.id:data.azurerm_disk_encryption_set.default.0.id):null
    security_encryption_type = (local.os_image_sku_arch[each.key] == "cvm")?var.security_encryption_type:null
  }

  admin_username = local.os_image_user[each.value.os_type]
  admin_password = random_password.default.0.result

  source_image_id     = each.value.os_image==null?null:(length(split("/",each.value.os_image))==9?each.value.os_image:tolist(data.azurerm_resources.image[each.key].resources).0.id)

  dynamic "source_image_reference" {
    for_each = each.value.os_image == null?[1]:[]

    content {
      publisher = local.os_image_publisher[each.value.os_type]
      offer     = local.os_image_offer[each.value.os_type][local.os_image_sku_arch[each.key]]
      sku       = local.os_image_sku[each.value.os_type][local.os_image_sku_arch[each.key]]
      version   = "latest"
    }
  }

  dynamic "additional_capabilities" {
    for_each = each.value.data_disk_spec!=null?[each.value.data_disk_spec.disk_type]:[]

    content {
      ultra_ssd_enabled = contains(local.speed_adjustable_disk_types, additional_capabilities.value)?true:false
    }
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.common_tags
}

locals {
  setup_winrm_script = "${path.module}/templates/setup-winrm-disks.ps1"
}

resource "azurerm_virtual_machine_extension" "setup" {
  for_each = { 
    for k,v in local.vms : k => v if replace(v.os_type,"windows","")!=v.os_type
  }

  name = "wsf-${var.job_id}-vmext-${each.key}"
  virtual_machine_id = azurerm_windows_virtual_machine.default[each.key].id
  publisher = "Microsoft.Compute"
  type = "CustomScriptExtension"
  type_handler_version = "1.10"
  auto_upgrade_minor_version = true

  protected_settings = <<EOF
{
  "commandToExecute": "powershell -command \"[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${base64encode(templatefile(local.setup_winrm_script, {
    winrm_port = var.winrm_port
    local_disk = each.value.data_disk_spec!=null?(each.value.data_disk_spec.disk_type!="local"?false:true):false
  }))}')) | Out-File -filepath postBuild.ps1\" && powershell -ExecutionPolicy Unrestricted -File postBuild.ps1"
}
EOF

  depends_on = [
    azurerm_windows_virtual_machine.default,
    azurerm_virtual_machine_data_disk_attachment.default]

  tags = var.common_tags
}
