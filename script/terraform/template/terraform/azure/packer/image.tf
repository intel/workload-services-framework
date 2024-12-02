#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#


locals {
  image_name = replace(lower(var.image_name),"_","-")
  image_rg = "wsf-${var.owner}-image-rg"
}

data "external" "check_image" {
  program = [
    "bash",
    "-c",
    "[[ \"$(az image list -g ${local.image_rg} --query \"[?name=='${local.image_name}'].location\")\" = *'\"${local.location}\"'* ]];echo \"{\\\"status\\\":\\\"$?\\\"}\""
  ]

  lifecycle {
    postcondition {
      condition = self.result.status != "0"
      error_message = "${var.image_name} already exists"
    }
  }
}

data "external" "image_rg" {
  program = [
    "bash",
    "-c",
    "echo \"{\\\"id\\\":$(az group create -l ${local.location} -n ${local.image_rg} --tags owner=${var.owner} --query id)}\""
  ]

  lifecycle {
    postcondition {
      condition = self.result.id != ""
      error_message = "Failed to create resource group ${local.image_rg}"
    }
  }
}

