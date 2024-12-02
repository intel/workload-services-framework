#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
terraform {
  required_providers {
    tencentcloud = {
      source = "tencentcloudstack/tencentcloud"
      version = "= 1.81.117"
    }
  }
}

locals {
  credentials = sensitive(jsondecode(file("~/.tccli/default.credential")))
  region = var.region!=null?var.region:replace(var.zone,"/([a-z][a-z]-[a-z]+)-[0-9]?$/","$1")
}

provider "tencentcloud" {
  secret_id = var.secret_id != null?var.secret_id:local.credentials["secretId"]
  secret_key = var.secret_key != null?var.secret_key:local.credentials["secretKey"]
  region = local.region
}

