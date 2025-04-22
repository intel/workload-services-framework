#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
_term() { 
  echo "shutdown mysql server"
  kill -TERM "$child"
  echo "clean up data dir"
  rm -rf /var/lib/mysql/*
}
trap _term SIGTERM

sed -i "s/innodb_buffer_pool_size.*/innodb_buffer_pool_size=$MYSQL_INNODB_BUFFER_POOL_SIZE/g" /etc/mysql/conf.d/mysql.cnf
/prepare_database.sh
/usr/local/bin/docker-entrypoint.sh "$@" &
child=$! 
wait "$child"
