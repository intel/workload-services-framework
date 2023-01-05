#!/bin/bash

. cleanup-common.sh

read_regions alicloud
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
            for iid in $(aliyun ecs DescribeInstances --RegionId $region $rg | jq '.Instances.Instance[] | select(.InstanceName | test("(wsf|perfkit)-.*")) | .InstanceId' 2>/dev/null | tr -d '"'); do
                echo "instance: $iid"
                resources+=($iid)
                (set -x; aliyun ecs DeleteInstance --InstanceId $iid --Force true) 
            done

            echo
            echo "Scanning vpcs..."
            for vpc in $(aliyun vpc DescribeVpcs --RegionId $region $rg | jq '.Vpcs.Vpc[] | select(.VpcName | test("(wsf|perfkit)-.*")) | .VpcId' 2>/dev/null | tr -d '"'); do
                echo "vpc: $vpc"
                resources+=($vpc)
                (set -x; aliyun vpc DeleteVpc --RegionId $region --VpcId $vpc)
            done

            echo
            echo "Scanning IP Address..."
            for eip in $(aliyun vpc DescribeEipAddresses --RegionId $region $rg | jq '.EipAddresses[] | select(.Name | test("(wsf|perfkit)-.*")) | .AllocationId' 2>/dev/null | tr -d '"'); do
                echo "IP Address: $eip"
                resources+=($eip)
                (set -x; aliyun vpc ReleaseEipAddress --RegionId $region --AllocationId $eip)
            done

            echo
            echo "Scanning Security Group..."
            for sg in $(aliyun ecs DescribeSecurityGroups --RegionId $region $rg | jq '.SecurityGroups.SecurityGroup[] | select(.SecurityGroupName | test("(wsf|perfkit)-.*")) | .SecurityGroupId' 2>/dev/null | tr -d '"'); do
                echo "Security Group: $sg"
                resources+=($sg)
                (set -x; aliyun ecs DeleteSecurityGroup --RegionId $region --SecurityGroupId $sg)
            done

            echo
            echo "Scanning VSwitch..."
            for vsid in $(aliyun vpc DescribeVSwitches --RegionId $region $rg | jq '.VSwitches.VSwitch[] | select(.VSwitchName | test("(wsf|perfkit)-.*")) | .VSwitchId' 2>/dev/null | tr -d '"'); do
                echo "VSwitch: $vsid"
                resources+=($vsid)
                (set -x; aliyun vpc DeleteVSwitch --RegionId $region --VSwitchId $vsid)
            done

            echo
            echo "Scanning KeyPair..."
            for kp in $(aliyun ecs DescribeKeyPairs --RegionId $region $rg | jq '.KeyPairs.KeyPair[] | select(.KeyPairName | test("wsf-.*")) | .KeyPairId' 2>/dev/null | tr -d '"'); do
                echo "KeyPair: $kp"
                resources+=($kp)
                (set -x; aliyun ecs DeleteKeyPairs --RegionId $region --KeyPairId $kp)
            done
        done

        [ "${#resources[@]}" -eq 0 ] && break
    done
done
delete_regions alicloud
