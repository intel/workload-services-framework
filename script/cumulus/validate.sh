#!/bin/bash -e

WORKLOAD_NAME=${WORKLOAD_NAME:-$WORKLOAD}
CUMULUS_CONFIG="${CUMULUS_CONFIG:-$LOGSDIRH/cumulus-config.yaml}"
CUMULUS_CONFIG_OVERRIDES="${CUMULUS_CONFIG_OVERRIDES:-''}"
LOGSTARFILE="${LOGSTARFILE:-$LOGSDIRH/output.tar}"
if [[ "$CUMULUS_OPTIONS" = *--owner=* ]]; then
    owner="$(echo "$CUMULUS_OPTIONS" | tr ' ' '\n' | grep -E '^--owner=' | cut -f2 -d=)"
else
    owner="$( (git config user.name || id -un) 2> /dev/null | tr ' ' '-')"
    CUMULUS_OPTIONS="$CUMULUS_OPTIONS --owner=$owner"
fi
if [ "$owner" = "root" ] || [ -z "$owner" ]; then
    echo "Please run as a user or specify --owner=<user> in CUMULUS_OPTIONS"
    exit 3
fi

# convert arrays to strings
if [ ${#WORKLOAD_PARAMS[@]} -gt 0 ]; then
    WORKLOAD_PARAMS="$(IFS=';';echo "${WORKLOAD_PARAMS[*]}")"
fi

# add tags
if [ -n "$WORKLOAD_TAGS" ]; then
    WORKLOAD_TAGS="${WORKLOAD_TAGS// /,}"
    if [[ "$CUMULUS_OPTIONS" = *"--tags="* ]]; then
        CUMULUS_OPTIONS="${CUMULUS_OPTIONS/--tags=/--tags=$WORKLOAD_TAGS,}"
    else
        CUMULUS_OPTIONS="$CUMULUS_OPTIONS --tags=$WORKLOAD_TAGS"
    fi
fi

# args: s2 s3
_reconfigure_cumulus () {
    options=(
        "-e"
        "s|dpt_name:.*|dpt_name: \"$WORKLOAD_NAME\"|"
        "-e"
        "s|dpt_script_args:.*|dpt_script_args: \"${SCRIPT_ARGS}\"|"
        "-e"
        "$1"
        "-e"
        "$2"
        "-e"
        "s|dpt_logs_dir:.*|dpt_logs_dir: \"/home\"|"
        "-e"
        "s|dpt_timeout:.*|dpt_timeout: \"$TIMEOUT\"|"
        "-e"
        "s|dpt_cluster_yaml:.*|dpt_cluster_yaml: \"${CLUSTER_CONFIG/${LOGSDIRH//\//\\\/}/\/home}\"|"
        "-e"
        "s|dpt_params:.*|dpt_params: \"$WORKLOAD_BOM\"|"
        "-e"
        "s|dpt_tunables:.*|dpt_tunables: \"$WORKLOAD_PARAMS;testcase:$TESTCASE$TESTCASE_CUSTOMIZED\"|"
        "-e"
        "s|dpt_registry_map: \"\"|dpt_registry_map: \"$REGISTRY,$REGISTRY\"|"
        "-e"
        "s|dpt_namespace:.*|dpt_namespace: \"$NAMESPACE\"|"
        "-e" 
        "s|dpt_trace_mode:.*|dpt_trace_mode: \"$EVENT_TRACE_PARAMS\"|"
    )
    if [ ${#DATASET[@]} -gt 0 ]; then
        options+=(
            "-e"
            "s|dpt_docker_dataset:.*|dpt_docker_dataset: \"$(echo "${DATASET[@]}" | tr ' ' ',')\"|"
        )
    fi
    sed "${options[@]}" -i "$CUMULUS_CONFIG"
}

# args: <none>
_invoke_cumulus () {
    if [ -r runs/*/pkb.log ]; then
        run_uri="$(ls -1 runs/*/pkb.log | cut -f2 -d/)"
    else
        run_uri=$(cat /proc/sys/kernel/random/uuid | cut -f5 -d-)
    fi
    vmounts+=(
        "-v" "$LOGSDIRH:/home"
        "-v" "$LOGSDIRH:/tmp/pkb"
    )
    if [ -z "$(grep -E '^\s+cloud:' "$CUMULUS_CONFIG")" ]; then
        options=(
            "--ip_addresses=EXTERNAL"
            "--trace_skip_install"
            "--trace_skip_cleanup"
        )
        if [ -d "$HOME/.ssh" ]; then
            vmounts+=(
                "-v" "$(readlink -e "$HOME/.ssh"):/home/.ssh"
                "-v" "$(readlink -e "$HOME/.ssh"):/root/.ssh"
            )
            mkdir -p "$LOGSDIRH/.ssh"
        fi
    else
        options=()
        vmounts+=(
            "-v" "$SCRIPT/cumulus/ssh_config:/home/.ssh/config:ro"
            "-v" "$SCRIPT/cumulus/ssh_config:/root/.ssh/config:ro"
        )
        mkdir -p "$LOGSDIRH/.ssh"
        touch "$LOGSDIRH/.ssh/config"
        if [ -n "REGISTRY" ]; then
            certdir="/etc/docker/certs.d/${REGISTRY/\/*/}"
            if [ -d "$certdir" ]; then
                vmounts+=(
                    "-v" "/etc/docker/certs.d:/etc/docker/certs.d:ro"
                )
                options+=(
                    "--skopeo_src_cert_dir=$certdir"
                )
            fi
        fi
    fi
    options+=(
        "--trace_allow_benchmark_control"
        "--run_uri=$run_uri"
        "--temp_dir=/tmp/pkb"
        "--benchmarks=docker_pt"
        "--benchmark_config_file=/home/$(basename "$CUMULUS_CONFIG")"
        "--ignore_package_requirements"
    )
    insecure_registries="$(docker info -f '{{range .RegistryConfig.IndexConfigs}}{{if(not .Secure)}}{{.Name}},{{end}}{{end}}' 2> /dev/null)"
    if [ -n "$insecure_registries" ]; then
        options+=(
            "--skopeo_insecure_registries=${insecure_registries%,}"
        )
    fi
    runoptions=(
        "--name" "$NAMESPACE"
    )
    touch "$LOGSDIRH/.gitconfig"
    mkdir -p "$LOGSDIRH/.docker"
    find "$SCRIPT/cumulus" -name ".??*" -type d -exec bash -c "mkdir -p '$LOGSDIRH'/\$(basename '{}')" \;
    ( # must be in subshell
        [ -e "$SCRIPT/cumulus/auto-provisioning.sh" ] && . "$SCRIPT/cumulus/auto-provisioning.sh"
        [[ "$CUMULUS_OPTIONS" = *"--dry-run"* ]] && exit 0
        image="$(awk -v h=static '/^\s+cloud:/{h=$NF}END{print tolower(h)}' "$CUMULUS_CONFIG")"
        $SCRIPT/cumulus/shell.sh $image "${vmounts[@]}" "${runoptions[@]}" -- python3 /PerfKitBenchmarker/pkb.py ${CUMULUS_OPTIONS/--docker-run/} "${options[@]}" $CTESTSH_OPTIONS
    )
}

_reconfigure_reuse_sut () {
    sutdir="$(echo $LOGSDIRH | sed 's|/[^/]*\(logs-[^/]*\)$|/sut-\1|')"
    if [[ "$CTESTSH_OPTIONS" = *"--reuse-sut"* ]]; then
        export CTESTSH_OPTIONS="${CTESTSH_OPTIONS/--reuse-sut/} --install_packages=false --dpt_reuse_sut"
        grep -v dpt_tunables: "$CUMULUS_CONFIG" | grep -v dpt_namespace: | grep -v dpt_docker_options: | grep -v dpt_script_args > "$CUMULUS_CONFIG".1
        grep -v dpt_tunables: "$sutdir/cumulus-config.yaml" | grep -v dpt_namespace: | grep -v dpt_docker_options: | grep -v dpt_script_args > "$CUMULUS_CONFIG".2
        if [ -n "$(diff "$CUMULUS_CONFIG".1 "$CUMULUS_CONFIG".2)" ]; then
            echo "$CUMULUS_CONFIG does not match $sutdur/cumulus-config.yaml"
            exit 3
        fi
        rm -f "$CUMULUS_CONFIG".1 "$CUMULUS_CONFIG".2
        (   cat "$sutdir"/runs/*/pkb.log
            echo "===cumulus-config.yaml==="
            cat "$CUMULUS_CONFIG"
        ) | awk -v keyfile="/home/sut/$(cd "$sutdir" && ls -1 runs/*/*_keyfile)" -f "$SCRIPT/cumulus/reuse-sut.awk" > "$CUMULUS_CONFIG".mod.yaml
        export CUMULUS_CONFIG="$CUMULUS_CONFIG.mod.yaml"
        vmounts+=(
            "-v" "$(readlink -e "$sutdir"):/home/sut:ro"
        )
        mkdir -p "$LOGSDIRH/sut"
    elif [[ "$CTESTSH_OPTIONS" = *"--cleanup-sut"* ]]; then
        export CTESTSH_OPTIONS="${CTESTSH_OPTIONS/--cleanup-sut/} --run_stage=teardown"
        export LOGSDIRH="$sutdir"
        cd "$LOGSDIRH"
        export CUMULUS_CONFIG="$LOGSDIRH/cumulus-config.yaml"
    fi
}

# args: image [options]
cumulus_docker_run () {
    image=$1; shift

    "$SCRIPT/cumulus/provision.sh" "$CLUSTER_CONFIG" "$CUMULUS_CONFIG" docker

    s2="s|dpt_docker_options:.*|dpt_docker_options: \"${@}\"|"
    s3="s|dpt_docker_image:.*|dpt_docker_image: \"$image\"|"
    _reconfigure_cumulus "$s2" "$s3"

    vmounts=()
    _reconfigure_reuse_sut
    _invoke_cumulus
}

# args: job-filter
cumulus_kubernetes_run () {
    "$SCRIPT/cumulus/provision.sh" "$CLUSTER_CONFIG" "$CUMULUS_CONFIG" kubernetes

    s2="s|dpt_kubernetes_job:.*|dpt_kubernetes_job: \"$1\"|"
    s3="s|dpt_kubernetes_yaml:.*|dpt_kubernetes_yaml: \"${KUBERNETES_CONFIG/${LOGSDIRH//\//\\\/}/\/home}\"|"
    _reconfigure_cumulus "$s2" "$s3"

    vmounts=()
    _reconfigure_reuse_sut
    _invoke_cumulus
}

rebuild_config "$CLUSTER_CONFIG_M4" > "$CLUSTER_CONFIG"
if [ -n "$DOCKER_IMAGE" ] && [[ $CUMULUS_OPTIONS = *"--docker-run"* ]]; then
    IMAGE=$(image_name "$DOCKER_IMAGE")
    DATASET=($(dataset_images))
    cumulus_docker_run $IMAGE $DOCKER_OPTIONS
else
    rebuild_kubernetes_config > "$KUBERNETES_CONFIG"
    cumulus_kubernetes_run $JOB_FILTER
fi

