output "instances" {
  value = {
    for k,v in local.vms : k => merge({
      public_ip = azurerm_public_ip.default[k].ip_address
      private_ip = azurerm_network_interface.default[k].private_ip_address
      instance_type = v.instance_type
      user_name = local.os_image_user[v.os_type]
    }, {
      for k1,v1 in azurerm_windows_virtual_machine.default : "winrm_password" => random_password.default.0.result if k1 == k
    }, {
      for k1,v1 in azurerm_windows_virtual_machine.default : "winrm_port" => var.winrm_port if k1 == k
    })
  }
}
