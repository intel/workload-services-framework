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

    options1=""
    if [ "$IMAGEARCH" != "linux/amd64" ]; then
        options1="--platform $IMAGEARCH"
    fi

    # start the jobs
    mkdir -p "$LOGSDIRH/$NAMESPACE"
    [ -n "$REGISTRY" ] && docker pull $options1 $image

    if [ ${#DATASET[@]} -gt 0 ]; then
        containers+=($(for ds in ${DATASET[@]}; do [ -n "$REGISTRY" ] && docker pull $ds > /dev/null; docker create $ds -; done))
        options1="$options1$(echo;for ds in ${containers[@]}; do echo "--volumes-from $ds"; done)"
    fi
    (set -x; docker run $options1 --name $NAMESPACE --rm --detach "${@}" $image)
    containers+=($NAMESPACE)

    # show the logs
    docker logs -f $NAMESPACE 2>/dev/null &

    # extract logs
    timeout ${TIMEOUT/,*/}s bash -c "docker exec $NAMESPACE cat /export-logs | tar xf - -C '$LOGSDIRH/$NAMESPACE'"

    # cleanup
    trap - ERR SIGINT EXIT
    stop_docker
}

IMAGE=$(image_name "$DOCKER_IMAGE")
DATASET=($(dataset_images))
docker_run $IMAGE $DOCKER_OPTIONS
 
