#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

csp="$1"

if [ -n "$csp" ]; then
  region1="$2,$3"
  region2="$4,$5"
  
  REGION_DIR="$BUILDROOT/.regions"
  REGION_DIR_LOCK="$BUILDROOT/.regions.lock"

  flock "$REGION_DIR_LOCK" bash -c "
    mkdir -p '$REGION_DIR';
    if [ -e '$REGION_DIR/$csp' ]; then
        echo '$region1' >> '$REGION_DIR/$csp';
    else  
        echo '$region1' >> '$REGION_DIR/$csp';  
        echo '$region2' >> '$REGION_DIR/$csp';  
    fi;
  "
fi
