
data "azurerm_resource_group" "default" {
  count    = var.create_resource?0:1
  name     = "wsf-${var.owner}-image-rg"
}

resource "azurerm_resource_group" "default" {
  count    = var.create_resource?1:0
  name     = "wsf-${var.owner}-image-rg"
  location = var.region!=null?var.region:replace(var.zone,"/^(.*)..$/","$1")
  tags     = merge(var.common_tags, {
    owner: var.owner
  })
}

