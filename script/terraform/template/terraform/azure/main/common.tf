#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
resource "azurerm_resource_group" "default" {
  name     = "wsf-${var.job_id}-rg"
  location = var.region!=null?var.region:replace(var.zone,"/^(.*)..$/","$1")
  tags     = var.common_tags
}
