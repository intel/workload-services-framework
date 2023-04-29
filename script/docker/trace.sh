#!/bin/bash -e

trace_invoke () {
    if [[ "$EVENT_TRACE_PARAMS" = "roi,"* ]]; then
        first_timeout="$(echo "$TIMEOUT" | cut -f1 -d,)"
        third_timeout="$(echo "$TIMEOUT" | cut -f3 -d,)"
        start_phrase="$(echo "$EVENT_TRACE_PARAMS" | cut -f2 -d,)"
        timeout ${wait_time:-$(( first_timeout / 2 ))}s bash -c "while true; do docker logs $1 | grep -q -F \"$start_phrase\" && exit 0; sleep 1s; done" || true
    elif [[ "$EVENT_TRACE_PARAMS" = "time,"* ]]; then
        sleep $(echo "$EVENT_TRACE_PARAMS" | cut -f2 -d,)s
    fi

    pids=()
    for tm in "$PROJECTROOT"/script/docker/trace/*; do
        if [[ " $DOCKER_RUNTIME_OPTIONS " = *" --${tm/*\//} "* ]]; then
            eval "${tm/*\//}_start" &
            pids+=($!)
        fi
    done
    if [ ${#pids[@]} -gt 0 ]; then
        wait ${pids[@]}
    fi

    if [[ "$EVENT_TRACE_PARAMS" = "roi,"* ]]; then
        stop_phrase="$(echo "$EVENT_TRACE_PARAMS" | cut -f3 -d,)"
        timeout ${wait_time:-$(( first_timeout / 2 ))}s bash -c "while true; do docker logs $1 | grep -q -F \"$stop_phrase\" && exit 0; sleep 1s; done" || true
        trace_revoke
    elif [[ "$EVENT_TRACE_PARAMS" = "time,"* ]]; then
        sleep $(echo "$EVENT_TRACE_PARAMS" | cut -f3 -d,)s
        trace_revoke
    fi
}

trace_revoke () {
    pids=()
    for tm in "$PROJECTROOT"/script/docker/trace/*; do
        if [[ " $DOCKER_RUNTIME_OPTIONS " = *" --${tm/*\//} "* ]]; then
            eval "${tm/*\//}_stop" &
            pids+=($!)
        fi
    done
    if [ ${#pids[@]} -gt 0 ]; then
        wait ${pids[@]}
    fi
}

trace_collect () {
    pids=()
    for tm in "$PROJECTROOT"/script/docker/trace/*; do
        if [[ " $DOCKER_RUNTIME_OPTIONS " = *" --${tm/*\//} "* ]]; then
            eval "${tm/*\//}_collect" &
            pids+=($!)
        fi
    done
    if [ ${#pids[@]} -gt 0 ]; then
        wait ${pids[@]}
    fi
}

for tm in "$PROJECTROOT"/script/docker/trace/*; do
    . "$tm"
done
