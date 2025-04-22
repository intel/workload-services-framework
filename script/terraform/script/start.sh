#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

copy_template () {
    mkdir -p "$2" || true
    cp -rL $3 "$1"/* "$2"/
}

terraform_log_level () {
    if   [[ "$@ " = *"--dev_log_level=ERROR "* ]]; then
      echo "ERROR"
    elif [[ "$@ " = *"--dev_log_level=WARN "*  ]]; then
      echo "WARN"
    elif [[ "$@ " = *"--dev_log_level=INFO "*  ]]; then
      echo "INFO"
    elif [[ "$@ " = *"--dev_log_level=DEBUG "* ]]; then
      echo "DEBUG"
    elif [[ "$@ " = *"--dev_log_level=TRACE "* ]]; then
      echo "TRACE"
    else
      echo "ERROR"
    fi
}

ansible_log_level () {
    if   [[ "$@ " = *"--dev_log_level=ERROR "* ]]; then
      echo ""
    elif [[ "$@ " = *"--dev_log_level=WARN "*  ]]; then
      echo "-v"
    elif [[ "$@ " = *"--dev_log_level=INFO "*  ]]; then
      echo "-vv"
    elif [[ "$@ " = *"--dev_log_level=DEBUG "* ]]; then
      echo "-vvv"
    elif [[ "$@ " = *"--dev_log_level=TRACE "* ]]; then
      echo "-vvvv"
    else
      echo "-vv"
    fi
}

destroy () {
    set +e
    trap - ERR EXIT
    trap " " SIGTERM
    kill -- -$BASHPID ${pids[@]} 2> /dev/null
    wait -f

    cd /opt/workspace

    if [[ "$stages" = *"--stage=cleanup"* ]]; then
        if [ -r cleanup.yaml ] && [ -r inventory.yaml ]; then
            echo "Restore SUT settings..." | tee -a cleanup.logs tfplan.logs
            run_playbook -vv cleanup.yaml >> cleanup.logs 2>&1 || true
        fi

        if [ -r tfplan ]; then
            echo "Destroy SUT resources..." | tee -a cleanup.logs tfplan.logs
            TF_LOG=ERROR terraform destroy -refresh -auto-approve -input=false -no-color -parallelism=$(nproc) -lock-timeout=300s >> cleanup.logs 2>&1 ||
            TF_LOG=ERROR terraform destroy -refresh -auto-approve -input=false -no-color -parallelism=$(nproc) -lock=false >> cleanup.logs 2>&1
        fi

        rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup tfplan .ssh .netrc
    fi 
      
    if [[ "$stages" = *"--stage=validation"* ]] && [ -e export.yaml ]; then
        echo "Export TRACE data..." | tee -a telemetry.logs tfplan.logs
        run_playbook -vv export.yaml $@ >> telemetry.logs 2>&1 &
        wait -f
    fi

    if [[ "$stages" = *"--stage=validation"* ]] || [[ "$stages" = *"--stage=provision"* ]]; then
        for publisher in "$DIR"/publish-*.py; do
            publisher="${publisher#*publish-}"
            publisher="${publisher%.py}"
            # create KPI and publish KPI
            if [[ "$stages" = *"--${publisher}_publish"* ]]; then
                echo "Publish to datalake..." | tee -a publish.logs tfplan.logs
                sed -e 's/_password":"[^"]*/_password":"string/g' -e 's/_password\\": *\\"[^"]*/_password\\":\\"XYZXYZ\\/g' .tfplan.json > tfplan.json 2> /dev/null
                "$DIR"/publish-$publisher.py $stages < tfplan.json 2>&1 | tee -a publish.logs || true
            fi
        done
    fi

    exit ${1:-3}
}

locate_trace_modules () {
    trace_modules=()
    trace_modules_options=()
    for tp in /opt/workload/template/ansible/traces/roles/* /opt/terraform/template/ansible/traces/roles/*; do
      tn="${tp/*\//}"
      if [ -d "$tp" ]; then
        for argv in $@; do
          if [ "$argv" = "--$tn" ] || [[ "$argv" =~ ^--$tn:[0-9a-z:_-]*$ ]]; then
            [[ "/$(IFS=/;echo "${trace_modules[*]}")/" = *"/$tn/"* ]] || trace_modules+=("$tp")
            [[ "|$(IFS=\|;echo "${trace_modules_options[*]}")|" = *"|${argv#--}|"* ]] || trace_modules_options+=("${argv#--}")
          fi
        done
      fi
    done
    trace_modules_options="--wl_trace_modules=$(IFS=,;echo "${trace_modules_options[*]}")"
}

run_playbook () {
    options=""
    while [[ "$1" = "-"* ]]; do
      options="$options $1"
      shift
    done
    playbook=$1
    shift

    playbooks=($(awk '/import_playbook/{print gensub("/[^/]+$","",1,$NF)}' $playbook))
    for pb in "${playbooks[@]}"; do
        [ -d "/opt/terraform/$pb" ] && copy_template "/opt/terraform/$pb" "$pb"
        # patch trace roles
        for tp in "${trace_modules[@]}"; do
            copy_template "$tp" "${tp/*\/template/template}"
        done
        [ -d "/opt/workload/$pb" ] && copy_template "/opt/workload/$pb" "$pb" "-S .origin -b"
    done
    [ "$playbook" = "cluster.yaml" ] && [[ "$stages" != *"--stage=provision"* ]] && return
    cp -f /opt/terraform/template/ansible/ansible.cfg .
    ANSIBLE_FORKS=$(nproc) ANSIBLE_ROLES_PATH="$ANSIBLE_ROLES_PATH:template/ansible/common/roles:template/ansible/traces/roles:/opt/collections/ansible_collections/cek/share/roles" ansible-playbook --flush-cache $options -i "$DIR"/create-inventory.py ${keyfile/-f/--private-key} $playbook &
    wait -f -n $!
}

check_docker_image () {
    missing=0
    echo
    for image in $("$DIR"/get-image-list.py); do
        if ALL_PROXY= all_proxy= skopeo inspect --retry-times 10 --tls-verify=false --raw docker://$image > /dev/null 2>&1; then
            echo -e "\033[0;32mOK\033[0m: $image"
        elif docker inspect $image > /dev/null 2>&1; then
            echo -e "\033[0;31mLOCAL\033[0m: $image"
        else
            echo -e "\033[0;31mMISSING\033[0m: $image"
            missing=1
        fi
    done
    echo
    return $missing
}

inspect_docker_image () {
    echo
    for image in $("$DIR"/get-image-list.py); do
        echo "Inspecting $image: ${1:-ls -l}"
        docker run --rm $image sh -c "${1:-ls -l}" 2> /dev/null || true
    done
    echo "inspection completed"
    exit 0
}

push_docker_image () {
    echo
    registry="$(sed -n '/^registry:/{s/.*"\(.*\)".*/\1/;p}' workload-config.yaml)"
    for image1s in $TERRAFORM_IMAGE $("$DIR"/get-image-list.py); do
        image1t="${1%/}/${image1s/${registry/\//\\\/}/}"
        echo "Pushing $image1s to $image1t..."
        if [[ "$image1t" = *".dkr.ecr."*".amazonaws.com/"* ]]; then
            /opt/project/script/csp/opt/script/push-to-ecr.sh $image1t --create-only
        fi
        ALL_PROXY= all_proxy= skopeo copy --src-tls-verify=false --dest-tls-verify=false docker://$image1s docker://$image1t
    done
    echo
    exit 0
}

