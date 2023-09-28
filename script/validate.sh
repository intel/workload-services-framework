#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# default settings
LOGSDIRH="${LOGSDIRH:-$(pwd)}"
KUBERNETES_CONFIG_M4="${KUBERNETES_CONFIG_M4:-$SOURCEROOT/kubernetes-config.yaml.m4}"
KUBERNETES_CONFIG_J2="${KUBERNETES_CONFIG_M4:-$SOURCEROOT/kubernetes-config.yaml.j2}"
KUBERNETES_CONFIG="${KUBERNETES_CONFIG:-$LOGSDIRH/kubernetes-config.yaml}"
HELM_CONFIG="${HELM_CONFIG:-$SOURCEROOT/helm}"
CLUSTER_CONFIG_M4="${CLUSTER_CONFIG_M4:-$SOURCEROOT/cluster-config.yaml.m4}"
CLUSTER_CONFIG_J2="${CLUSTER_CONFIG_J2:-$SOURCEROOT/cluster-config.yaml.j2}"
CLUSTER_CONFIG="${CLUSTER_CONFIG:-$LOGSDIRH/cluster-config.yaml}"
COMPOSE_CONFIG_M4="${COMPOSE_CONFIG_M4:-$SOURCEROOT/compose-config.yaml.m4}"
COMPOSE_CONFIG_J2="${COMPOSE_CONFIG_J2:-$SOURCEROOT/compose-config.yaml.j2}"
COMPOSE_CONFIG="${COMPOSE_CONFIG:-$LOGSDIRH/compose-config.yaml}"
JOB_FILTER="${JOB_FILTER:-job-name=benchmark}"
EXPORT_LOGS="${EXPORT_LOGS:-/export-logs}"
HELM_OPTIONS="${HELM_OPTIONS:-${RECONFIG_OPTIONS//-D/--set }}"
J2_OPTIONS="${J2_OPTIONS:-${RECONFIG_OPTIONS//-D/-e }}"
WORKLOAD_CONFIG="$LOGSDIRH/workload-config.yaml"

# OWNER and NAMESPACE
eval "options=\"\$${BACKEND^^}_OPTIONS \$${BACKEND^^}_CMAKE_OPTIONS $CTESTSH_OPTIONS\""
if [[ "$options" = *--owner=* ]]; then
    export OWNER="$(echo "x$options" | sed 's|.*--owner=\([^ ]*\).*|\1|' | tr 'A-Z' 'a-z' | tr -c -d 'a-z0-9-')"
else
    export OWNER="$( (git config user.name || id -un) 2> /dev/null | tr 'A-Z' 'a-z' | tr -c -d 'a-z0-9-')"
fi
if [ "$OWNER" = "root" ] || [ -z "$OWNER" ]; then
    echo "Please run as a regular user or specify --owner=<user> in ${BACKEND^^}_OPTIONS"
    exit 3
fi
NAMESPACE="${NAMESPACE:-$(echo $OWNER | sed 's|^\(.\{12\}\).*$|\1|')-$(cut -f5 -d- /proc/sys/kernel/random/uuid)}"

# args: image or Dockerfile
image_name () {
    if [ "$IMAGEARCH" = "linux/amd64" ]; then
        arch=""
    else
        arch="-${IMAGEARCH/*\//}"
    fi
    (
        cd "$SOURCEROOT"
        if [ -e "$1" ]; then
            echo "$REGISTRY$(head -n2 "$1" | grep '^# ' | tail -n1 | cut -d' ' -f2)$arch$RELEASE"
        else
            echo "$REGISTRY$1$arch$RELEASE"
        fi
    )
}

