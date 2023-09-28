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
        start_phrase="$(echo "$EVENT_TRACE_PARAMS" | cut -f2 -d,)"
        while kill -0 $2; do
            docker $1 | grep -q -F "$start_phrase" && break
            bash -c "sleep 0.1"
        done > /dev/null 2>&1
    elif [[ "$EVENT_TRACE_PARAMS" = "time,"* ]]; then
        sleep $(echo "$EVENT_TRACE_PARAMS" | cut -f2 -d,)s
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
        stop_phrase="$(echo "$EVENT_TRACE_PARAMS" | cut -f3 -d,)"
        while kill -0 $2; do
            docker $1 | grep -q -F "$stop_phrase" && break
            bash -c "sleep 0.1"
        done > /dev/null 2>&1
        trace_revoke $3
    elif [[ "$EVENT_TRACE_PARAMS" = "time,"* ]]; then
        sleep $(echo "$EVENT_TRACE_PARAMS" | cut -f3 -d,)s
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
