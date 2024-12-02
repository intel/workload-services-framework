#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
output "instances" {
  sensitive = true
  value = merge({
    for i, instance in local.vms : i => {
        public_ip: azurerm_public_ip.default[i].ip_address,
        private_ip: azurerm_network_interface.default[i].private_ip_address,
        user_name: local.os_image_user[instance.os_type],
        instance_type: instance.instance_type,
    }
  },
  {
    "dbinstance" = {
      user_name: var.admin_username == null ? "sqladmin" : var.admin_username,
      password: var.admin_password == null ? random_password.main.result : var.admin_password,
      address: format("%s.database.windows.net", azurerm_mssql_server.sql.name),
      port: var.port,
      database: azurerm_mssql_database.single_database.name
    }
  }
  )
}