# args: yaml
rebuild_config () {
    (
        cd "$SOURCEROOT" && \
        m4 -Itemplate -I"$PROJECTROOT/template" \
            -DNAMESPACE=$NAMESPACE \
            -DTESTCASE=$TESTCASE \
            -DPLATFORM=$PLATFORM \
            -DIMAGEARCH=$IMAGEARCH \
            -DWORKLOAD=$WORKLOAD \
            -DBACKEND=$BACKEND \
            -DREGISTRY=$REGISTRY \
            -DRELEASE=$RELEASE \
            -DEXPORT_LOGS=$EXPORT_LOGS \
            $RECONFIG_OPTIONS \
            "$1" > "$2"
    )
}

# args: yaml
rebuild_config_j2 () {
    (
        cd "$SOURCEROOT" && \
        ansible all -i "localhost," -c local -m template \
            -a "src=\"$1\" dest=\"$2\"" \
            -e NAMESPACE=$NAMESPACE \
            -e TESTCASE=$TESTCASE \
            -e PLATFORM=$PLATFORM \
            -e IMAGEARCH=$IMAGEARCH \
            -e WORKLOAD=$WORKLOAD \
            -e BACKEND=$BACKEND \
            -e REGISTRY=$REGISTRY \
            -e RELEASE=$RELEASE \
            -e EXPORT_LOGS=$EXPORT_LOGS \
            $J2_OPTIONS
    )
}

