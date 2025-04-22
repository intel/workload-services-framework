#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

roi=$1
itr=$2
shift
shift

{% if trace_host == 'localhost' %}

delegate_to () {
  node="$1"
  shift
  case "$node" in
{% for h in groups.trace_hosts|union(groups.controller|default([]))|unique %}
  {{ h }})
    ssh -p {{ hostvars[h]['ansible_port'] | default(22) }} {{ hostvars[h]['ansible_user'] }}@{{ hostvars[h]['ansible_host'] }} {% if ansible_private_key_file is defined %}-i {{ ansible_private_key_file }}{% endif %} "$@"
    ;;
{% endfor %}
  esac
}

{% else %}

get_child_pids () {
  local p
  for p in $@; do
    echo $p
    get_child_pids $(ps --ppid $p -o pid h)
  done
}

get_docker_pids () {
  case "$1" in
  docker:*)
    get_child_pids $(docker inspect -f '{''{ .State.Pid }''}' ${@//*:/})
    ;;
  esac
}

{% endif %}

is_roi () {
  IFS=$'\n' local stop_time=($(cat TRACE_STOP 2> /dev/null || true))
  local i=0
  while [ $i -le $roi ]; do
    [ -n "${stop_time[$i]}" ] || stop_time[$i]="---"
    i=$(( $i + 1 ))
  done

  local in_roi=0
  if (( ! [[ "$1:" =~ :[0-9]+: ]] && [ $roi -ne 0 ] ) || [[ "$1:" = *":$roi:"* ]]) && (( ! [[ "$1:" =~ :itr[0-9]+: ]] ) || [[ "$1:" = *":itr$itr:"* ]]); then
    if [ "${stop_time[$roi]}" = "---" ]; then
      stop_time[$roi]="$(date -Ins)"
      in_roi=1
    fi
  else
    stop_time[$roi]="---"
  fi
  (IFS=$'\n';echo "${stop_time[*]}") > TRACE_STOP
  [ $in_roi -eq 1 ]
}

wait
