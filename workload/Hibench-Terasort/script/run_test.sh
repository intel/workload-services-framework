#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

LOGFILE="output.log"
exec &> >(tee $LOGFILE)

rm -rf /data/*/dfs/dn/*
rm -rf /root/hdfs/namenode

/usr/sbin/sshd -D &

# grab worker system cpu and memory
MEM_TOTAL=`free -g |grep Mem|awk '{print $2-5}'`  #minus 5GB from recipe
MEM_TOTAL_MB=$((MEM_TOTAL*1024))
CPU_CORES=`lscpu |grep '^CPU(s):'|awk '{print$2}'`
CPU_CORES_IN_CLUSTER=$((CPU_CORES*WORKERNODE_NUM))
MEM_TOTAL_IN_CLUSTER=$((MEM_TOTAL*WORKERNODE_NUM))
echo "MEM_TOTAL (GB): $MEM_TOTAL"
echo "MEM_TOTAL_IN_CLUSTER (GB): $MEM_TOTAL_IN_CLUSTER"

#configure yarn-site.xml with system cpu and memory info
YARN_SITE_FILE="/usr/local/hadoop/etc/hadoop/yarn-site.xml"
\cp ${YARN_SITE_FILE}_example $YARN_SITE_FILE

if [ $YARN_SCHEDULER_MAXIMUM_ALLOCATION_MB = "auto" ]; then
  sed -i -e "/yarn.scheduler.maximum-allocation-mb/{n;s@auto@$MEM_TOTAL_MB@}" $YARN_SITE_FILE
  YARN_SCHEDULER_MAXIMUM_ALLOCATION_MB=$MEM_TOTAL_MB
fi

if [ $YARN_SCHEDULER_MAXIMUM_ALLOCATION_VCORES = "auto" ]; then
  sed -i -e "/yarn.scheduler.maximum-allocation-vcores/{n;s@auto@$CPU_CORES@}" $YARN_SITE_FILE
fi

if [ $YARN_NODEMANAGER_RESOURCE_MEMORY_MB = "auto" ]; then
  sed -i -e "/yarn.nodemanager.resource.memory-mb/{n;s@auto@$MEM_TOTAL_MB@}" $YARN_SITE_FILE
fi

if [ $YARN_NODEMANAGER_RESOURCE_CPU_VCORES = "auto" ]; then
  sed -i -e "/yarn.nodemanager.resource.cpu-vcores/{n;s@auto@$CPU_CORES@}" $YARN_SITE_FILE
fi

#configure mapred-site.xml with system cpu and memory info
MAPRED_SITE_FILE="/usr/local/hadoop/etc/hadoop/mapred-site.xml"
\cp ${MAPRED_SITE_FILE}_example $MAPRED_SITE_FILE
MAPREDUCE_MAP_MEMORY_MB=$((YARN_SCHEDULER_MAXIMUM_ALLOCATION_MB/CPU_CORES_IN_CLUSTER))
MAPREDUCE_REDUCE_MEMORY_MB=$((MAPREDUCE_MAP_MEMORY_MB))
if [[ "$MAPREDUCE_MAP_MEMORY_MB" -lt 1024 ]]; then
  MAPREDUCE_MAP_MEMORY_MB=1024
  MAPREDUCE_REDUCE_MEMORY_MB=1024
  MAPREDUCE_JOB_MAPS=$((CPU_CORES_IN_CLUSTER/2))
  MAPREDUCE_JOB_REDUCES=$((CPU_CORES_IN_CLUSTER/2))
  MAPREDUCE_REDUCE_SHUFFLE_PARALLELCOPIES=$((CPU_CORES_IN_CLUSTER/2))
else
  MAPREDUCE_JOB_MAPS=$((CPU_CORES_IN_CLUSTER))
  MAPREDUCE_JOB_REDUCES=$((CPU_CORES_IN_CLUSTER))
  MAPREDUCE_REDUCE_SHUFFLE_PARALLELCOPIES=$((CPU_CORES_IN_CLUSTER))
fi
MAPREDUCE_MAP_JAVA_OPTS_XMX_REPLACE=$((MAPREDUCE_MAP_MEMORY_MB*4/5))
MAPREDUCE_REDUCE_JAVA_OPTS_XMX_REPLACE=$((MAPREDUCE_REDUCE_MEMORY_MB*4/5))

sed -i "s/MAPREDUCE_JOB_MAPS_REPLACE/$MAPREDUCE_JOB_MAPS/" $MAPRED_SITE_FILE
sed -i "s/MAPREDUCE_JOB_REDUCES_REPLACE/$MAPREDUCE_JOB_REDUCES/" $MAPRED_SITE_FILE
sed -i "s/MAPREDUCE_MAP_MEMORY_MB_REPLACE/$MAPREDUCE_MAP_MEMORY_MB/" $MAPRED_SITE_FILE
sed -i "s/MAPREDUCE_REDUCE_MEMORY_MB_REPLACE/$MAPREDUCE_REDUCE_MEMORY_MB/" $MAPRED_SITE_FILE
sed -i "s/MAPREDUCE_REDUCE_SHUFFLE_PARALLELCOPIES_REPLACE/$MAPREDUCE_REDUCE_SHUFFLE_PARALLELCOPIES/" $MAPRED_SITE_FILE
sed -i "s/MAPREDUCE_MAP_JAVA_OPTS_XMX_REPLACE/${MAPREDUCE_MAP_JAVA_OPTS_XMX_REPLACE}m/" $MAPRED_SITE_FILE
sed -i "s/MAPREDUCE_REDUCE_JAVA_OPTS_XMX_REPLACE/${MAPREDUCE_REDUCE_JAVA_OPTS_XMX_REPLACE}m/" $MAPRED_SITE_FILE
echo "export YARN_OPTS=\"-Xmx${MAPREDUCE_MAP_MEMORY_MB}m -Djava.net.preferIPv4Stack=true \$YARN_OPTS\"" >> /usr/local/hadoop/etc/hadoop/hadoop-env.sh

#configure hdfs-site.xml with dfs.datanode.data.dir
HDFS_SITE_FILE="/usr/local/hadoop/etc/hadoop/hdfs-site.xml"
prefix="/data/"
suffix="/dfs/dn"
result="file:"
for ((i=1; i<=${DISK_COUNT}; i++)); do
  dir_num=$(printf "%02d" $i)
  result+="$prefix$dir_num$suffix,"
done
result=${result%,}
sed -i "s|file:///root/hdfs/datanode|$result|g" $HDFS_SITE_FILE
sed -i -e "/dfs.namenode.handler.count/{n;s@[0-9]\+@$DFS_NAMENODE_HANDLER_COUNT@}" $HDFS_SITE_FILE
sed -i -e "/dfs.datanode.handler.count/{n;s@[0-9]\+@$DFS_DATANODE_HANDLER_COUNT@}" $HDFS_SITE_FILE
sed -i -e "/dfs.blocksize/{n;s@[0-9]\+[a-z]@$DFS_BLOCKSIZE@}" $HDFS_SITE_FILE

if [ $HADOOP_NODE_TYPE = "master" ]; then
  # #HiBench settings


  if [[ "$CPU_CORES" -gt 5 ]]; then
      EXECUTOR_CORES=5
  else
      EXECUTOR_CORES=2
  fi
  if [[ "$MEM_TOTAL" -gt 32 ]]; then
      DRIVER_MEMORY_GB=20
  elif [[ "$MEM_TOTAL" -gt 8 ]]; then
      DRIVER_MEMORY_GB=8
  else
      DRIVER_MEMORY_GB=2
  fi
  EXECUTOR_NUM=$((CPU_CORES_IN_CLUSTER/EXECUTOR_CORES))
  EXECUTOR_MEMORY_GB=$((MEM_TOTAL_IN_CLUSTER/EXECUTOR_NUM*4/5))  #80%
  EXECUTOR_MEMORY_OVERHEAD_GB=$((MEM_TOTAL_IN_CLUSTER/EXECUTOR_NUM/5)) #20%
  SPARK_PARALLELISM=${CPU_CORES_IN_CLUSTER}
  SHUFFLE_PARTITIONS=${CPU_CORES_IN_CLUSTER}

#configure /HiBench/conf/spark.conf
  SPARK_CONF=/HiBench/conf/spark.conf
  \cp /HiBench/conf/spark.conf_template $SPARK_CONF

  if [ $HIBENCH_YARN_EXECUTOR_CORES = "auto" ]; then
    if [[ "$CPU_CORES" -lt 8 ]]; then
      HIBENCH_YARN_EXECUTOR_CORES=2
    else
      HIBENCH_YARN_EXECUTOR_CORES=5
    fi
    sed -i -e "/hibench.yarn.executor.cores/{s@auto@$HIBENCH_YARN_EXECUTOR_CORES@}"  $SPARK_CONF
    sed -i -e "/spark.executor.cores/{s@auto@$HIBENCH_YARN_EXECUTOR_CORES@}"  $SPARK_CONF
  fi

  if [ $HIBENCH_YARN_EXECUTOR_NUM = "auto" ]; then
    HIBENCH_YARN_EXECUTOR_NUM=$((CPU_CORES_IN_CLUSTER/HIBENCH_YARN_EXECUTOR_CORES))
    sed -i -e "/hibench.yarn.executor.num/{s@auto@$HIBENCH_YARN_EXECUTOR_NUM@}"  $SPARK_CONF
  fi

  if [ $SPARK_EXECUTOR_MEMORY = "auto" ]; then
    SPARK_EXECUTOR_MEMORY=$((MEM_TOTAL_IN_CLUSTER/HIBENCH_YARN_EXECUTOR_NUM*4/5))  #80%
    sed -i -e "/\<spark.executor.memory\>/{s@auto@"$SPARK_EXECUTOR_MEMORY"g@}"  $SPARK_CONF
  fi

  if [ $SPARK_EXECUTOR_MEMORYOVERHEAD = "auto" ]; then
    SPARK_EXECUTOR_MEMORYOVERHEAD=$((MEM_TOTAL_IN_CLUSTER/HIBENCH_YARN_EXECUTOR_NUM/5)) #20%
    sed -i -e "/spark.executor.memoryOverhead/{s@auto@"$SPARK_EXECUTOR_MEMORYOVERHEAD"g@}"  $SPARK_CONF
  fi

  if [ $SPARK_DRIVER_MEMORY = "auto" ]; then
    if [[ "$MEM_TOTAL" -gt 32 ]]; then
      SPARK_DRIVER_MEMORY=20
    elif [[ "$MEM_TOTAL" -gt 8 ]]; then
      SPARK_DRIVER_MEMORY=8
    else
      SPARK_DRIVER_MEMORY=2
    fi
    sed -i -e "/spark.driver.memory/{s@auto@"$SPARK_DRIVER_MEMORY"g@}"  $SPARK_CONF
  fi

  if [ $SPARK_DEFAULT_PARALLELISM = "auto" ]; then
    SPARK_DEFAULT_PARALLELISM=${CPU_CORES_IN_CLUSTER}
    sed -i -e "/spark.default.parallelism/{s@auto@$SPARK_DEFAULT_PARALLELISM@}"  $SPARK_CONF
  fi

  if [ $SPARK_SQL_SHUFFLE_PARTITIONS = "auto" ]; then
    SPARK_SQL_SHUFFLE_PARTITIONS=${CPU_CORES_IN_CLUSTER}
    sed -i -e "/spark.sql.shuffle.partitions/{s@auto@$SPARK_SQL_SHUFFLE_PARTITIONS@}"  $SPARK_CONF
  fi

#redefine terasort.conf
  \cp /HiBench/conf/workloads/micro/terasort.conf_template /HiBench/conf/workloads/micro/terasort.conf


  sleep 30
  hdfs namenode -format
  $HADOOP_HOME/sbin/start-dfs.sh
  $HADOOP_HOME/sbin/start-yarn.sh
 

  set -e
  echo "Starting benchmark."
  echo "Scale profile is $HIBENCH_SCALE_PROFILE."

#configure hibench.conf
  HIBENCH_CONF=/HiBench/conf/hibench.conf

  if [ $HIBENCH_DEFAULT_MAP_PARALLELISM = "auto" ]; then
    HIBENCH_DEFAULT_MAP_PARALLELISM=$((HIBENCH_YARN_EXECUTOR_CORES*HIBENCH_YARN_EXECUTOR_NUM))
    sed -i "s/^hibench\.default\.map\.parallelism\s\+[0-9]\+$/hibench.default.map.parallelism ${HIBENCH_DEFAULT_MAP_PARALLELISM}/" $HIBENCH_CONF
  fi

  if [ $HIBENCH_DEFAULT_SHUFFLE_PARALLELISM = "auto" ]; then
    HIBENCH_DEFAULT_SHUFFLE_PARALLELISM=$((HIBENCH_YARN_EXECUTOR_CORES*HIBENCH_YARN_EXECUTOR_NUM))
    sed -i "s/^hibench\.default\.shuffle\.parallelism\s\+[0-9]\+$/hibench.default.shuffle.parallelism ${HIBENCH_DEFAULT_SHUFFLE_PARALLELISM}/" $HIBENCH_CONF
  fi
  sed -i "s/tiny/$HIBENCH_SCALE_PROFILE/" $HIBENCH_CONF
  
  # configure hadoop.conf
  \cp /HiBench/conf/hadoop.conf.template /HiBench/conf/hadoop.conf
  sed -i "s|/PATH/TO/YOUR/HADOOP/ROOT|/usr/local/hadoop|" /HiBench/conf/hadoop.conf
  sed -i "s|localhost\:8020|node-master:9000|" /HiBench/conf/hadoop.conf
  echo "export SPARK_DIST_CLASSPATH=$(hadoop classpath)" > /usr/local/spark/conf/spark-env.sh

  echo "export SPARK_DIST_CLASSPATH=$(hadoop classpath)" > /usr/local/spark/conf/spark-env.sh

  echo "Starting benchmark."
  if [[ $WORKLOAD == *"terasort"* ]];then
    echo "Terasort selected."
    echo "Entering prepare phase."
    /HiBench/bin/workloads/micro/terasort/prepare/prepare.sh
    echo "Entering run phase."
    echo "begin region of interest"
    if [[ $ENGINE == *"spark"* ]];then
      /HiBench/bin/workloads/micro/terasort/spark/run.sh
    else
      /HiBench/bin/workloads/micro/terasort/hadoop/run.sh 
    fi
    echo "end region of interest"
  else
    echo "\$WORKLOAD invalid or empty. Aborting."
    exit 1
  fi
  echo "Finished benchmark."
fi