# args: none
test_pass_fail () {
  local ret=0
  for status_path in "$LOGSDIRH"/*/*/status "$LOGSDIRH"/*/status "$LOGSDIRH"/status
  do
    [ ! -e $status_path ] && continue
    
    local value=$(< $status_path)
    if [ "$value" != "0" ]; then
      echo "Failure reported in: $status_path"
      ret=1
    fi
  done
  return $ret
}

rebuild_compose_config () {
    if [ -r "${COMPOSE_CONFIG_M4%.m4}" ]; then
        cp -f "${COMPOSE_CONFIG_M4%.m4}" "$COMPOSE_CONFIG"
        return 0
    elif [ -r "$COMPOSE_CONFIG_M4" ]; then
        rebuild_config "$COMPOSE_CONFIG_M4" "$COMPOSE_CONFIG"
        return 0
    elif [ -r "$COMPOSE_CONFIG_J2" ]; then
        rebuild_config_j2 "$COMPOSE_CONFIG_J2" "$COMPOSE_CONFIG"
        return 0
    fi
    return 1
}

rebuild_kubernetes_config () {
    if [ -r "${KUBERNETES_CONFIG_M4%.m4}" ]; then
        cp -f "${KUBERNETES_CONFIG_M4%.m4}" "$KUBERENTES_CONFIG"
        return 0
    elif [ -r "$KUBERNETES_CONFIG_M4" ]; then
        rebuild_config "$KUBERNETES_CONFIG_M4" "$KUBERNETES_CONFIG"
        return 0
    elif [ -r "$KUBERNETES_CONFIG_J2" ]; then
        rebuild_config_j2 "$KUBERNETES_CONFIG_J2" "$KUBERNETES_CONFIG"
        return 0
    elif [ -d "$HELM_CONFIG" ]; then
        local options="-n $NAMESPACE \
            --set NAMESPACE=$NAMESPACE \
            --set TESTCASE=$TESTCASE \
            --set PLATFORM=$PLATFORM \
            --set IMAGEARCH=$IMAGEARCH \
            --set WORKLOAD=$WORKLOAD \
            --set BACKEND=$BACKEND \
            --set REGISTRY=$REGISTRY \
            --set RELEASE=$RELEASE \
            --set EXPORT_LOGS=$EXPORT_LOGS \
            $HELM_OPTIONS"
        local chart_list=$(find "$HELM_CONFIG" -name "Chart.yaml")
        if helm version &>/dev/null; then
            while read chart_path; do
                local appdir="$(dirname $chart_path)"
                local appname="$(basename "$appdir")"
                helm template "$appname" "$appdir" $options
            done <<< "$chart_list" > "$KUBERNETES_CONFIG"
        else
            while read chart_path; do
                local appdir="$(dirname $chart_path)"
                local appname="$(basename "$appdir")"
                docker run --rm -v "$appdir":/apps:ro alpine/helm:3.7.1 template "$appname" /apps $options
            done <<< "$chart_list" > "$KUBERNETES_CONFIG"
        fi
        return 0
    fi
    return 1
}

testcase_suffix () {
    for k in "${WORKLOAD_PARAMS[@]}"; do
        if [[ " ${TESTCASE_OVERWRITE_CUSTOMIZED[@]} " = *" $k "* ]]; then
            echo "_customized"
            return
        fi
    done
    if [ ${#TESTCASE_OVERWRITE_WITHBKC[@]} -gt 0 ]; then
        echo "_withbkc"
    fi
}

save_workload_params () {
    echo "script_args: \"$SCRIPT_ARGS\""
    eval "bk_opts=\"\$${BACKEND^^}$([ "$BACKEND" != "docker" ] || echo _CMAKE)_OPTIONS\""
    eval "bk_sut=\"\$${BACKEND^^}_SUT\""
    echo "cmake_cmdline: \"cmake -DPLATFORM=$PLATFORM -DREGISTRY=$REGISTRY -DREGISTRY_AUTH=$REGISTRY_AUTH -DRELEASE=$RELEASE -DTIMEOUT=$TIMEOUT -DBENCHMARK='$BENCHMARK' -DBACKEND=$BACKEND -D${BACKEND^^}_OPTIONS='$bk_opts' -D${BACKEND^^}_SUT='$bk_sut' -DSPOT_INSTANCE=$SPOT_INSTANCE\""
    echo "platform: \"$PLATFORM\""
    echo "registry: \"$REGISTRY\""
    echo "release: \"$RELEASE\""
    echo "timeout: \"$TIMEOUT\""
    echo "benchmark: \"$BENCHMARK\""
    echo "backend: \"$BACKEND\""
    echo "${BACKEND,,}_options: \"$bk_opts\""
    echo "${BACKEND,,}_sut: \"$bk_sut\""
    echo "spot_instance: \"$SPOT_INSTANCE\""
    echo "name: \"$WORKLOAD\""
    echo "category: \"$(sed -n '/^.*Category:\s*[`].*[`]\s*$/{s/.*[`]\(.*\)[`]\s*$/\1/;p}' "$SOURCEROOT"/README.md | tail -n1)\""
    echo "export_logs: \"$EXPORT_LOGS\""

    eval "bk_registry=\"\$${BACKEND^^}_REGISTRY\""
    eval "bk_release=\"\$${BACKEND^^}_RELEASE\""
    echo "${BACKEND,,}_registry: \"$bk_registry\""
    echo "${BACKEND,,}_release: \"$bk_release\""

    [ "${CTESTSH_EVENT_TRACE_PARAMS-undefined}" = "undefined" ] ||  EVENT_TRACE_PARAMS="$CTESTSH_EVENT_TRACE_PARAMS"
    echo "trace_mode: \"${EVENT_TRACE_PARAMS//%20/ }\""
    echo "job_filter: \"$JOB_FILTER\""
    echo "timeout: \"$TIMEOUT\""
    echo "ctestsh_cmdline: \"${CTESTSH_CMDLINE//\"/\\\"}\""
    echo "ctestsh_options: \"$CTESTSH_OPTIONS\""

    echo "tunables:"
    for k in "${WORKLOAD_PARAMS[@]}"; do
        eval "v=\"\${$k}\""
        echo "  $k: \"${v//%20/ }\""
    done
    echo "  testcase: \"$TESTCASE$(testcase_suffix)\""

    if [ -n "$DOCKER_IMAGE" ]; then
        echo "docker_image: \"$(image_name "$DOCKER_IMAGE")\""
        echo "docker_options: \"${DOCKER_OPTIONS//\"/\\\"}\""
    fi

    echo "bom:"
    for line in $("$SOURCEROOT"/build.sh --bom | grep -E '^ARG ' | sed 's/^ARG //'); do
        echo "  ${line/=*/}: \"${line/*=/}\""
    done

    if git --version > /dev/null 2>&1; then
        commit_id="$(GIT_SSH_COMMAND='ssh -o BatchMode=yes' GIT_ASKPASS=echo git log -1 2> /dev/null | head -n1 | cut -f2 -d' ' || echo -n "")"
        if [ -n "$commit_id" ]; then
            echo "git_commit: \"$commit_id\""
        fi
        branch_id="refs/tags/${RELEASE#:}"
        if [ -z "$(GIT_SSH_COMMAND='ssh -o BatchMode=yes' GIT_ASKPASS=echo git show-ref -s $branch_id 2> /dev/null || echo -n "")" ]; then
            branch_id="$(GIT_SSH_COMMAND='ssh -o BatchMode=yes' GIT_ASKPASS=echo git show-ref 2> /dev/null | grep -F "$commit_id" | tail -n1 | cut -f2 -d' ' || echo -n "")"
        fi
        if [ -n "$branch_id" ]; then
            echo "git_branch: \"${branch_id#refs/}\""
        fi
    fi
}

