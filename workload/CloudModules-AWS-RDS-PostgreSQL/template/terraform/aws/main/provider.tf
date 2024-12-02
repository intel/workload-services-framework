#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

resource "aws_key_pair" "default" {
  key_name   = "wsf-${var.job_id}-key"
  public_key = var.ssh_pub_key
  tags = var.common_tags 
}

terraform {
  required_providers {
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

provider "aws" {
  region = var.region
  profile = var.profile
}

