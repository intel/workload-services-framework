#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

if [ -z "$CTESTSH_OPTIONS" ]; then
    echo -e "\033[31m=====================================================\033[0m" 1>&2
    echo -e "\033[31mInvoking testcases via ctest directly is discouraged.\033[0m" 1>&2
    echo -e "\033[31mPlease use ./ctest.sh to invoke WSF testcases.       \033[0m" 1>&2
    echo -e "\033[31m=====================================================\033[0m" 1>&2
    exit 3
fi

# default settings
LOGSDIRH="${LOGSDIRH:-$(pwd)}"
KUBERNETES_CONFIG_M4="${KUBERNETES_CONFIG_M4:-$SOURCEROOT/kubernetes-config.yaml.m4}"
KUBERNETES_CONFIG_J2="${KUBERNETES_CONFIG_J2:-$SOURCEROOT/kubernetes-config.yaml.j2}"
KUBERNETES_CONFIG="${KUBERNETES_CONFIG:-$LOGSDIRH/kubernetes-config.yaml}"
HELM_CONFIG="${HELM_CONFIG:-$SOURCEROOT/helm}"
CLUSTER_CONFIG_M4="${CLUSTER_CONFIG_M4:-$SOURCEROOT/cluster-config.yaml.m4}"
CLUSTER_CONFIG_J2="${CLUSTER_CONFIG_J2:-$SOURCEROOT/cluster-config.yaml.j2}"
CLUSTER_CONFIG="${CLUSTER_CONFIG:-$LOGSDIRH/cluster-config.yaml}"
COMPOSE_CONFIG_M4="${COMPOSE_CONFIG_M4:-$SOURCEROOT/compose-config.yaml.m4}"
COMPOSE_CONFIG_J2="${COMPOSE_CONFIG_J2:-$SOURCEROOT/compose-config.yaml.j2}"
COMPOSE_CONFIG="${COMPOSE_CONFIG:-$LOGSDIRH/compose-config.yaml}"
DOCKER_CONFIG_M4="${DOCKER_CONFIG_M4:-$SOURCEROOT/docker-config.yaml.m4}"
DOCKER_CONFIG_J2="${DOCKER_CONFIG_J2:-$SOURCEROOT/docker-config.yaml.j2}"
DOCKER_CONFIG="${DOCKER_CONFIG:-$LOGSDIRH/docker-config.yaml}"
JOB_FILTER="${JOB_FILTER:-job-name=benchmark}"
EXPORT_LOGS="${EXPORT_LOGS:-/export-logs}"
RECONFIG_OPTIONS=" ${RECONFIG_OPTIONS:-$(for k in ${WORKLOAD_PARAMS[@]%%#*};do echo -n "-D$k=${!k} ";done)}"
DOCKER_OPTIONS="${DOCKER_OPTIONS:-${RECONFIG_OPTIONS// -D/ -e }}"
HELM_OPTIONS="${HELM_OPTIONS:-${RECONFIG_OPTIONS// -D/ --set }}"
J2_OPTIONS="${J2_OPTIONS:-${RECONFIG_OPTIONS// -D/ -e }}"
WORKLOAD_CONFIG="$LOGSDIRH/workload-config.yaml"
WORKLOAD_SECRET="$LOGSDIRH/.workload-secret.yaml"
TESTCASE_DESCRIPTION="${TESTCASE_DESCRIPTION//%20/ }"

detect_user () {
    eval "local options=\"\$${BACKEND^^}_OPTIONS \$${BACKEND^^}_CMAKE_OPTIONS $CTESTSH_OPTIONS\""
    if [[ "$options" = *--owner=* ]]; then
        echo "$(echo "x$options" | sed 's|.*--owner=\([^ ]*\).*|\1|' | tr 'A-Z' 'a-z' | tr -c -d 'a-z0-9-')"
    else
        echo "$(cd "$PROJECTROOT";(flock "$PROJECTROOT" git config user.name 2> /dev/null || id -un) | tr 'A-Z' 'a-z' | tr -c -d 'a-z0-9-')"
    fi
}

