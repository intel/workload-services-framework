#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# args: [in] cluster-config [out] terraform-config.yaml [in] controller_vm_count
terraform_config_tf="$2"

# env_suffix default_group_value variable_pattern
extract_group_value () {
    group="$(echo "$line" | cut -f1 -d=)"
    group="${group/#${CSP}_}"
    group="${group/%_$1}"
    group="${group/%$1}"
    group="${group,,}"
    group="${group:-$2}"
    if [[ "$3" = _* ]]; then
        var="${group/${3/%_}}$3"
    elif [[ "$3" = *_ ]]; then
        var="$3${group/${3/#_}}"
    else
        var="$3"
    fi
    value="$(echo "$line" | cut -f2- -d=)"
}

# default_group_value variable_pattern value_keyword env_suffix
override_string () {
    extract_group_value "$4" "$1" "$2"
    [ "$value" = "null" ] || value="\"$value\""
    sed -i "/^\s*variable\s*[\"]$var[\"]\s*{/,/^\s*}/s|^\(\s*$3\s*=\).*$|\1 $value|" "$terraform_config_tf"
}

# default_group_value variable_pattern value_keyword env_suffix
override_number () {
    extract_group_value "$4" "$1" "$2"
    sed -i "/^\s*variable\s*[\"]$var[\"]\s*{/,/^\s*}/s|^\(\s*$3\s*=\).*$|\1 $value|" "$terraform_config_tf"
}

# default_group_value variable_pattern value_keyword env_suffix
override_dict () {
    extract_group_value "$4" "$1" "$2"
    ns="$(sed -n "/^\s*variable\s*[\"]$var[\"]\s*{/,/^\s*variable\s*[\"]/{/^\s*$3\s*=/{s/^\(\s*\)$3\s*=.*/\1/;p}}" "$terraform_config_tf")"
    # normalize {} to {\n}
    sed -i "/^\s*variable\s*[\"]$var[\"]\s*{/,/^\s*variable\s*[\"]/s/^\(\s*$3\s*=\)\s*{\s*}/\1 {\\n$ns}/" "$terraform_config_tf"
    # remove old dictionary between {}
    sed -i "/^\s*variable\s*[\"]$var[\"]\s*{/,/^\s*}/{/^\s*$3\s*=/,/^\s*}/{/^\s*$3\s*=/!d}}" "$terraform_config_tf"
    # insert new dictionary
    sed -i "/^\s*variable\s*[\"]$var[\"]\s*{/,/^\s*}/s|^\(\s*$3\s*=\).*$|\1 {\\n$ns$ns${value//,/\\n$ns$ns}\\n$ns}|" "$terraform_config_tf"
}

# group var if-value set-value
replace_if () {
    sed -i "/^\s*variable\s*[\"]$1[\"]\s*{/,/^\s*}/s|^\(\s*$2\s*=\s*\)[\"]*$3[\"]*\s*$|\1\"$4\"|" "$terraform_config_tf"
}

