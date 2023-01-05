#!/bin/bash

. cleanup-common.sh

read_regions tencent
for regionres in "${REGIONS[@]}"; do
    region="${regionres/,*/}"
    echo "region: $region"
    region1=$(echo $region | cut -f1-2 -d-)

    while true; do
        resources=()

        echo
        echo "Scanning cvm..."
        for iid in $(tccli cvm DescribeInstances --region $region1 --output=json | awk '/"InstanceId":/{print$NF}' | tr -d '",'); do
            echo "cvm: $iid"
            resources+=($iid)
            (set -x; tccli cvm TerminateInstances --region $region1 --InstanceIds "[\"$iid\"]") 
        done

        echo
        echo "Scanning vpcs..."
        for vpc in $(tccli vpc DescribeVpcs --region $region1 --output=json | awk '/"VpcId":/{print$NF}' | tr -d '",'); do
            echo "vpc: $vpc"
            resources+=($vpc)
            (set -x; tccli vpc DeleteVpc --region $region1 --VpcId $vpc)
        done

        [ "${#resources[@]}" -eq 0 ] && break
    done

    echo "Scanning key pairs..."
    for kp in $(tccli cvm DescribeKeyPairs --region $region1 --output=json | grep KeyIds | cut -f4 -d'"'); do
        (set -x; tccli cvm DeleteKeyPairs --region $region1 --KeyIds "[\"$kp\"]")
    done
done
delete_regions tencent
