#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
terraform {
  required_providers {
    alicloud = {
      source = "aliyun/alicloud"
      version = "= 1.209.0"
    }
    template = {
      source = "hashicorp/template"
      version = "= 2.2.0"
    }
    external = {
      source = "hashicorp/external"
      version = "= 2.3.1"
    }
  }
}

locals {
  region = var.region!=null?var.region:(var.zone=="cn-hangzhou"?var.zone:length(regexall("^cn-",var.zone))>0?replace(var.zone,"/-[a-z0-9]*$/",""):replace(var.zone,"/.$/",""))
}

provider "alicloud" {
  region = local.region
  profile = var.profile
}

