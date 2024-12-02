#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

clouds="$(
    for x in $TERRAFORM_SUT $PACKER_SUT; do 
        [ -r "$DIR/terraform-config.$x.tf" ] && ( grep -m1 -E '^\s*csp\s*=' "$DIR"/terraform-config.$x.tf || echo '"static"' ) | cut -f2 -d'"'
    done
)"

FIND_OPTIONS="-name Dockerfile.*.terraform"

for c in "$DIR"/Dockerfile.1.*; do
    c="${c#"$DIR/Dockerfile.1."}"
    [[ "$clouds" = *$c* ]] && FIND_OPTIONS="$FIND_OPTIONS -o -name Dockerfile.1.$c"
done

[ -r "$DIR"/Dockerfile.*.static-int ] && FIND_OPTIONS="$FIND_OPTIONS -o -name Dockerfile.*.static-int" || FIND_OPTIONS="$FIND_OPTIONS -o -name Dockerfile.*.static-ext"
FIND_OPTIONS="( $FIND_OPTIONS )"
. "$DIR"/../build.sh
