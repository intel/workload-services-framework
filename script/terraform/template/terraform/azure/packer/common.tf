#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

locals {
  location = var.region!=null?var.region:replace(var.zone,"/^(.*)..$/","$1")
}

resource "azurerm_resource_group" "default" {
  name     = "wsf-${var.job_id}-rg"
  location = local.location
  tags     = merge(var.common_tags, {
    owner: var.owner
  })
}

data "azurerm_subscription" "current" {
}

