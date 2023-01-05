#!/bin/bash

. plugin_utils.sh

if is_ubuntu; then
    apt-get install -y sysstat
fi

if is_centos; then
    yum install -y sysstat
fi
