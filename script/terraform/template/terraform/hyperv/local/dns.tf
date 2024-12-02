#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

data "external" "dns" {
  program = [ "/bin/bash", "-c",
    "dns=$(ansible-playbook -i ${local_sensitive_file.host.filename} ${path.module}/scripts/dns.yaml | sed -n '/DNS_START/{s/^.*DNS_START//;s/DNS_END.*$//;p;q}');echo \"{\\\"dns\\\":\\\"$dns\\\"}\""
  ]
}

