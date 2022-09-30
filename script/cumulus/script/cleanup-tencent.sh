#!/bin/bash

DRYRUN="$(echo "-- $CUMULUS_OPTIONS" | tr ' ' '\n' | grep -- --dry-run)"
OWNER="$(echo "-- $CUMULUS_OPTIONS" | tr ' ' '\n' | grep -- --owner | cut -f2 -d=)"
OWNER="${OWNER:-$( (git config user.name || id -un) 2> /dev/null | tr ' ' '-')}"
echo "OWNER=$OWNER"

region_list_array=($(find /home -name "cumulus-config.*.yaml" -exec sh -c "grep -E 'cloud: *Tencent' '{}' > /dev/null" \; -exec grep zone: "{}" \; | awk '{print$NF}' | sort| uniq))

for region in "${region_list_array[@]}" ; do
    echo "region: $region"
    region1=$(echo $region | cut -f1-2 -d-)

    while true; do
        resources=()

        echo
        echo "Scanning cvm..."
        for iid in $(tccli cvm DescribeInstances --region $region1 --output=json | awk '/"InstanceId":/{print$NF}' | tr -d '",'); do
            echo "cvm: $iid"
            resources+=($iid)
            [ -z "$DRYRUN" ] && (set -x; tccli cvm TerminateInstances --region $region1 --InstanceIds "[\"$iid\"]") 
        done

        echo
        echo "Scanning vpcs..."
        for vpc in $(tccli vpc DescribeVpcs --region $region1 --output=json | awk '/"VpcId":/{print$NF}' | tr -d '",'); do
            echo "vpc: $vpc"
            resources+=($vpc)
            [ -z "$DRYRUN" ] && (set -x; tccli vpc DeleteVpc --region $region1 --VpcId $vpc)
        done

        [ "${#resources[@]}" -eq 0 ] && break
    done

    echo "Scanning key pairs..."
    for kp in $(tccli cvm DescribeKeyPairs --region $region1 --output=json | grep KeyIds | cut -f4 -d'"'); do
        [ -z "$DRYRUN" ] && (set -x; tccli cvm DeleteKeyPairs --region $region1 --KeyIds "[\"$kp\"]")
    done

done
