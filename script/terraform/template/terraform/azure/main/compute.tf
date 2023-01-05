resource "azurerm_linux_virtual_machine" "default" {
  for_each = local.vms

  name                = "wsf-${var.job_id}-vm-${each.key}"
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_resource_group.default.location
  size                = each.value.instance_type
  admin_username      = local.os_image_user[each.value.os_type]
  source_image_id     = each.value.image
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
    for_each = each.value.image == null?[1]:[]

    content {
      publisher = local.os_image_publisher[each.value.os_type]
      offer     = local.os_image_offer[each.value.os_type]
      sku       = format("%s%s", local.os_image_sku[each.value.os_type], local.os_image_sku_suffixes[each.key]) 
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
