#!/bin/bash

REGION_DIR="/opt/build/.regions"
REGION_DIR_LOCK="/opt/build/.regions.lock"

read_regions () {
  REGIONS=($(flock "$REGION_DIR_LOCK" cat "$REGION_DIR/$1" | sort | uniq))
}

delete_regions () {
  csp=$1
  for region in "${REGIONS[@]}"; do
    flock "$REGION_DIR_LOCK" bash -c "
      grep -v -F '$region' '$REGION_DIR/$csp' > '$REGION_DIR/$csp.tmp';
      mv -f '$REGION_DIR/$csp.tmp' '$REGION_DIR/$csp';
    "
  done
}

OWNER="${OWNER:-$(env | grep _OPTIONS= | tr ' ' '\n' | grep -F owner= | cut -f2 -d= | tr -c -d 'a-z0-9-')}"
OWNER="${OWNER:-$(grep -E "^\s*name\s*=" $HOME/.gitconfig | cut -f2 -d= | tr -c -d 'a-z0-9-')}"
OWNER="${OWNER:-$(env | grep _USER= | cut -f2 -d= | tr -c -d 'a-z0-9-')}"

