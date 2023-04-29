
output "packer" {
  value = {
    region: element(coalescelist(data.azurerm_resource_group.default.*.location, azurerm_resource_group.default.*.location, [""]), 0)
    zone: var.zone
    resource_group_id: element(coalescelist(data.azurerm_resource_group.default.*.id, azurerm_resource_group.default.*.id, [""]), 0)
    resource_group_name: element(coalescelist(data.azurerm_resource_group.default.*.name, azurerm_resource_group.default.*.name, [""]), 0)
  }
}

