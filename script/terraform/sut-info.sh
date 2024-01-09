#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

TERRAFORM_CONFIG="${TERRAFORM_CONFIG:-$LOGSDIRH/terraform-config.tf}"

"$PROJECTROOT/script/terraform/provision.sh" "$CLUSTER_CONFIG" "$TERRAFORM_CONFIG" 1
csp="$(grep -E '^\s*csp\s*=' "$TERRAFORM_CONFIG" | cut -f2 -d'"' | tail -n1)"
csp="${csp:-static}"
echo "SUTINFO_CSP=$csp"
eval "SUTINFO_CSP=$csp"

if [ -x "$PROJECTROOT/script/csp/opt/script/sut-info-$csp.sh" ] && [[ "$@" != *"--csp-only"* ]] && [[ "$CTESTSH_OPTIONS " != *"--nosutinfo "* ]]; then
    zone="$(sed -n '/^\s*variable\s*"zone"\s*{/,/^\s*}\s*$/{/^\s*default\s*=/{s/.*=\s*"\(.*\)".*/\1/;p}}' "$TERRAFORM_CONFIG")"
    rid="$(sed -n '/^\s*variable\s*"\(resource_group_id\|compartment\)"\s*{/,/^\s*}/{/^\s*default\s*=\s*/p}' "$TERRAFORM_CONFIG" | cut -f2 -d'"')"
    profiles=(
        $(for profile1 in $(sed -n '/^\s*variable\s*".*_profile"\s*{/{s/.*"\(.*\)_profile".*/\1/;p}' "$TERRAFORM_CONFIG"); do
            if [ "$csp" = "static" ]; then
                public_ip="$(sed -n "/^\s*variable\s*\"${profile1}_profile\"\s*{/,/^\s*}\s*$/{/^\s*[\"]public_ip[\"]:\s*/{s/.*:\s*[\"]\([0-9.]*\)[\"].*/\\1/;p}}" "$TERRAFORM_CONFIG")"
                user_name="$(sed -n "/^\s*variable\s*\"${profile1}_profile\"\s*{/,/^\s*}\s*$/{/^\s*[\"]user_name[\"]:\s*/{s/.*:\s*[\"]\([^\"]*\)[\"].*/\\1/;p}}" "$TERRAFORM_CONFIG")"
                ssh_port="$(sed -n "/^\s*variable\s*\"${profile1}_profile\"\s*{/,/^\s*}\s*$/{/^\s*[\"]ssh_port[\"]:\s*/{s/.*:\s*\([0-9]*\).*/\\1/;p}}" "$TERRAFORM_CONFIG")"
                echo "${profile1^^}:$ssh_port:$user_name@$public_ip"
            else
                core_count="$(sed -n "/^\s*variable\s*\"${profile1}_profile\"\s*{/,/^\s*}\s*$/{/^\s*cpu_core_count\s*=\s*/{s/.*=\s*\([^ ]*\).*/\\1/;p}}" "$TERRAFORM_CONFIG")"
                if [ -z "$core_count" ] || [ "$core_count" = "null" ]; then
                    core_count=""
                else
                    core_count="-$core_count"
                fi
                memory_size="$(sed -n "/^\s*variable\s*\"${profile1}_profile\"\s*{/,/^\s*}\s*$/{/^\s*memory_size\s*=\s*/{s/.*=\s*\([^ ]*\).*/\\1/;p}}" "$TERRAFORM_CONFIG")"
                if [ -z "$memory_size" ] || [ "$memory_size" = "null" ]; then
                    memory_size=""
                else
                    memory_size="-$memory_size"
                fi
                instance_type="$(sed -n "/^\s*variable\s*\"${profile1}_profile\"\s{/,/^\s*}\s*$/{/^\s*instance_type\s*=\s*/{s/.*=\s*\"\(.*\)\".*/\\1/;p}}" "$TERRAFORM_CONFIG")"
                echo "${profile1^^}:$instance_type$core_count$memory_size"
            fi
          done)
    )
    vars=($("$PROJECTROOT/script/terraform/shell.sh" $csp -v "$PROJECTROOT/script/csp:/home" -v "$PROJECTROOT/script/csp:/root" -- /opt/project/script/csp/opt/script/sut-info-$csp.sh $zone $rid ${profiles[@]}))
    for var1 in "${vars[@]}"; do
        echo "SUTINFO_$var1"
        eval "SUTINFO_$var1"
    done
fi
