#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

data "external" "local_ssd" {
  for_each = toset([
    for k,v in local.vms : v.instance_type
      if v.data_disk_spec!=null?(v.data_disk_spec.disk_type=="local"):false
  ])
  program = [ "${path.module}/templates/get-local-ssd.sh", each.value, var.zone ]
}

resource "google_compute_instance" "default" {
  for_each = local.vms

  name         = "wsf-${var.job_id}-vm-${each.key}"
  machine_type = each.value.instance_type
  zone         = var.zone
  min_cpu_platform = each.value.min_cpu_platform

  tags         = [
    "wsf-${var.job_id}-fwext",
    "wsf-${var.job_id}-fwint",
  ]

  boot_disk {
    initialize_params {
      image = each.value.os_image!=null?each.value.os_image:local.os_images[each.key]
      size = each.value.os_disk_size
      type = each.value.os_disk_type
      provisioned_iops = contains(local.prohibit_set_iops_disktype, each.value.os_disk_type)?null:each.value.os_disk_iops
      provisioned_throughput = contains(local.prohibit_set_iops_disktype, each.value.os_disk_type)?null:each.value.os_disk_throughput
    }
  }

  metadata = {
    ssh-keys = "${local.os_image_user[each.value.os_type]}:${var.ssh_pub_key}"
    user-data = "${data.template_cloudinit_config.default[each.key].rendered}"
    enable-oslogin = "FALSE"
  }
  
  network_interface {
    network = google_compute_network.default.name
    subnetwork = google_compute_subnetwork.default.name
    access_config {
    }
    nic_type = each.value.nic_type
  }

  dynamic "network_interface" {
    for_each = [
      for k,v in local.networks : {
        instance     = k
        lun          = v.lun
      } if v.instance == each.key
    ]
    content {
      network = google_compute_network.secondary[network_interface.value.lun].name
      subnetwork = google_compute_subnetwork.secondary[network_interface.value.lun].name
      access_config {
      }
      nic_type = each.value.nic_type
    }
  }

  scheduling {
    preemptible = var.spot_instance?true:false
    automatic_restart = false
    provisioning_model = var.spot_instance?"SPOT":"STANDARD"
    instance_termination_action = var.spot_instance?"DELETE":null
    on_host_maintenance = startswith(each.value.instance_type,"e2-")?null:"TERMINATE"
  }

  advanced_machine_features {
    enable_nested_virtualization = false
    threads_per_core = each.value.threads_per_core
    visible_core_count = each.value.cpu_core_count
  }

  dynamic "scratch_disk" {
    for_each = range(each.value.data_disk_spec!=null?(each.value.data_disk_spec.disk_type=="local"?max(each.value.data_disk_spec.disk_count,data.external.local_ssd[each.value.instance_type].result.local_ssds):0):0)
    content {
      interface = var.instance_storage_interface
    }
  }

  labels = var.common_tags
}
