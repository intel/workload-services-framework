#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

WORKERNODE_NUM=${1:-1}
awk -v WORKERNODE_NUM=$WORKERNODE_NUM '
/Terasort/ {
    printf "Input_data_size (bytes): %d\n", $4    
    printf "Duration (s): %d\n", $5
    printf "*Throughput (bytes/s): %d\n", $6
    printf "Throughput per node (bytes/s): %d\n", $7/WORKERNODE_NUM
}
' */HiBench/report/hibench.report 2>/dev/null || true


#spark.conf settings
# •	Spark.deploy.mode (static, Yarn-client should be displayed only)
# •	hibench.yarn.executor.cores
# •	hibench.yarn.executor.num
# •	spark.executor.memory
# •	spark.driver.memory
# •	hibench.default.shuffle.parallelism
# •	spark.executor.memoryOverhead
# •	spark.serializer (display only)
awk '
/spark.serializer/ { print "## SPARK_SERIALIZER: " $2 }
/hibench.yarn.executor.cores/ { print "## HIBENCH_YARN_EXECUTOR_CORES: " $2 }
/hibench.yarn.executor.num/ { print "## HIBENCH_YARN_EXECUTOR_NUM: " $2 }
/\<spark.executor.memory\>/ { 
    if (match($2,"[0-9]+")) {
        print "## SPARK_EXECUTOR_MEMORY: "substr($2,RSTART,RLENGTH)
        }
    }
/spark.driver.memory/ { 
    if (match($2,"[0-9]+")) {
        print "## SPARK_DRIVER_MEMORY: "substr($2,RSTART,RLENGTH)
        }
    }
/spark.executor.memoryOverhead/ {
    if (match($2,"[0-9]+")) {
        print "## SPARK_EXECUTOR_MEMORYOVERHEAD: "substr($2,RSTART,RLENGTH)
        }
    }
/spark.default.parallelism/ { print "## SPARK_DEFAULT_PARALLELISM: " $2 }
/spark.sql.shuffle.partition/ { print "## SPARK_SQL_SHUFFLE_PARTITIONS: " $2 }


' */HiBench/conf/spark.conf  2>/dev/null || true

# •	hibench.default.shuffle.parallelism
awk '
/hibench.default.map.parallelism/ { print "## HIBENCH_DEFAULT_MAP_PARALLELISM: " $2 }
/hibench.default.shuffle.parallelism/ { print "## HIBENCH_DEFAULT_SHUFFLE_PARALLELISM: " $2 }
' */HiBench/conf/hibench.conf  2>/dev/null || true

# yarn-site.xml settings
# •	yarn.scheduler.maximum-allocation-mb
# •	yarn.nodemanager.resource.memory-mb
# •	yarn.scheduler.minimum-allocation-mb
# •	yarn.nodemanager.resource.cpu-vcores
# •	yarn.scheduler.minimum-allocation-vcores
# •	yarn.scheduler.maximum-allocation-vcores

awk -F"[<>]" '
/yarn.scheduler.maximum-allocation-mb/ { getline; print "## YARN_SCHEDULER_MAXIMUM_ALLOCATION_MB: " $3 }
/yarn.nodemanager.resource.memory-mb/ { getline; print "## YARN_NODEMANAGER_RESOURCE_MEMORY_MB: " $3 }
/yarn.nodemanager.resource.cpu-vcores/ { getline; print "## YARN_NODEMANAGER_RESOURCE_CPU_VCORES : " $3 }
/yarn.scheduler.maximum-allocation-vcores/ { getline; print "## YARN_SCHEDULER_MAXIMUM_ALLOCATION_VCORES : " $3 }

' */usr/local/hadoop/etc/hadoop/yarn-site.xml 2>/dev/null || true
