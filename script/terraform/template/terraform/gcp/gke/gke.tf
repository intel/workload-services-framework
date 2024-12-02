#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

resource "google_container_cluster" "default" {
  name     = "wsf-${var.job_id}-cluster"

  location = var.zone
  cluster_ipv4_cidr = var.pod_network_cidr
  enable_kubernetes_alpha = var.enable_kubernetes_alpha

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.default.id
  subnetwork = google_compute_subnetwork.default.id

  provisioner "local-exec" {
    command = format("gcloud container clusters get-credentials %s --zone=%s", self.name, var.zone)
  }
}

resource "google_container_node_pool" "default" {
  for_each = local.vms

  name = "wsf-${var.job_id}-${each.key}-np"
  location = var.zone
  cluster = google_container_cluster.default.name
  node_count = 1

  node_config {
    disk_size_gb = each.value.os_disk_size
    disk_type = each.value.os_disk_type
    image_type = local.os_image_type[each.value.os_type]
    machine_type = each.value.instance_type
    min_cpu_platform = each.value.min_cpu_platform
    spot = var.spot_instance
    resource_labels = var.common_tags

    dynamic "kubelet_config" {
      for_each = toset(var.kubelet_config!=null?[1]:[])
      content {
        cpu_manager_policy = var.kubelet_config.cpu_manager_policy
      }
    }

    metadata = {
      "ssh-keys" = "${local.os_image_user[each.value.os_type]}:${var.ssh_pub_key}"
    }

    tags = [
      "wsf-${var.job_id}-fwext",
      "wsf-${var.job_id}-fwint",
    ]
  }
}

data "google_compute_instance_group" "default" {
  for_each = local.vms
  self_link = google_container_node_pool.default[each.key].instance_group_urls.0
}

data "google_compute_instance" "default" {
  for_each = local.vms
  self_link = tolist(data.google_compute_instance_group.default[each.key].instances).0
}

resource "local_file" "default" {
  for_each = local.vms

  content = local.init_disks[each.key]
  filename = "/tmp/${var.job_id}-${each.key}-init_disks.sh"
}

resource "null_resource" "init-disks" {
  for_each = local.vms

  provisioner "local-exec" {
    command = format("scp -p -i %s %s %s@%s:/tmp/%s-init-disks.sh", var.ssh_private_key_file, local_file.default[each.key].filename, local.os_image_user[each.value.os_type], data.google_compute_instance.default[each.key].network_interface.0.access_config.0.nat_ip, var.job_id)
  }

  provisioner "local-exec" {
    command = format("ssh -i %s %s@%s /tmp/%s-init-disks.sh", var.ssh_private_key_file, local.os_image_user[each.value.os_type], data.google_compute_instance.default[each.key].network_interface.0.access_config.0.nat_ip, var.job_id)
  }

  depends_on = [
    google_compute_attached_disk.default
  ]
}
