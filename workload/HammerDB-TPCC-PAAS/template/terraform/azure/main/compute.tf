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
       offer    = local.os_image_offer[each.value.os_type][local.os_image_sku_arch[each.key]]
       sku      = local.os_image_sku[each.value.os_type][local.os_image_sku_arch[each.key]] 
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

resource "azurerm_mssql_server" "sql" {
  name                = "wsf-${var.job_id}-sql"
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_resource_group.default.location

  version                              = "12.0"
  connection_policy                    = "Default"
  minimum_tls_version                  = 1.2
  public_network_access_enabled        = false
  #outbound_network_restriction_enabled = false

  administrator_login          = var.admin_username == null ? "sqladmin" : var.admin_username
  administrator_login_password = var.admin_password == null ? random_password.main.result : var.admin_password

  identity {
    type = "SystemAssigned"
  }

  tags = var.common_tags
}

resource "azurerm_mssql_elasticpool" "elastic_pool" {
  count = local.elastic_pool_enabled ? 1 : 0
  name = "wsf-${var.job_id}-elastic_pool"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  license_type = local.elastic_pool_license

  server_name = azurerm_mssql_server.sql.name

  per_database_settings {
    max_capacity = local.elastic_pool_sku.capacity
    min_capacity = local.min_capacity
  }

  max_size_gb    = 500

  sku {
    capacity = local.elastic_pool_sku.capacity
    name     = local.elastic_pool_sku.name
    tier     = local.elastic_pool_sku.tier
    family   = local.elastic_pool_sku.family
  }

  tags = var.common_tags
}

resource "azurerm_mssql_database" "single_database" {
  name            = "wsf-${var.job_id}-single_database"
  server_id       = azurerm_mssql_server.sql.id
  collation       = "SQL_Latin1_General_CP1_CI_AS"
  license_type    = "LicenseIncluded"
  max_size_gb     = 200   
  sku_name        = local.elastic_pool_enabled ? "ElasticPool" : local.sku_name
  create_mode     = "Default"
  depends_on      = [azurerm_mssql_server.sql]
 
  elastic_pool_id = local.elastic_pool_enabled ? one(azurerm_mssql_elasticpool.elastic_pool[*].id) : null

  tags = var.common_tags
}

resource "azurerm_private_endpoint" "default" {
  name                = "wsf-${var.job_id}-private-endpoint"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  subnet_id           = azurerm_subnet.private_link_endpoint.id
  tags                = var.common_tags

  private_dns_zone_group {
    name                 = "wsf-${var.job_id}-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.default.id]
  }

  private_service_connection {
    name                           = "sqldbprivatelink"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_mssql_server.sql.id
    subresource_names              = ["sqlServer"]
  }

  depends_on        = [azurerm_virtual_network.default]
}

resource "azurerm_private_dns_zone" "default" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.default.name
  tags                = var.common_tags
  depends_on          = [azurerm_virtual_network.default]
}

data "azurerm_private_endpoint_connection" "default" {
  name                = azurerm_private_endpoint.default.name
  resource_group_name = azurerm_resource_group.default.name
  depends_on          = [azurerm_mssql_server.sql]
}

resource "azurerm_private_dns_a_record" "default" {
  name                = "wsf-${var.job_id}-dns-record"
  zone_name           = azurerm_private_dns_zone.default.name
  resource_group_name = azurerm_resource_group.default.name
  ttl                 = 300
  records             = [data.azurerm_private_endpoint_connection.default.private_service_connection.0.private_ip_address]
}

resource "azurerm_private_dns_zone_virtual_network_link" "default" {
  name                  = "wsf-${var.job_id}-network-link"
  resource_group_name   = azurerm_resource_group.default.name
  private_dns_zone_name = azurerm_private_dns_zone.default.name
  virtual_network_id    = azurerm_virtual_network.default.id
  registration_enabled  = false
  tags                  = var.common_tags
}




