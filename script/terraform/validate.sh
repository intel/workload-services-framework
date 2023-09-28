#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

TERRAFORM_CONFIG="${TERRAFORM_CONFIG:-$LOGSDIRH/terraform-config.tf}"
LOGSTARFILE="${LOGSTARFILE:-$LOGSDIRH/output.tar}"

# add tags
if [ -n "$WORKLOAD_TAGS" ]; then
    WORKLOAD_TAGS="${WORKLOAD_TAGS// /,}"
    if [[ "$TERRAFORM_OPTIONS" = *"--tags="* ]]; then
        TERRAFORM_OPTIONS="${TERRAFORM_OPTIONS/--tags=/--tags=$WORKLOAD_TAGS,}"
    else
        TERRAFORM_OPTIONS="$TERRAFORM_OPTIONS --tags=$WORKLOAD_TAGS"
    fi
fi

# args: s2 s3
_reconfigure_terraform () {
    export WL_NAME="$WORKLOAD"
    export WL_REGISTRY_MAP="$REGISTRY,$REGISTRY"
    export WL_NAMESPACE="$NAMESPACE"
}

_reconfigure_reuse_sut () {
    sutdir="$(echo $LOGSDIRH | sed 's|/[^/]*\(logs-[^/]*\)$|/sut-\1|')"
    case "$CTESTSH_OPTIONS" in
    *"--prepare-sut"*)
        export CTESTSH_OPTIONS="${CTESTSH_OPTIONS/--prepare-sut/} --stage=provision"
        ;;
    *"--reuse-sut"*)
        export CTESTSH_OPTIONS="${CTESTSH_OPTIONS/--reuse-sut/} --stage=validation"
        cp -f "$sutdir"/ssh_access.key "$LOGSDIRH" 2> /dev/null || true
        chmod 400 "$LOGSDIRH"/ssh_access.key 2> /dev/null || true
        cp -f "$sutdir"/ssh_access.key.pub "$LOGSDIRH" 2> /dev/null || true
        cp -f "$sutdir"/inventory.yaml "$LOGSDIRH"
        cp -f "$sutdir"/tfplan.json "$LOGSDIRH"
        cp -f "$sutdir"/ssh_config* "$LOGSDIRH" 2> /dev/null || true
        cp -rf "$sutdir"/*-svrinfo "$LOGSDIRH" 2> /dev/null || true
        cp -rf "$sutdir"/*-msrinfo "$LOGSDIRH" 2> /dev/null || true
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
        "--my_ip_list=$(ip -4 addr show scope global | sed -n '/^[0-9]*:.*state UP/,/^[0-9]*:/{/^ *inet /{s|.*inet \([0-9.]*\).*|\1|;p}}' | tr '\n' ',')"
    )
    dk_options=(
        "--name" "$NAMESPACE"
        "-v" "$SOURCEROOT:/opt/workload:ro"
        "-v" "$LOGSDIRH:/opt/workspace"
        "-e" STACK_TEMPLATE_PATH
        "--add-host" "host.docker.internal:host-gateway"
    )
    if [ -r "$HOME/.netrc" ]; then
        dk_options+=(
            "-v" "$HOME/.netrc:/home/.netrc:ro"
            "-v" "$HOME/.netrc:/root/.netrc:ro"
        )
        touch "$LOGSDIRH/.netrc"
    fi
    csp="$(grep -E '^\s*csp\s*=' "$TERRAFORM_CONFIG" | cut -f2 -d'"' | tail -n1)"
    if [[ " static kvm " != *" ${csp:-static} "* ]] && [ ! -e "$LOGSDIRH/ssh_config" ]; then
        cp -f "$PROJECTROOT/script/csp/ssh_config" "$LOGSDIRH/ssh_config"
    fi
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
    insecure_registries="$(docker info -f '{{range .RegistryConfig.IndexConfigs}}{{if(not .Secure)}}{{.Name}},{{end}}{{end}}' 2> /dev/null || true)"
    if [ -n "$insecure_registries" ]; then
        st_options+=(
            "--skopeo_insecure_registries=${insecure_registries%,}"
        )
    fi
    if [ -n "$(grep auths "${HOME}/.docker/config.json" 2>&-)" ]; then
        if [ -z "${REGISTRY_AUTH}" ]; then
            REGISTRY_AUTH=$(cat "${HOME}/.docker/config.json" 2>&- | sed -n 's/\s*"credsStore"\s*:\s*"\(.*\)".*/\1/p' || true)
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
        [[ "$TERRAFORM_OPTIONS $CTESTSH_OPTIONS " = *"--dry-run "* ]] && [[ "$TERRAFORM_OPTIONS $CTESTSH_OPTIONS " != *"--check-docker-image "* ]] && [[ "$TERRAFORM_OPTIONS$CTESTSH_OPTIONS" != *"--push-docker-image="* ]] && exit 0
        "$PROJECTROOT"/script/terraform/shell.sh ${csp:-static} "${dk_options[@]}" -- /opt/terraform/script/start.sh ${TERRAFORM_OPTIONS} "${st_options[@]}" ${CTESTSH_OPTIONS} --owner=$OWNER
    )
}

if [[ "$TERRAFORM_OPTIONS $CTESTSH_OPTIONS " = *"--native "* ]] && [ -n "$DOCKER_IMAGE" ]; then
    nctrs=0
elif [[ "$TERRAFORM_OPTIONS $CTESTSH_OPTIONS " = *"--docker "* ]] && [ -n "$DOCKER_IMAGE" ]; then
    nctrs=0
elif [[ "$TERRAFORM_OPTIONS $CTESTSH_OPTIONS " = *"--compose "* ]] && rebuild_compose_config; then
    nctrs=0
elif rebuild_kubernetes_config; then
    nctrs=1
else
    nctrs=0
fi

_checkdeprecatedoptions () {
  if [[ "$TERRAFORM_OPTIONS$CTESTSH_OPTIONS" = *" --wl_enable_reboot"* ]]; then
      echo -e "\033[31mDeprecated:\033[0m --wl_enable_reboot. Use --sut_reboot instead."
      exit 3
  fi
  if [[ "$TERRAFORM_OPTIONS$CTESTSH_OPTIONS" = *" --bios_update"* ]]; then
      echo -e "\033[31mDeprecated:\033[0m --bios_update. Use --sut_update_bios instead."
      exit 3
  fi
}

_checkdeprecatedoptions
_reconfigure_terraform
"$PROJECTROOT/script/terraform/provision.sh" "$CLUSTER_CONFIG" "$TERRAFORM_CONFIG" $nctrs
_reconfigure_reuse_sut
_invoke_terraform
