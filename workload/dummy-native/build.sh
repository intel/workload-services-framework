#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# For native workloads, build.sh is not required.
# This is just a placeholder as some scripts may use 
# the existance of build.sh to locate a workload. 

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR"/../../script/build.sh

