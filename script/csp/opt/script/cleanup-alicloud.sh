#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

. "$(dirname "$0")"/cleanup-common.sh

read_regions alicloud
has_image=0
for regionres in "${REGIONS[@]}"; do
    region=$(echo ${regionres/,*/} | cut -f1-2 -d-)
    echo "region: $region"

    while true; do
        resources=()

        for rg in "${regionres/*,/}"; do
            echo
            echo "Resource group: $rg"
            [ -n "$rg" ] && rg="--ResourceGroupId $rg"

            echo
            echo "Scanning instance..."
            for iid in $(aliyun ecs DescribeInstances --RegionId $region $rg --PageSize=100 | jq ".Instances.Instance[] | select(.Tags.Tag[].TagValue | test(\"$OWNER\")) | .InstanceId" 2>/dev/null | tr -d '"'); do
                echo "instance: $iid"
                resources+=($iid)
                (set -x; aliyun ecs DeleteInstance --InstanceId $iid --Force true) 
            done

            echo
            echo "Scanning vpcs..."
            for vpc in $(aliyun vpc DescribeVpcs --RegionId $region $rg | jq ".Vpcs.Vpc[] | select(.Tags.Tag[].TagValue | test(\"$OWNER\")) | .VpcId" 2>/dev/null | tr -d '"'); do
                echo "vpc: $vpc"
                resources+=($vpc)
                (set -x; aliyun vpc DeleteVpc --RegionId $region --VpcId $vpc)
            done

            echo
            echo "Scanning IP Address..."
            for eip in $(aliyun vpc DescribeEipAddresses --RegionId $region $rg | jq ".EipAddresses[] | select(.Tags.Tag[].TagValue | test(\"$OWNER\")) | .AllocationId" 2>/dev/null | tr -d '"'); do
                echo "IP Address: $eip"
                resources+=($eip)
                (set -x; aliyun vpc ReleaseEipAddress --RegionId $region --AllocationId $eip)
            done

            echo
            echo "Scanning Security Group..."
            for sg in $(aliyun ecs DescribeSecurityGroups --RegionId $region $rg | jq ".SecurityGroups.SecurityGroup[] | select(.Tags.Tag[].TagValue | test(\"$OWNER\")) | .SecurityGroupId" 2>/dev/null | tr -d '"'); do
                echo "Security Group: $sg"
                resources+=($sg)
                (set -x; aliyun ecs DeleteSecurityGroup --RegionId $region --SecurityGroupId $sg)
            done

            echo
            echo "Scanning VSwitch..."
            for vsid in $(aliyun vpc DescribeVSwitches --RegionId $region $rg | jq ".VSwitches.VSwitch[] | select(.Tags.Tag[].TagValue | test(\"$OWNER\")) | .VSwitchId" 2>/dev/null | tr -d '"'); do
                echo "VSwitch: $vsid"
                resources+=($vsid)
                (set -x; aliyun vpc DeleteVSwitch --RegionId $region --VSwitchId $vsid)
            done

            echo
            echo "Scanning KeyPair..."
            for kp in $(aliyun ecs DescribeKeyPairs --RegionId $region $rg | jq ".KeyPairs.KeyPair[] | select(.Tags.Tag[].TagValue | test(\"$OWNER\")) | .KeyPairId" 2>/dev/null | tr -d '"'); do
                echo "KeyPair: $kp"
                resources+=($kp)
                (set -x; aliyun ecs DeleteKeyPairs --RegionId $region --KeyPairId $kp)
            done

            echo
            echo "Scanning images..."
            for image in $(aliyun ecs DescribeImages --RegionId $region $rg --PageSize=100 | jq ".Images.Image[] | select(.Tags.Tag[].TagValue | test(\"$OWNER\")) | .ImageId" 2>/dev/null | tr -d '"'); do
                echo "image: $image"
                if [[ "$@" = *"--images"* ]]; then
                    resources+=($image)
                    (set -x; aliyun ecs DeleteImage --RegionId $region --ImageId $image --Force=true)
                else
                    has_image=1
                fi
            done

            echo
            echo "Scanning snapshots..."
            for ss in $(aliyun ecs DescribeSnapshots --RegionId $region $rg --PageSize=100 | jq ".Snapshots.Snapshot[] | select(.Tags.Tag[].TagValue | test(\"$OWNER\")) | .SnapshotId" 2>/dev/null | tr -d '"'); do
                echo "snapshot: $ss"
                if [[ "$@" = *"--images"* ]]; then
                    resources+=($ss)
                    (set -x; aliyun ecs DeleteSnapshot --SnapshotId $ss --Force=true)
                else
                    has_image=1
                fi
            done
        done

        [ "${#resources[@]}" -eq 0 ] && break
    done
done

if [ $has_image -eq 1 ]; then
    echo "VM images are left untouched."
    echo "Use 'cleanup --images' to clean up VM images"
else
    delete_regions alicloud
fi
