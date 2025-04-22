#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

locals {
  is_windows = {
    for k,v in local.instances : k=>replace(v.os_type,"windows","")!=v.os_type
  }
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
  count = length(local.instances)>0?1:0
  program = [ "${path.module}/scripts/env.sh", "-p", var.kvm_host.port, "${var.kvm_host.user}@${var.kvm_host.host}"]
}

resource "macaddress" "network" {
  for_each = toset(flatten([
    for k,v in local.instances : [
      for n in var.kvm_host.networks: 
        format("%s-%s",k,n)
    ]
  ]))
  prefix = var.mac_prefix
}

resource "macaddress" "spec" {
  for_each = toset(flatten([
    for k,v in local.instances : [
      for n in range(v.network_spec!=null?v.network_spec.network_count:0) : 
        format("%s-%d", k, n)
    ]
  ]))
  prefix = var.mac_prefix
}

resource "libvirt_cloudinit_disk" "default" {
  for_each = local.instances

  name = "wsf-${var.job_id}-cloud-init-${each.key}"
  pool = libvirt_pool.default.0.name

  user_data = local.is_windows[each.key]?templatefile("${path.module}/templates/cloud-init.windows.tpl", {
    user = local.os[each.value.os_type].user
    password = random_password.default[each.key].result
    host_name = each.key
    drives  = slice(local.drive_letters,0,length([
      for k,v in local.ebs_disks : k if v.instance == each.key
    ]))
    http_proxy = replace(replace(data.external.env.0.result.http_proxy,"http://",""),"/","")
    https_proxy = replace(replace(data.external.env.0.result.https_proxy,"http://",""),"/","")
    no_proxy = join(";",concat([for x in split(",",data.external.env.0.result.no_proxy): x if (!strcontains(x,"/"))],["<local>","<-loopback>"]))
  }):templatefile("${path.module}/templates/cloud-init.linux.tpl", {
    host_name = each.key
    user = local.os[each.value.os_type].user
    authorized_keys = var.ssh_pub_key
    http_proxy = data.external.env.0.result.http_proxy
    https_proxy = data.external.env.0.result.https_proxy
    no_proxy = data.external.env.0.result.no_proxy
    data_disks = [
      for k,v in local.ebs_disks : {
        device = v.device
        path = v.path
        format = v.disk_format
      } if v.instance == each.key
    ]
  })

  meta_data = local.is_windows[each.key]?templatefile("${path.module}/templates/meta-data.windows.tpl", {
  }):null

  network_config = local.is_windows[each.key]?null:templatefile("${path.module}/templates/network-config.cfg.tpl", {
    macs = concat([
      for n in var.kvm_host.networks : 
        macaddress.network[format("%s-%s",each.key,n)].address
    ], [
      for i in range(each.value.network_spec!=null?each.value.network_spec.network_count:0) :
        macaddress.spec[format("%s-%d",each.key,i)].address
    ])
  })
}

