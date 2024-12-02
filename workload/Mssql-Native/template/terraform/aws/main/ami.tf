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
    "debian12"  : "136693071363" # Debian
    "rhel9"    : "309956199498" #RHEL 9
    "windows2016"   : "801119661308" # amazon
    "windows2019"   : "801119661308" # amazon
  }
  os_image_filter = {
    "ubuntu2004": "ubuntu/images/*/ubuntu-focal-20.04-*64-server-20*",
    "ubuntu2204": "ubuntu/images/*/ubuntu-jammy-22.04-*64-server-20*",
    "ubuntu2404": "ubuntu/images/*/ubuntu-noble-24.04-*64-server-20*",
    "debian11"  : "debian-11-*64-20220911-1135",
    "debian12"  : "debian-12-*64-20230910-1499",
    "rhel9"     : "RHEL-9*",
    "windows2016_sql2016" : "Windows_Server-2016-English-Full-SQL_2016_SP3_Enterprise*"
    "windows2016_sql2019" : "Windows_Server-2016-English-Full-SQL_2019_Enterprise*"
    "windows2019_sql2016" : "Windows_Server-2019-English-Full-SQL_2016_Enterprise*"
    "windows2019_sql2019" : "Windows_Server-2019-English-Full-SQL_2019_Enterprise*"
  }
  os_image_user = {
    "ubuntu2004": "ubuntu",
    "ubuntu2204": "ubuntu",
    "ubuntu2404": "ubuntu",
    "debian11"  : "admin",
    "debian12"  : "admin",
    "rhel9"     : "ec2-user",
    "windows2016" : "Administrator"
    "windows2019" : "Administrator"
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
    values = [ "${local.os_image_filter["${each.value.os_type}_${local.config.tunables.SQL_VER}"]}" ]
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

data "aws_ami" "image" {
  for_each = {
    for k,v in local.instances : k => v 
      if startswith((v.os_image!=null?v.os_image:"ami-"), "ami-")==false
  }

  filter {
    name = "name"
    values = [ each.value.os_image ]
  }

  most_recent = true
}