override_static_host () {
    local group="$(echo "$line" | cut -f2 -d_ | tr 'A-Z' 'a-z')"
    local host="$(echo "$line" | cut -f1 -d= | cut -f3 -d_)"
    if [ -z "$(sed -n "/^\s*variable\s*\"${group}_profile\"\s*{/,/^\s*}/{/^\s\s\s\s*\"${group}-${host}\":\s*{/{p}}" "$terraform_config_tf")" ]; then
        local group_0="$(sed -n "/^\s*variable\s*\"${group}_profile\"\s*{/,/^\s*}/{/^\s\s\s\s*\"$group-0\":\s*{/,/^\s\s\s\s*},/{p}}" "$terraform_config_tf" | sed -e "s/\"$group-0\":/\"$group-$host\":/" -e 's/$/\\n/' | tr -d '\n')"
        sed -i "/^\s*variable\s*\"${group}_profile\"\s*{/,/^ *}/{/^\s\s\s*hosts\s*=\s*{/{s|hosts\s*=\s*{|hosts = {\n${group_0%\\n}|}}" "$terraform_config_tf"
    fi
    if [[ "$line" = *"winrm:"* ]]; then
        # winrm:<user>
        local value="${line##*winrm:}"
        local winrm_user="${value%%,*}"
        sed -i "/^\s*variable\s*\"${group}_profile\"\s*{/,/^\s*}\s*$/{/^\s\s\s\s*\"${group}-${host}\":\s*{/,/^\s\s\s\s*},\s*$/{s|#*\s*\(\"winrm_user\":\).*|\1 \"$winrm_user\",|}}" "$terraform_config_tf"
        sed -i "/^\s*variable\s*\"${group}_profile\"\s*{/,/^\s*}\s*$/{/^\s\s\s\s*\"${group}-${host}\":\s*{/,/^\s\s\s\s*},\s*$/{/^\s\s\s\s\s\s*#\s{/,/^\s\s\s\s\s\s*#\s}/{d};s|#*\s*\(\"winrm_password\":\).*|\1 \"\",|}}" "$terraform_config_tf"
    fi
    if [[ "$line" = *"bmc:"* ]]; then
        # bmc:<user>@<ip>:<port>
        local value="${line##*bmc:}"
        value="${value%%,*}"
        local bmc_user="${value%%@*}"
        local bmc_ip="${value##*@}"
        local bmc_ip="${bmc_ip%%:*}"
        local bmc_port="${value##*:}"
        sed -i "/^\s*variable\s*\"${group}_profile\"\s*{/,/^\s*}\s*$/{/^\s\s\s\s*\"${group}-${host}\":\s*{/,/^\s\s\s\s*},\s*$/{s|#*\s*\(\"bmc_user\":\).*|\1 \"$bmc_user\",|}}" "$terraform_config_tf"
        sed -i "/^\s*variable\s*\"${group}_profile\"\s*{/,/^\s*}\s*$/{/^\s\s\s\s*\"${group}-${host}\":\s*{/,/^\s\s\s\s*},\s*$/{s|#*\s*\(\"bmc_ip\":\).*|\1 \"$bmc_ip\",|}}" "$terraform_config_tf"
        sed -i "/^\s*variable\s*\"${group}_profile\"\s*{/,/^\s*}\s*$/{/^\s\s\s\s*\"${group}-${host}\":\s*{/,/^\s\s\s\s*},\s*$/{s|#*\s*\(\"bmc_port\":\).*|\1 $bmc_port,|}}" "$terraform_config_tf"
        sed -i "/^\s*variable\s*\"${group}_profile\"\s*{/,/^\s*}\s*$/{/^\s\s\s\s*\"${group}-${host}\":\s*{/,/^\s\s\s\s*},\s*$/{/^\s\s\s\s\s*#\s{/,/^\s\s\s\s\s*#\s}/{d};s|#*\s*\(\"bmc_password\":\).*|\1 \"\",|}}" "$terraform_config_tf"
    fi
    if [[ "$line" = *"pdu:"* ]]; then
        # pdu:<user>@<ip>:<group>:<port>
        local value="${line##*pdu:}"
        value="${value%%,*}"
        local pdu_user="${value%%@*}"
        value="${value##*@}"
        local pdu_ip="${value%%:*}"
        local pdu_group="${value#"$pdu_ip:"}"
        local pdu_port="${value##*:}"
        sed -i "/^\s*variable\s*\"${group}_profile\"\s*{/,/^\s*}\s*$/{/^\s\s\s\s*\"${group}-${host}\":\s*{/,/^\s\s\s\s*},\s*$/{s|#*\s*\(\"pdu_port\":\).*|\1 \"${pdu_port}\",|}}" "$terraform_config_tf"
        sed -i "/^\s*variable\s*\"${group}_profile\"\s*{/,/^\s*}\s*$/{/^\s\s\s\s*\"${group}-${host}\":\s*{/,/^\s\s\s\s*},\s*$/{s|#*\s*\(\"pdu_group\":\).*|\1 \"${pdu_group%%:*}\",|}}" "$terraform_config_tf"
        sed -i "/^\s*variable\s*\"${group}_profile\"\s*{/,/^\s*}\s*$/{/^\s\s\s\s*\"${group}-${host}\":\s*{/,/^\s\s\s\s*},\s*$/{s|#*\s*\(\"pdu_ip\":\).*|\1 \"${pdu_ip}\",|}}" "$terraform_config_tf"
        sed -i "/^\s*variable\s*\"${group}_profile\"\s*{/,/^\s*}\s*$/{/^\s\s\s\s*\"${group}-${host}\":\s*{/,/^\s\s\s\s*},\s*$/{s|#*\s*\(\"pdu_user\":\).*|\1 \"${pdu_user}\",|}}" "$terraform_config_tf"
        sed -i "/^\s*variable\s*\"${group}_profile\"\s*{/,/^\s*}\s*$/{/^\s\s\s\s*\"${group}-${host}\":\s*{/,/^\s\s\s\s*},\s*$/{/^\s\s\s\s\s*#\s{/,/^\s\s\s\s\s*#\s}/{d};s|#*\s*\(\"pdu_password\":\).*|\1 \"\",|}}" "$terraform_config_tf"
    fi
    # host:<user>@<public_ip>:<private_ip>:<port>
    if [[ "$line" = *"host:"* ]]; then
        local value="${line##*host:}"
        value="${value%%,*}"
        local user_name=""
        [[ "$value" != *"@"* ]] || user_name="${value%%@*}"
        value="${value##*@}"
        local public_ip="${value%%:*}"
        value="${value#"$public_ip:"}"
        if [[ "$value" = *:* ]]; then
            local private_ip="${value%%:*}"
            local ssh_port="${value##*:}"
        elif [[ "$value" = *"."* ]]; then
            local private_ip="$value"
            local ssh_port=22
        else
            local private_ip="$public_ip"
            local ssh_port="$value"
        fi
        if [ -n "$user_name" ]; then
            sed -i "/^\s*variable\s*\"${group}_profile\"\s*{/,/^\s*}\s*$/{/^\s\s\s\s*\"${group}-${host}\":\s*{/,/^\s\s\s\s*},\s*$/{s|#*\s*\(\"user_name\":\).*|\1 \"$user_name\",|}}" "$terraform_config_tf"
        else
            sed -i "/^\s*variable\s*\"${group}_profile\"\s*{/,/^\s*}\s*$/{/^\s\s\s\s*\"${group}-${host}\":\s*{/,/^\s\s\s\s*},\s*$/{s|#*\s*\(\"user_name\":\).*|# \1 \"<user>\",|}}" "$terraform_config_tf"
        fi
        sed -i "/^\s*variable\s*\"${group}_profile\"\s*{/,/^\s*}\s*$/{/^\s\s\s\s*\"${group}-${host}\":\s*{/,/^\s\s\s\s*},\s*$/{s|\(\"public_ip\":\).*|\1 \"$public_ip\",|}}" "$terraform_config_tf"
        sed -i "/^\s*variable\s*\"${group}_profile\"\s*{/,/^\s*}\s*$/{/^\s\s\s\s*\"${group}-${host}\":\s*{/,/^\s\s\s\s*},\s*$/{s|\(\"private_ip\":\).*|\1 \"${private_ip}\",|}}" "$terraform_config_tf"
        sed -i "/^\s*variable\s*\"${group}_profile\"\s*{/,/^\s*}\s*$/{/^\s\s\s\s*\"${group}-${host}\":\s*{/,/^\s\s\s\s*},\s*$/{s|\(\"ssh_port\":\).*|\1 ${ssh_port},|}}" "$terraform_config_tf"
    fi
}

