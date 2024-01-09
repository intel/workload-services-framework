#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# args: cmd pid itr
trace_invoke () {
    if [[ "$EVENT_TRACE_PARAMS" = "roi,"* ]]; then
        first_timeout="$(echo "$TIMEOUT" | cut -f1 -d,)"
        third_timeout="$(echo "$TIMEOUT" | cut -f3 -d,)"
        start_phrase="$(echo "$EVENT_TRACE_PARAMS" | cut -f2 -d, | sed 's/[+][0-9]*[smh]$//')"
        start_delay="$(echo "$EVENT_TRACE_PARAMS" | cut -f2 -d, | sed 's/^.*[+]\([0-9]*[smh]\)$/\1/')"
        while kill -0 $2; do
            if [[ "$start_phrase" = /*/ ]]; then
                start_phrase1="${start_phrase#/}"
                docker $1 | tr '\n' '~' | grep -q -E "${start_phrase1%/}" && break
            else
                docker $1 | grep -q -F "$start_phrase" && break
            fi
            bash -c "sleep 0.1"
        done > /dev/null 2>&1
        if [[ "$start_delay" =~ ^[0-9]*[smh]$ ]]; then
            [[ "$start_delay" =~ ^0*[smh]$ ]] || sleep $start_delay
        fi
    elif [[ "$EVENT_TRACE_PARAMS" = "time,"* ]]; then
        sleep $(echo "$EVENT_TRACE_PARAMS" | cut -f2 -d, | sed 's/^\([0-9]*\)$/\1s/')
    fi

    pids=()
    for tm in "$PROJECTROOT"/script/docker/trace/*; do
        if [[ " $DOCKER_RUNTIME_OPTIONS $CTESTSH_OPTIONS " = *" --${tm/*\//} "* ]] && [ -x "$tm" ]; then
            eval "${tm/*\//}_start '$LOGSDIRH/worker-0-$3'" &
            pids+=($!)
        fi
    done
    if [ ${#pids[@]} -gt 0 ]; then
        wait ${pids[@]}
    fi

    if [[ "$EVENT_TRACE_PARAMS" = "roi,"* ]]; then
        stop_phrase="$(echo "$EVENT_TRACE_PARAMS" | cut -f3 -d, | sed 's/[+][0-9]*[smh]$//')"
        stop_delay="$(echo "$EVENT_TRACE_PARAMS" | cut -f3 -d, | sed 's/^.*[+]\([0-9]*[smh]\)$/\1/')"
        while kill -0 $2; do
            if [[ "$stop_phrase" = /*/ ]]; then
                stop_phrase1="${stop_phrase#/}"
                docker $1 | tr '\n' '~' | grep -q -E "${stop_phrase1%/}" && break
            else
                docker $1 | grep -q -F "$stop_phrase" && break
            fi
            bash -c "sleep 0.1"
        done > /dev/null 2>&1
        if [[ "$stop_delay" =~ ^[0-9]*[smh]$ ]]; then
            [[ "$stop_delay" =~ ^0*[smh]$ ]] || sleep $stop_delay
        fi
        trace_revoke $3
    elif [[ "$EVENT_TRACE_PARAMS" = "time,"* ]]; then
        sleep $(echo "$EVENT_TRACE_PARAMS" | cut -f3 -d, | sed 's/^\([0-9]*\)$/\1s/')
        trace_revoke $3
    fi
}

# args: itr
trace_revoke () {
    pids=()
    for tm in "$PROJECTROOT"/script/docker/trace/*; do
        if [[ " $DOCKER_RUNTIME_OPTIONS $CTESTSH_OPTIONS " = *" --${tm/*\//} "* ]] && [ -x "$tm" ]; then
            eval "${tm/*\//}_stop '$LOGSDIRH/worker-0-$1'" &
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
        if [[ " $DOCKER_RUNTIME_OPTIONS $CTESTSH_OPTIONS " = *" --${tm/*\//} "* ]] && [ -x "$tm" ]; then
            eval "${tm/*\//}_collect '$LOGSDIRH/worker-0-$1'" &
            pids+=($!)
        fi
    done
    if [ ${#pids[@]} -gt 0 ]; then
        wait ${pids[@]}
    fi
}

for tm in "$PROJECTROOT"/script/docker/trace/*; do
    if [ -x "$tm" ]; then
        . "$tm"
    fi
done
