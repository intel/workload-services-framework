#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
locals {
  os_image_owner = {
    "ubuntu2004": "099720109477" # CANONICAL
    "ubuntu2204": "099720109477" # CANONICAL
    "ubuntu2404": "099720109477" # CANONICAL
    "debian11"  : "136693071363" # Debian
  }
  os_image_filter = {
    "ubuntu2004": "ubuntu/images/*/ubuntu-focal-20.04-*64-server-20*",
    "ubuntu2204": "ubuntu/images/*/ubuntu-jammy-22.04-*64-server-20*",
    "ubuntu2404": "ubuntu/images/*/ubuntu-noble-24.04-*64-server-20*",
    "debian11"  : "debian-11-*64-20220911-1135",
  }
  os_image_user = {
    "ubuntu2004": "ubuntu",
    "ubuntu2204": "ubuntu",
    "ubuntu2404": "ubuntu",
    "debian11"  : "admin",
  }
}

data "aws_ami" "search" {
  for_each = {
    for k,v in local.profile_map : k => v
      if v.vm_count > 0
  }

  most_recent = true

  filter {
    name = "name"
    values = [ "${local.os_image_filter[each.value.os_type]}" ]
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

