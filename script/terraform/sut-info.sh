#!/bin/bash -e

TERRAFORM_CONFIG="${TERRAFORM_CONFIG:-$LOGSDIRH/terraform-config.tf}"

"$PROJECTROOT/script/terraform/provision.sh" "$CLUSTER_CONFIG" "$TERRAFORM_CONFIG" 1

CSP="$(grep -E '^\s*csp\s*=' "$TERRAFORM_CONFIG" | cut -f2 -d'"' | tail -n1)"
echo "SUTINFO_CSP=$CSP"
if [ -x "$PROJECTROOT/script/csp/opt/script/sut-info-$CSP.sh" ]; then
    zone="$(sed -n '/^\s*variable\s*"zone"\s*{/,/^\s*}\s*$/{/^\s*default\s*=/{s/.*=\s*"\(.*\)".*/\1/;p}}' "$TERRAFORM_CONFIG")"
    rid="$(sed -n '/^\s*variable\s*"\(resource_group_id\|compartment\)"\s*{/,/^\s*}/{/^\s*default\s*=\s*/p}' "$TERRAFORM_CONFIG" | cut -f2 -d'"')"
    profiles=(
        $(for profile1 in $(sed -n '/^\s*variable\s*".*_profile"\s{/{s/.*"\(.*\)_profile".*/\1/;p}' "$TERRAFORM_CONFIG"); do
            core_count="$(sed -n "/^\s*variable\s*\"${profile1}_profile\"\s{/,/^\s*}\s*$/{/^\s*cpu_core_count\s*=\s*/{s/.*=\s*\([^ ]*\).*/\\1/;p}}" "$TERRAFORM_CONFIG")"
            if [ -z "$core_count" ] || [ "$core_count" = "null" ]; then
                core_count=""
            else
                core_count="-$core_count"
            fi
            memory_size="$(sed -n "/^\s*variable\s*\"${profile1}_profile\"\s{/,/^\s*}\s*$/{/^\s*memory_size\s*=\s*/{s/.*=\s*\([^ ]*\).*/\\1/;p}}" "$TERRAFORM_CONFIG")"
            if [ -z "$memory_size" ] || [ "$memory_size" = "null" ]; then
                memory_size=""
            else
                memory_size="-$memory_size"
            fi
            echo ${profile1^^}:$(sed -n "/^\s*variable\s*\"${profile1}_profile\"\s{/,/^\s*}\s*$/{/^\s*instance_type\s*=\s*/{s/.*=\s*\"\(.*\)\".*/\\1/;p}}" "$TERRAFORM_CONFIG")$core_count$memory_size
          done)
    )
    vars=($("$PROJECTROOT/script/terraform/shell.sh" $CSP -v "$PROJECTROOT/script/csp:/home" -v "$PROJECTROOT/script/csp:/root" -- /opt/script/sut-info-$CSP.sh $zone $rid ${profiles[@]}))
    for var1 in "${vars[@]}"; do
        echo "SUTINFO_$var1"
        eval "SUTINFO_$var1"
    done
fi
