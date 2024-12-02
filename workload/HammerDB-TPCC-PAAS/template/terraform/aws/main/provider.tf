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
    aws = {
      source = "hashicorp/aws"
      version = ">= 4.16.0"
    }
  }
}

provider "aws" {
  region = var.region
  profile = var.profile
}

