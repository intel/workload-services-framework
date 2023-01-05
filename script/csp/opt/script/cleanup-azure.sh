#!/bin/bash

. cleanup-common.sh

read_regions azure
while true; do
    resources=()

    echo
    echo "Scanning resource groups..."
    for group in $(az group list --query "[?tags.owner=='$OWNER']"| awk '/"id":/{print$NF}' | tr -d '",' | sed 's|.*/||'); do
        echo "Resource Group: $group"
        resources+=($group)
        (set -x; az group delete --resource-group $group --yes)
    done

    [ "${#resources[@]}" -eq 0 ] && break
done
delete_regions azure
