#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

locals {
  os_image_family_suffix = {
    "t2a" = "-arm64",
  }
  os_image_family = {
    "ubuntu2004": "family/ubuntu-2004-lts",
    "ubuntu2204": "family/ubuntu-2204-lts",
    "debian11"  : "family/debian-11",
    "debian12"  : "family/debian-12",
    "rhel9"     : "family/rhel-9"
  }
  os_image_project = {
    "ubuntu2004": "ubuntu-os-cloud",
    "ubuntu2004": "ubuntu-os-cloud",
    "debian11"  : "debian-cloud",
    "debian12"  : "debian-cloud",
    "rhel9"     : "rhel-cloud",
  }
  os_image_user = {
    "ubuntu2004": "tfu",
    "ubuntu2204": "tfu",
    "debian11"  : "tfu",
    "debian12"  : "tfu",
    "rhel9"     : "tfu",
  }
}

locals {
  os_images = {
    for k,v in local.vms: k => format("%s%s",local.os_image_family[v.os_type],lookup(local.os_image_family_suffix,split("-",v.instance_type)[0],""))
  }
}
