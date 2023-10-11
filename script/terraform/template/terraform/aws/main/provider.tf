#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "= 5.13.1"
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

provider "aws" {
  region = var.region!=null?var.region:replace(var.zone,"/(.*)[a-z]$/","$1")
  profile = var.profile

  default_tags {
    tags = var.common_tags
  }
}
