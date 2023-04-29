#!/bin/bash -e

zone=$1
shift
instances=($(echo $@ | tr ' ' '\n' | cut -f2 -d:))
lines=""
for instance in $@; do
  vm_group="${instance/:*/}"
  instance="${instance/*:/}"
  if [[ "$instance" = *"-custom-"* ]]; then
      vcpus="$(echo $instance | cut -f3 -d-)"
      memory="$(echo $instance | cut -f4 -d-)"
  else
      [ -n "$lines" ] || lines="$(gcloud compute machine-types list --zones=$zone --filter=name="($(echo ${instances[@]} | tr '\n' ' '))" --format json)"
      vcpus="$(echo "$lines" | tac | sed -n "/\"name\":\s*\"$instance\"/,/\"name\":/{/\"guestCpus\":/{s/.*:\s*\([0-9]*\).*/\\1/;p;q}}")"
      memory="$(echo "$lines" | tac | sed -n "/\"name\":\s*\"$instance\"/,/\"name\":/{/\"memoryMb\":/{s/.*:\s*\([0-9]*\).*/\\1/;p;q}}")"
  fi
  echo "${vm_group^^}_VCPUS=$vcpus"
  echo "${vm_group^^}_MEMORY=$(( memory / 1024 ))"
done
