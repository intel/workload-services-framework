#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

if [[ "$@" = *"--bom"* ]]; then
    . "$PROJECTROOT"/script/build.sh $@
    exit 0
fi

if [[ "$TERRAFORM_OPTIONS" = *--owner=* ]]; then
    owner="$(echo "$TERRAFORM_OPTIONS" | tr ' ' '\n' | grep -E '^--owner=' | tr 'A-Z' 'a-z' | cut -f2 -d=)"
else
    owner="$( (git config user.name || id -un) 2> /dev/null | tr 'A-Z' 'a-z' | tr -c -d 'a-z0-9-')"
    export TERRAFORM_OPTIONS="$TERRAFORM_OPTIONS --owner=$owner"
fi
if [ "$owner" = "root" ] || [ -z "$owner" ]; then
    echo "Please run as a regular user or specify --owner=<user> in TERRAFORM_OPTIONS"
    exit 3
fi

this="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
export NAMESPACE=${NAMESPACE:-$( (git config user.name || id -un) 2> /dev/null | tr 'A-Z' 'a-z' | tr -c -d 'a-z0-9-' | sed 's|^\(.\{12\}\).*$|\1|')-$(flock /dev/urandom cat /dev/urandom | tr -dc '0-9a-z' | head -c 12)}

if [ -z "$PACKER_GITHUB_API_TOKEN" ] && [ -r "$HOME/.netrc" ]; then
    export PACKER_GITHUB_API_TOKEN="$(sed -n '/^\s*machine\s*github.com/,/^\s*machine/{/^\s*password\s*/{s///;p;q}}' $HOME/.netrc)"
fi

for sut in $TERRAFORM_SUT; do
    TERRAFORM_CONFIG="$PROJECTROOT/script/terraform/terraform-config.$sut.tf"
    csp="$(grep -E '^\s*csp\s*=' "$TERRAFORM_CONFIG" | cut -f2 -d'"' | tail -n1)"
    csp="${csp:-static}"

    LOGSDIRH="$(pwd)/logs-$sut-build-${IMAGE:-$WORKLOAD}"

    rm -rf "$LOGSDIRH"
    mkdir -p "$LOGSDIRH"
    cp -f "$TERRAFORM_CONFIG" "$LOGSDIRH"/terraform-config.tf

    options=(
        "-v" "$this:/opt/workload:ro"
        "-v" "$LOGSDIRH:/opt/workspace:rw"
        "-e" "TERRAFORM_OPTIONS"
        "-e" "NAMESPACE"
        "-e" "PLATFORM"
        "-e" "PACKER_GITHUB_API_TOKEN"
        "--name" "$NAMESPACE"
    )
    if [ "$csp" = "static" ] || [ "$csp" = "kvm" ]; then
        options+=(
            "-v" "$(readlink -e "$HOME/.ssh"):/home/.ssh"
            "-v" "$(readlink -e "$HOME/.ssh"):/root/.ssh"
        )
        if [ -d /opt/dataset ]; then
            options+=(
                "-v" "/opt/dataset:/opt/dataset"
            )
        fi
    else
        cat "$PROJECTROOT"/script/csp/ssh_config > "$LOGSDIRH"/ssh_config_csp
        chmod 600 "$LOGSDIRH"/ssh_config_csp
    fi

    project_vars="${csp^^}_PROJECT_VARS[@]"
    (
        if [ "$csp" != "static" ] && [ "$csp" != "kvm" ]; then
            . "$PROJECTROOT"/script/csp/opt/script/save-region.sh $csp \
                "$(sed -n '/^\s*variable\s*"zone"\s*{/,/^\s*}/{/^\s*default\s*=\s*/p}' "$LOGSDIRH/terraform-config.tf" | cut -f2 -d'"')" \
                "$(sed -n '/^\s*variable\s*"\(resource_group_id\|compartment\)"\s*{/,/^\s*}/{/^\s*default\s*=\s*/p}' "$LOGSDIRH/terraform-config.tf" | cut -f2 -d'"')" \
                "$(sed -n '/^\s*variable\s*"zone"\s*{/,/^\s*}/{/^\s*default\s*=\s*/p}' "$TERRAFORM_CONFIG" | cut -f2 -d'"')" \
                "$(sed -n '/^\s*variable\s*"\(resource_group_id\|compartment\)"\s*{/,/^\s*}/{/^\s*default\s*=\s*/p}' "$TERRAFORM_CONFIG" | cut -f2 -d'"')"
        fi
        "$PROJECTROOT"/script/terraform/shell.sh $csp "${options[@]}" -- /opt/terraform/script/packer.sh $@ ${!project_vars} ${COMMON_PROJECT_VARS[@]} | tee "$LOGSDIRH/packer.logs" 2>&1
    )
done
