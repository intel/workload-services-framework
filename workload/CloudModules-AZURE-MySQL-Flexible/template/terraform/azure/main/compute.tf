#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
data "template_cloudinit_config" "default" {
  for_each = local.vms
  gzip = true
  base64_encode = true

  part {
    filename = "init-cloud"
    content_type = "text/cloud-config"
    content = "${file("./template/terraform/azure/main/cloud_init_resourcedisk.cfg")}"
  }
}

resource "azurerm_linux_virtual_machine" "default" {
  for_each = local.vms

  name                = "wsf-${var.job_id}-vm-${each.key}"
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_resource_group.default.location
  size                = each.value.instance_type
  admin_username      = local.os_image_user[each.value.os_type]
  source_image_id     = each.value.os_image
  user_data           = "${data.template_cloudinit_config.default[each.key].rendered}"

  priority            = var.spot_instance?"Spot":"Regular"
  eviction_policy     = var.spot_instance?"Delete":null
  max_bid_price       = var.spot_instance?var.spot_price:null

  zone                = each.value.data_disk_spec!=null?each.value.data_disk_spec.disk_type=="UltraSSD_LRS"?local.availability_zone:null:null

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
      ultra_ssd_enabled = additional_capabilities.value=="UltraSSD_LRS"?true:false
    }
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.common_tags
}


resource "random_password" "main" {
  length      = 12
  min_upper   = 4
  min_lower   = 2
  min_numeric = 4
  special     = false
}

module "intel-optimized-mysql-flexible-server" {
  source                    = "intel/azure-mysql-flexible-server/intel"
  resource_group_name       = azurerm_resource_group.default.name
  db_server_name            = "tank"
  db_password               = random_password.main.result
  db_username               = "adminsql"
  db_name                   = "wsf-${var.job_id}-database"

  db_private_dns_zone_id    = azurerm_private_dns_zone.default.id
  db_delegated_subnet_id    = azurerm_subnet.private_link_endpoint.id
  
  tags                      = var.common_tags

  depends_on                = [azurerm_resource_group.default]
}

resource "azurerm_private_dns_zone" "default" {
  name                = "example.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.default.name
  tags                = var.common_tags
  depends_on          = [azurerm_virtual_network.default]
}

resource "azurerm_private_dns_zone_virtual_network_link" "default" {
  name                  = "wsf-${var.job_id}-network-link"
  resource_group_name   = azurerm_resource_group.default.name
  private_dns_zone_name = azurerm_private_dns_zone.default.name
  virtual_network_id    = azurerm_virtual_network.default.id
  registration_enabled  = false
  tags                  = var.common_tags
}




