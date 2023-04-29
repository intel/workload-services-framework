#!/bin/bash -e

WORKLOAD_NAME=${WORKLOAD_NAME:-$WORKLOAD}
TERRAFORM_CONFIG="${TERRAFORM_CONFIG:-$LOGSDIRH/terraform-config.tf}"
LOGSTARFILE="${LOGSTARFILE:-$LOGSDIRH/output.tar}"
if [[ "$TERRAFORM_OPTIONS $CTESTSH_OPTIONS" = *--owner=* ]]; then
    export OWNER="$(echo "$TERRAFORM_OPTIONS $CTESTSH_OPTIONS" | tr ' ' '\n' | grep -E '^--owner=' | cut -f2 -d= | tr -c -d 'a-z0-9-')"
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
    wl_readme="$SOURCEROOT/README.md"
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
    export WL_EXPORT_LOGS="$EXPORT_LOGS"
}

_reconfigure_reuse_sut_replace_workload_params () {
    sed -i "s|\"wl_docker_options\":\"[^\"]*\"|\"wl_docker_options\":\"$WL_DOCKER_OPTIONS\"|" "$1"
    sed -i "s|\"wl_timeout\":\"[^\"]*\"|\"wl_timeout\":\"$WL_TIMEOUT\"|" "$1"
    sed -i "s|\"wl_trace_mode\":\"[^\"]*\"|\"wl_trace_mode\":\"$WL_TRACE_MODE\"|" "$1"
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
        _reconfigure_reuse_sut_replace_workload_params "$LOGSDIRH"/tfplan.json
        cp -f "$sutdir"/ssh_config* "$LOGSDIRH" 2>/dev/null || true
        cp -rf "$sutdir"/*-svrinfo "$LOGSDIRH" 2>/dev/null || true
        cp -rf "$sutdir"/*-msrinfo "$LOGSDIRH" 2>/dev/null || true
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
        "-v" "$SOURCEROOT:/opt/workload:ro"
        "-v" "$LOGSDIRH:/opt/workspace"
        "-v" "$PROJECTROOT/script/terraform/template:/opt/template:ro"
        "-v" "$PROJECTROOT/script/terraform/script:/opt/script"
        "-e" STACK_TEMPLATE_PATH
        "--add-host" "host.docker.internal:host-gateway"
    )
    if [ -d "$PROJECTROOT/stack" ]; then
        dk_options+=(
            "-v" "$PROJECTROOT/stack:/opt/stack"
        )
    fi
    if [ -r "$HOME/.netrc" ]; then
        dk_options+=(
            "-v" "$HOME/.netrc:/home/.netrc:ro"
            "-v" "$HOME/.netrc:/root/.netrc:ro"
        )
        touch "$LOGSDIRH/.netrc"
    fi
    csp="$(grep -E '^\s*csp\s*=' "$TERRAFORM_CONFIG" | cut -f2 -d'"' | tail -n1)"
    if [ "${csp:-static}" = "static" ] || [ "${csp}" = "kvm" ]; then
        if [ -d "$HOME/.ssh" ]; then
            dk_options+=(
                "-v" "$(readlink -e "$HOME/.ssh"):/home/.ssh"
                "-v" "$(readlink -e "$HOME/.ssh"):/root/.ssh"
            )
            mkdir -p "$LOGSDIRH/.ssh"
        fi
    else
        dk_options+=(
            "-v" "$PROJECTROOT/script/csp/ssh_config:/home/.ssh/config:ro"
            "-v" "$PROJECTROOT/script/csp/ssh_config:/root/.ssh/config:ro"
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
    insecure_registries="$(docker info -f '{{range .RegistryConfig.IndexConfigs}}{{if(not .Secure)}}{{.Name}},{{end}}{{end}}' 2> /dev/null || true)"
    if [ -n "$insecure_registries" ]; then
        st_options+=(
            "--skopeo_insecure_registries=${insecure_registries%,}"
        )
    fi
    if [ -n "$(grep auths "${HOME}/.docker/config.json" 2>&-)" ]; then
        if [ -z "${REGISTRY_AUTH}" ]; then
            REGISTRY_AUTH=$(cat "${HOME}/.docker/config.json" 2>&- | sed -n 's/\s*"credsStore"\s*:\s*"\(.*\)"/\1/p' || true)
        fi
        if [ "${REGISTRY_AUTH}" = "docker" ]; then
            st_options+=(
                "--docker_auth_reuse=true"
            )
        elif [ "${REGISTRY_AUTH}" = "pass" ]; then
            st_options+=(
                "--docker_auth_reuse=true"
                "--docker_auth_method=${REGISTRY_AUTH}"
                "--docker_auth_pass_ver=$(pass version 2>&- | grep v[0-9]\.[0-9]\.[0-9]\ | sed 's/.*v\([0-9]\.[0-9]\.[0-9]\).*/\1/g' || echo 'undefined')"
                "--docker_auth_cred_ver=$(docker-credential-pass version 2>&- || echo 'undefined')"
            )
            if [ ! -n "${PASSWORD_STORE_DIR}" ]; then
                PASSWORD_STORE_DIR="${HOME}/.password-store"
            fi
            dk_options+=(
                "-v" "${HOME}/.gnupg:/home/.gnupg"
                "-v" "${HOME}/.gnupg:/root/.gnupg"
                "-v" "${PASSWORD_STORE_DIR}:/home/.password-store"
                "-v" "${PASSWORD_STORE_DIR}:/root/.password-store"
            )
        elif [ -n "${REGISTRY_AUTH}" ]; then
            echo "Warning, unsupported Docker credential store [${REGISTRY_AUTH}]."
        fi
    fi
    (
        echo "TERRAFORM_OPTIONS=${TERRAFORM_OPTIONS} ${st_options[@]} ${CTESTSH_OPTIONS}"
        . "$PROJECTROOT"/script/csp/opt/script/save-region.sh $csp \
            "$(sed -n '/^\s*variable\s*"zone"\s*{/,/^\s*}/{/^\s*default\s*=\s*/p}' "$TERRAFORM_CONFIG" | cut -f2 -d'"')" \
            "$(sed -n '/^\s*variable\s*"\(resource_group_id\|compartment\)"\s*{/,/^\s*}/{/^\s*default\s*=\s*/p}' "$TERRAFORM_CONFIG" | cut -f2 -d'"')" \
            "$(sed -n '/^\s*variable\s*"zone"\s*{/,/^\s*}/{/^\s*default\s*=\s*/p}' "${TERRAFORM_CONFIG_TF:-$TERRAFORM_CONFIG_IN}" | cut -f2 -d'"')" \
            "$(sed -n '/^\s*variable\s*"\(resource_group_id\|compartment\)"\s*{/,/^\s*}/{/^\s*default\s*=\s*/p}' "${TERRAFORM_CONFIG_TF:-$TERRAFORM_CONFIG_IN}" | cut -f2 -d'"')"
        [[ "$TERRAFORM_OPTIONS $CTESTSH_OPTIONS" = *"--dry-run"* ]] && exit 0
        set -o pipefail
        "$PROJECTROOT"/script/terraform/shell.sh ${csp:-static} "${dk_options[@]}" -- /opt/script/start.sh ${TERRAFORM_OPTIONS} "${st_options[@]}" ${CTESTSH_OPTIONS} 2>&1 | tee "$LOGSDIRH/tfplan.logs"
    )
}

