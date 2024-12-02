#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

resource "null_resource" "compute" {
  for_each = local.instances

  triggers = {
    inventory = local_sensitive_file.host.filename
    vm_name = "wsf-${var.job_id}-${each.key}-instance"
    vm_path = "${var.instance_path}\\wsf-${var.job_id}-${each.key}-instance"
    net_names = join(",",[
      for i in range(length(var.hpv_host.networks)):
        "wsf-${var.job_id}-${each.key}-net${i}"
    ])
  }

  provisioner "local-exec" {
    command = "ansible-playbook -i ${self.triggers.inventory} -t create ${path.module}/scripts/vm.yaml"
    environment = {
      VM_NAME = self.triggers.vm_name
      VM_PATH = self.triggers.vm_path
      GENERATION = local.is_windows[each.key]?var.generation:1
      SECURE_BOOT = local.is_windows[each.key]?(var.secure_boot?"On":"Off"):"Off"
      PROCESSOR_COUNT = each.value.cpu_core_count
      MEMORY_SIZE = each.value.memory_size * 1024 * 1024 * 1024
      OS_DISK = "${var.data_disk_path}\\wsf-${var.job_id}-${each.key}-osdisk.vhdx"
      DVD_ISO = "${var.data_disk_path}\\wsf-${var.job_id}-${each.key}-dvd.iso"
      DATA_DISKS = join(",", [
        for k,v in local.ebs_disks : v.path if v.instance == each.key
      ])
      DATA_DISK_CONTROLLER = "${var.data_disk_controller.type},${var.data_disk_controller.number},${var.data_disk_controller.location}"
      NETWORKS = join(",", concat(split(",",self.triggers.net_names), each.value.network_spec!=null?[
        for i in range(each.value.network_spec.network_count):
          "wsf-${var.job_id}-${each.key}-net${i+1}"
      ]:[]))
      SWITCHES = join(",",var.hpv_host.networks)
    }
  }

  provisioner "local-exec" {
    when = destroy
    command = "ansible-playbook -i ${self.triggers.inventory} -t destroy ${path.module}/scripts/vm.yaml"
    environment = {
      VM_NAME = self.triggers.vm_name
      VM_PATH = self.triggers.vm_path
    }
  }

  depends_on = [
    null_resource.cloud_init,
    null_resource.data_disk,
    null_resource.os_disk,
  ]
}

