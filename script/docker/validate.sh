#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# args: itr
docker_run () {
    [[ "$CTESTSH_OPTIONS" = *"--dry-run"* ]] && exit 0

    IFS=$'\n' images=($(sed -n "/^worker-0:/,/^worker-[0-9]*:/{/ image:/{s/.* image: *[\"']*\([^\"']*\)[\"']* *$/\1/;p}}" "$LOGSDIRH/docker-config.yaml"))
    IFS=$'\n' docker_options=($(sed -n "/^worker-0:/,/^worker-/{/ options:/,/(^ *[^:]*:|^ *$)/{/^ * [-] /{s/^ *[-] *[\"']*\([^\"']*\)[\"']* *$/\1/;p};/ options: [^ ]/{s/^.*options: *[\"']*\([^\"']*\)[\"']* *$/~\1/;p};/ options: *$/{s/.*/~/;p}}}" "$LOGSDIRH/docker-config.yaml" | sed '1d' | tr '\n~' ' \n'))
    IFS=$'\n' export_logs=($(sed -n "/^worker-0:/,/^worker-/{/^ *[-] * [a-z-]*:/{s/.*/ export-logs: ~true/};/ export[-]logs:/{s/^.*export[-]logs: *//;p}}" "$LOGSDIRH/docker-config.yaml" | tr '\n~' ' \n'))
    IFS=$'\n' traceables=($(sed -n "/^worker-0:/,/^worker-/{/^ *[-] * [a-z-]*:/{s/.*/ traceable: ~true/};/ traceable:/{s/^.*traceable: *//;p}}" "$LOGSDIRH/docker-config.yaml" | tr '\n~' ' \n'))
    IFS=$'\n' commands=($(sed -n "/^worker-0:/,/^worker-/{/^ *[-] * [a-z-]*:/{s/.*/ command: ~/};/ command:/{s/^.*command: *[\"']*\([^\"']*\)[\"']* *$/\1/;p}}" "$LOGSDIRH/docker-config.yaml" | tr '\n~' ' \n'))

    # set trap
    containers=()
    stop_docker () {
        trap - ERR SIGINT EXIT
        docker rm -f -v ${containers[@]} > /dev/null || true
        exit 3
    }
    trap stop_docker ERR SIGINT EXIT

    # start the jobs
    mkdir -p "$LOGSDIRH/itr-$1"
    cp -f "$LOGSDIRH/kpi.sh" "$LOGSDIRH/itr-$1" 2> /dev/null || true

    options1=()
    [ "$IMAGEARCH" = "linux/amd64" ] || options1+=(--platform $IMAGEARCH)

    # pull images
    if [ -n "$REGISTRY" ]; then
        for i in $(seq 0 $(( ${#images[@]} - 1 ))); do
            docker pull ${options1[@]} ${images[$i]}
        done
    fi

    if [ -r "$PROJECTROOT/script/docker/preswa-hook.sh" ]; then
        . "$PROJECTROOT/script/docker/preswa-hook.sh"
    fi

    options1+=($(compgen -e | sed -nE '/_(proxy|PROXY)$/{s/^/-e /;p}'))
    options1+=(-e TZ=$(timedatectl show --va -p Timezone 2> /dev/null || echo $TZ))

    # invoke docker runs
    for i in $(seq 0 $(( ${#images[@]} - 1 ))); do
        containers+=($(eval "docker run ${options1[@]} --rm --detach ${docker_options[$i]} $([[ " ${docker_options[$i]} " = *" ${images[$i]} "* ]] || echo "${images[$i]}") ${commands[$i]}"))
    done

    # Indicate workload beginning on the first log line
    for i in $(seq 0 $(( ${#images[@]} - 1 ))); do
        docker logs -f ${containers[$i]} | (
            IFS= read _line;
            echo "===begin workload==="
            while echo "worker-0-c$i: $_line" && IFS= read _line; do :; done
            echo "===end workload==="
        ) 2>/dev/null &
    done

    # extract logs
    timeout ${TIMEOUT/,*/}s bash -c "$(
        for i in $(seq 0 $(( ${#images[@]} - 1 ))); do
            if [[ "${export_logs[$i]}" =~ ^.*true" "*$ ]]; then
                mkdir -p "$LOGSDIRH/itr-$1/worker-0-c$i"
                echo -n "docker exec ${containers[$i]} sh -c \"cat $EXPORT_LOGS > /tmp/${containers[$i]}-logs.tar;tar tf /tmp/${containers[$i]}-logs.tar > /dev/null 2>&1 && cat /tmp/${containers[$i]}-logs.tar || tar cf - \\\$(cat /tmp/${containers[$i]}-logs.tar)\" | tar xf - -C \"$LOGSDIRH/itr-$1/worker-0-c$i\"&"
            fi
        done
        echo -n "wait"
    )" > /dev/null 2>&1 &
    waitproc=$!

    trace_cmd="($(
        for i in $(seq 0 $(( ${#images[@]} - 1 ))); do
          if [[ "${traceables[$i]}" =~ ^.*true" "*$ ]]; then
              echo -n "docker logs ${containers[$i]}&"
          fi
        done
    )wait)"
    trace_invoke "$trace_cmd" $waitproc $1 0 || true
    for r in $(seq 1 3 $(echo "${EVENT_TRACE_PARAMS:-1,2,3}" | tr ',' '\n' | wc -l)); do
        roi=$(( $r / 3 + 1 ))
        mode="$(echo "$EVENT_TRACE_PARAMS" | cut -f$r -d,),$(echo "$EVENT_TRACE_PARAMS" | cut -f$(( $r + 1 )) -d,),$(echo "$EVENT_TRACE_PARAMS" | cut -f$(( $r + 2 )) -d,)" 
        trace_invoke "$trace_cmd" $waitproc $1 $roi "$mode" && roi=0 || true
    done
    
    # wait until completion
    tail --pid=$waitproc -f /dev/null > /dev/null 2>&1 || true

    [ $roi -eq 0 ] || trace_revoke $1 $roi || true
    trace_revoke $1 0 || true
    trace_collect $1 || true

    # cleanup
    trap - ERR SIGINT EXIT
    docker rm -f -v ${containers[@]} > /dev/null || true
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
    cp -f "$LOGSDIRH/kpi.sh" "$LOGSDIRH/itr-$1" 2> /dev/null || true
    cd "$LOGSDIRH/itr-$1"
    cp -f "$COMPOSE_CONFIG" docker-compose.yaml
    echo "TZ=$(timedatectl show --va -p Timezone 2> /dev/null || echo $TZ)" > .env
    chmod 600 .env
    for k in "${WORKLOAD_PARAMS[@]%%#*}"; do
        if [[ "$k" = "-"* ]]; then
            eval "echo \"${k#-}=\$${k#-}\"" >> .env
        fi
    done

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

    trace_invoke "docker compose logs $service" $waitproc $1 0 || true
    for r in $(seq 1 3 $(echo "${EVENT_TRACE_PARAMS:-1,2,3}" | tr ',' '\n' | wc -l)); do
        roi=$(( $r / 3 + 1 ))
        mode="$(echo "$EVENT_TRACE_PARAMS" | cut -f$r -d,),$(echo "$EVENT_TRACE_PARAMS" | cut -f$(( $r + 1 )) -d,),$(echo "$EVENT_TRACE_PARAMS" | cut -f$(( $r + 2 )) -d,)" 
        trace_invoke "docker compose logs $service" $waitproc $1 $roi "$mode" && roi=0 || true
    done
    
    # Wait until job completes
    tail --pid $waitproc -f /dev/null > /dev/null 2>&1 || true

    [ $roi -eq 0 ] || trace_revoke $1 $roi || true
    trace_revoke $1 0 || true
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

print_workload_configurations 2>&1 | tee -a "$LOGSDIRH"/docker.logs
. "$PROJECTROOT/script/docker/trace.sh"
iterations="$(echo "x--run_stage_iterations=1 $DOCKER_CMAKE_OPTIONS $CTESTSH_OPTIONS" | sed 's/.*--run_stage_iterations=\([0-9]*\).*/\1/')"
if [[ "$DOCKER_CMAKE_OPTIONS $CTESTSH_OPTIONS " = *"--native "* ]]; then
    echo "--native not supported"
    exit 3
elif [[ "$DOCKER_CMAKE_OPTIONS $CTESTSH_OPTIONS " = *"--compose "* ]]; then
    rebuild_compose_config
    for itr in $(seq 1 $iterations); do
        docker_compose_run $itr
    done 2>&1 | tee -a "$LOGSDIRH/docker.logs"
else
    rebuild_docker_config
    for itr in $(seq 1 $iterations); do
        docker_run $itr
    done 2>&1 | tee -a "$LOGSDIRH/docker.logs"
fi
sed -i '1acd itr-1' "$LOGSDIRH/kpi.sh" 2> /dev/null || true

