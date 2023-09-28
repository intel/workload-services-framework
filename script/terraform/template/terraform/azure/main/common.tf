#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
resource "azurerm_resource_group" "default" {
  count = var.resource_group_name!=null?0:1

  name     = "wsf-${var.job_id}-rg"
  location = local.location
  tags     = var.common_tags
}
