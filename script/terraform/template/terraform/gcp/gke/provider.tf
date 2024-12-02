#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "= 5.42.0"
    }
    local = {
      source = "hashicorp/local"
      version = "= 2.4.0"
    }
    null = {
      source = "hashicorp/null"
      version = "= 3.2.1"
    }
  }
}

locals {
  region =  var.region!=null?var.region:replace(var.zone,"/([a-z0-9]+-[a-z0-9]+)-.*/","$1")
}

provider "google" {
  region = local.region
  zone = var.zone
  project = local.project_id
}
