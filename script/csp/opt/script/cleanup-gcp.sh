#!/bin/bash

. cleanup-common.sh 

read_regions gcp

network_urls=()
for iid in $(gcloud compute instances list --filter "labels.owner:$OWNER" --format=yaml | awk '/^name:/{print$NF}' | tr -d '"'); do
    for url in $(gcloud compute instances list --filter "name:$iid" --format=yaml | awk '/subnetwork:/{print$NF}' | tr -d '"'); do
        network_urls+=($url)
    done
done

while true; do
    resources=()

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
        resources+=($im)
        (set -x; gcloud compute images delete --quiet $im)
    done

    [ "${#resources[@]}" -eq 0 ] && break
done
delete_regions gcp