set -o pipefail
DIR="$(dirname "$0")"
cd /opt/workspace
if [ ! -e ssh_config_all ]; then
    cat /opt/terraform/ssh_config > ssh_config_all
    chmod 600 ssh_config_all
fi

[[ "$@ " != *"--check-docker-image "* ]] || check_docker_image || exit 3
[[ " $@" != *" --inspect-docker-image="* ]] || inspect_docker_image "$(echo "x$@" | sed -e 's/.*--inspect-docker-image=\([^ ]*\).*/\1/' | base64 -d 2> /dev/null)"
[[ " $@" != *" --push-docker-image="* ]] || push_docker_image "$(echo "x$@" | sed 's/.*--push-docker-image=\([^ ]*\).*/\1/')"
[[ "$@ " != *"--dry-run "* ]] || exit 0

stages="$@"
if [[ "$stages" != *"--stage="* ]]; then
    stages="$@ --stage=provision --stage=validation --stage=cleanup"
fi

tf_pathes=($(grep -E 'source\s*=.*/template/terraform/' terraform-config.tf | cut -f2 -d'"' || true))
if [ ${#tf_pathes[@]} -ge 1 ]; then
    keyfile="-f ssh_access.key"
else
    keyfile=""
fi

pids=()
if [[ "$stages" = *"--stage=provision"* ]]; then
    echo "Provision SUT resources..." | tee -a tfplan.logs
    echo "provision_start: \"$(date -Ins)\"" >> timing.yaml

    # copy shared stack templates
    if [ -d "$STACK_TEMPLATE_PATH" ]; then
        cp -r -f "${STACK_TEMPLATE_PATH}" "${STACK_TEMPLATE_PATH/*\/template/template}"
    fi

    # copy templates over
    for tfp in "${tf_pathes[@]}"; do
        if [ -d "/opt/workload/$tfp" ]; then
            copy_template "/opt/workload/$tfp" "$tfp"
        elif [ -d "/opt/terraform/$tfp" ]; then
            copy_template "/opt/terraform/$tfp" "$tfp"
        else
            echo "Missing $tfp"
            exit 3
        fi
    done
    
    # Create SG white list
    if [ ${#tf_pathes[@]} -ge 1 ]; then
        "$DIR"/get-ip-list.sh /opt/project/script/csp/opt/etc/proxy-ip-list.txt > proxy-ip-list.txt
        # Create key pair
        ssh-keygen -t rsa -m PEM -q $keyfile -N ''
    fi

    # provision VMs
    cp -f /opt/terraform/template/ansible/ansible.cfg .
    if [[ "$@ " = *"--dev_log_level=NONE "* ]]; then
        TF_LOG=ERROR terraform init -input=false -no-color >> tfplan.logs 2>&1
    else
        TF_LOG=$(terraform_log_level "$@") terraform init -input=false -no-color 2>&1 | tee -a tfplan.logs
    fi

    trap destroy ERR

    dev_terraform_retries="$(echo "x $@" | sed -n '/--dev_terraform_retries=/{s/.* --dev_terraform_retries=\([0-9,]*\).*/\1/;p}')"
    dev_terraform_retries="${dev_terraform_retries:-10,3}"
    dev_terraform_delay="$(echo "x $@" | sed -n '/--dev_terraform_delay=/{s/.* --dev_terraform_delay=\([0-9,.smh]*\).*/\1/;p}')"
    dev_terraform_delay="${dev_terraform_delay:-10s,0}"

    terraform_replace=()
    terraform_refresh=""
    sts=1
    for i in $(seq ${dev_terraform_retries%,*}); do
        for j in $(seq ${dev_terraform_retries#*,}); do
            trap - SIGTERM SIGINT SIGKILL ERR EXIT

            if [[ "$@ " = *"--dev_log_level=NONE "* ]]; then
                TF_LOG=ERROR terraform plan -input=false -no-color --parallelism=$(nproc) "${terraform_replace[@]}" $terraform_refresh -out tfplan >> tfplan.logs 2>&1 || break
            else
                TF_LOG=$(terraform_log_level "$@") terraform plan -input=false -no-color --parallelism=$(nproc) "${terraform_replace[@]}" $terraform_refresh -out tfplan 2>&1 | tee -a tfplan.logs || break
            fi

            trap destroy SIGTERM SIGINT SIGKILL ERR EXIT
            terraform_refresh="-refresh"
            if [[ "$@ " = *"--dev_log_level=NONE "* ]]; then
                TF_LOG=ERROR terraform apply -input=false --auto-approve -no-color --parallelism=$(nproc) tfplan >> tfplan.logs 2>&1 &
            else
                TF_LOG=$(terraform_log_level "$@") terraform apply -input=false --auto-approve -no-color --parallelism=$(nproc) tfplan 2>&1 | tee -a tfplan.logs &
            fi
            if wait -f -n $!; then
                sts=0
                break
            fi
            sleep ${dev_terraform_delay#*,}
        done

        [ $sts -eq 0 ] || break
        terraform show -json > .tfplan.json
        terraform_replace=($(sed -n '/"terraform_replace":/{s/.*"terraform_replace":{"sensitive":false,"value":{"command":"\([^"]*\)".*/\1/;p}' .tfplan.json 2> /dev/null | sed 's/[[]\([^]]*\)[]]/["\1"]/g' | tr ' ' '\n' || true))
        sts=${#terraform_replace[@]}
        [ $sts -gt 0 ] || break
        sleep ${dev_terraform_delay%,*}
    done

    echo "provision_end: \"$(date -Ins)\"" >> timing.yaml
    [ $sts -eq 0 ] || destroy 3
fi

mkfifo /tmp/streaming-console
while true; do
    while read cmd; do
      eval "$cmd" 2>&1 | tee -a tfplan.logs &
      pids+=($!)
    done < /tmp/streaming-console
done &
pids+=($!)

# create cluster with ansible
# for validation only, we still want to prepare cluster.yaml but not execute it.
echo "host_setup_start: \"$(date -Ins)\"" >> timing.yaml
locate_trace_modules $@
cat .tfplan.json 2> /dev/null | $DIR/create-cluster.py $@ $trace_modules_options || true
echo "Setup SUT settings..." | tee -a tfplan.logs
if [[ "$@ " = *"--dev_log_level=NONE "* ]]; then
    run_playbook -vv cluster.yaml $@ >> tfplan.logs 2>&1 &
    wait -f -n $!
    grep -E '^\[.*\]: Host .*[+-] ' tfplan.logs || true
else
    run_playbook $(ansible_log_level "$@") cluster.yaml $@ 2>&1 | tee -a tfplan.logs &
    wait -f -n $!
fi
echo "host_setup_end: \"$(date -Ins)\"" >> timing.yaml

rc=0
if [[ "$stages" = *"--stage=validation"* ]]; then
    # create deployment with ansible
    echo "Deploy workload on SUT..." | tee -a tfplan.logs
    echo "deployment_start: \"$(date -Ins)\"" >> timing.yaml

    trap destroy SIGTERM SIGINT SIGKILL ERR EXIT

    locate_trace_modules $@
    cat .tfplan.json 2> /dev/null | $DIR/create-deployment.py $@ $trace_modules_options || true

    if [[ "$@ " = *"--dev_log_level=NONE "* ]]; then
        run_playbook -vv deployment.yaml $@ >> tfplan.logs 2>&1 &
    else
        run_playbook $(ansible_log_level "$@") deployment.yaml $@ 2>&1 | tee -a tfplan.logs &
    fi
    wait -f -n $! || rc=3

    echo "deployment_end: \"$(date -Ins)\"" >> timing.yaml
fi

destroy $rc