# args: image [options]
terraform_docker_run () {
    export WL_DOCKER_IMAGE=$1; shift
    export WL_DOCKER_OPTIONS="$@"
    _reconfigure_terraform
    "$PROJECTROOT/script/terraform/provision.sh" "$CLUSTER_CONFIG" "$TERRAFORM_CONFIG" 0
    _reconfigure_reuse_sut
    _invoke_terraform
}

# args: job-filter
terraform_kubernetes_run () {
    _reconfigure_terraform
    "$PROJECTROOT/script/terraform/provision.sh" "$CLUSTER_CONFIG" "$TERRAFORM_CONFIG" 1
    _reconfigure_reuse_sut
    _invoke_terraform
}

# args: job-filter
terraform_run () {
    _reconfigure_terraform
    "$PROJECTROOT/script/terraform/provision.sh" "$CLUSTER_CONFIG" "$TERRAFORM_CONFIG" 0
    _reconfigure_reuse_sut
    _invoke_terraform
}

if [ -n "$DOCKER_IMAGE" ] && [[ "$TERRAFORM_OPTIONS " = *"--docker "* ]] && [ -n "$(grep wl_docker_image "${TERRAFORM_CONFIG_TF:-$TERRAFORM_CONFIG_IN}")" ]; then
    IMAGE=$(image_name "$DOCKER_IMAGE")
    DATASET=($(dataset_images))
    terraform_docker_run $IMAGE $DOCKER_OPTIONS
elif [ -r "$KUBERNETES_CONFIG_M4" ] || [ -d "$HELM_CONFIG" ]; then
    rebuild_kubernetes_config > "$KUBERNETES_CONFIG"
    terraform_kubernetes_run
else
    terraform_run
fi
