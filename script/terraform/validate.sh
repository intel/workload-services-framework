#!/bin/bash -e

WORKLOAD_NAME=${WORKLOAD_NAME:-$WORKLOAD}
TERRAFORM_CONFIG="${TERRAFORM_CONFIG:-$LOGSDIRH/terraform-config.tf}"
LOGSTARFILE="${LOGSTARFILE:-$LOGSDIRH/output.tar}"
if [[ "$TERRAFORM_OPTIONS" = *--owner=* ]]; then
    export OWNER="$(echo "$TERRAFORM_OPTIONS" | tr ' ' '\n' | grep -E '^--owner=' | cut -f2 -d= | tr -c -d 'a-z0-9-')"
else
    export OWNER="$( (git config user.name || id -un) 2> /dev/null | tr -c -d 'a-z0-9-')"
    TERRAFORM_OPTIONS="$TERRAFORM_OPTIONS --owner=$OWNER"
fi
if [ "$OWNER" = "root" ] || [ -z "$OWNER" ]; then
    echo "Please run as a user or specify --owner=<user> in TERRAFORM_OPTIONS"
    exit 3
fi

# add tags
if [ -n "$WORKLOAD_TAGS" ]; then
    WORKLOAD_TAGS="${WORKLOAD_TAGS// /,}"
    if [[ "$TERRAFORM_OPTIONS" = *"--tags="* ]]; then
        TERRAFORM_OPTIONS="${TERRAFORM_OPTIONS/--tags=/--tags=$WORKLOAD_TAGS,}"
    else
        TERRAFORM_OPTIONS="$TERRAFORM_OPTIONS --tags=$WORKLOAD_TAGS"
    fi
fi

#add category
if [[ "$TERRAFORM_OPTIONS" = *"--intel_publish"* ]]; then
    wl_readme="$DIR/README.md"
    wl_category=$(sed -n '/^.*Category:\s*[`].*[`]\s*$/{s/.*[`]\(.*\)[`]\s*$/\1/;p}' "$wl_readme")
    export WL_CATEGORY="$wl_category"
fi

# args: s2 s3
_reconfigure_terraform () {
    export WL_NAME="$WORKLOAD_NAME"
    export WL_TIMEOUT="$TIMEOUT"
    export WL_JOB_FILTER="$JOB_FILTER"
    export WL_REGISTRY_MAP="$REGISTRY,$REGISTRY"
    export WL_NAMESPACE="$NAMESPACE"
    export WL_TRACE_MODE="$EVENT_TRACE_PARAMS"
}

