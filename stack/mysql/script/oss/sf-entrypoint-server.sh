#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
cd /home
TEMP_PASSWORD=$(mysqld --defaults-file="/home/mysql/my.cnf" --initialize --console 2>&1 |  grep root@localhost | awk -F": " '{print $2}')
echo "start MYSQL server"
mysqld --defaults-file="/home/mysql/my.cnf" --user=root&

echo "sleep 10 second for MYSQL init"
sleep 10

# change to default password
cat <<EOM > /home/mysql/postInit.sql
ALTER USER 'root'@'localhost' IDENTIFIED BY 'mysql';
CREATE USER 'root'@'%' IDENTIFIED BY 'mysql';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
flush privileges;
EOM

mysql -S /tmp/mysql.sock -u root --connect-expired-password --password=$TEMP_PASSWORD < /home/mysql/postInit.sql
echo "MYSQL READY"

# since mysqld were started on detached-mode
# need to add sleep infinity so container will continue running
sleep infinity
