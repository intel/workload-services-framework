#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
mkfifo /export-logs
cd /home/HammerDB-4.0/
sed -ie "s/127.0.0.1/${DB_HOST}/g" *.tcl

echo "SF: append wait mechanism to innodbbuild400.tcl because it is not waiting for build to complete."

APPEND=$(cat << EOL
puts "SETTING CONFIGURATION"
global complete
proc wait_to_complete {} {
global complete
set complete [vucomplete]
puts "Is it complete ?: \$complete"
if {!\$complete} {
 after 5000 wait_to_complete
} else {
 exit
}
}
wait_to_complete
vwait forever
EOL
)

echo "$APPEND" >> ./innodbbuild400.tcl

echo "SF: wait mechanism added to innodbbuild400.tcl"

mysql_counter=0
until ((mysql_counter >= 10));
do
    echo "MYSQL service connection are stable for $mysql_counter second"
    nc -z -w5 ${DB_HOST} 3306
    if [ $? -eq 0 ]; then
        ((mysql_counter++))
    else
        mysql_counter=0
    fi
    sleep 1
done

(./hammerdbcli auto ./innodbbuild400.tcl && ./hammerdbcli auto ./innodbtest.tcl  ; echo $? > status) 2>&1 | tee output.log ;
tar cf /export-logs status output.log && sleep infinity