save_kpish () {
    if [ -e "$SOURCEROOT/kpi.sh" ]; then
        cp -f "$SOURCEROOT/kpi.sh" "$LOGSDIRH"
        chmod a+rx "$LOGSDIRH/kpi.sh"
    fi
}

save_git_history () {
    if [[ "$CTESTSH_OPTIONS " != *"--dry-run "* ]]; then
        if git --version > /dev/null 2>&1; then
            mkdir -p "$LOGSDIRH/git-history"
            GIT_SSH_COMMAND='ssh -o BatchMode=yes' GIT_ASKPASS=echo git show HEAD | sed  '/^diff/{q}' > "$LOGSDIRH/git-history/HEAD" || true
            GIT_SSH_COMMAND='ssh -o BatchMode=yes' GIT_ASKPASS=echo git diff HEAD > "$LOGSDIRH/git-history/DIFF" || true
        fi
    fi
}

print_workload_configurations () {
    echo ""
    if [ -r "$CLUSTER_CONFIG" ]; then
      awk -f "$PROJECTROOT/script/show-hostsetup.awk" "$CLUSTER_CONFIG"
    fi
    echo "Workload Configuration:"
    for k in "${WORKLOAD_PARAMS[@]}"; do
        eval "v=\"\${$k}\""
        echo "$k=${v//%20/ }"
    done
    echo ""
    echo "EVENT_TRACE_PARAMS=$EVENT_TRACE_PARAMS"
}

if [ -z "$CTESTSH_OPTIONS" ]; then
    echo -e "\033[31m=====================================================\033[0m" 1>&2
    echo -e "\033[31mInvoking testcases via ctest directly is discouraged.\033[0m" 1>&2
    echo -e "\033[31mPlease use ./ctest.sh to invoke WSF testcases.       \033[0m" 1>&2
    echo -e "\033[31m=====================================================\033[0m" 1>&2
    exit 3
fi

if [ -r "$PROJECTROOT/script/${BACKEND}/validate.sh" ]; then
    save_kpish
    save_workload_params > "$WORKLOAD_CONFIG"
    save_git_history
    if [ -r "$CLUSTER_CONFIG_M4" ]; then
        rebuild_config "$CLUSTER_CONFIG_M4" "$CLUSTER_CONFIG"
    elif [ -r "$CLUSTER_CONFIG_J2" ]; then
        rebuild_config_j2 "$CLUSTER_CONFIG_J2" "$CLUSTER_CONFIG"
    fi
    print_workload_configurations
    . "$PROJECTROOT/script/${BACKEND}/validate.sh"
    test_pass_fail
else
    echo "$BACKEND not supported"
    exit 3
fi
