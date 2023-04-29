#!/bin/bash -e

# args: config
print_labels () {
    echo "Labels: $(awk '
/HAS-SETUP-/ {
    for(i=1;i<=NF;i++)
        if ($i ~ /HAS-SETUP-/)
            a[gensub(/[:"]/,"","g",$i)]=1
}
END {
    for(l in a)
        print(l)
}' "$1" | tr '\n' ' ')"
}

# args: job-filter
kubernetes_run () {
    if [ -r "$PROJECTROOT/script/kubernetes/preswa-hook.sh" ]; then
        . "$PROJECTROOT/script/kubernetes/preswa-hook.sh"
    fi

    export LOGSDIRH NAMESPACE

    [[ "$CTESTSH_OPTIONS" = *"--dry-run"* ]] && exit 0

    # create namespace
    kubectl create namespace $NAMESPACE

    # upload docker registry secret
    config_json="$HOME/.docker/config.json"
    if [ -n "$(grep auths "$config_json" 2> /dev/null)" ] && [ "$REGISTRY_AUTH" = "docker" ]; then
        secret_name="docker-registry-secret"
        kubectl create secret docker-registry $secret_name --from-file=.dockerconfigjson="$config_json" -n $NAMESPACE
        kubectl patch serviceaccount default -p "{\"imagePullSecrets\": [{\"name\": \"$secret_name\"}]}" -n $NAMESPACE
    fi
        
    stop_kubernetes () {
        kubectl get node -o json
        kubectl --namespace=$NAMESPACE describe pod 2> /dev/null || true
        kubectl delete -f "$KUBERNETES_CONFIG" --namespace=$NAMESPACE --ignore-not-found=true || true
        kubectl delete namespace $NAMESPACE --wait --timeout=0 --ignore-not-found=true || (kubectl replace --raw "/api/v1/namespaces/$NAMESPACE/finalize" -f <(kubectl get ns $NAMESPACE -o json | grep -v '"kubernetes"')) || true
	}

    # set trap for cleanup
    trap stop_kubernetes ERR SIGINT EXIT

    # start the jobs and wait until the namespace is stable
    kubectl create -f "$KUBERNETES_CONFIG" --namespace=$NAMESPACE

    wait_for_pods_ready () {
        until kubectl --namespace=$NAMESPACE wait pod --all --for=condition=Ready --timeout=1s 1>/dev/null 2>&1; do 
            if kubectl --namespace=$NAMESPACE get pod -o json | grep -q Unschedulable; then 
                return 3
            fi
        done 
        return 0
    }

    # wait until either resource is ready or unschedulable
    export -pf wait_for_pods_ready
    timeout ${TIMEOUT/*,/}s bash -c wait_for_pods_ready

    extract_logs () {
        container=$1; shift
        for pod1 in $@; do
            mkdir -p "$LOGSDIRH/$pod1"
            kubectl logs -f --namespace=$NAMESPACE $pod1 -c $container &
            kubectl exec --namespace=$NAMESPACE $pod1 -c $container -- sh -c "cat $EXPORT_LOGS > /tmp/$NAMESPACE-logs.tar"
            for r in 1 2 3 4 5; do
                kubectl exec --namespace=$NAMESPACE $pod1 -c $container -- cat /tmp/$NAMESPACE-logs.tar | tar -xf - -C "$LOGSDIRH/$pod1" && break
            done
            kubectl exec --namespace=$NAMESPACE $pod1 -c $container -- rm -f /tmp/$NAMESPACE-logs.tar
        done
    }

    # copy logs
    export -pf extract_logs
    export EXPORT_LOGS
    timeout ${TIMEOUT/,*/}s bash -c "extract_logs ${1/*=/} $(kubectl get pod --namespace=$NAMESPACE --selector="$1" -o=jsonpath="{.items[*].metadata.name}")"

    # cleanup
    trap - ERR SIGINT EXIT
    stop_kubernetes
}

if [ -z "$REGISTRY" ]; then
    major=($(kubectl version -o json | grep '"major"' | cut -f4 -d'"'))
    minor=($(kubectl version -o json | grep '"minor"' | cut -f4 -d'"'))
    if [ ${major[0]} -gt 1 ] || [ ${minor[0]} -ge 24 ]; then
        echo
        echo "With Kubernetes v${major[0]}.${minor[0]}, a docker registry is required for on-prem validation. Use cmake -DREGISTRY=<URL> .. to specify the registry URL."
        echo
        exit 3
    fi
fi

rebuild_config "$CLUSTER_CONFIG_M4" > "$CLUSTER_CONFIG"
rebuild_kubernetes_config > "$KUBERNETES_CONFIG"
# replace %20 to space 
sed -i '/^\s*-\s*name:/,/^\s*/{/value:/s/%20/ /g}' "$KUBERNETES_CONFIG"
print_labels "$KUBERNETES_CONFIG"
kubernetes_run $JOB_FILTER 2>&1 | tee "$LOGSDIRH/k8s.logs"

