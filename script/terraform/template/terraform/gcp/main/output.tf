output "instances" {
  value = {
    for i, instance in google_compute_instance.default : i => {
        public_ip: instance.network_interface.0.access_config.0.nat_ip,
        private_ip: instance.network_interface.0.network_ip,
        user_name: local.os_image_user[local.vms[i].os_type],
        instance_type: instance.machine_type,
    }
  }
}
