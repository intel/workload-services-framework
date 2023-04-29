
locals {
  sg_whitelist_cidr_blocks = compact(split("\n", file(var.proxy_ip_list)))
}

resource "google_compute_network" "default" {
  name         = "wsf-${var.job_id}-net"
  project      = local.project_id
  auto_create_subnetworks = false
  routing_mode = "REGIONAL"
}

resource "google_compute_subnetwork" "default" {
  name          = "wsf-${var.job_id}-subnet"
  project       = local.project_id
  ip_cidr_range = var.vpc_cidr_block
  network       = google_compute_network.default.id
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
  source_ranges = local.sg_whitelist_cidr_blocks
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
