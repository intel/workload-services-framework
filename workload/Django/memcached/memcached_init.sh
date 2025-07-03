#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# This script will configure and start the memcached service inside a docker
# container

if [ -f /etc/memcached.conf ]; then
    mv /etc/memcached.conf /etc/memcached.conf.old
    echo -e "\n\nBackup /etc/memcached.conf to /etc/memcached.conf.old"
fi

. /scripts/memcached.cfg

echo -e "\n\nWrite memcached config file ..."
cat > /etc/memcached.conf <<- EOF
	# Daemon mode
	-d
	logfile /var/log/memcached.log
	-m "$MEMCACHE_MEMORY"
	-p "$PORT"
	-u "$USER"
	-l "$LISTEN"
	-t "$MEMCACHE_THREAD"
EOF

service memcached start  \
    && tail -f /dev/null
