#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
terraform {
  required_providers {
    alicloud = {
      source = "aliyun/alicloud"
      version = "= 1.260.0"
    }
  }
}

locals {
  region = var.region!=null?var.region:(length(regexall("^cn-",var.zone))>0?replace(var.zone,"/-[0-9a-z]*$/",""):replace(var.zone,"/.$/",""))
  profiles = sensitive([
    for p in jsondecode(file(var.config_file))["profiles"] : p
      if p["name"] == var.profile
  ])
}

provider "alicloud" {
  region = local.region
  access_key = local.profiles.0.access_key_id
  secret_key = local.profiles.0.access_key_secret
}

