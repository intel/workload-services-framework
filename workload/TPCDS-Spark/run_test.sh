#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#


function start_sshd() {
  /usr/sbin/sshd -D &
}

function end_sshd() {
  echo "stopping sshd"
  kill -9 $(cat /run/sshd.pid)
}

function config_dfs_mountdisk() {
  HDFS_SITE_FILE="/usr/local/hadoop/etc/hadoop/hdfs-site.xml"
  prefix="/data/"
  dn_suffix="/dfs/dn"
  dn_result="file:"
  for ((i=1; i<=${DFS_DIR_DISK_NUM}; i++)); do
    dir_num=$(printf "%02d" $i)
    dn_result+="$prefix$dir_num$dn_suffix,"
  done
  dn_result=${dn_result%,}
  sed -i "s|file:///root/hdfs/datanode|$dn_result|g" $HDFS_SITE_FILE
}

function config_spark_local_dir_mountdisk() {
  HDFS_SITE_FILE="/usr/local/hadoop/etc/hadoop/hdfs-site.xml"
  prefix="/data/spark_local"
  dir_result=""

  if [ ${SPARK_LOCAL_DIR_DISK_NUM} -gt 0 ]; then
    for ((i=1; i<=${SPARK_LOCAL_DIR_DISK_NUM}; i++)); do
      dir_result+="$prefix$i,"
    done
    dir_result=${dir_result%,}
    echo "spark.local.dir $dir_result" >> /usr/local/spark/conf/spark-defaults.conf
  fi
}

function config_yarn_local_dir_mountdisk() {
  YARN_SITE_FILE="/usr/local/hadoop/etc/hadoop/yarn-site.xml"
  prefix="/data/yarn_local"
  dir_result=""
  if [ ${YARN_LOCAL_DIR_DISK_NUM} -gt 0 ]; then
    for ((i=1; i<=${YARN_LOCAL_DIR_DISK_NUM}; i++)); do
      dir_result+="$prefix$i,"
    done
    dir_result=${dir_result%,}
    sed -i "s|\${hadoop.tmp.dir}/nm-local-dir|$dir_result|g" $YARN_SITE_FILE
  fi

}

