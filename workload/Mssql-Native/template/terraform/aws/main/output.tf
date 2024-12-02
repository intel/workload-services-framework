#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
output "instances" {
  value = {
    for i, instance in var.spot_instance?aws_spot_instance_request.default:aws_instance.default : i => {
        public_ip: instance.public_ip,
        private_ip: instance.private_ip,
        user_name: "Administrator"
        instance_type: instance.instance_type,
        ansible_password : rsadecrypt(instance.password_data, file("/opt/workspace/ssh_access.key"))
        ansible_port: 5986
        ansible_connection: "winrm",
        ansible_winrm_server_cert_validation: "ignore",
        ansible_winrm_transport: "basic",
        ansible_winrm_scheme: "https",
        ansible_winrm_connection_timeout: 60,
    }
  }
}
