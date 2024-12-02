#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "= 5.63.0"
    }
  }
}

locals {
  region = var.region!=null?var.region:replace(var.zone,"/(.*)[a-z]$/","$1")
}

provider "aws" {
  region = local.region
  profile = var.profile

  default_tags {
    tags = merge(var.common_tags, {
      owner: var.owner
    })
  }
}
