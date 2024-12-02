#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

locals {
  os_image_owner = {
    "ubuntu2004": "099720109477" # CANONICAL
  }
  os_image_filter = {
    "ubuntu2004": "ubuntu-eks/k8s_%s/images/*/ubuntu-focal-20.04-*64-server-20*",
  }
  os_image_user = {
    "ubuntu2004": "ubuntu",
  }
}

data "aws_ami" "search" {
  for_each = { for k,v in local.instances : k => v if (v.os_image==null) }

  most_recent = true

  filter {
    name = "name"
    values = [ format(local.os_image_filter[each.value.os_type], var.k8s_version) ]
  }

  filter {
    name = "architecture"
    values = [ replace(each.value.instance_type, "/^[a-z]+[0-9]+([a-z]).*/", "$1") == "g" || split(".", each.value.instance_type)[0] == "a1" ? "arm64" : "x86_64" ]
  }

  owners = [ local.os_image_owner[each.value.os_type] ]

  filter {
    name   = "virtualization-type"
    values = [ "hvm" ]
  }
}

data "aws_ami" "custom" {
  for_each = { for k,v in local.instances : k => v if (v.os_image!=null) }

  filter {
    name = "image-id"
    values = [ each.value.os_image ]
  }
}
