#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

output "instances" {
  sensitive = true
  value = merge({
    for i, instance in aws_instance.default : i => {
        public_ip: instance.public_ip,
        private_ip: instance.private_ip,
        user_name: local.os_image_user[local.instances[i].os_type],
        instance_type: instance.instance_type,
    }
  },
  {
    "dbinstance" = {
        endpoint: aws_db_instance.default.endpoint,
        address: aws_db_instance.default.address,
        user_name: aws_db_instance.default.username,
        port: aws_db_instance.default.port,
        engine: aws_db_instance.default.engine,
        password: random_password.default.result,
        database: "tpcc",
    }
  }
  )
}
