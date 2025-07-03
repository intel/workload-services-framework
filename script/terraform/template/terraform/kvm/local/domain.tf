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
      for k,v in local.ebs_disks : k => v
        if (v.instance == each.key)
    }
    content {
      volume_id = disk.value.disk_pool!=null?startswith(element(split(",",disk.value.disk_pool),disk.value.lun),"/dev/")?null:libvirt_volume.data_disk[disk.key].id:libvirt_volume.data_disk[disk.key].id
      block_device = disk.value.disk_pool!=null?startswith(element(split(",",disk.value.disk_pool),disk.value.lun),"/dev/")?element(split(",",disk.value.disk_pool),disk.value.lun):null:null
    }
  }

  dynamic "network_interface" {
    for_each = var.kvm_host.networks
    content {
      network_name = network_interface.value
      mac = macaddress.network[format("%s-%s",each.key,network_interface.value)].address
      wait_for_lease = false
    }
  }

  dynamic "network_interface" {
    for_each = each.value.network_spec!=null?[for i in range(each.value.network_spec.network_count):i]:[]
    content {
      network_name = each.value.network_spec.network_type!=null?each.value.network_spec.network_type:var.kvm_host.networks.0
      mac = macaddress.spec[format("%s-%s",each.key,network_interface.value)].address
      wait_for_lease = false
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
      cpu_set = length(each.value.cpu_set)==0?"":join(",", element(chunklist(each.value.cpu_set,each.value.cpu_core_count),each.value.index))
      node_set = length(each.value.node_set)==0?"":join(",", element(chunklist(each.value.node_set,each.value.cpu_core_count),each.value.index))
      nvme_disks = [
        for k,v in local.ebs_disks : {
          device = split("/",v.device)[2]
          namespace = replace(element(split(",",v.disk_pool),v.lun),"/^/dev/nvme[0-9][0-9]*n([0-9][0-9]*).*$/","$1")
          pci = split(":",data.external.nvme.0.result[replace(element(split(",",v.disk_pool),v.lun),"/^/dev//","")])
        } if (v.instance == each.key && (v.disk_pool==null?false:startswith(element(split(",",v.disk_pool),v.lun),"/dev/nvme")))
      ]
    })
  }
}
