output "packer" {
  value = {
    region: local.region
    zone: var.zone
    project_id: local.project_id
    network_id: google_compute_network.default.id
    subnet_id: google_compute_subnetwork.default.id
    firewall_rules: [
       google_compute_firewall.internal.id,
       google_compute_firewall.external.id,
    ]
  }
}
