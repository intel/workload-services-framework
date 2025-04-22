#!/bin/tclsh
puts "SETTING CONFIGURATION"
dbset db mysql
diset connection mysql_host 127.0.0.1
diset connection mysql_port 3306
diset tpcc mysql_count_ware 400
diset tpcc mysql_partition true
diset tpcc mysql_num_vu 64
diset tpcc mysql_storage_engine innodb
vuset logtotemp 1
print dict
buildschema
