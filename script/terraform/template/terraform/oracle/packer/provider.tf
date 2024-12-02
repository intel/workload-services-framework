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
  }
}

provider "oci" {
  region = local.region
}
