#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

WORKLOAD=${WORKLOAD:-clickhouse_xdr_hyperscan}

case ${WORKLOAD} in
    *internal_hyperscan* )
        FIND_OPTIONS="( $FIND_OPTIONS -name Dockerfile.?.internal_hyperscan* )"
        ;;
    *public_hyperscan* )
        FIND_OPTIONS="( $FIND_OPTIONS -name Dockerfile.?.public_hyperscan* )"
        ;;
    *vectorscan* )
        FIND_OPTIONS="( $FIND_OPTIONS -name Dockerfile.?.vectorscan* )"
        ;;
    * )
        FIND_OPTIONS=$FIND_OPTIONS
        ;;
esac

. "$DIR"/../../script/build.sh