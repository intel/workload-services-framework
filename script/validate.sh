#!/bin/bash -e

PLATFORM=${PLATFORM:-SPR}
IMAGEARCH=${IMAGEARCH:-linux/amd64}
WORKLOAD=${WORKLOAD:-default}
TIMEOUT=${TIMEOUT:-300}
RELEASE=${RELEASE:-:latest}
BACKEND=${BACKEND:-docker}
SCRIPT="${SCRIPT:-"$DIR/../../script"}"

# default settings
LOGSDIRH="${LOGSDIRH:-$(pwd)}"
KUBERNETES_CONFIG_M4="${KUBERNETES_CONFIG_M4:-$DIR/kubernetes-config.yaml.m4}"
KUBERNETES_CONFIG="${KUBERNETES_CONFIG:-$LOGSDIRH/kubernetes-config.yaml}"
HELM_CONFIG="${HELM_CONFIG:-$DIR/helm}"
CLUSTER_CONFIG_M4="${CLUSTER_CONFIG_M4:-$DIR/cluster-config.yaml.m4}"
CLUSTER_CONFIG="${CLUSTER_CONFIG:-$LOGSDIRH/cluster-config.yaml}"
JOB_FILTER="${JOB_FILTER:-job-name=benchmark}"
NAMESPACE=${NAMESPACE:-$( (git config user.name || id -un) 2> /dev/null | tr 'A-Z' 'a-z' | tr -c -d 'a-z0-9-' | sed 's|^\(.\{12\}\).*$|\1|')-$(cut -f5 -d- /proc/sys/kernel/random/uuid)}
HELM_OPTIONS="${HELM_OPTIONS:-${RECONFIG_OPTIONS//-D/--set }}"

# args: image or Dockerfile
image_name () {
    if [ "$IMAGEARCH" = "linux/amd64" ]; then
        arch=""
    else
        arch="-${IMAGEARCH/*\//}"
    fi
    if [ -e "$1" ]; then
        echo $REGISTRY$(head -n 2 "$1" | grep '^# ' | tail -n 1 | cut -d' ' -f2)$arch$RELEASE
    else
        echo $REGISTRY$1$arch$RELEASE
    fi
}

# args: yaml
rebuild_config () {
    (cd "$DIR" && \
    m4 -Itemplate -I"$SCRIPT/../template" \
      -DNAMESPACE=$NAMESPACE \
      -DTESTCASE=$TESTCASE \
      -DPLATFORM=$PLATFORM \
      -DIMAGEARCH=$IMAGEARCH \
      -DWORKLOAD=$WORKLOAD \
      -DBACKEND=$BACKEND \
      -DREGISTRY=$REGISTRY \
      -DRELEASE=$RELEASE \
      $RECONFIG_OPTIONS \
      "$@")
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

rebuild_kubernetes_config () {
    if [ -r "$KUBERNETES_CONFIG_M4" ]; then
        rebuild_config "$KUBERNETES_CONFIG_M4"
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
          $HELM_OPTIONS"

      local chart_list=$(find "$HELM_CONFIG" -name "Chart.yaml")

      if helm version &>/dev/null; then
        while read chart_path
        do
          local appdir="$(dirname $chart_path)"
          local appname="$(basename "$appdir")"
          helm template "$appname" "$appdir" $options
        done <<< "$chart_list"
      else
        while read chart_path
        do
          local appdir="$(dirname $chart_path)"
          local appname="$(basename "$appdir")"
          docker run --rm -v "$appdir":/apps:ro alpine/helm:3.7.1 template "$appname" /apps $options
        done <<< "$chart_list"
      fi
    else
        echo "Missing Kubernetes configuration"
        exit 3
    fi
}

dataset_images () {
    if [ ${#DOCKER_DATASET[@]} -gt 0 ]; then
        for ds in "${DOCKER_DATASET[@]}"; do
            image_name "$ds"
        done
    elif [ -n "$DOCKER_DATASET" ]; then
        image_name "$DOCKER_DATASET"
    fi
}

# convert arrays to strings
convert_workload_params () {
    if [ ${#WORKLOAD_PARAMS[@]} -gt 0 ]; then
        WORKLOAD_PARAMS="$(for kv in "${WORKLOAD_PARAMS[@]}"; do
            if [[ "$kv" != *:* ]]; then
                eval "kv=\"$kv:\${$kv}\""
            fi
            echo "$kv"
        done | tr '\n' ';')"
        WORKLOAD_PARAMS="${WORKLOAD_PARAMS%;}"
    fi
}

save_script_args () {
    echo "script_args: \"$SCRIPT_ARGS\"" >> "$LOGSDIRH/workload-config.yaml"
}

save_workload_params () {
    echo "tunables: \"$WORKLOAD_PARAMS;testcase:$TESTCASE$TESTCASE_CUSTOMIZED\"" >> "$LOGSDIRH/workload-config.yaml"
    echo "bom: \"$WORKLOAD_BOM\"" >> "$LOGSDIRH/workload-config.yaml"
}

save_kpish () {
    cp -f "$DIR/kpi.sh" "$LOGSDIRH"
    chmod a+rx "$LOGSDIRH/kpi.sh"
}

save_git_history () {
    if git show HEAD > /dev/null 2>&1; then
        mkdir -p "$LOGSDIRH/git-history"
        git show HEAD > "$LOGSDIRH/git-history/HEAD"
        git diff HEAD > "$LOGSDIRH/git-history/DIFF"
    fi
}

print_workload_configurations () {
    echo ""
    if [ -r "$CLUSTER_CONFIG" ]; then
      echo "Workload Labels:"
      grep HAS-SETUP- "$CLUSTER_CONFIG" | awk '{a[$0]=1}END{if(length(a)) for(x in a)print x;else print "N/A"}' | sed 's|^\s*||'
      echo ""
    fi
    echo "Workload Configuration:"
    echo "$WORKLOAD_PARAMS" | sed 's/;/\n/g' | sed 's/:/: /'
    echo ""
}
    
WORKLOAD_BOM="$("$DIR"/build.sh --bom | grep -E '^ARG' | sed 's/^ARG //' | tr '=\n' ':;' | sed 's/;$//')"
if [ -r "$SCRIPT/${BACKEND}/validate.sh" ]; then
    save_kpish
    save_script_args
    convert_workload_params
    save_workload_params
    save_git_history
    if [ -r "$CLUSTER_CONFIG_M4" ]; then
        rebuild_config "$CLUSTER_CONFIG_M4" > "$CLUSTER_CONFIG"
    fi
    print_workload_configurations
    . "$SCRIPT/${BACKEND}/validate.sh"
    test_pass_fail
else
    echo "$BACKEND not supported"
    exit 3
fi