# OWNER and NAMESPACE
export OWNER="$(detect_user)"
if [ "$OWNER" = "root" ] || [ -z "$OWNER" ]; then
    echo "Please run as a regular user or specify --owner=<user> in ${BACKEND^^}_OPTIONS"
    exit 3
fi
NAMESPACE="${NAMESPACE:-$(echo $OWNER | sed 's|^\(.\{12\}\).*$|\1|')-$(flock /dev/urandom cat /dev/urandom | tr -dc '0-9a-z' | head -c 12)}"

# args: image or Dockerfile
image_name () {
    (
        cd "$SOURCEROOT"
        if [ -e "$1" ]; then
            echo "$REGISTRY$(head -n2 "$1" | grep '^# ' | tail -n1 | cut -d' ' -f2)$IMAGESUFFIX$RELEASE"
        elif [[ "$1" = "$REGISTRY"*"$IMAGESUFFIX$RELEASE" ]]; then
            echo "$1"
        else
            echo "$REGISTRY$1$IMAGESUFFIX$RELEASE"
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
            -DIMAGESUFFIX=$IMAGESUFFIX \
            -DIMAGEPULLPOLICY=Always \
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
            -e IMAGESUFFIX=$IMAGESUFFIX \
            -e IMAGEPULLPOLICY=Always \
            -e WORKLOAD=$WORKLOAD \
            -e BACKEND=$BACKEND \
            -e REGISTRY=$REGISTRY \
            -e RELEASE=$RELEASE \
            -e EXPORT_LOGS=$EXPORT_LOGS \
            $J2_OPTIONS > /dev/null 2>&1 || \
        ansible all -i "localhost," -c local -m template \
            -a "src=\"$1\" dest=\"$2\"" \
            -e NAMESPACE=$NAMESPACE \
            -e TESTCASE=$TESTCASE \
            -e PLATFORM=$PLATFORM \
            -e IMAGEARCH=$IMAGEARCH \
            -e IMAGESUFFIX=$IMAGESUFFIX \
            -e IMAGEPULLPOLICY=Always \
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
  eval "local bk_opts=\"\$${BACKEND^^}$([ "$BACKEND" != "docker" ] || echo _CMAKE)_OPTIONS\""
  [[ "$bk_opts $CTESTSH_OPTIONS " != *"--dry-run "* ]] && [[ "$bk_opts $CTESTSH_OPTIONS " != *"--skip-app-status-check "* ]] || return 0

  local status_ret=1
  for itr in "$LOGSDIRH"/itr-*; do
      status_ret=1
      local status_value=0
      for status_path in "$itr"/*/status; do
          if [ -e "$status_path" ]; then
              status_value="$(< "$status_path")"
              if [ "$status_value" -ne 0 ]; then
                  echo -e "\033[31m${itr/"$LOGSDIRH"\//} app status: $status_value\033[0m"
                  return 1
              fi
              status_ret=0
          fi
      done
      if [ $status_ret -ne 0 ]; then
          echo -e "\033[31mMissing ${itr/"$LOGSDIRH"\//} app status\033[0m"
          return 1
      fi
  done
  [ $status_ret -eq 0 ] || echo -e "\033[31mMissing app status\033[0m"
  return $status_ret
}

rebuild_docker_config () {
    if [ -r "${DOCKER_CONFIG_M4%.m4}" ]; then
        cp -f "${DOCKER_CONFIG_M4%.m4}" "$DOCKER_CONFIG"
        return 0
    elif [ -r "$DOCKER_CONFIG_M4" ]; then
        rebuild_config "$DOCKER_CONFIG_M4" "$DOCKER_CONFIG"
        return 0
    elif [ -r "$DOCKER_CONFIG_J2" ]; then
        rebuild_config_j2 "$DOCKER_CONFIG_J2" "$DOCKER_CONFIG"
        return 0
    elif [ -n "$DOCKER_IMAGE" ]; then
        cat > "$DOCKER_CONFIG" <<EOF
worker-0:
- image: "$(image_name "$DOCKER_IMAGE")"
  options: "$DOCKER_OPTIONS"
  export-logs: true
EOF
        return 0
    fi
    return 1
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
            --set IMAGESUFFIX=$IMAGESUFFIX \
            --set IMAGEPULLPOLICY=Always \
            --set WORKLOAD=$WORKLOAD \
            --set BACKEND=$BACKEND \
            --set REGISTRY=$REGISTRY \
            --set RELEASE=$RELEASE \
            --set EXPORT_LOGS=$EXPORT_LOGS \
            ${HELM_OPTIONS//,/\\,}"
        local chart_list=$(find "$HELM_CONFIG" -name "Chart.yaml")
        if helm version &>/dev/null; then
            local chart_path
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
    if [[ "$BUILDSH_OPTIONS" = *"--upgrade-ingredients="* ]]; then
        echo "_ingredients"
        return
    fi
    for k in "${WORKLOAD_PARAMS[@]%%#*}"; do
        if [[ " ${TESTCASE_OVERWRITE_CUSTOMIZED[@]} " = *" ${k#-} "* ]]; then
            echo "_customized"
            return
        fi
    done
    if [ ${#TESTCASE_OVERWRITE_WITHBKC[@]} -gt 0 ]; then
        echo "_withbkc"
    fi
}

save_attached_files () {
    if [[ "$BUILDSH_OPTIONS" = *"--upgrade-ingredients="* ]]; then
        local ingredient_file="${BUILDSH_OPTIONS/*--upgrade-ingredients=/}"
        cp -f "${ingredient_file/ */}" "$LOGSDIRH"/ingredient-config.yaml
    fi
    local file1
    echo "$CTESTSH_ATTACH_FILES" | tr ',' '\n' | while IFS= read file1; do
        [ ! -r "$file1" ] || cp -f "$file1" "$LOGSDIRH"
    done
}

