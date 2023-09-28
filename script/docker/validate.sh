#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# args: image itr
docker_run () {
    containers=()

    [[ "$CTESTSH_OPTIONS" = *"--dry-run"* ]] && exit 0

    stop_docker () {
        trap - ERR SIGINT EXIT
        (set -x; docker rm -f -v ${containers[@]}) || true
        exit 3
    }

    # set trap
    trap stop_docker ERR SIGINT EXIT

    mkdir -p "$LOGSDIRH/itr-$2/worker-0"
    cp -f "$LOGSDIRH/kpi.sh" "$LOGSDIRH/itr-$2"

    # start the jobs
    options1=""
    [ "$IMAGEARCH" = "linux/amd64" ] || options1="--platform $IMAGEARCH"
    [ -z "$REGISTRY" ] || docker pull $options1 $1

    if [ -r "$PROJECTROOT/script/docker/preswa-hook.sh" ]; then
        . "$PROJECTROOT/script/docker/preswa-hook.sh"
    fi

    options1="$options1 $(compgen -e | sed -nE '/_(proxy|PROXY)$/{s/^/-e /;p}' | tr "\n" " ")"
    (set -x; docker run $options1 $DOCKER_OPTIONS --name $NAMESPACE --rm --detach $1)
    containers+=($NAMESPACE)

    # Indicate workload beginning on the first log line
    docker logs -f $NAMESPACE | (
        IFS= read _line;
        echo "===begin workload==="
        while echo "$_line" && IFS= read _line; do :; done
        echo "===end workload==="
    ) 2>/dev/null &

    # extract logs
    timeout ${TIMEOUT/,*/}s bash -c "docker exec $NAMESPACE sh -c 'cat $EXPORT_LOGS > /tmp/$NAMESPACE-logs.tar;tar tf /tmp/$NAMESPACE-logs.tar > /dev/null 2>&1 && cat /tmp/$NAMESPACE-logs.tar || tar cf - \$(cat /tmp/$NAMESPACE-logs.tar)' | tar xf - -C '$LOGSDIRH/itr-$2/worker-0'" > /dev/null 2>&1 &
    waitproc=$!

    trace_invoke "logs $NAMESPACE" $waitproc $2 || true
    
    # wait until completion
    tail --pid=$waitproc -f /dev/null > /dev/null 2>&1 || true

    trace_revoke $2 || true
    trace_collect $2 || true

    # cleanup
    trap - ERR SIGINT EXIT
    (set -x; docker rm -f -v ${containers[@]})
}

# args: itr
docker_compose_run () {
    [[ "$CTESTSH_OPTIONS" = *"--dry-run"* ]] && exit 0

    stop_docker_compose () {
        trap - ERR SIGINT EXIT
        (set -x; docker compose down --volumes)
        exit 3
    }

    mkdir -p "$LOGSDIRH/itr-$1"
    cp -f "$LOGSDIRH/kpi.sh" "$LOGSDIRH/itr-$1"
    cd "$LOGSDIRH/itr-$1"
    cp -f "$COMPOSE_CONFIG" "docker-compose.yaml"

    trap stop_docker_compose ERR SIGINT EXIT

    # start the jobs
    options=""
    [ -z "$REGISTRY" ] || options="--pull always"
    (set -x; docker compose up $options --detach --force-recreate)

    # extract logs
    filters=($(echo "$JOB_FILTER" | tr ',' '\n'))
    service="${filters[0]#*=}"

    mkdir -p "$LOGSDIRH/itr-$1/$service"
    timeout ${TIMEOUT/,*/}s bash -c "docker compose exec $service sh -c 'cat $EXPORT_LOGS > /tmp/$NAMESPACE-logs.tar;tar tf /tmp/$NAMESPACE-logs.tar > /dev/null 2>&1 && cat /tmp/$NAMESPACE-logs.tar || tar cf - \$(cat /tmp/$NAMESPACE-logs.tar)' | tar xf - -C '$LOGSDIRH/itr-$1/$service'" > /dev/null 2>&1 &
    waitproc=$!

    trace_invoke "compose logs $service" $waitproc $1 || true

    # Wait until job completes
    tail --pid $waitproc -f /dev/null > /dev/null 2>&1 || true

    trace_revoke $1 || true
    trace_collect $1 || true

    # retrieve any service logs
    for service in ${filters[@]}; do
        if [ "$service" != "${filters[0]}" ]; then
            mkdir -p "$LOGSDIRH/itr-$1/${service#*=}"
            docker compose exec ${service#*=} sh -c "cat $EXPORT_LOGS > /tmp/$NAMESPACE-logs.tar;tar tf /tmp/$NAMESPACE-logs.tar > /dev/null 2>&1 && cat /tmp/$NAMESPACE-logs.tar || tar cf - \$(cat /tmp/$NAMESPACE-logs.tar)" | tar xf - -C "$LOGSDIRH/itr-$1/${service#*=}" || true
        fi
    done

    # cleanup
    trap - ERR SIGINT EXIT
    (set -x; docker compose down --volumes)
}

. "$PROJECTROOT/script/docker/trace.sh"
iterations="$(echo "x--run_stage_iterations=1 $DOCKER_CMAKE_OPTIONS $CTESTSH_OPTIONS" | sed 's/.*--run_stage_iterations=\([0-9]*\).*/\1/')"
if [[ "$DOCKER_CMAKE_OPTIONS $CTESTSH_OPTIONS " = *"--native "* ]]; then
    echo "--native not supported"
    exit 3
elif [[ "$DOCKER_CMAKE_OPTIONS $CTESTSH_OPTIONS " = *"--compose "* ]]; then
    rebuild_compose_config
    for itr in $(seq 1 $iterations); do
        docker_compose_run $itr
    done 2>&1 | tee "$LOGSDIRH/docker.logs"
else
    IMAGE=$(image_name "$DOCKER_IMAGE")
    for itr in $(seq 1 $iterations); do
        docker_run $IMAGE $itr
    done 2>&1 | tee "$LOGSDIRH/docker.logs"
fi
sed -i '1acd itr-1' "$LOGSDIRH/kpi.sh"
