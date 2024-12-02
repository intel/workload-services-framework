#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

parse_key_value () {
  awk -v owner="$OWNER" -v key="$1" -v this="" '
/"freeform_tags":/ {
  this=""
}
/"owner":/ {
  split($0,fields,"\"")
  this=fields[4]
}
$1==key && this==owner {
  split($0,fields,"\"")
  print fields[4]
}'
}

zone_to_region () {
    zglist=(
        "SYD:ap-sydney-1"
        "MEL:ap-melbourne-1"
        "GRU:sa-saopaulo-1"
        "VCP:sa-vinhedo-1"
        "YUL:ca-montreal-1"
        "YYZ:ca-toronto-1"
        "SCL:sa-santiago-1"
        "CDG:eu-paris-1"
        "MRS:eu-marseille-1"
        "FRA:eu-frankfurt-1"
        "HYD:ap-hyderabad-1"
        "BOM:ap-mumbai-1"
        "MTZ:il-jerusalem-1"
        "LIN:eu-milan-1"
        "KIX:ap-osaka-1"
        "NRT:ap-tokyo-1"
        "QRO:mx-queretaro-1"
        "AMS:eu-amsterdam-1"
        "JED:me-jeddah-1"
        "SIN:ap-singapore-1"
        "JNB:af-johannesburg-1"
        "ICN:ap-seoul-1"
        "YNY:ap-chuncheon-1"
        "MAD:eu-madrid-1"
        "ARN:eu-stockholm-1"
        "ZRH:eu-zurich-1"
        "AUH:me-abudhabi-1"
        "UAE:me-dubai-1"
        "LHR:uk-london-1"
        "CWL:uk-cardiff-1"
        "IAD:us-ashburn-1"
        "ORD:us-chicago-1"
        "PHX:us-phoenix-1"
        "SJC:us-sanjose-1"
    )
    for zg in ${zglist[@]}; do
        if [[ "$1" = *":${zg/:*/}-"* ]]; then
            echo ${zg/*:/}
        fi
    done
}


scan_vcn () {
    for id in $(oci network vcn list --region $region --compartment-id $compartment --all | parse_key_value '"id":'); do
        echo "vcn: $id"
        (set -x; oci network vcn delete --region $region --vcn-id $id --force)
        resources+=("$id")
    done
}

scan_security_list () {
    for id in $(oci network security-list list --region $region --compartment-id $compartment --all | parse_key_value '"id":'); do
        echo "security-list: $id"
        (set -x; oci network security-list delete --region $region --security-list-id $id --force)
        resources+=("$id")
    done
}

scan_subnet () {
    for id in $(oci network subnet list --region $region --compartment-id $compartment --all | parse_key_value '"id":'); do
        echo "subnet: $id"
        (set -x; oci network subnet delete --region $region --subnet-id $id --force)
        resources+=("$id")
    done
}

scan_route_table () {
    for id in $(oci network route-table list --region $region --compartment-id $compartment --all | parse_key_value '"id":'); do
        echo "route-table: $id"
        (set -x; oci network route-table delete --region $region --rt-id $id --force)
        resources+=("$id")
    done
}

scan_internet_gateway () {
    for id in $(oci network internet-gateway list --region $region --compartment-id $compartment --all | parse_key_value '"id":'); do
        echo "internet-gateway: $id"
        (set -x; oci network internet-gateway delete --region $region --ig-id $id --force)
        resources+=("$id")
    done
}

scan_compute_image () {
    for id in $(oci compute image list --region $region --compartment-id $compartment --all | parse_key_value '"id":'); do
        echo "compute image: $id"
        if [[ "$@" = *"--images"* ]]; then
            (set -x; oci compute image delete --region $region --image-id $id --force)
            resources+=("$id")
        else
            has_image=1
        fi
    done
}

scan_compute_instance () {
    instances=($(oci compute instance list --region $region --compartment-id $compartment --lifecycle-state TERMINATED --all | parse_key_value '"id":'))
    for id in $(oci compute instance list --region $region --compartment-id $compartment --all | parse_key_value '"id":'); do
        [ -z "$(for t in ${instances[@]}; do [ "$id" != "$t" ] || echo "$id"; done)" ] || continue
        echo "compute instance: $id"

        for vid in $(oci compute instance list-vnics --region $region --compartment-id $compartment --instance-id $id --all | parse_key_value '"id":'); do
            echo "compute instance: $id vnic $vid"
            (set -x; oci compute instance detach-vnic --region $region --compartment-id $compartment --vnic-id $vid --force)
            resources+=("$vid")
        done

        for vid in $(oci compute volume-attachment list --region $region --compartment-id $compartment --instance-id $id --all | parse_key_value '"id":'); do
            echo "compute instance: $id volume $vid"
            (set -x; oci compute volume-attachment detach --region $region --volume-attachment-id $vid --force)
            resource+=("$vid")
        done

        (set -x; oci compute instance terminate --region $region --instance-id $id --force)
        resources+=("$id")
    done
}

. "$(dirname "$0")"/cleanup-common.sh

read_regions oracle
export -pf parse_key_value zone_to_region
has_image=0
for regionres in "${REGIONS[@]}"; do
    zone="${regionres/,*/}"
    region="$(zone_to_region "$zone")"
    if [ -n "$region" ]; then
        echo "region: $region"

        while true; do
            resources=()

            for compartment in "${regionres/*,/}"; do
                echo
                echo "compartment: $compartment"

                scan_security_list
                scan_route_table
                scan_compute_instance 
                scan_internet_gateway
                scan_subnet
                scan_vcn
                scan_compute_image $@
            done
            [ "${#resources[@]}" -eq 0 ] && break
        done
    fi
done

if [ $has_image -eq 1 ]; then
    echo "VM images are left untouched."
    echo "Use 'cleanup --images' to clean up VM images"
else
    delete_regions oracle
fi
