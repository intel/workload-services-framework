#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# args: image [options]
docker_run () {
    image=$1; shift
    containers=()

    [[ "$CTESTSH_OPTIONS" = *"--dry-run"* ]] && exit 0

    stop_docker () {
        trap - ERR SIGINT EXIT
        (set -x; docker rm -f -v ${containers[@]}) || true
        exit ${1:-3}
    }

    # set trap
    trap stop_docker ERR SIGINT EXIT

    if [ "$IMAGEARCH" != "linux/amd64" ]; then
        options1="--platform $IMAGEARCH"
    else
        options1=""
    fi

    # start the jobs
    mkdir -p "$LOGSDIRH/$NAMESPACE"
    [ -n "$REGISTRY" ] && docker pull $options1 $image

    if [ -r "$PROJECTROOT/script/docker/preswa-hook.sh" ]; then
        . "$PROJECTROOT/script/docker/preswa-hook.sh"
    fi

    options1="$options1 $(compgen -e | sed -nE '/_(proxy|PROXY)$/{s/^/-e /;p}' | tr "\n" " ")"
    options1="$(echo "x$options1 $@" | sed -r 's/(=|\s)(\S*%20\S*)/\1\"\2\"/g' | sed -r 's/%20/ /g')"
    (set -x; docker run ${options1#x} --name $NAMESPACE --rm --detach $image)
    containers+=($NAMESPACE)

    # Indicate workload beginning on the first log line
    docker logs -f $NAMESPACE | (
        IFS= read _line;
        echo "===begin workload==="
        while echo "$_line" && IFS= read _line; do :; done
        echo "===end workload==="
    ) 2>/dev/null &

    # extract logs
    timeout ${TIMEOUT/,*/}s bash -c "docker exec $NAMESPACE cat $EXPORT_LOGS | tar xf - -C '$LOGSDIRH/$NAMESPACE'" > /dev/null 2>&1 &
    waitproc=$!

    trace_invoke "logs $NAMESPACE" $waitproc || true
    
    # wait until completion
    tail --pid=$waitproc -f /dev/null > /dev/null 2>&1 || true

    trace_revoke || true
    trace_collect || true

    # cleanup
    stop_docker 0
}

docker_compose_run () {
    [[ "$CTESTSH_OPTIONS" = *"--dry-run"* ]] && exit 0

    stop_docker_compose () {
        trap - ERR SIGINT EXIT
        cd "$LOGSDIRH/$NAMESPACE"
        (set -x; docker compose down --volumes) || true
        exit ${1:-3}
    }

    # start the jobs
    mkdir -p "$LOGSDIRH/$NAMESPACE"
    cd "$LOGSDIRH/$NAMESPACE"
    trap stop_docker_compose ERR SIGINT EXIT

    if [ -r "$PROJECTROOT/script/docker/preswa-hook.sh" ]; then
        . "$PROJECTROOT/script/docker/preswa-hook.sh"
    fi

    cp -f "$COMPOSE_CONFIG" "docker-compose.yaml"
    options="$([ -n "$REGISTRY" ] && echo "--pull always")"
    (set -x; docker compose up $options --detach --force-recreate)

    # extract logs
    timeout ${TIMEOUT/,*/}s bash -c "docker compose exec ${JOB_FILTER/*=/} cat $EXPORT_LOGS | tar xf - -C '$LOGSDIRH/$NAMESPACE'" > /dev/null 2>&1 &
    waitproc=$!

    # Indicate workload beginning on the first log line
    docker compose logs -f | (
        IFS= read _line;
        echo "===begin workload==="
        while echo "$_line" && IFS= read _line; do :; done
        echo "===end workload==="
    ) 2>/dev/null &

    trace_invoke "compose logs ${JOB_FILTER/*=/}" $waitproc || true

    # Wait until job completes
    tail --pid $waitproc -f /dev/null > /dev/null 2>&1 || true

    trace_revoke || true
    trace_collect || true

    # cleanup
    stop_docker_compose 0
}

. "$PROJECTROOT/script/docker/trace.sh"
if [[ "$DOCKER_CMAKE_OPTIONS $CTESTSH_OPTIONS " = *"--native "* ]]; then
    echo "--native not supported"
    exit 3
elif [[ "$DOCKER_CMAKE_OPTIONS $CTESTSH_OPTIONS " = *"--compose "* ]]; then
    rebuild_compose_config
    docker_compose_run 2>&1 | tee "$LOGSDIRH/docker.logs"
else
    IMAGE=$(image_name "$DOCKER_IMAGE")
    docker_run $IMAGE $DOCKER_OPTIONS 2>&1 | tee "$LOGSDIRH/docker.logs"
fi
