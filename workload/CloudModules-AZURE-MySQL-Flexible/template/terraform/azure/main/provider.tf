#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 3.18.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}