# adjust vm_count and data_disk_spec
DIR="$(dirname "$(readlink -f "$0")")"
awk -v cvc=$3 -f "$DIR/script/update-tfconfig.awk" "$1" "${TERRAFORM_CONFIG_IN:-$PROJECTROOT/script/terraform/terraform-config.$TERRAFORM_SUT.tf}" > "$terraform_config_tf"

case "$PLATFORM" in
ARMv8)
    replace_if worker_profile instance_type t2.medium m6g.large
    replace_if worker_profile instance_type e2-small t2a-standard-2
    ;;
ARMv9)
    replace_if worker_profile instance_type t2.medium c7g.large
    replace_if worker_profile instance_type Standard_A2_v2 Standard_D2ps_v5
    replace_if worker_profile instance_type S1.MEDIUM2 SR1.MEDIUM4
    ;;
ROME)
    replace_if worker_profile instance_type t2.medium m5a.large
    replace_if worker_profile instance_type e2-small n2d-standard-2
    replace_if worker_profile instance_type Standard_A2_v2 Standard_D2a_v4
    replace_if worker_profile instance_type S1.MEDIUM2 SA2.MEDIUM4
    replace_if worker_profile instance_type ecs.g5.large ecs.g6a.large
    ;;
MILAN)
    replace_if worker_profile instance_type t2.medium m6a.large
    replace_if worker_profile instance_type e2-small n2d-standard-2
    replace_if worker_profile instance_type Standard_A2_v2 Standard_D2as_v5
    replace_if worker_profile instance_type S1.MEDIUM2 SA3.MEDIUM4
    replace_if worker_profile instance_type ecs.g5.large ecs.g7a.large
    replace_if worker_profile min_cpu_platform null "AMD Milan"
    ;;
