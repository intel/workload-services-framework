#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
terraform {
  required_providers {
    local = {
      source = "hashicorp/local"
      version = "= 2.4.0"
    }
    random = {
      source = "hashicorp/random"
      version = "= 3.5.1"
    }
    external = {
      source = "hashicorp/external"
      version = "= 2.3.1"
    }
    null = {
      source = "hashicorp/null"
      version = "= 3.2.1"
    }
  }
}

locals {
  configs = sensitive(jsondecode(file(var.config_file)))
}

