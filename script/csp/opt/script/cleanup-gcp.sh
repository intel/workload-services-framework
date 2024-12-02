#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

. "$(dirname "$0")"/cleanup-common.sh 

read_regions gcp

network_urls=()
for iid in $(gcloud compute instances list --filter "labels.owner:$OWNER" --format=yaml | awk '/^name:/{print$NF}' | tr -d '"'); do
    for url in $(gcloud compute instances list --filter "name:$iid" --format=yaml | awk '/subnetwork:/{print$NF}' | tr -d '"'); do
        network_urls+=($url)
    done
done

has_image=0
while true; do
    resources=()

    for zone in ${REGIONS[@]}; do
        zone=${zone/,*/}
        echo
        echo "Scanning gke clusters...zone $zone"
        for gke in $(gcloud container clusters list --format json --zone $zone | tac | sed -n "/\"name\": \"wsf-$OWNER-.*-cluster\"/,/\"name\":/{/\"name\":/{p}}" | cut -f4 -d'"'); do
            echo "Cluster: $gke"
            (set -x; gcloud container clusters delete $gke --zone $zone --quiet)
            resources+=($gke)
        done

        echo 
        echo "Scanning artifacts...zone $zone"
        region=$(echo $zone | sed 's|[-][a-z]$||')
        for pos in $(gcloud artifacts repositories list --format json --location=$region | tac | sed -n "/\"name\": \"wsf-$OWNER-.*-gcr\"/,/\"name\":/{/\"name\":/{p}}" | cut -f4 -d'"'); do
            echo "Artifacts: $pos"
            (set -x; gcloud artifacts repositories delete $pos --location=$region --quiet)
            resources+=($pos)
        done
    done

    echo
    echo "Scanning instances..."
    for iid in $(gcloud compute instances list --filter "labels.owner:$OWNER" --format=yaml | awk '/^name:/{print$NF}' | tr -d '"'); do
        echo "Instance: $iid"
        resources+=($iid)
        zone=$(gcloud compute instances list --filter "name:$iid" --format=yaml | awk '/^zone:/{print$NF}' | tr -d '",')
        (set -x; gcloud compute instances delete $iid --zone=${zone/*\//} --quiet)
    done

    for url in ${network_urls[@]}; do
        net=${url/*\//}

        for url in $(gcloud compute networks list --filter "name:$net" --format=yaml | awk '/\/subnetworks\// && /^- / {print$NF}' | tr -d '"'); do
            subnet=${url/*\//}
            echo "Instance: $iid, subnet: $subnet"
            resources+=($subnet)
            region=$(echo $url | sed -e 's|.*/regions/||' -e 's|/.*||')
            (set -x; gcloud compute networks subnets delete $subnet --region=$region --quiet)
        done

        for net1 in $(gcloud compute networks list --filter "name:$net" --format=yaml | awk '/^name:/{print$NF}' | tr -d '"'); do
            echo "Instance: $iid, network: $net1"
            resources+=($net1)
            (set -x; gcloud compute networks delete $net1 --quiet)
        done

        for fwr in $(gcloud compute firewall-rules list --filter network:$net --format=yaml | awk '/^name:/{print$NF}' | tr -d '"'); do
            echo "Instance: $iid, firewall: $fwr"
            (set -x; gcloud compute firewall-rules delete $fwr --quiet)
        done
    done

    echo "Scaning Images..."
    for im in $(gcloud compute images list --filter "labels.owner=$OWNER" --format yaml | awk '/^name:/{print$NF}' | tr -d '"'); do
        echo "Image: $im"
        if [[ "$@" = *"--images"* ]]; then
            resources+=($im)
            (set -x; gcloud compute images delete --quiet $im)
        else
            has_image=1
        fi
    done

    [ "${#resources[@]}" -eq 0 ] && break
done

if [ $has_image -eq 1 ]; then
    echo "VM images are left untouched."
    echo "Use 'cleanup --images' to clean up VM images"
else
    delete_regions gcp
fi
