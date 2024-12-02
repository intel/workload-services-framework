#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
      version = "= 5.40.0"
    }
    template = {
      source = "hashicorp/template"
      version = "= 2.2.0"
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

provider "oci" {
  region = local.region
}
