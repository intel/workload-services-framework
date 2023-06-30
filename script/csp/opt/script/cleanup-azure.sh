#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

. "$(dirname "$0")"/cleanup-common.sh

read_regions azure
has_image=0
while true; do
    resources=()

    echo
    echo "Scanning resource groups..."
    for group in $(az group list --query "[?tags.owner=='$OWNER']"| awk '/"id":/{print$NF}' | tr -d '",' | sed 's|.*/||'); do
        echo "Resource Group: $group"
        if [[ "$group" = *"-image-rg" ]]; then
            if [[ "$@" = *"--images"* ]]; then
                resources+=($group)
                (set -x; az group delete --resource-group $group --yes)
            else
                has_image=1
            fi
        else
            resources+=($group)
            (set -x; az group delete --resource-group $group --yes)
        fi
    done

    [ "${#resources[@]}" -eq 0 ] && break
done

if [ $has_image -eq 1 ]; then
    echo "VM images are left untouched."
    echo "Use 'cleanup --images' to clean up VM images"
else
    delete_regions azure
fi
