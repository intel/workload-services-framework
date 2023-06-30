#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
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
    }
  }

  metadata = {
    ssh-keys = "${local.os_image_user[each.value.os_type]}:${var.ssh_pub_key}"
    user-data = "${data.template_cloudinit_config.default[each.key].rendered}"
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
  }

  advanced_machine_features {
    enable_nested_virtualization = false
    threads_per_core = each.value.threads_per_core
    visible_core_count = each.value.cpu_core_count
  }

  dynamic "scratch_disk" {
    for_each = range(each.value.data_disk_spec!=null?(each.value.data_disk_spec.disk_type=="local"?each.value.data_disk_spec.disk_count:0):0)
    content {
      interface = var.instance_storage_interface
    }
  }

  labels = var.common_tags
}
