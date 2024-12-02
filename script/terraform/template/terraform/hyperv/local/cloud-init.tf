#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

locals {
  is_windows = {
    for k,v in local.instances : k=>replace(v.os_type,"windows","")!=v.os_type
  }
  device_paths = [
    "/dev/sdb",
    "/dev/sdc",
    "/dev/sdd",
    "/dev/sde",
    "/dev/sdf",
    "/dev/sdg",
    "/dev/sdh",
    "/dev/sdi",
    "/dev/sdj",
    "/dev/sdk",
  ]
  drive_letters = ["H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"]
}

resource "random_password" "default" {
  for_each = local.instances
  length = 16
  min_special = 2
  min_numeric = 2
  min_lower = 2
  min_upper = 2
  special = true
  override_special = "!#&*()_=+[]?"
}

data "external" "env" {
  program = [ "${path.module}/scripts/env.sh" ]
}

resource "random_string" "hostname" {
  for_each = local.instances
  length = 14 - length(each.key)
  special = false
  lower = false
  upper = false
  numeric = true
}

resource "null_resource" "cloud_init" {
  for_each = local.instances

  triggers = {
    inventory = local_sensitive_file.host.filename
    dest = "${var.data_disk_path}\\wsf-${var.job_id}-${each.key}-dvd.iso"
    host_name = "${each.key}-${random_string.hostname[each.key].result}"
  }

  provisioner "local-exec" {
    command = "ansible-playbook -i ${self.triggers.inventory} -t create ${path.module}/scripts/iso.yaml"
    environment = {
      USER_DATA = base64encode(local.is_windows[each.key]?templatefile("${path.module}/templates/cloud-init.windows.tpl", {
        user = local.os[each.value.os_type].user
        password = random_password.default[each.key].result
        host_name = self.triggers.host_name
        drives  = slice(local.drive_letters,0,length([
          for k,v in local.ebs_disks : k if v.instance == each.key
        ]))
        http_proxy = replace(replace(data.external.env.result.http_proxy,"http://",""),"/","")
        https_proxy = replace(replace(data.external.env.result.https_proxy,"http://",""),"/","")
        no_proxy = join(";",[for x in split(",",data.external.env.result.no_proxy): x if (!strcontains(x,"/"))])
      }):templatefile("${path.module}/templates/cloud-init.linux.tpl", {
        host_name = self.triggers.host_name
        user = local.os[each.value.os_type].user
        authorized_keys = var.ssh_pub_key
        http_proxy = data.external.env.result.http_proxy
        https_proxy = data.external.env.result.https_proxy
        no_proxy = data.external.env.result.no_proxy
        data_disks = [
          for k,v in local.ebs_disks : {
            device = local.device_paths[v.lun]
            path = format("/mnt/disk%d", v.lun+1)
            format = v.disk_format
          } if v.instance == each.key
        ]
      }))
      META_DATA = base64encode(templatefile("${path.module}/templates/meta-data.tpl", {
      }))
      NETWORK_CONFIG = local.is_windows[each.key]?"":base64encode(templatefile("${path.module}/templates/network-config.linux.tpl", {
      }))
      DEST = self.triggers.dest
    }
  }

  provisioner "local-exec" {
    when = destroy
    command = "ansible-playbook -i ${self.triggers.inventory} -t destroy ${path.module}/scripts/iso.yaml"
    environment = {
      DEST = self.triggers.dest
    }
  }
}