GENOA)
    replace_if worker_profile instance_type t2.medium m7a.large
    replace_if worker_profile instance_type e2-small n2d-standard-2
    replace_if worker_profile instance_type Standard_A2_v2 Standard_D2as_v5
    replace_if worker_profile instance_type S1.MEDIUM2 SA4.MEDIUM4
    replace_if worker_profile instance_type ecs.g5.large ecs.g8a.large
    replace_if worker_profile min_cpu_platform null "AMD Genoa"
    ;;
ICX)
    replace_if worker_profile instance_type t2.medium m6i.large
    replace_if worker_profile instance_type e2-small n2-standard-2
    replace_if worker_profile instance_type Standard_A2_v2 Standard_D2_v5
    replace_if worker_profile instance_type S1.MEDIUM2 S6.MEDIUM4
    replace_if worker_profile instance_type ecs.g5.large ecs.g7.large
    replace_if worker_profile min_cpu_platform null "Intel Ice Lake"
    ;;
#SPR)
#    replace_if worker_profile instance_type t2.medium m7i.large
#    replace_if worker_profile instance_type e2-small n2-standard-2
#    replace_if worker_profile instance_type Standard_A2_v2 Standard_D2_v5
#    replace_if worker_profile instance_type S1.MEDIUM2 S7.MEDIUM4
#    replace_if worker_profile instance_type ecs.g5.large ecs.g8.large
#    replace_if worker_profile min_cpu_platform null "Intel Sapphire Rapids"
#    ;;
esac