save_workload_secrets () {
    for k in "${WORKLOAD_PARAMS[@]%%#*}"; do
        if [[ "$k" = "-"* ]]; then
            eval "local v=\"\${${k#-}}\""
            echo "${k#-}: \"${v//%20/ }\""
        fi
    done
}

save_workload_params () {
    echo "script_args: \"$SCRIPT_ARGS\""
    eval "local bk_opts=\"\$${BACKEND^^}$([ "$BACKEND" != "docker" ] || echo _CMAKE)_OPTIONS\""
    eval "local bk_sut=\"\$${BACKEND^^}_SUT\""
    echo "cmake_cmdline: \"cmake -DPLATFORM=$PLATFORM -DREGISTRY=$REGISTRY -DREGISTRY_AUTH=$REGISTRY_AUTH -DRELEASE=$RELEASE -DTIMEOUT=$TIMEOUT -DBENCHMARK='$BENCHMARK' -DBACKEND=$BACKEND -D${BACKEND^^}_OPTIONS='$bk_opts' -D${BACKEND^^}_SUT='$bk_sut' -DSPOT_INSTANCE=$SPOT_INSTANCE -DBUILDSH_OPTIONS='$BUILDSH_OPTIONS'\""
    echo "platform: \"$PLATFORM\""
    echo "registry: \"$REGISTRY\""
    echo "release: \"$RELEASE\""
    echo "buildsh_options: \"$BUILDSH_OPTIONS\""
    echo "image_arch: \"$IMAGEARCH\""
    echo "image_suffix: \"$IMAGESUFFIX\""
    echo "timeout: \"$TIMEOUT\""
    echo "benchmark: \"$BENCHMARK\""
    echo "backend: \"$BACKEND\""
    echo "${BACKEND,,}_options: \"$bk_opts\""
    echo "${BACKEND,,}_sut: \"$bk_sut\""
    echo "spot_instance: \"$SPOT_INSTANCE\""
    echo "name: \"$WORKLOAD\""
    echo "display_name: \"$(sed -n '/^ *### *Index *Info *$/,/^ *###/{/Name:/{s/.*://;s/^ *//;s/ *$//;p}}' "$SOURCEROOT"/README.md | tr -d '"`,' | tail -n1)\""
    echo "path: \"${SOURCEROOT#"$PROJECTROOT/"}\""
    echo "category: \"$(sed -n '/^ *### *Index *Info *$/,/^ *###/{/Category:/{s/.*://;s/^ *//;s/ *$//;p}}' "$SOURCEROOT"/README.md | tr -d '"`' | tail -n1)\""
    echo "export_logs: \"$EXPORT_LOGS\""

    eval "bk_registry=\"\$${BACKEND^^}_REGISTRY\""
    eval "bk_release=\"\$${BACKEND^^}_RELEASE\""
    echo "${BACKEND,,}_registry: \"$bk_registry\""
    echo "${BACKEND,,}_release: \"$bk_release\""

    [ "${CTESTSH_EVENT_TRACE_PARAMS-undefined}" = "undefined" ] ||  EVENT_TRACE_PARAMS="$CTESTSH_EVENT_TRACE_PARAMS"
    echo "trace_mode: \"${EVENT_TRACE_PARAMS//%20/ }\""
    echo "job_filter: \"$JOB_FILTER\""
    echo "ctestsh_cmdline: \"$CTESTSH_CMDLINE\""
    echo "ctestsh_options: \"$CTESTSH_OPTIONS\""

    echo "tunables:"
    for k in "${WORKLOAD_PARAMS[@]%%#*}"; do
        if [[ "$k" != "-"* ]]; then
            eval "local v=\"\${$k}\""
            echo "  $k: \"${v//%20/ }\""
        else
            echo "  ${k#-}: \"secret\""
        fi
    done
    echo "  testcase: \"$TESTCASE$(testcase_suffix)\""  # compatibility
    echo "testcase: \"$TESTCASE$(testcase_suffix)\""
    echo "description: \"$TESTCASE_DESCRIPTION\""

    if [ -n "$DOCKER_IMAGE" ]; then
        echo "docker_image: \"$(image_name "$DOCKER_IMAGE")\""
        echo "docker_options: \"${DOCKER_OPTIONS//\"/\\\"}\""
    fi

    if [[ "$CTESTSH_OPTIONS " != *"--nobomlist "* ]]; then
        echo "bom:"
        for line in $("$SOURCEROOT"/build.sh $BUILDSH_OPTIONS --bom | grep -E '^ARG ' | sed 's/^ARG //'); do
            echo "  ${line/=*/}: \"${line/*=/}\""
        done
    fi 

    if git --version > /dev/null 2>&1; then
        local commit_id="$(cd "$PROJECTROOT";GIT_SSH_COMMAND='ssh -o BatchMode=yes' GIT_ASKPASS=echo flock "$PROJECTROOT" git rev-parse HEAD 2> /dev/null || true)"
        if [ -n "$commit_id" ]; then
            echo "git_commit: \"$commit_id\""
        fi
        local branch_id=""
        local show_ref="$(cd "$PROJECTROOT";GIT_SSH_COMMAND='ssh -o BatchMode=yes' GIT_ASKPASS=echo flock "$PROJECTROOT" git show-ref 2> /dev/null | grep -F $commit_id 2> /dev/null || true)"
        if [[ "$RELEASE" = :v* ]]; then
            branch_id="$(echo "$show_ref" | grep -m1 -E "refs/tags/${RELEASE#:}\$" | cut -f2- -d/)"
            [ -n "$branch_id" ] || branch_id="$(echo "$show_ref" | grep -m1 -E "refs/remotes/.*/${RELEASE#:v}\$" | cut -f3- -d/)"
        fi
        [ -n "$branch_id" ] || branch_id="$(echo "$show_ref" | grep -m1 -E "refs/tags/" | cut -f2- -d/)"
        [ -n "$branch_id" ] || branch_id="$(echo "$show_ref" | grep -m1 -E "refs/remotes/" | cut -f3- -d/)"
        [ -z "$branch_id" ] || echo "git_branch: \"$branch_id\""
    fi

    if [ -r "$PROJECTROOT/.hybrid_release" ]; then
        cat "$PROJECTROOT/.hybrid_release"
    fi
}

save_kpish () {
    if [ -e "$SOURCEROOT/kpi.sh" ]; then
        sed "1aset -- $SCRIPT_ARGS" "$SOURCEROOT/kpi.sh" > "$LOGSDIRH/kpi.sh"
        chmod a+rx "$LOGSDIRH/kpi.sh"
    fi
}

save_git_history () {
    if [[ "$CTESTSH_OPTIONS " != *"--dry-run "* ]]; then
        if git --version > /dev/null 2>&1; then
            mkdir -p "$LOGSDIRH/git-history"
            (
                cd "$PROJECTROOT"
                GIT_SSH_COMMAND='ssh -o BatchMode=yes' GIT_ASKPASS=echo flock "$PROJECTROOT" git log HEAD -n 1 > "$LOGSDIRH/git-history/HEAD"
                GIT_SSH_COMMAND='ssh -o BatchMode=yes' GIT_ASKPASS=echo flock "$PROJECTROOT" git diff HEAD > "$LOGSDIRH/git-history/DIFF"
            ) 2> /dev/null || echo -e "\033[31mWARNING: Failed to save git history\033[0m"
        fi
    fi
}

print_workload_configurations () {
    echo ""
    echo "Description:"
    echo "$TESTCASE_DESCRIPTION"
    echo ""
    if [ -r "$CLUSTER_CONFIG" ]; then
      awk -f "$PROJECTROOT/script/show-hostsetup.awk" "$CLUSTER_CONFIG"
    fi
    echo "Workload Configuration:"
    for k in "${WORKLOAD_PARAMS[@]}"; do
        if [[ "$k" != "-"* ]]; then
            eval "v=\"\${${k%%#*}}\""
            echo "${k%%#*}=${v//%20/ }"
        else
            k1="${k%%#*}"
            echo "${k1#-}=secret"
        fi
        if [[ " $CTESTSH_OPTIONS " = *"--describe_workload_params "* ]] && [[ "$k" = *'#'* ]]; then
            k1="${k#-}"
            echo -e "${k1#*#}" | sed 's|^|  |'
        fi
    done
    echo "EVENT_TRACE_PARAMS=$EVENT_TRACE_PARAMS"
    if [[ " $CTESTSH_OPTIONS " = *"--describe_workload_params "* ]]; then
        cat <<EOF
  Specify the trace options as multiple roi,<start>,<stop> triples,
  or empty not to set ROI(s)
EOF
    fi
    echo ""
    echo "Workload Logs: $LOGSDIRH"
}

if [ -r "$PROJECTROOT/script/${BACKEND}/validate.sh" ]; then
    save_attached_files
    save_kpish
    save_workload_params > "$WORKLOAD_CONFIG"
    save_workload_secrets > "$WORKLOAD_SECRET" && chmod 600 "$WORKLOAD_SECRET"
    save_git_history
    if [ -r "$CLUSTER_CONFIG_M4" ]; then
        rebuild_config "$CLUSTER_CONFIG_M4" "$CLUSTER_CONFIG"
    elif [ -r "$CLUSTER_CONFIG_J2" ]; then
        rebuild_config_j2 "$CLUSTER_CONFIG_J2" "$CLUSTER_CONFIG"
    fi
    . "$PROJECTROOT/script/${BACKEND}/validate.sh"
    test_pass_fail
else
    echo "$BACKEND not supported"
    exit 3
fi
