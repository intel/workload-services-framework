resource "azurerm_resource_group" "default" {
  name     = "wsf-${var.job_id}-rg"
  location = var.region!=null?var.region:replace(var.zone,"/^(.*)..$/","$1")
  tags     = merge(var.common_tags, {
    owner: var.owner
  })
}