# adjust disk_spec parameters
CSP="$(grep -E '^\s*csp\s*=' "$terraform_config_tf" | cut -f2 -d'"' | tail -n1 | tr 'a-z' 'A-Z')"
for e in $(compgen -e); do
    eval "line=\"$e=\$$e\""
    case "$line" in
    # ./ctest.sh --set SPOT_INSTANCE=false
    "SPOT_INSTANCE="*)
        override_number "" spot_instance default SPOT_INSTANCE
        ;;
    # RESERVED
    OWNER=*)
        override_string "" owner default OWNER
        ;;
    # RESERVED
    WL_NAME=*)
        override_string "" wl_name default WL_NAME
        ;;
    # RESERVED
    WL_NAMESPACE=*)
        override_string "" wl_namespace default WL_NAMESPACE
        ;;
    # RESERVED
    WL_REGISTRY_MAP=*)
        override_string "" wl_registry_map default WL_REGISTRY_MAP
        ;;
    esac
    if [ -n "$CSP" ]; then
        case "$line" in
        # ./ctest.sh --set KVM_WORKER_CPU_SET=1-4
        $CSP"_"*"_CPU_SET="*)
            override_string worker _profile cpu_set CPU_SET
            ;;
        # ./ctest.sh --set KVM_WORKER_NODE_SET=1-2
        $CSP"_"*"_NODE_SET="*)
            override_string worker _profile node_set NODE_SET
            ;;
        # ./ctest.sh --set ALICLOUD_WORKER_ACCELERATORS=vqat
        $CSP"_"*"_ACCELERATORS="*)
            override_string worker _profile accelerators ACCELERATORS
            ;;
        # ./ctest.sh --set AZURE_WORKER_INSTANCE_TYPE=m6i.x4large
        $CSP"_"*"_INSTANCE_TYPE="*)
            override_string worker _profile instance_type INSTANCE_TYPE
            ;;
        # ./ctest.sh --set AZURE_WORKER_CPU_MODEL_REGEX=8259CL
        $CSP"_"*"_CPU_MODEL_REGEX="*)
            override_string worker _profile cpu_model_regex CPU_MODEL_REGEX
            ;;
        # ./ctest.sh --set GCP_WORKER_MIN_CPU_PLATFORM=INTEL ICE LAKE
        $CSP"_"*"_MIN_CPU_PLATFORM="*)
            override_string worker _profile min_cpu_platform MIN_CPU_PLATFORM
            ;;
        # ./ctest.sh --set GCP_WORKER_THREADS_PER_CORE=1
        $CSP"_"*"_THREADS_PER_CORE="*)
            override_number worker _profile threads_per_core THREADS_PER_CORE
            ;;
        # ./ctest.sh --set GCP_WORKER_CPU_CORE_COUNT=1
        $CSP"_"*"_CPU_CORE_COUNT="*)
            override_number worker _profile cpu_core_count CPU_CORE_COUNT
            ;;
        # ./ctest.sh --set ORACLE_WORKER_MEMORY_SIZE=4
        $CSP"_"*"_MEMORY_SIZE="*)
            override_number worker _profile memory_size MEMORY_SIZE
            ;;
        # ./ctest.sh --set GCP_WORKER_NIC_TYPE=GVNIC
        $CSP"_"*"_NIC_TYPE="*)
            override_string worker _profile nic_type NIC_TYPE
            ;;
        # ./ctest.sh --set AZURE_WORKER_OS_IMAGE=xxxyyyzzz
        $CSP"_"*"_OS_IMAGE="*)
            override_string worker _profile os_image OS_IMAGE
            ;;
        # ./ctest.sh --set AZURE_WORKER_OS_TYPE=ubuntu2004
        $CSP"_"*"_OS_TYPE="*)
            override_string worker _profile os_type OS_TYPE
            ;;
        # ./ctest.sh --set AZURE_WORKER_OS_DISK_SIZE=100
        $CSP"_"*"_OS_DISK_SIZE="*)
            override_number worker _profile os_disk_size OS_DISK_SIZE
            ;;
        # ./ctest.sh --set AWS_WORKER_OS_DISK_IOPS=64000
        $CSP"_"*"_OS_DISK_IOPS="*)
            override_number worker _profile os_disk_iops OS_DISK_IOPS
            ;;
        # ./ctest.sh --set AWS_WORKER_OS_DISK_THROUGHPUT=3000
        $CSP"_"*"_OS_DISK_THROUGHPUT="*)
            override_number worker _profile os_disk_throughput OS_DISK_THROUGHPUT
            ;;
        # ./ctest.sh --set AZURE_WORKER_OS_DISK_TYPE=gp2
        $CSP"_"*"_OS_DISK_TYPE="*)
            override_string worker _profile os_disk_type OS_DISK_TYPE
            ;;
        # ./ctest.sh --set AZURE_DISK_SPEC_1_DISK_FORMAT=ext4
        $CSP"_DISK_SPEC_"*"_DISK_FORMAT="*)
            override_string 1 disk_spec_ disk_format DISK_FORMAT
            ;;
        # ./ctest.sh --set KVM_DISK_SPEC_1_DISK_POOL=mypool
        $CSP"_DISK_SPEC_"*"_DISK_POOL="*)
            override_string 1 disk_spec_ disk_pool DISK_POOL
            ;;
        # ./ctest.sh --set AZURE_DISK_SPEC_1_DISK_TYPE=Premium_LRS
        $CSP"_DISK_SPEC_"*"_DISK_TYPE="*)
            override_string 1 disk_spec_ disk_type DISK_TYPE
            ;;
        # ./ctest.sh --set AZURE_DISK_SPEC_1_DISK_COUNT=1
        $CSP"_DISK_SPEC_"*"_DISK_COUNT="*)
            override_number 1 disk_spec_ disk_count DISK_COUNT
            ;;
        # ./ctest.sh --set AZURE_DISK_SPEC_1_DISK_SIZE=200
        $CSP"_DISK_SPEC_"*"_DISK_SIZE="*)
            override_number 1 disk_spec_ disk_size DISK_SIZE
            ;;
        # ./ctest.sh --set AZURE_DISK_SPEC_1_DISK_IOPS=null
        $CSP"_DISK_SPEC_"*"_DISK_IOPS="*)
            override_number 1 disk_spec_ disk_iops DISK_IOPS
            ;;
        # ./ctest.sh --set AZURE_DISK_SPEC_1_DISK_THROUGHPUT=null
        $CSP"_DISK_SPEC_"*"_DISK_THROUGHPUT="*)
            override_number 1 disk_spec_ disk_throughput DISK_THROUGHPUT
            ;;
        # ./ctest.sh --set AZURE_DISK_SPEC_1_DISK_PERFORMANCE=null
        $CSP"_DISK_SPEC_"*"_DISK_PERFORMANCE="*)
            override_string 1 disk_spec_ disk_performance DISK_PERFORMANCE
            ;;
        # ./ctest.sh --set AZURE_NETWORK_SPEC_1_NETWORK_COUNT=1
        $CSP"_NETWORK_SPEC_"*"_NETWORK_COUNT="*)
            override_number 1 network_spec_ network_count NETWORK_COUNT
            ;;
        # ./ctest.sh --set AZURE_NETWORK_SPEC_1_NETWORK_TYPE=1
        $CSP"_NETWORK_SPEC_"*"_NETWORK_TYPE="*)
            override_string 1 network_spec_ network_type NETWORK_TYPE
            ;;
        # ./ctest.sh --set AZURE_REGION=uswest
        $CSP"_REGION="*)
            override_string "" region default REGION
            ;;
        # ./ctest.sh --set AZURE_ZONE=uswest
        $CSP"_ZONE="*)
            override_string "" zone default ZONE
            ;;
        # ./ctest.sh --set AZURE_CUSTOM_TAGS='x=y,s=t'
        $CSP"_CUSTOM_TAGS="*)
            line="$(echo "$line" | cut -f1 -d=)=$(echo "$line" | cut -f2- -d= | sed 's/\([^,=]*\)=*\([^,]*\)/\"\1\" = \"\2\"/g')"
            override_dict "" custom_tags default CUSTOM_TAGS
            ;;
        # ./ctest.sh --set ALICLOUD_RESOURCE_GROUP_ID=xyz
        $CSP"_RESOURCE_GROUP_ID="*)
            override_string "" resource_group_id default RESOURCE_GROUP_ID
            ;;
        # ./ctest.sh --set ORACLE_COMPARTMENT=xyz
        $CSP"_COMPARTMENT="*)
            override_string "" compartment default COMPARTMENT
            ;;
        esac
    else
        case "$line" in
        STATIC_*_*=*)
            override_static_host
            ;;
        esac
    fi
done

