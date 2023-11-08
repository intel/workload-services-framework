#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
WRKLOG_TIMEOUT=${WRKLOG_TIMEOUT:-240}

# For EVENT_TRACE_PARAMS
tail -F /OUTPUT/output1.log &

timeout ${WRKLOG_TIMEOUT/,*/}s bash -c "while ([ ! -f OUTPUT/status1 ]);do echo Waiting wrk test...;sleep 10s;done"
