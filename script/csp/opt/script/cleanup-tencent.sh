#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

. "$(dirname "$0")"/cleanup-common.sh

read_regions tencent
has_image=0
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

        echo
        echo "Scanning images..."
        for image in $(tccli cvm DescribeImages --region $region1 --output=json | jq ".ImageSet[] | select(.Tags.Tag[].TagValue | test(\"$OWNER\")) | .ImageId" 2>/dev/null | tr -d '"'); do
            echo "image: $image"
            if [[ "$@" = *"--images"* ]]; then
                resources+=($image)
                (set -x; tccli cvm DeleteImages --region $region1 --ImageIds "[\"$image\"]")
            else
                has_image=1
            fi
        done

        [ "${#resources[@]}" -eq 0 ] && break
    done

    echo "Scanning key pairs..."
    for kp in $(tccli cvm DescribeKeyPairs --region $region1 --output=json | grep KeyIds | cut -f4 -d'"'); do
        (set -x; tccli cvm DeleteKeyPairs --region $region1 --KeyIds "[\"$kp\"]")
    done
done

if [ $has_image -eq 1 ]; then
    echo "VM images are left untouched."
    echo "Use 'cleanup --images' to clean up VM images"
else
    delete_regions tencent
fi
