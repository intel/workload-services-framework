#!/usr/bin/gawk
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

BEGIN {
  worker_ip="0.0.0.0"
  worker_instance="static"
  vm_group=""
  ssh_config = 1
  terraform_config = 1
  inventory_yaml = 1
}

/^\s*["]public_ip["]:/ && vm_group=="worker-0" && terraform_config==1 {
  worker_ip=gensub(/[",]/, "", "g", $NF)
  ssh_config = 0
}

(/^\s*[a-z]*_[a-z]*:/ || /^\s*[a-z]*:/) && ssh_config==1 {
  vm_group=$1
  terraform_config = 0
  inventory_yaml = 0
}

/^\s*variable\s*"[a-z]+_profile"\s*{/ && terraform_config==1 {
  vm_group=gensub(/"(.*)_profile"/,"\\1",1,$2)
  ssh_config = 0
}

/^\s*instance_type\s*=\s*".*"\s*$/ && vm_group=="worker" && terraform_config==1{
  worker_instance=gensub(/["]/,"","g",$3)
  ssh_config = 0
}

/^\s*Host / && ssh_config==1 {
  vm_group=$2
  terraform_config = 0
  inventory_yaml = 0
}

/^\s*HostName=/ && vm_group=="worker-0" && ssh_config==1 {
  split($1, fields, "=")
  worker_ip=fields[2]
  terraform_config = 0
  inventory_yaml = 0
}

/^\s*[a-z]+-[0-9]+:/ && inventory_yaml==1 {
  vm_group=gensub(/:$/, "", 1, $1)
  ssh_config = 0
}

/^\s*ansible_host:/ && vm_group=="worker-0" && inventory_yaml==1 {
  worker_ip=$NF
  ssh_config = 0
}

END {
  if (worker_instance=="static" && length(sutinfo_values)>0)
    for (p in sutinfo_values[sutinfo_ws])
      for (s in sutinfo_values[sutinfo_ws][p])
        for (c in sutinfo_values[sutinfo_ws][p][s])
          for (g in sutinfo_values[sutinfo_ws][p][s])
            for (k in sutinfo_values[sutinfo_ws][p][s][g])
              if (s==worker_ip && g=="CPU" && k=="Microarchitecture")
                worker_instance=sutinfo_values[sutinfo_ws][p][s][c][g][k][1]
  print worker_instance
  print worker_ip
}