function config_spark(){
  MEM_TOTAL=`free -g |grep Mem|awk '{print $2}'`
  CPU_CORES=`lscpu |grep '^CPU(s):'|awk '{print$2}'`

  EXECUTOR_NUM=$((CPU_CORES/SPARK_EXECUTOR_CORES))
  MEM_SPARK=$(echo "scale=0;($MEM_TOTAL*$SPARK_AVAILABLE_MEMORY)/1" | bc)

  # Reserve 1GB for memory overhead
  TOTAL_EXECUTOR_MEMORY_GB=$(((MEM_SPARK/EXECUTOR_NUM)-SPARK_EXECUTOR_MEMORY_OVERHEAD))

  MEMORY_OFFHEAP_SIZE=$(echo "scale=2;($TOTAL_EXECUTOR_MEMORY_GB/12)*5" | bc)
  MEMORY_OFFHEAP_SIZE=$(echo "scale=0;$MEMORY_OFFHEAP_SIZE/1" | bc)
  # EXECUTOR_MEMORY_GB=$(((TOTAL_EXECUTOR_MEMORY_GB-MEMORY_OFFHEAP_SIZE)))
  EXECUTOR_MEMORY_GB=$(((TOTAL_EXECUTOR_MEMORY_GB)))

  DRIVER_MEMORY_GB=$EXECUTOR_MEMORY_GB

  if [ $GATED == "false" ]; then
      EXECUTOR_NUM=$((EXECUTOR_NUM*NUM_WORKERS))
  fi

  SPARK_DEFAULT_PARALLELISM=$((4*EXECUTOR_NUM*SPARK_EXECUTOR_CORES*SPARK_PARALLELISM_FACTOR))
  SPARK_SQL_SHUFFLE_PARTITIONS=$((4*EXECUTOR_NUM*SPARK_EXECUTOR_CORES*SPARK_PARALLELISM_FACTOR))

  cp /usr/local/spark/conf/spark-default.conf.template /usr/local/spark/conf/spark-defaults.conf
  echo "" >> /usr/local/spark/conf/spark-defaults.conf
  echo "spark.executor.instances ${EXECUTOR_NUM}" >> /usr/local/spark/conf/spark-defaults.conf
  echo "spark.executor.cores ${SPARK_EXECUTOR_CORES}" >> /usr/local/spark/conf/spark-defaults.conf
  echo "spark.executor.memory ${EXECUTOR_MEMORY_GB}g" >> /usr/local/spark/conf/spark-defaults.conf
  echo "spark.memory.offHeap.size ${MEMORY_OFFHEAP_SIZE}g" >> /usr/local/spark/conf/spark-defaults.conf
  echo "spark.driver.memory ${DRIVER_MEMORY_GB}g" >> /usr/local/spark/conf/spark-defaults.conf
  echo "spark.default.parallelism ${SPARK_DEFAULT_PARALLELISM}" >> /usr/local/spark/conf/spark-defaults.conf
  echo "spark.sql.shuffle.partitions ${SPARK_SQL_SHUFFLE_PARTITIONS}" >> /usr/local/spark/conf/spark-defaults.conf
  echo "spark.memory.fraction ${SPARK_MEMORY_FRACTION}" >> /usr/local/spark/conf/spark-defaults.conf
  echo "spark.memory.storageFraction ${SPARK_MEMORY_STORAGE_FRACTION}" >> /usr/local/spark/conf/spark-defaults.conf
  echo "spark.executor.memoryOverhead ${SPARK_EXECUTOR_MEMORY_OVERHEAD}g" >> /usr/local/spark/conf/spark-defaults.conf
  echo "spark.memory.offHeap.enabled false" >> /usr/local/spark/conf/spark-defaults.conf
  # echo "spark.eventLog.enabled false" >> /usr/local/spark/conf/spark-defaults.conf
  # echo "spark.eventLog.dir hdfs:///spark-logs-history" >> /usr/local/spark/conf/spark-defaults.conf
  echo "Initial Spark configuration:"
  cat /usr/local/spark/conf/spark-defaults.conf

  mkdir /tmp/spark-logs

  echo "export SPARK_DIST_CLASSPATH=$(hadoop classpath)" > /usr/local/spark/conf/spark-env.sh
  sleep 3
}
function run_benchmark() {


  hdfs namenode -format
  $HADOOP_HOME/sbin/start-dfs.sh
  $HADOOP_HOME/sbin/start-yarn.sh

  # hdfs dfs -mkdir /spark-logs-history

  echo "scale factor: $SCALE_FACTOR"

  SPARK_OPTS="--num-executors ${EXECUTOR_NUM} --executor-cores ${SPARK_EXECUTOR_CORES} --executor-memory ${EXECUTOR_MEMORY_GB}g --driver-memory ${DRIVER_MEMORY_GB}g"

  ${SPARK_HOME}/bin/spark-submit --deploy-mode client --master yarn ${SPARK_OPTS} --class TpcdsSparkDatagen /usr/local/spark/jars/tpcds-spark-benchmark.jar $SCALE_FACTOR "hdfs://master-0:9000/" && \
  ${SPARK_HOME}/bin/spark-submit --deploy-mode client --master yarn ${SPARK_OPTS} --class TpcdsSparkBenchmark /usr/local/spark/jars/tpcds-spark-benchmark.jar $SCALE_FACTOR "hdfs://master-0:9000/"

  # hadoop fs -get /spark-logs-history/*  /tmp/spark-logs  #remove comment when eventlog dir is enabled
}

start_sshd
config_dfs_mountdisk
config_yarn_local_dir_mountdisk


rm -rf /root/hdfs/namenode
rm -rf /data/*/dfs/dn/*
if [ $HADOOP_NODE_TYPE = "master" ]; then
  config_spark
  config_spark_local_dir_mountdisk
  run_benchmark
  end_sshd
fi