_reconfigure_reuse_sut () {
    sutdir="$(echo $LOGSDIRH | sed 's|/[^/]*\(logs-[^/]*\)$|/sut-\1|')"
    case "$CTESTSH_OPTIONS" in
    *"--prepare-sut"*)
        export CTESTSH_OPTIONS="${CTESTSH_OPTIONS/--prepare-sut/} --stage=provision"
        ;;
    *"--reuse-sut"*)
        export CTESTSH_OPTIONS="${CTESTSH_OPTIONS/--reuse-sut/} --stage=validation"
        cp -f "$sutdir"/ssh_access.key "$LOGSDIRH"
        chmod 400 "$LOGSDIRH"/ssh_access.key
        cp -f "$sutdir"/ssh_access.key.pub "$LOGSDIRH"
        cp -f "$sutdir"/inventory.yaml "$LOGSDIRH"
        cp -f "$sutdir"/tfplan.json "$LOGSDIRH"
        cp -f "$sutdir"/ssh_config "$LOGSDIRH" 2>/dev/null || true
        cp -rf "$sutdir"/*-svrinfo "$LOGSDIRH" 2>/dev/null || true
        ;;
    *"--cleanup-sut"*)
        export CTESTSH_OPTIONS="${CTESTSH_OPTIONS/--cleanup-sut/} --stage=cleanup"
        export LOGSDIRH="$sutdir"
        cd "$LOGSDIRH"
        export TERRAFORM_CONFIG="$LOGSDIRH/terraform-config.tf"
        ;;
    esac
}

# args: <none>
_invoke_terraform () {
    st_options=(
        "--my_ip_list=$(hostname -I | tr ' ' ',')"
    )
    dk_options=(
        "--name" "$NAMESPACE"
        "-v" "$DIR:/opt/workload:ro"
        "-v" "$LOGSDIRH:/opt/workspace"
        "-v" "$SCRIPT/terraform/template:/opt/template:ro"
        "-v" "$SCRIPT/terraform/script:/opt/script:ro"
        "-e" STACK_TEMPLATE_PATH
    )
    if [ -d "$SCRIPT/../stack" ]; then
        dk_options+=(
            "-v" "$SCRIPT/../stack:/opt/stack"
        )
    fi
    if [ -r "$HOME/.netrc" ]; then
        dk_options+=(
            "-v" "$HOME/.netrc:/home/.netrc:ro"
            "-v" "$HOME/.netrc:/root/.netrc:ro"
        )
        touch "$LOGSDIRH/.netrc"
    fi
    if ! grep -q -F '/template/terraform/' "$TERRAFORM_CONFIG"; then
        if [ -d "$HOME/.ssh" ]; then
            dk_options+=(
                "-v" "$(readlink -e "$HOME/.ssh"):/home/.ssh"
                "-v" "$(readlink -e "$HOME/.ssh"):/root/.ssh"
            )
            mkdir -p "$LOGSDIRH/.ssh"
        fi
    else
        dk_options+=(
            "-v" "$SCRIPT/csp/ssh_config:/home/.ssh/config:ro"
            "-v" "$SCRIPT/csp/ssh_config:/root/.ssh/config:ro"
        )
        if [ -n "$REGISTRY" ]; then
            certdir="/etc/docker/certs.d/${REGISTRY/\/*/}"
            if [ -d "$certdir" ]; then
                dk_options+=(
                    "-v" "/etc/docker/certs.d:/etc/docker/certs.d:ro"
                )
                st_options+=(
                    "--skopeo_options=--src-cert-dir=$certdir"
                )
            fi
        fi
    fi
    insecure_registries="$(docker info -f '{{range .RegistryConfig.IndexConfigs}}{{if(not .Secure)}}{{.Name}},{{end}}{{end}}' 2> /dev/null)"
    if [ -n "$insecure_registries" ]; then
        st_options+=(
            "--skopeo_insecure_registries=${insecure_registries%,}"
        )
    fi
    if [ "$REGISTRY_AUTH" = "docker" ] && [ -n "$(grep auths "$HOME/.docker/config.json" 2> /dev/null)" ]; then
        st_options+=(
            "--docker_auth_reuse=true"
        )
    fi
    (
        echo "TERRAFORM_OPTIONS: ${TERRAFORM_OPTIONS} ${st_options[@]} ${CTESTSH_OPTIONS}"
        [[ "$TERRAFORM_OPTIONS$CTESTSH_OPTIONS" = *"--dry-run"* ]] && exit 0
        csp="$(grep -E '^\s*csp\s*=' "$TERRAFORM_CONFIG" | cut -f2 -d'"' | tail -n1)"
        . $SCRIPT/csp/opt/script/save-region.sh $csp \
            "$(sed -n '/^\s*variable\s*"zone"\s*{/,/^\s*}/{/^\s*default\s*=\s*/p}' "$TERRAFORM_CONFIG" | cut -f2 -d'"')" \
            "$(sed -n '/^\s*variable\s*"resource_group_id"\s*{/,/^\s*}/{/^\s*default\s*=\s*/p}' "$TERRAFORM_CONFIG" | cut -f2 -d'"')" \
            "$(sed -n '/^\s*variable\s*"zone"\s*{/,/^\s*}/{/^\s*default\s*=\s*/p}' "$TERRAFORM_CONFIG_IN" | cut -f2 -d'"')" \
            "$(sed -n '/^\s*variable\s*"resource_group_id"\s*{/,/^\s*}/{/^\s*default\s*=\s*/p}' "$TERRAFORM_CONFIG_IN" | cut -f2 -d'"')"
        set -o pipefail
        $SCRIPT/terraform/shell.sh ${csp:-static} "${dk_options[@]}" -- /opt/script/start.sh ${TERRAFORM_OPTIONS} "${st_options[@]}" ${CTESTSH_OPTIONS} 2>&1 | tee "$LOGSDIRH/tfplan.logs"
    )
}

# args: image [options]
terraform_docker_run () {
    export WL_DOCKER_IMAGE=$1; shift
    export WL_DOCKER_OPTIONS="$@"
    _reconfigure_terraform
    "$SCRIPT/terraform/provision.sh" "$CLUSTER_CONFIG" "$TERRAFORM_CONFIG" 0
    _reconfigure_reuse_sut
    _invoke_terraform
}

# args: job-filter
terraform_kubernetes_run () {
    _reconfigure_terraform
    "$SCRIPT/terraform/provision.sh" "$CLUSTER_CONFIG" "$TERRAFORM_CONFIG" 1
    _reconfigure_reuse_sut
    _invoke_terraform
}

# args: job-filter
terraform_run () {
    _reconfigure_terraform
    "$SCRIPT/terraform/provision.sh" "$CLUSTER_CONFIG" "$TERRAFORM_CONFIG" 0
    _reconfigure_reuse_sut
    _invoke_terraform
}

if [ -n "$DOCKER_IMAGE" ] && [[ "$TERRAFORM_OPTIONS " = *"--docker "* ]]; then
    IMAGE=$(image_name "$DOCKER_IMAGE")
    DATASET=($(dataset_images))
    terraform_docker_run $IMAGE $DOCKER_OPTIONS
elif [ -r "$KUBERNETES_CONFIG_M4" ] || [ -d "$HELM_CONFIG" ]; then
    rebuild_kubernetes_config > "$KUBERNETES_CONFIG"
    terraform_kubernetes_run
else
    terraform_run
fi
