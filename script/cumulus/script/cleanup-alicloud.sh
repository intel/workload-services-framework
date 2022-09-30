#!/bin/bash

DRYRUN="$(echo "-- $CUMULUS_OPTIONS" | tr ' ' '\n' | grep -- --dry-run)"
OWNER="$(echo "-- $CUMULUS_OPTIONS" | tr ' ' '\n' | grep -- --owner | cut -f2 -d=)"
OWNER="${OWNER:-$( (git config user.name || id -un) 2> /dev/null | tr ' ' '-')}"
echo "OWNER=$OWNER"

region_list_array=($(find /home -name "cumulus-config.*.yaml" -exec sh -c "grep -E 'cloud: *AliCloud' '{}' > /dev/null" \; -exec grep zone: "{}" \; | awk '{print$NF}' | sort| uniq))
echo "regions: ${region_list_array[@]}"

resource_groups=($(find /home -name "cumulus-config.*.yaml" -exec grep ali_resource_group_id: '{}' \; | awk '{print $NF}' | tr -d '"' | sort| uniq))
[ ${#resource_groups[@]} -eq 0 ] && resource_groups=("")
echo "resource groups: ${resource_groups[@]}"

for region in "${region_list_array[@]}" ; do
    echo "region: $region"
    region1=$(echo $region | cut -f1-2 -d-)

    while true; do
        resources=()

        for rg in ${resource_groups[@]}; do
            echo
            echo "Resource group: $rg"
            [ -n "$rg" ] && rg="--ResourceGroupId $rg"

            echo
            echo "Scanning instance..."
            for iid in $(aliyun ecs DescribeInstances --RegionId $region1 $rg | jq '.Instances.Instance[] | select(.InstanceName | test("perfkit-.*")) | .InstanceId' 2>/dev/null | tr -d '"'); do
                echo "instance: $iid"
                resources+=($iid)
                [ -z "$DRYRUN" ] && (set -x; aliyun ecs DeleteInstance --InstanceId $iid --Force true) 
            done

            echo
            echo "Scanning vpcs..."
            for vpc in $(aliyun vpc DescribeVpcs --RegionId $region1 $rg | jq '.Vpcs.Vpc[] | select(.VpcName | test("perfkit-.*")) | .VpcId' 2>/dev/null | tr -d '"'); do
                echo "vpc: $vpc"
                resources+=($vpc)
                [ -z "$DRYRUN" ] && (set -x; aliyun ecs DeleteVpc --RegionId $region1 --VpcId $vpc)
            done

            echo
            echo "Scanning IP Address..."
            for eip in $(aliyun vpc DescribeEipAddresses --RegionId $region1 $rg | jq '.EipAddresses[] | select(.Name | test("perfkit-.*")) | .AllocationId' 2>/dev/null | tr -d '"'); do
                echo "IP Address: $eip"
                resources+=($eip)
                [ -z "$DRYRUN" ] && (set -x; aliyun ecs ReleaseEipAddress --RegionId $region1 --AllocationId $eip)
            done

            echo
            echo "Scanning VSwitch..."
            for vsid in $(aliyun vpc DescribeVSwitches --RegionId $region1 $rg | jq '.VSwitches.VSwitch[] | select(.VSwitchName | test("perfkit-.*")) | .VSwitchId' 2>/dev/null | tr -d '"'); do
                echo "VSwitch: $vsid"
                resources+=($vsid)
                [ -z "$DRYRUN" ] && (set -x; aliyun vpc DeleteVSwitch --RegionId $region1 --VSiwtchId $vsid)
            done
        done

        [ "${#resources[@]}" -eq 0 ] && break
    done
done
