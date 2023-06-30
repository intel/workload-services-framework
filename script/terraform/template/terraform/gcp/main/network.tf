#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
resource "google_compute_network" "default" {
  name         = "wsf-${var.job_id}-network"
  project      = local.project_id
  auto_create_subnetworks = false
  routing_mode = "REGIONAL"
}

resource "google_compute_subnetwork" "default" {
  name          = "wsf-${var.job_id}-subnet-0"
  project       = local.project_id
  ip_cidr_range = cidrsubnet(var.vpc_cidr_block, 3, 0)
  network       = google_compute_network.default.id
}

resource "google_compute_network" "secondary" {
  for_each = local.cidrs
  name         = "wsf-${var.job_id}-network-${each.key}"
  project      = local.project_id
  auto_create_subnetworks = false
  routing_mode = "REGIONAL"
}

resource "google_compute_subnetwork" "secondary" {
  for_each = local.cidrs
  name          = "wsf-${var.job_id}-subnet-${each.key}"
  project       = local.project_id
  ip_cidr_range = cidrsubnet(var.vpc_cidr_block, 3, each.value)
  network       = google_compute_network.secondary[each.key].id
}

resource "google_compute_firewall" "external" {
  name    = "wsf-${var.job_id}-fwext"
  project = local.project_id
  network = google_compute_network.default.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags = ["wsf-${var.job_id}-fwext"]
  source_ranges = var.sg_whitelist_cidr_blocks
}

resource "google_compute_firewall" "internal" {
  name    = "wsf-${var.job_id}-fw"
  project = local.project_id
  network = google_compute_network.default.name

  allow {
    protocol = "all"
  }

  target_tags = ["wsf-${var.job_id}-fwint"]
  source_ranges = [var.vpc_cidr_block]
}
