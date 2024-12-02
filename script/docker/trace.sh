#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

sudo_password_required () {
  if [ -z "$DEV_SUDO_PASSWORD" ]; then
      read -s -p "[sudo] password for $(id -un): " DEV_SUDO_PASSWORD < /dev/tty > /dev/tty 2>&1
  fi
}

# args: name roi itr TRACE_START/STOP
is_roi () {
  IFS=$'\n' local startstop_time=($(cat $4 2> /dev/null || true))
  startstop_time[$2]="---"
  local option
  while IFS= read option; do
      [[ "$option:" = "--$1:"* ]] || continue
      if ( ( ! [[ "$option:" =~ :[0-9]+: ]] && [ $2 -ne 0 ] ) || [[ "$option:" = *":$2:"* ]] ) && ( ( ! [[ "$option:" =~ :itr[0-9]+: ]] ) || [[ "$option:" = *":itr$3:"* ]] ); then
        startstop_time[$2]="$(date -Ins)"
      fi
  done < <(echo "x $DOCKER_CMAKE_OPTIONS $CTESTSH_OPTIONS " | tr ' ' '\n')

  local i=0
  while [ $i -lt ${#startstop_time[@]} ]; do
    [ -n "${startstop_time[$i]}" ] || startstop_time[$i]="---"
    i=$(( $i + 1 ))
  done
  (IFS=$'\n';echo "${startstop_time[*]}") > $4
  [ "${startstop_time[$2]}" != "---" ]
}

# args: itr roi
trace_start () {
    local pids=()
    for tm in "$PROJECTROOT"/script/docker/trace/*; do
        if ( [[ " $DOCKER_CMAKE_OPTIONS $CTESTSH_OPTIONS " = *" --${tm/*\//}:"* ]] || [[ " $DOCKER_CMAKE_OPTIONS $CTESTSH_OPTIONS " = *" --${tm/*\//} "* ]] ) && [ -x "$tm" ]; then
            eval "${tm/*\//}_start '$LOGSDIRH/worker-0-$1' $2" &
            pids+=($!)
        fi
    done
    if [ ${#pids[@]} -gt 0 ]; then
        wait ${pids[@]}
    fi
}

# args: cmd pid itr roi mode
trace_invoke () {
    if [[ "$5" = "roi,"* ]]; then
        first_timeout="$(echo "$TIMEOUT" | cut -f1 -d,)"
        third_timeout="$(echo "$TIMEOUT" | cut -f3 -d,)"
        start_phrase="$(echo "$5" | cut -f2 -d, | sed 's/[+][0-9]*[smh]$//')"
        start_delay="$(echo "$5" | cut -f2 -d, | sed 's/^.*[+]\([0-9]*[smh]\)$/\1/')"
        while kill -0 $2; do
            if [[ "$start_phrase" = /*/ ]]; then
                start_phrase1="${start_phrase#/}"
                eval "$1" | tr '\n' '~' | grep -q -E "${start_phrase1%/}" && break
            else
                eval "$1" | grep -q -F "$start_phrase" && break
            fi
            bash -c "sleep 0.1"
        done > /dev/null 2>&1
        if [[ "$start_delay" =~ ^[0-9]*[smh]$ ]]; then
            [[ "$start_delay" =~ ^0*[smh]$ ]] || sleep $start_delay
        fi
    elif [[ "$5" = "time,"* ]]; then
        sleep $(echo "$5" | cut -f2 -d, | sed 's/^\([0-9]*\)$/\1s/')
    fi

    trace_start $3 $4

    if [[ "$5" = "roi,"* ]]; then
        stop_phrase="$(echo "$5" | cut -f3 -d, | sed 's/[+][0-9]*[smh]$//')"
        stop_delay="$(echo "$5" | cut -f3 -d, | sed 's/^.*[+]\([0-9]*[smh]\)$/\1/')"
        while kill -0 $2; do
            if [[ "$stop_phrase" = /*/ ]]; then
                stop_phrase1="${stop_phrase#/}"
                eval "$1" | tr '\n' '~' | grep -q -E "${stop_phrase1%/}" && break
            else
                eval "$1" | grep -q -F "$stop_phrase" && break
            fi
            bash -c "sleep 0.1"
        done > /dev/null 2>&1
        if [[ "$stop_delay" =~ ^[0-9]*[smh]$ ]]; then
            [[ "$stop_delay" =~ ^0*[smh]$ ]] || sleep $stop_delay
        fi
        trace_revoke $3 $4
        return 0
    elif [[ "$5" = "time,"* ]]; then
        sleep $(echo "$5" | cut -f3 -d, | sed 's/^\([0-9]*\)$/\1s/')
        trace_revoke $3 $4
        return 0
    fi
    return 1
}

# args: itr roi
trace_revoke () {
    local pids=()
    for tm in "$PROJECTROOT"/script/docker/trace/*; do
        if ( [[ " $DOCKER_CMAKE_OPTIONS $CTESTSH_OPTIONS " = *" --${tm/*\//}:"* ]] || [[ " $DOCKER_CMAKE_OPTIONS $CTESTSH_OPTIONS " = *" --${tm/*\//} "* ]] ) && [ -x "$tm" ]; then
            eval "${tm/*\//}_stop '$LOGSDIRH/worker-0-$1' $2" &
            pids+=($!)
        fi
    done
    if [ ${#pids[@]} -gt 0 ]; then
        wait ${pids[@]}
    fi
}

# args: itr
trace_collect () {
    pids=()
    for tm in "$PROJECTROOT"/script/docker/trace/*; do
        if ( [[ " $DOCKER_CMAKE_OPTIONS $CTESTSH_OPTIONS " = *" --${tm/*\//}:"* ]] || [[ " $DOCKER_CMAKE_OPTIONS $CTESTSH_OPTIONS " = *" --${tm/*\//} "* ]] ) && [ -x "$tm" ]; then
            eval "${tm/*\//}_collect '$LOGSDIRH/worker-0-$1'" &
            pids+=($!)
        fi
    done
    if [ ${#pids[@]} -gt 0 ]; then
        wait ${pids[@]}
    fi
}

for tm in "$PROJECTROOT"/script/docker/trace/*; do
    if ( [[ " $DOCKER_CMAKE_OPTIONS $CTESTSH_OPTIONS " = *" --${tm/*\//}:"* ]] || [[ " $DOCKER_CMAKE_OPTIONS $CTESTSH_OPTIONS " = *" --${tm/*\//} "* ]] ) && [ -x "$tm" ]; then
        . "$tm"
    fi
done
