#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# For most workloads, the build.sh can be used as is. 
# The build process will follow certain order to detect Dockerfiles and build the 
# docker images accordingly. The build process can be customized through DOCKER_CONTEXT 
# and FIND_OPTIONS. DOCKER_CONTEXT specifies the list of build contexts and FIND_OPTIONS 
# defines special rules to find a subset of Dockerfiles. 
# See doc/build.sh.md for full documentation. 
# See SpecCpu-2017 for working with multiple workload versions using FIND_OPTIONS. 
# See QATzip for building workloads with software stacks
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
MYSQL_USECASE="base"
STACK="mysql" USECASE=$MYSQL_USECASE "$DIR/../../stack/mysql/build.sh" $@

#DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR"/../../script/build.sh

