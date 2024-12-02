#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

zone=$1
shift
instances=($(echo $@ | tr ' ' '\n' | cut -f2 -d:))
lines="$(AWS_PAGER= aws ec2 describe-instance-types --instance-types ${instances[@]} --output json --color off)"
for instance in $@; do
  vm_group="${instance/:*/}"
  instance="${instance/*:/}"
  vcpus="$(echo "$lines" | sed -n "/\"InstanceType\":\s*\"$instance\"/,/\"InstanceType\":/{/\"DefaultVCpus\":/{s/.*:\s*\([0-9]*\).*/\\1/;p;q}}")"
  memory="$(echo "$lines" | sed -n "/\"InstanceType\":\s*\"$instance\"/,/\"InstanceType\":/{/\"MemoryInfo\":/,/}/{/\"SizeInMiB\":/{s/.*:\s*\([0-9]*\).*/\\1/;p;q}}}")"
  IFS=$'\n' gpus=($(echo "$lines" | sed -n "/\"InstanceType\":\s*\"$instance\"/,/\"InstanceType\":/{/\"Gpus\":/,/]/{p}}" | awk -F '"' '/"Name"/{n=$4}/"Manufacturer"/{m=$4}/"Count"/{c=gensub(/.*:/,"",1,$3)*1}/"SizeInMiB"/{s=gensub(/.*:/,"",1,$3)/1024;d[m" "n"-"s"GB"]+=c}END{for(n in d)print d[n]"x"n}'))
  echo "${vm_group^^}_VCPUS=$vcpus"
  echo "${vm_group^^}_MEMORY=$memory"
  (IFS=,;echo "${vm_group^^}_ACCELS=\"${gpus[*]}\"")
done
