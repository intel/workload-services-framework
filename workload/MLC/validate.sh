#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

TEST=${1:-loaded_latency}
WORKLOAD=${WORKLOAD:-mlc}
DURATION=${DURATION:-}
ARGS=${ARGS:-}
HUGEPAGE_MEMORY_NUM=${HUGEPAGE_MEMORY_NUM:-2Mb*4Gi}
HUGEPAGE_KB8_CPU_UNITS=${HUGEPAGE_KB8_CPU_UNITS:-1}

# Logs Setting
DIR="$(cd "$(dirname "$0")" &>/dev/null && pwd)"
. "$DIR/../../script/overwrite.sh"

# For getting hugepage settings for Kuberentes and cumulus setup @example HUGEPAGE_MEMORY_NUM=2Mb*16Gi
read -r hugepage_size memory_requested_gi < <(awk -F '*' '{print $1, $2}' <<<"${HUGEPAGE_MEMORY_NUM}")                                   # 2Mb
read -r hugepage_size huge_page_unit_size < <(awk 'match($0, /([0-9]{1,})([Gi|Mb|Gb]{2})/, a) {print a[1], a[2]}' <<<"${hugepage_size}") # 2 MB
read -r memory_requested_gi_value < <(awk 'match($0, /([0-9]{1,})/, a) {print a[1]}' <<<"${memory_requested_gi}")                        # 10

if [[ "${huge_page_unit_size,,}" =~ ^(m|M) ]]; then
    page_multiplier=512
    kb_power_of=1
    huge_page_unit_size=Mb
else
    page_multiplier=1
    kb_power_of=2
    huge_page_unit_size=Gi
fi

HUGEPAGE_UNIT_SIZE=${huge_page_unit_size}
HUGEPAGE_NUMBER_OF_PAGES=$((memory_requested_gi_value * page_multiplier))
HUGEPAGE_SIZE_KB=$((hugepage_size * (1024 ** kb_power_of)))

HUGEPAGE_LIMIT="${memory_requested_gi_value}Gi"
HUGEPAGE_REQUEST="${memory_requested_gi_value}Gi"
HUGEPAGE_KB8_DIRECTIVE=$([[ "${huge_page_unit_size}" =~ ^(m|M) ]] && echo "hugepages-2Mi" || echo "hugepages-1Gi")

# Workload Setting
WORKLOAD_PARAMS=(DURATION ARGS)

# Huge page configuration on backend docker (bare metal), needs to be setup by the user, otherwise include params for all other backends
if [[ ! "$BACKEND" == "docker" ]]; then
    WORKLOAD_PARAMS+=($(for var in ${!HUGEPAGE@}; do echo "$var"; done | tr "\n" " "))
fi

# Docker Setting
DOCKER_IMAGE="$DIR/Dockerfile.1.mlc"
DOCKER_OPTIONS="--privileged -e TEST=$TEST -e WORKLOAD=$WORKLOAD -e DURATION=${DURATION} -e ARGS=${ARGS} -e HUGEPAGE_MEMORY_NUM=${HUGEPAGE_MEMORY_NUM}"

# Kubernetes Setting
HUGEPAGE_RECONFIG_OPTIONS=$(
    for var in ${!HUGEPAGE@}; do
        val=$(echo "${!var}" | tr -d "\n" | perl -p -e 's/([^\S])/sprintf("%%%02X", ord($1))/eg')
        echo "-D$var=${val}"
    done
)

RECONFIG_OPTIONS="-DTEST=$TEST -DWORKLOAD=${WORKLOAD} -DDOCKER_IMAGE=$DOCKER_IMAGE -DDURATION=$DURATION -DARGS=$ARGS ${HUGEPAGE_RECONFIG_OPTIONS}"

JOB_FILTER="job-name=benchmark"

. "$DIR/../../script/validate.sh"
