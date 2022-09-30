#!/bin/bash

DRYRUN="$(echo "-- $CUMULUS_OPTIONS" | tr ' ' '\n' | grep -- --dry-run)"
OWNER="$(echo "-- $CUMULUS_OPTIONS" | tr ' ' '\n' | grep -- --owner | cut -f2 -d=)"
OWNER="${OWNER:-$( (git config user.name || id -un) 2> /dev/null | tr ' ' '-')}"
echo "OWNER=$OWNER"

while true; do
    resources=()

    echo
    echo "Scanning resource groups..."
    for group in $(az group list --query "[?tags.owner=='$OWNER']"| awk '/"id":/{print$NF}' | tr -d '",' | sed 's|.*/||'); do
        echo "Resource Group: $group"
        resources+=($group)
        [ -z "$DRYRUN" ] && (set -x; az group delete --resource-group $group --yes)
    done

    [ "${#resources[@]}" -eq 0 ] && break
done
