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

WORKLOAD=${WORKLOAD:-"wordpress_wp5.6_php8.0"}
if [[ "$WORKLOAD" == *wp5.6_php8.0 ]]; then
    FIND_OPTIONS="( -name *wp56php80* -o -name *nginx*openssl11 -o -name *nginx*openssl31 -o -name *nginx -o -name *siege* ! -name *nginx_*_openssl314* )"
elif [[ "$WORKLOAD" == *wp6.4_php8.3 ]]; then
    FIND_OPTIONS="( -name *wp64php83* -o -name *nginx*openssl11 -o -name *nginx*openssl31 -o -name *nginx -o -name *siege*  )"
elif [[ "$WORKLOAD" == *wp6.5_php8.1 ]]; then
    FIND_OPTIONS="( -name *wp65php81* -o -name *nginx_*_openssl314*  -o -name *nginx -o -name *siege* )"
elif [[ "$WORKLOAD" == *wp6.7_php8.3 ]]; then
    FIND_OPTIONS="( -name *wp67php83* -o -name *nginx_*_openssl331*  -o -name *nginx_ubuntu2404 -o -name *siege_ubuntu2404* )"
fi

if [[ "$WORKLOAD" == *wp6.5_php8.1 ]]; then
    STACK="qatsw_ssl3_ubuntu_24.04.1" "$DIR/../../stack/QAT/build.sh" $@
elif [[ "$WORKLOAD" == *wp6.7_php8.3 ]]; then
    STACK="qatsw_ssl3_ubuntu2404" "$DIR/../../stack/QAT_UBUNTU2404/build.sh" $@
else
    STACK="qatsw_ssl3_ubuntu_23.43.1" "$DIR/../../stack/QAT/build.sh" $@
fi

echo "FIND_OPTIONS=$FIND_OPTIONS"

. "$DIR"/../../script/build.sh
