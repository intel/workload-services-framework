#!/bin/bash -e

# args: image [options]
docker_run () {
    image=$1; shift
    containers=()

    [[ "$CTESTSH_OPTIONS" = *"--dry-run"* ]] && exit 0

    stop_docker () {
        docker rm -f -v ${containers[@]} >/dev/null 2>/dev/null || true
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

    if [ ${#DATASET[@]} -gt 0 ]; then
        containers+=($(for ds in ${DATASET[@]}; do [ -n "$REGISTRY" ] && docker pull $options1 $ds > /dev/null; docker create $options1 $ds -; done))
        options1="$options1$(echo;for ds in ${containers[@]}; do echo "--volumes-from $ds"; done)"
    fi

    if [ -r "$PROJECTROOT/script/docker/preswa-hook.sh" ]; then
        . "$PROJECTROOT/script/docker/preswa-hook.sh"
    fi

    options1="$options1 $(compgen -e | sed -nE '/_(proxy|PROXY)$/{s/^/-e /;p}' | tr "\n" " ")"
    options1="$(echo "x$options1 $@" | sed -r 's/(=|\s)(\S*%20\S*)/\1\"\2\"/g' | sed -r 's/%20/ /g')"
    (set -x; bash -c "docker run ${options1#x} --name $NAMESPACE --rm --detach $image")
    containers+=($NAMESPACE)

    # Indicate workload beginning on the first log line
    docker logs -f $NAMESPACE | (
        IFS= read _line;
        echo "===begin workload==="
        while echo "$_line" && IFS= read _line; do :; done
        echo "===end workload==="
    ) 2>/dev/null &

    trace_invoke $NAMESPACE || true
    
    # extract logs
    timeout ${TIMEOUT/,*/}s bash -c "docker exec $NAMESPACE cat $EXPORT_LOGS | tar xf - -C '$LOGSDIRH/$NAMESPACE'"

    trace_revoke || true
    trace_collect || true

    # cleanup
    trap - ERR SIGINT EXIT
    stop_docker
}

. "$PROJECTROOT/script/docker/trace.sh"
IMAGE=$(image_name "$DOCKER_IMAGE")
DATASET=($(dataset_images))
docker_run $IMAGE $DOCKER_OPTIONS 2>&1 | tee "$LOGSDIRH/docker.logs"

