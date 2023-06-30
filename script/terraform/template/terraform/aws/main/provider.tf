#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "= 4.65.0"
    }
  }
}

provider "aws" {
  region = var.region!=null?var.region:replace(var.zone,"/(.*)[a-z]$/","$1")
  profile = var.profile

  default_tags {
    tags = var.common_tags
  }
}
