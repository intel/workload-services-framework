#!/bin/bash -e

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

clouds="$(
    for x in $TERRAFORM_SUT $PACKER_SUT; do 
        [ -r "$DIR/terraform-config.$x.tf" ] && grep -E '^\s*csp\s*=' "$DIR"/terraform-config.$x.tf
    done | awk -F'"' '{a[$2]=1}END{for(x in a)print x}'
)"

FIND_OPTIONS="-name Dockerfile.*.terraform"
([[ "$clouds" = *aws* ]] || [ "$REGISTRY" = "amr-registry-pre.caas.intel.com/sf-cwr-test/" ]) && FIND_OPTIONS="$FIND_OPTIONS -o -name Dockerfile.*.aws"
[[ "$clouds" = *gcp* ]] && FIND_OPTIONS="$FIND_OPTIONS -o -name Dockerfile.*.gcp"
[[ "$clouds" = *azure* ]] && FIND_OPTIONS="$FIND_OPTIONS -o -name Dockerfile.*.azure"
[[ "$clouds" = *tencent* ]] && FIND_OPTIONS="$FIND_OPTIONS -o -name Dockerfile.*.tencent"
[[ "$clouds" = *alicloud* ]] && FIND_OPTIONS="$FIND_OPTIONS -o -name Dockerfile.*.alicloud"
[[ "$clouds" = *vsphere* ]] && FIND_OPTIONS="$FIND_OPTIONS -o -name Dockerfile.*.vsphere"
[ -r "$DIR"/Dockerfile.*.static-int ] && FIND_OPTIONS="$FIND_OPTIONS -o -name Dockerfile.*.static-int" || FIND_OPTIONS="$FIND_OPTIONS -o -name Dockerfile.*.static-ext"
FIND_OPTIONS="( $FIND_OPTIONS )"
. $DIR/../build.sh
