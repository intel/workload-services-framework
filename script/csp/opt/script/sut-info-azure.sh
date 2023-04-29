#!/bin/bash -e

zone=$1
shift
instances=($(echo $@ | tr ' ' '\n' | cut -f2 -d:))
lines="$(az vm list-sizes --location=${zone::-2} --output=json)"
for instance in $@; do
  vm_group="${instance/:*/}"
  instance="${instance/*:/}"
  cores="$(echo "$lines" | sed -n "/\"name\":\s*\"$instance\"/,/\"name\":/{/\"numberOfCores\":/{s/.*:\s*\([0-9]*\).*/\\1/;p;q}}")"
  memory="$(echo "$lines" | tac | sed -n "/\"name\":\s*\"$instance\"/,/\"name\":/{/\"memoryInMb\":/{s/.*:\s*\([0-9]*\).*/\\1/;p;q}}")"
  echo "${vm_group^^}_VCPUS=$cores"
  echo "${vm_group^^}_MEMORY=$(( memory / 1024 ))"
done
