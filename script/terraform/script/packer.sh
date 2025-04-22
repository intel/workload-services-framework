#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$(dirname "$0")"

if [[ $1 = *=* ]]; then
    PROJECT_NAME=main
else
    PROJECT_NAME=$1
    shift
fi

extract_string () {
    value="$(sed -n "/^\s*variable\s*\"$1\"\s*{/,/^\s*}/{/^\s*$2\s*=\s*\"/{s/^\s*$2\s*=\s*\"\(.*\)\"\s*$/\1/;p}}" terraform-config.tf)"
    echo "$3=${value:-null}"
    eval "$3=\"${value:-null}\""
}

extract_number () {
    value="$(sed -n "/^\s*variable\s*\"$1\"\s*{/,/^\s*}/{/^\s*$2\s*=/{s/^\s*$2\s*=\s*\([0-9.]*\).*$/\1/;p}}" terraform-config.tf)"
    echo "$3=${value:-0}"
    eval "$3=\"${value:-0}\""
}

extract_bool () {
    value="$(sed -n "/^\s*variable\s*\"$1\"\s*{/,/^\s*}/{/^\s*$2\s*=/{s/^\s*$2\s*=\s*\([truefals]*\).*$/\1/;p}}" terraform-config.tf)"
    echo "$3=${value:-false}"
    eval "$3=\"${value:-false}\""
}

extract_host_string () {
    value="$(sed -n "/^\s*variable\s*\"$1\"\s*{/,/^\s*}\s*$/{/^\s*\"$2\"\s*:\s*{/,/^\s*}/{/^\s*\"$3\"\s*:/{s/^\s*\"$3\"\s*:\s*\"\(.*\)\"\s*,*\s*$/\1/;p}}}" terraform-config.tf)"
    echo "$4=${value:-null}"
    eval "$4=\"${value:-null}\""
}

extract_host_number () {
    value="$(sed -n "/^\s*variable\s*\"$1\"\s*{/,/^\s*}\s*$/{/^\s*\"$2\"\s*:\s*{/,/^\s*}/{/^\s*\"$3\"\s*:/{s/^\s*\"$3\"\s*:\s*\([0-9.]*\).*$/\1/;p}}}" terraform-config.tf)"
    echo "$4=${value:-0}"
    eval "$4=\"${value:-0}\""
}

CSP="$(grep -E '^\s*csp\s*=' terraform-config.tf | cut -f2 -d'"' | tail -n1)"
CSP=${CSP:-static}
echo "CSP=$CSP"
OWNER=${OWNER:-$(env | grep _OPTIONS= | tr ' ' '\n' | grep -F owner= | sed 's/.*--owner=\([^ ]*\)/\1/')}
echo "OWNER=$OWNER"

cd /opt/workspace
extract_string worker_profile instance_type INSTANCE_TYPE
extract_number worker_profile memory_size MEMORY_SIZE
extract_number worker_profile cpu_core_count CPU_CORE_COUNT
extract_string worker_profile min_cpu_platform MIN_CPU_PLATFORM
extract_string zone default ZONE
extract_string resource_group_id default RESOURCE_GROUP_ID
extract_string compartment default COMPARTMENT
extract_bool   spot_instance default SPOT_INSTANCE
extract_string worker_profile os_type OS_TYPE
extract_string worker_profile os_disk_type OS_DISK_TYPE
extract_number worker_profile os_disk_size OS_DISK_SIZE
extract_string worker_profile os_image OS_IMAGE
extract_number worker_profile vm_count WORKER_VM_COUNT
extract_string compute_gallery gallery_name GALLERY_NAME
extract_string compute_gallery gallery_resource_group_name GALLERY_RESOURCE_GROUP_NAME
extract_string compute_gallery gallery_image_name GALLERY_IMAGE_NAME
extract_string compute_gallery gallery_image_verion GALLERY_IMAGE_VERION
user_name=""
public_ip=""
private_ip=""
ssh_port=""
for i in $(seq $WORKER_VM_COUNT); do
    extract_host_string worker_profile worker-$((i-1)) user_name USER_NAME
    user_name="$user_name$([ "$USER_NAME" = "null" ] && id -un || echo $USER_NAME),"
    extract_host_string worker_profile worker-$((i-1)) public_ip PUBLIC_IP
    public_ip="$public_ip$PUBLIC_IP,"
    extract_host_string worker_profile worker-$((i-1)) private_ip PRIVATE_IP
    private_ip="$private_ip$PRIVATE_IP,"
    extract_host_number worker_profile worker-$((i-1)) ssh_port SSH_PORT
    ssh_port="$ssh_port$SSH_PORT,"
done
USER_NAME="${user_name%,}"
PUBLIC_IP="${public_ip%,}"
PRIVATE_IP="${private_ip%,}"
SSH_PORT="${ssh_port%,}"
extract_string kvm_hosts host KVM_HOST
extract_string kvm_hosts user KVM_HOST_USER
extract_number kvm_hosts port KVM_HOST_PORT
extract_string kvm_hosts pool KVM_HOST_POOL

case "$PLATFORM" in
ARMv*)
    ARCHITECTURE="arm64";;
*)
    ARCHITECTURE="x86_64";;
esac
echo "ARCHITECTURE=$ARCHITECTURE"

