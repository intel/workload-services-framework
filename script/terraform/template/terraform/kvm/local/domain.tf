#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

resource "libvirt_domain" "default" {
  for_each = local.instances

  name = "wsf-${var.job_id}-${each.key}"
  memory = each.value.memory_size * 1024
  vcpu = each.value.cpu_core_count
  autostart = true
  running = true

  cloudinit = libvirt_cloudinit_disk.default[each.key].id

  cpu {
    mode = "host-model"
  }

  disk {
    volume_id = libvirt_volume.os_disk[each.key].id
    scsi = "false"
  }

  dynamic "disk" {
    for_each = {
      for k,v in local.ebs_disks : k => v if v.instance == each.key
    }
    content {
      volume_id = libvirt_volume.data_disk[disk.key].id
      scsi = "false"
    }
  }

  dynamic "network_interface" {
    for_each = var.kvm_host.networks
    content {
      network_name = network_interface.value
      mac = macaddress.network[format("%s-%s",each.key,network_interface.value)].address
      wait_for_lease = false
      bridge = null
      passthrough = var.network_passthrough
    }
  }

  dynamic "network_interface" {
    for_each = each.value.network_spec!=null?[for i in range(each.value.network_spec.network_count):i]:[]
    content {
      network_name = var.kvm_host.networks.0
      mac = macaddress.spec[format("%s-%s",each.key,network_interface.value)].address
      wait_for_lease = false
      bridge = null
      passthrough = var.network_passthrough
    }
  }

  # https://bugs.launchpad.net/cloud-images/+bug/1573095
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }

  xml {
    xslt = templatefile("${path.module}/templates/domain.xslt.tpl", {
      hugepages = lookup(local.cluster_hugepages, each.key, [])
      nic_model = lookup(local.os[each.value.os_type], "nic_model", null)
    })
  }
}
