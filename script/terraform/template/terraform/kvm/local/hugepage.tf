#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

locals {
  cluster_config = yamldecode(file("${path.root}/cluster-config.yaml"))

  hugepage_sizes = {
    "2048kB" = {
       size = 2
       unit = "M"
    }
    "1048576kB" = {
       size = 1
       unit = "G"
    }
  }

  cluster_hugepage_aux = [
    for c in local.cluster_config.cluster : {
      name = c
      vm_group = contains(keys(c), "vm_group") ? c.vm_group : "worker"
      hugepages = [
        for k,v in c.labels : local.hugepage_sizes[split("-", k)[3]] 
          if (startswith(k,"HAS-SETUP-HUGEPAGE-") && (v=="required"))
      ]
    }
  ]

  cluster_hugepage_flat = flatten([
    for p in var.instance_profiles : [
      for i in range(length(local.cluster_hugepage_aux)) : {
        host = format("%s-%d", local.cluster_hugepage_aux[i].vm_group, 
          sum(slice([
            for g in local.cluster_hugepage_aux : g.vm_group == p.name ? 1 : 0
          ], 0, i+1))-1), 
        hugepages = local.cluster_hugepage_aux[i].hugepages
      } if local.cluster_hugepage_aux[i].vm_group == p.name
    ] if p.vm_count > 0
  ])

  cluster_hugepages = {
    for hp in local.cluster_hugepage_flat : hp.host => hp.hugepages
  }
}

