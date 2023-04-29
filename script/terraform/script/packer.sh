#!/bin/bash -e

DIR="$(dirname "$0")"

if [[ $1 = *=* ]]; then
    PROJECT_NAME=main
else
    PROJECT_NAME=$1
    shift
fi

cd /opt/workspace

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

CSP="$(grep -E '^\s*csp\s*=' terraform-config.tf | cut -f2 -d'"' | tail -n1)"
echo "CSP=$CSP"
OWNER=${OWNER:-$(env | grep _OPTIONS= | tr ' ' '\n' | grep -F owner= | sed 's/.*--owner=\([^ ]*\)/\1/')}
echo "OWNER=$OWNER"

extract_string worker_profile instance_type INSTANCE_TYPE
extract_number worker_profile memory_size MEMORY_SIZE
extract_number worker_profile cpu_core_count CPU_CORE_COUNT
extract_string worker_profile min_cpu_platform MIN_CPU_PLATFORM
extract_string zone default ZONE
extract_string compartment default COMPARTMENT
extract_bool   spot_instance default SPOT_INSTANCE
extract_string worker_profile os_type OS_TYPE
extract_string worker_profile os_disk_type OS_DISK_TYPE
extract_number worker_profile os_disk_size OS_DISK_SIZE

case "$PLATFORM" in
ARMv*)
    ARCHITECTURE="arm64";;
ROME|MILAN|GENOA)
    ARCHITECTURE="amd64";;
*)
    ARCHITECTURE="x86_64";;
esac
echo "ARCHITECTURE=$ARCHITECTURE"

cp -r -L /opt/workload/* .
if [ ! -d template/packer/$CSP/$PROJECT_NAME ]; then
    if [ -d /opt/template/packer/$CSP/$PROJECT_NAME ]; then
        mkdir -p template/packer/$CSP/$PROJECT_NAME
        cp -r /opt/template/packer/$CSP/$PROJECT_NAME template/packer/$CSP
    else
        echo "Missing template/packer/$CSP/$PROJECT_NAME"
        exit 0
    fi
fi

# copy shared stack templates
if [ -d "$STACK_TEMPLATE_PATH" ]; then
    cp -r -f "${STACK_TEMPLATE_PATH}" /opt/workspace
fi

# Create SG white list
"$DIR"/get-ip-list.sh /opt/etc/proxy-ip-list.txt > proxy-ip-list.txt

if [ -e /home/.ssh/config ]; then
    SSH_PROXY="$(grep ProxyCommand /home/.ssh/config | tr ' ' '\n' | grep -E ':[0-9]+$' | head -n1)"
    SSH_PROXY_HOST="${SSH_PROXY/:*/}"
    SSH_PROXY_PORT="${SSH_PROXY/*:/}"
fi

mkdir -p /opt/workspace/template/terraform/$CSP
if [ -d /opt/template/terraform/$CSP/packer-rg ]; then
    cp -rf /opt/template/terraform/$CSP/packer-rg /opt/workspace/template/terraform/$CSP
    cd /opt/workspace/template/terraform/$CSP/packer-rg

    cat > terraform.tfvars <<EOF
zone="$ZONE"
owner="$OWNER"
EOF
    (
        set -x
        terraform init -input=false -no-color -upgrade
        terraform apply -input=false --auto-approve -no-color --var create_resource=false || terraform apply -input=false --auto-approve -no-color --var create_resource=true
    )
    eval "$(terraform show -json | "$DIR"/create-vars.py)"
fi

destroy () {
    trap - SIGINT SIGKILL ERR EXIT
    cd /opt/workspace/template/terraform/$CSP/packer
    TF_LOG=ERROR terraform destroy -auto-approve -input=false -no-color -parallelism=1
    echo "exit with status: ${1:-3}"
    exit ${1:-3}
}

if [ -d /opt/template/terraform/$CSP/packer ]; then
    cp -rf /opt/template/terraform/$CSP/packer /opt/workspace/template/terraform/$CSP
    cd /opt/workspace/template/terraform/$CSP/packer

    cat > terraform.tfvars <<EOF
zone="$ZONE"
owner="$OWNER"
proxy_ip_list="$(readlink -f ../../../../proxy-ip-list.txt)"
job_id="$NAMESPACE"
EOF
    [ "$COMPARTMENT" == "null" ] || echo "compartment=\"$COMPARTMENT\"" >> terraform.tfvars
    (
        set -x
        terraform init -input=false -no-color -upgrade
        terraform plan -input=false -out tfplan -no-color
    )

    trap destroy SIGINT SIGKILL ERR EXIT

    (
        set -x
        terraform apply -input=false --auto-approve -no-color
    )
    terraform show -json > ../../../../tfplan.json
    eval "$("$DIR"/create-vars.py < ../../../../tfplan.json)"
fi

cd /opt/workspace/template/packer/$CSP/$PROJECT_NAME
packer init .

vars=()
for argv in $@; do
    if [[ "$argv" = *'='* ]]; then
        k="${argv/=*/}"
        v="${argv/*=/}"
        [[ "$k" = *'$'* ]] && eval "k=$k"
        [[ "$v" = *'$'* ]] && eval "v=$v"
        vars+=("-var" "$k=$v")
    fi
done

(
    set -x
    PACKER_LOG=1 PACKER_LOG_PATH=/opt/workspace/packer.logs packer build -force "${vars[@]}" .
)

destroy 0
