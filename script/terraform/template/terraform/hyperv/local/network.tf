#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

locals {
  interfaces_flat = flatten(concat([
    for k,v in local.instances : [
      for i in range(length(var.hpv_host.networks)): {
        name = "${k}-switch-${i}"
        instance = k
      }
    ]
  ], [
    for k,v in local.instances : [
      for i in range(v.network_spec!=null?v.network_spec.network_count:0) : {
        name = "${k}-inf-${i}"
        instance = k
      }
    ]
  ]))

  interfaces = {
    for inf in local.interfaces_flat : inf.name => {
      instance = inf.instance
    }
  }
}

data "external" "ip" {
  for_each = local.instances

  program = [ "timeout", "${var.wait_for_ips_timeout}s", "/bin/bash", "-xc",
    format("ip=$(ansible-playbook -i ${local_sensitive_file.host.filename} -e skip=%t -e vmname=%s -e netname=%s ${path.module}/scripts/ip.yaml 2>&1 | sed -n '/IP_START/{s/^.*IP_START//;s/IP_END.*$//;p;q}');echo \"{\\\"ip\\\":\\\"$ip\\\"}\"", fileexists("${path.root}/inventory.yaml"), null_resource.compute[each.key].triggers.vm_name, split(",",null_resource.compute[each.key].triggers.net_names).0)
  ]
}

