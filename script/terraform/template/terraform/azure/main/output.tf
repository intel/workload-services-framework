output "instances" {
  value = {
    for i, instance in local.vms : i => {
        public_ip: azurerm_public_ip.default[i].ip_address,
        private_ip: azurerm_network_interface.default[i].private_ip_address,
        user_name: local.os_image_user[instance.os_type],
        instance_type: instance.instance_type,
    }
  }
}