cp -r -L /opt/workload/* .
if [ ! -d template/packer/$CSP/$PROJECT_NAME ]; then
    if [ -d /opt/terraform/template/packer/$CSP/$PROJECT_NAME ]; then
        mkdir -p template/packer/$CSP/$PROJECT_NAME
        cp -r /opt/terraform/template/packer/$CSP/$PROJECT_NAME template/packer/$CSP
    else
        echo "Missing template/packer/$CSP/$PROJECT_NAME"
        exit 0
    fi
fi

# Create SG white list
"$DIR"/get-ip-list.sh /opt/project/script/csp/opt/etc/proxy-ip-list.txt > proxy-ip-list.txt

if [ -e ssh_config_csp ]; then
    SSH_PROXY="$(grep ProxyCommand ssh_config_csp | tr ' ' '\n' | grep -E ':[0-9]+$' | head -n1)"
    SSH_PROXY_HOST="${SSH_PROXY/:*/}"
    SSH_PROXY_PORT="${SSH_PROXY/*:/}"
fi

mkdir -p /opt/workspace/template/terraform/$CSP

pids=()
destroy () {
    trap - ERR EXIT
    trap " " SIGTERM
    kill -- -$BASHPID ${pids[@]} 2> /dev/null
    wait

    if [ -d /opt/workspace/template/terraform/$CSP/packer ]; then
        cd /opt/workspace/template/terraform/$CSP/packer
        echo "Cleanup resources..."
        TF_LOG=ERROR terraform destroy -auto-approve -input=false -no-color -parallelism=$(nproc) -lock-timeout=300s > ../../../../cleanup.logs 2>&1 || 
        TF_LOG=ERROR terraform destroy -auto-approve -input=false -no-color -parallelism=$(nproc) -lock=false >> ../../../../cleanup.logs 2>&1
    fi
    echo "exit with status: ${1:-3}"
    exit ${1:-3}
}

write_var () {
    if [ "$2" = "null" ]; then
        echo "$1=$2"
    elif [ "$2" = "true" ] || [ "$2" = "false" ]; then
        echo "$1=$2"
    elif [[ "$2" =~ ^[+-]?([0-9]+([.][0-9]*)?|\.[0-9]+)$ ]]; then
        echo "$1=$2"
    elif [[ "$2" = "["*"]" ]] || [[ "$2" = "{"*"}" ]]; then
        echo "$1=$2"
    else
        echo "$1=\"$2\""
    fi
}

if [ -d /opt/terraform/template/terraform/$CSP/packer ]; then
    cp -rf /opt/terraform/template/terraform/$CSP/packer /opt/workspace/template/terraform/$CSP
    cd /opt/workspace/template/terraform/$CSP/packer

    case "$CSP" in
    kvm)
        cat > terraform.tfvars <<EOF
kvm_host="$KVM_HOST"
kvm_host_user="$KVM_HOST_USER"
kvm_host_port="$KVM_HOST_PORT"
pool_name="$(eval "echo \"$(echo "$@" | tr ' ' '\n' | sed -n '/^pool_name=/{s///;p}')\"")"
image_name="$(eval "echo \"$(echo "$@" | tr ' ' '\n' | sed -n '/^image_name=/{s///;p}')\"")"
EOF
        ;;
    *)
        cat > terraform.tfvars <<EOF
zone="$ZONE"
owner="$OWNER"
proxy_ip_list="$(readlink -f ../../../../proxy-ip-list.txt)"
job_id="$NAMESPACE"
image_name="$(eval "echo \"$(echo "$@" | tr ' ' '\n' | sed -n '/^image_name=/{s///;p}')\"")"
EOF
        ;;
    esac

    vars="$(sed -n '/^\s*variable\s*"[^"]*"\s*{*\s*#*.*$/{s/.*"\(.*\)".*/\1/;p}' *.tf | tr '\n' ' ')"
    for var in compartment resource_group_id instance_type os_type os_image; do
        if [[ " $vars " = *" $var "* ]]; then
            eval "v=\"\$${var^^}\""
            write_var "$var" "$v" >> terraform.tfvars
        fi
    done

    trap destroy SIGINT SIGKILL ERR EXIT

    (set -x; terraform init -input=false -no-color) &
    wait -n $!

    (set -x; terraform plan -input=false -out tfplan -no-color -parallelism=$(nproc)) & 
    wait -n $! 

    (set -x; terraform apply -input=false --auto-approve -no-color -parallelism=$(nproc)) &
    wait -n $!

    terraform show -json > ../../../../.tfplan.json
    eval "$("$DIR"/create-vars.py < ../../../../.tfplan.json)"
fi

trap destroy SIGINT SIGKILL ERR EXIT

cd /opt/workspace/template/packer/$CSP/$PROJECT_NAME
ssh-keygen -t rsa -m PEM -q -f ssh_access.key -N ''
if [ "$CSP" = "static" ] && [ "$PUBLIC_IP" = "127.0.0.1" ]; then
    echo "AuthorizedKeysFile $(readlink -e ssh_access.key.pub)" | sudo tee -a /etc/ssh/sshd_config
    sudo service ssh start
fi
packer init .

vars="$(sed -n '/^\s*variable\s*"[^"]*"\s*{*\s*#*.*$/{s/.*"\(.*\)".*/\1/;p}' *.pkr.hcl | tr '\n' ' ')"
for argv in $@; do
    if [[ "$argv" = *'='* ]]; then
        k="${argv/=*/}"
        if [[ " $vars " = *" $k "* ]]; then
            v="${argv/*=/}"
            [[ "$k" = *'$'* ]] && eval "k=$k"
            [[ "$v" = *'$'* ]] && eval "v=$v"
            write_var "$k" "$v" >> packer.auto.pkrvars.hcl
        fi
    fi
done

mkfifo /tmp/streaming-console
while true; do
    while read cmd; do
      eval "$cmd" 2>&1 | tee -a tfplan.logs &
      pids+=($!)
    done < /tmp/streaming-console
done &
pids+=($!)
(set -x; PACKER_LOG=1 PACKER_LOG_PATH=/opt/workspace/packer.logs packer build -force .) &
pids+=($!)
wait -n

destroy 0
