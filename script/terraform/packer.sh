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

# check signature to avoid rebuilding multiple times
this="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
signature="$(find "$this" -type f -exec md5sum "{}" \; | sort | md5sum)"
export NAMESPACE=${NAMESPACE:-$( (git config user.name || id -un) 2> /dev/null | tr 'A-Z' 'a-z' | tr -c -d 'a-z0-9-' | sed 's|^\(.\{12\}\).*$|\1|')-$(cut -f5 -d- /proc/sys/kernel/random/uuid)}

for sut in $TERRAFORM_SUT; do
    TERRAFORM_CONFIG="$PROJECTROOT/script/terraform/terraform-config.$sut.tf"
    csp="$(grep -E '^\s*csp\s*=' "$TERRAFORM_CONFIG" | cut -f2 -d'"' | tail -n1)"
    csp="${csp:-static}"
    if [ "$signature" != "$(cat .code-signature.$csp.$PLATFORM.$IMAGE 2>/dev/null)" ]; then
        LOGSDIRH="$(pwd)/logs-$sut-build-${IMAGE:-$WORKLOAD}"

        rm -rf "$LOGSDIRH"
        mkdir -p "$LOGSDIRH"

        TERRAFORM_CONFIG_IN="$TERRAFORM_CONFIG" "$PROJECTROOT"/script/terraform/provision.sh <(cat <<EOF
cluster:
- labels: {}
EOF
) "$LOGSDIRH"/terraform-config.tf 0

        options=(
            "-v" "$this:/opt/workload:ro"
            "-v" "$LOGSDIRH:/opt/workspace:rw"
	          "-v" "$PROJECTROOT/stack:/opt/stack:ro"
            "-e" "TERRAFORM_OPTIONS"
            "-e" "NAMESPACE"
            "-e" "PLATFORM"
	          "-e" "STACK_TEMPLATE_PATH"
            "-e" "PACKER_GITHUB_API_TOKEN"
            "--name" "$NAMESPACE"
        )
        if [ "$csp" = "static" ] || [ "$csp" = "kvm" ]; then
            options+=(
                "-v" "$(readlink -e "$HOME/.ssh"):/home/.ssh"
                "-v" "$(readlink -e "$HOME/.ssh"):/root/.ssh"
            )
        else
            options+=(
                "-v" "$PROJECTROOT/script/csp/ssh_config:/home/.ssh/config:ro"
                "-v" "$PROJECTROOT/script/csp/ssh_config:/root/.ssh/config:ro"
            )
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
            set -o pipefail
            "$PROJECTROOT"/script/terraform/shell.sh $csp "${options[@]}" -- /opt/terraform/script/packer.sh $@ ${!project_vars} ${COMMON_PROJECT_VARS[@]} | tee "$LOGSDIRH/packer.logs" 2>&1
        )

        echo "$signature" > .code-signature.$csp.$PLATFORM.$IMAGE
    fi
done
