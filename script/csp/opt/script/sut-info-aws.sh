#!/bin/bash -e

zone=$1
shift
instances=($(echo $@ | tr ' ' '\n' | cut -f2 -d:))
lines="$(AWS_PAGER= aws ec2 describe-instance-types --instance-types ${instances[@]} --output json --color off)"
for instance in $@; do
  vm_group="${instance/:*/}"
  instance="${instance/*:/}"
  vcpus="$(echo "$lines" | sed -n "/\"InstanceType\":\s*\"$instance\"/,/\"InstanceType\":/{/\"DefaultVCpus\":/{s/.*:\s*\([0-9]*\).*/\\1/;p;q}}")"
  memory="$(echo "$lines" | sed -n "/\"InstanceType\":\s*\"$instance\"/,/\"InstanceType\":/{/\"MemoryInfo\":/,/}/{/\"SizeInMiB\":/{s/.*:\s*\([0-9]*\).*/\\1/;p;q}}}")"
  echo "${vm_group^^}_VCPUS=$vcpus"
  echo "${vm_group^^}_MEMORY=$memory"
done
