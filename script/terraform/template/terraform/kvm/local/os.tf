#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

locals {
  os = {
    "ubuntu2404": {
      "image_url": "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img",
      "user": "ubuntu",
    },
    "ubuntu2204": {
      "image_url": "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img",
      "user": "ubuntu",
    },
    "ubuntu2004": {
      "image_url": "https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img",
      "user": "ubuntu",
    },
    "centos9": {
      "image_url": "https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2",
      "user": "centos",
    },
    "debian11": {
      "image_url": "https://cdimage.debian.org/images/cloud/bullseye/latest/debian-11-genericcloud-amd64.qcow2",
      "user": "tfu",
    },
    "debian12": {
      "image_url": "https://cdimage.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2",
      "user": "tfu",
    },
  }
}
