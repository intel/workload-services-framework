#!/bin/bash -e

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

clouds="$(
for x in $CUMULUS_SUT; do 
    grep cloud: "$DIR"/cumulus-config.$x.yaml
done | awk '{a[$NF]=1}END{for(x in a)print x}'
)"

FIND_OPTIONS="-name Dockerfile.*.static"
[[ "$clouds" = *AWS* ]] && FIND_OPTIONS="$FIND_OPTIONS -o -name Dockerfile.*.aws -o -name Dockerfile.*.cloud"
[[ "$clouds" = *GCP* ]] && FIND_OPTIONS="$FIND_OPTIONS -o -name Dockerfile.*.gcp -o -name Dockerfile.*.cloud"
[[ "$clouds" = *Azure* ]] && FIND_OPTIONS="$FIND_OPTIONS -o -name Dockerfile.*.azure -o -name Dockerfile.*.cloud"
[[ "$clouds" = *Tencent* ]] && FIND_OPTIONS="$FIND_OPTIONS -o -name Dockerfile.*.tencent -o -name Dockerfile.*.cloud"
[[ "$clouds" = *AliCloud* ]] && FIND_OPTIONS="$FIND_OPTIONS -o -name Dockerfile.*.alicloud -o -name Dockerfile.*.cloud"
FIND_OPTIONS="( $FIND_OPTIONS )"
. $DIR/../build.sh
