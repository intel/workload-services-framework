#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

copy_template () {
    echo copy template $1 to $2
    mkdir -p "$2" || true
    cp -rL $3 "$1"/* "$2"/
}

destroy () {
    set +e
    trap - ERR EXIT
    trap " " SIGTERM
    kill -- -$BASHPID 2> /dev/null
    wait

    cd /opt/workspace

    if [[ "$stages" = *"--stage=cleanup"* ]]; then
        if [ -r cleanup.yaml ]; then
            echo "Restore SUT settings..." | tee -a tfplan.logs
            run_playbook -vv cleanup.yaml >> tfplan.logs 2>&1 || true
        fi

        echo "Destroy SUT resources..." | tee -a tfplan.logs
        TF_LOG=ERROR terraform destroy -refresh -auto-approve -input=false -no-color -parallelism=$(nproc) -lock-timeout=300s >> tfplan.logs 2>&1 ||
        TF_LOG=ERROR terraform destroy -refresh -auto-approve -input=false -no-color -parallelism=$(nproc) -lock=false >> tfplan.logs 2>&1

        rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup tfplan .ssh .netrc
    fi 
      
    if [[ "$stages" = *"--stage=validation"* ]]; then
        for publisher in "$DIR"/publish-*.py; do
            publisher="${publisher#*publish-}"
            publisher="${publisher%.py}"
            # create KPI and publish KPI
            if [[ "$stages" = *"--${publisher}_publish"* ]]; then
                echo "Publish to datalake..." | tee -a tfplan.logs
                sed -e 's/_password":"[^"]*/_password":"string/g' -e 's/_password\\": *\\"[^"]*/_password\\":\\"XYZXYZ\\/g' .tfplan.json > tfplan.json
                "$DIR"/publish-$publisher.py $stages < tfplan.json 2>&1 | tee publish.logs
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
    (set -ex; ANSIBLE_FORKS=$(nproc) ANSIBLE_ROLES_PATH="$ANSIBLE_ROLES_PATH:template/ansible/common/roles:template/ansible/traces/roles:/opt/collections/ansible_collections/cek/share/roles" ansible-playbook --flush-cache $options -i "$DIR"/create-inventory.py --private-key "$keyfile" $playbook)
}

check_docker_image () {
    missing=0
    echo
    for image in $("$DIR"/get-image-list.py); do
        if ALL_PROXY= all_proxy= skopeo inspect --tls-verify=false --raw docker://$image > /dev/null 2>&1; then
            echo -e "\033[0;32mOK\033[0m: $image"
        else
            echo -e "\033[0;31mMISSING\033[0m: $image"
            missing=1
        fi
    done
    echo
    return $missing
}

push_docker_image () {
    echo
    registry="$(sed -n '/^registry:/{s/.*"\(.*\)".*/\1/;p}' workload-config.yaml)"
    for image1s in $TERRAFORM_IMAGE $("$DIR"/get-image-list.py); do
        image1t="${1%/}/${image1s/${registry/\//\\\/}/}"
        echo "Pushing $image1s to $image1t..."
        if [[ "$image1t" = *".dkr.ecr."*".amazonaws.com/"* ]]; then
            /opt/csp/script/push-to-ecr.sh $image1t --create-only
        fi
        ALL_PROXY= all_proxy= skopeo copy --src-tls-verify=false --dest-tls-verify=false docker://$image1s docker://$image1t
    done
    echo
}

DIR="$(dirname "$0")"
cd /opt/workspace

[[ "$@ " != *"--check-docker-image "* ]] || check_docker_image || exit 3
[[ " $@" != *" --push-docker-image="* ]] || push_docker_image "$(echo "x$@" | sed 's/.*--push-docker-image=\([^ ]*\).*/\1/')"
[[ "$@ " != *"--dry-run "* ]] || exit 0

stages="$@"
if [[ "$stages" != *"--stage="* ]]; then
    stages="$@ --stage=provision --stage=validation --stage=cleanup"
fi
    
tf_pathes=($(grep -E 'source\s*=.*/template/terraform/' terraform-config.tf | cut -f2 -d'"'))
if [ ${#tf_pathes[@]} -ge 1 ]; then
    keyfile="ssh_access.key"
else
    keyfile="$HOME/.ssh/id_rsa"
fi

if [[ "$stages" = *"--stage=provision"* ]]; then
    echo "Create the provisioning plan..."
    echo "provision_start: \"$(date -Ins)\"" >> timing.yaml

    # copy shared stack templates
    if [ -d "$STACK_TEMPLATE_PATH" ]; then
        cp -r -f "${STACK_TEMPLATE_PATH}" "${STACK_TEMPLATE_PATH/*\/template/template}"
    fi

    # copy templates over
    for tfp in "${tf_pathes[@]}"; do
        if [ -d "/opt/workload/template/terraform" ]; then
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
        "$DIR"/get-ip-list.sh /opt/csp/etc/proxy-ip-list.txt > proxy-ip-list.txt
        # Create key pair
        ssh-keygen -m PEM -q -f $keyfile -t rsa -N ''
    fi

    trap destroy SIGTERM SIGINT SIGKILL ERR EXIT

    # provision VMs
    cp -f /opt/terraform/template/ansible/ansible.cfg .
    (set -xeo pipefail; terraform init -input=false -no-color 2>&1 | tee -a tfplan.logs) &
    wait -n %1

    terraform_retries="$(echo "x $@" | sed -n '/--terraform_retries=/{s/.* --terraform_retries=\([0-9,]*\).*/\1/;p}')"
    terraform_retries="${terraform_retries:-10,3}"
    terraform_delay="$(echo "x $@" | sed -n '/--terraform_delay=/{s/.* --terraform_delay=\([0-9,.smh]*\).*/\1/;p}')"
    terraform_delay="${terraform_delay:-10s,0}"

    terraform_replace=()
    terraform_refresh=""
    sts=1
    terraform_log_level="$(echo "x $@" | sed -n '/--terraform_log_level=/{s/.*--terraform_log_level=\([^[:space:]]*\).*/\1/;p}')"
    for i in $(seq ${terraform_retries%,*}); do
        for j in $(seq ${terraform_retries#*,}); do
            (set -xeo pipefail; TF_LOG=${terraform_log_level:-ERROR} terraform plan -input=false -no-color --parallelism=$(nproc) "${terraform_replace[@]}" $terraform_refresh -out tfplan 2>&1 | tee -a tfplan.logs) &
            wait -n $! || break
            terraform_refresh="-refresh"

            (set -xeo pipefail; TF_LOG=${terraform_log_level:-ERROR} terraform apply -input=false --auto-approve -no-color --parallelism=$(nproc) tfplan 2>&1 | tee -a tfplan.logs) &
            if wait -n $!; then
                sts=0
                break
            fi
            sleep ${terraform_delay#*,}
        done

        [ $sts -eq 0 ] || break
        terraform show -json > .tfplan.json
        terraform_replace=($(sed -n '/"terraform_replace":/{s/.*"terraform_replace":{"sensitive":false,"value":{"command":"\([^"]*\)".*/\1/;p}' .tfplan.json | sed 's/[[]\([^]]*\)[]]/["\1"]/g' | tr ' ' '\n'))
        sts=${#terraform_replace[@]}
        [ $sts -gt 0 ] || break
        sleep ${terraform_delay%,*}
    done

    echo "provision_end: \"$(date -Ins)\"" >> timing.yaml
    [ $sts -eq 0 ] || destroy 3
fi

# create cluster with ansible
# for validation only, we still want to prepare cluster.yaml but not execute it.
echo "host_setup_start: \"$(date -Ins)\"" >> timing.yaml
locate_trace_modules $@
cat .tfplan.json | $DIR/create-cluster.py $@ $trace_modules_options
(set -eo pipefail; run_playbook -vv cluster.yaml $@ 2>&1 | tee -a tfplan.logs) &
wait -n %1
echo "host_setup_end: \"$(date -Ins)\"" >> timing.yaml

if [[ "$stages" = *"--stage=validation"* ]]; then
    # create deployment with ansible
    echo "Create the deployment plan..." | tee -a tfplan.logs
    echo "deployment_start: \"$(date -Ins)\"" >> timing.yaml

    trap destroy SIGTERM SIGINT SIGKILL ERR EXIT

    locate_trace_modules $@
    cat .tfplan.json | $DIR/create-deployment.py $@ $trace_modules_options
    (set -eo pipefail; run_playbook -vv deployment.yaml $@ 2>&1 | tee -a tfplan.logs) &
    wait -n %1
    echo "deployment_end: \"$(date -Ins)\"" >> timing.yaml
fi

destroy 0
