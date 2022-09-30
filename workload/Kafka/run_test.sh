#!/bin/bash

# This script is used to run producer tasks, consumer tasks and create Kafka topic

# Parameters
id=${IDENTIFIER}
k_topic=${K_KAFKA_BENCHMARK_TOPIC}
k_message=${K_MESSAGES}
k_kafka_server=${KAFKA_SERVER}
k_zookeeper_server=${ZOOKEEPER_SERVER}
k_num_records=${K_NUM_RECORDS}
k_throughput=${K_THROUGHPUT}
k_record_size=${K_RECORD_SIZE}
k_compression_type=${K_COMPRESSION_TYPE}
k_producers=${K_PRODUCERS}
k_consumers=${K_CONSUMERS}
k_consumer_timeout=${K_CONSUMER_TIMEOUT}
k_partitions=${K_PARTITIONS}
k_replication_factor=${K_REPLICATION_FACTOR}
kafka_dir=$BASE_DIR/$KAFKA_VER
kafka_consumer_group_id="PKB_CONSUMER_GROUP"

# Calculate default PARTITIONS/PRODUCERS/CONSUMERS load according to CPU cores and free memory size(GB)
# default_load = min(2 * cores, free memory GB)
cores=`lscpu | egrep '^CPU\(s\)' | awk '{print $2}'`
free_memory=`cat /proc/meminfo | egrep '^MemFree' | awk '{printf "%d\n", $2/1024/1024}'`
default_load=$((2 * cores < free_memory ? 2 * cores : free_memory))
echo "CPU Cores: $cores"
echo "Free Memory: $free_memory"
echo "Default Load: $default_load"
if [[ $k_partitions == 0 ]]; then k_partitions=$default_load; fi
if [[ $k_producers == 0 ]]; then k_producers=$default_load; fi
if [[ $k_consumers == 0 ]]; then k_consumers=$default_load; fi

echo "=== START $(basename $0)"
echo "id = [$id]"
echo "k_message = [$k_message]"
echo "k_kafka_server = [$k_kafka_server]"
echo "k_zookeeper_server=[$k_zookeeper_server]"
echo "k_num_records = [$k_num_records]"
echo "k_throughput = [$k_throughput]"
echo "k_record_size = [$k_record_size]"
echo "k_compression_type = [$k_compression_type]"
echo "k_topic = [$k_topic]"
echo "k_replication_factor=[$k_replication_factor]"
echo "kafka_consumer_group_id=[$kafka_consumer_group_id]"
echo "k_partitions=[$k_partitions]"
echo "k_producers=[$k_producers]"
echo "k_consumers=[$k_consumers]"
echo "k_consumer_timeout=[$k_consumer_timeout]"
echo "kafka_dir=[$kafka_dir]"

if [[ ${id} == producer ]]; then
    echo "Producer:"
    python3 start_test.py -i $id -b $k_producers -k $kafka_dir -s $k_kafka_server -t $k_topic -h $k_throughput -n $k_num_records -r $k_record_size -c $k_compression_type
elif [[ ${id} == consumer ]]; then
    echo "Consumer:"
    python3 start_test.py -i $id -a $k_consumers -k $kafka_dir -s $k_kafka_server -t $k_topic -m $k_message -g $kafka_consumer_group_id -l $k_consumer_timeout
elif [[ ${id} == topic ]]; then
    echo "Topic:"
    sh $kafka_dir/bin/kafka-topics.sh --create --zookeeper $k_zookeeper_server --replication-factor $k_replication_factor --partitions ${k_partitions} --topic $k_topic
else
    echo "Unknown id: ${id}"
fi
