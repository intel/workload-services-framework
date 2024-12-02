#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

ulimit -n 65535
PORT=${PORT:-8080}
GATED=${GATED:-""}
NTHREADS=${NTHREADS:-4}
DIR=$(dirname $(readlink -f "$0"))
NUSERS=${NUSERS:-400}
DURATION=${DURATION:-60}
NICIP_W1=${NICIP_W1:-192.168.2.200}
STORAGE_MEDIUM=${STORAGE_MEDIUM:-disk}
LUASCRIPT=${LUASCRIPT:-$DIR/query.lua}
KEEPALIVE=${KEEPALIVE:-"true"}
URL_NUM=${URL_NUM:-100000}

if [[ "$PORT" == "8080" ]];then
    if [[ "$GATED" == "gated" ]];then
        URL=http://cachenginxurl #gated test
    else
        URL=http://${NICIP_W1} #performance test, modify to the bond0 ip you configured(See README.md).
    fi
else
    if [[ "$GATED" == "gated" ]];then
        URL=https://cachenginxurl #gated test
    else
        URL=https://${NICIP_W1}  #performance test, modify to bond0 ip you configured(See README.md).
    fi
fi


if [[ "$NTHREADS" -gt "$NUSERS" ]]; then
   NTHREADS="$NUSERS"
fi

if [[ "$URL_NUM" -gt 0 ]]; then
    sed -i "s|math.random(800000)|math.random($URL_NUM)|" $LUASCRIPT
fi

for i in {1..10}; do
    sleep 1s
    echo "test pass $i"

    # fill cache
    if [ "$GATED" == "gated" ]; then
        DURATION=6
    else
        if [ "$STORAGE_MEDIUM" = "disk" ]; then
            timeout 660s wrk -t $NTHREADS -c $NUSERS -d 600s -s $LUASCRIPT --timeout 10s $URL:$PORT || continue
        else
            timeout 360s wrk -t $NTHREADS -c $NUSERS -d 300s -s $LUASCRIPT --timeout 10s $URL:$PORT || continue
        fi
        sleep 10
        (sleep 10 && echo "begin_region_of_interest") &
        (sleep 20 && echo "end_region_of_interest") &
    fi

    # read cache
    if [[ "$KEEPALIVE" == "false" ]]; then
        timeout $((DURATION+60))s wrk -H 'Connection: Close' -t $NTHREADS -c $NUSERS -d ${DURATION}s -s $LUASCRIPT --timeout 10s -L $URL:$PORT && exit 0 || continue
    else
        timeout $((DURATION+60))s wrk -t $NTHREADS -c $NUSERS -d ${DURATION}s -s $LUASCRIPT --timeout 10s -L $URL:$PORT && exit 0 || continue
    fi
    
done
exit 3
