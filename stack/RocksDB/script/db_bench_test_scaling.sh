#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

export  LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib
#Input
comp=$1 #options: iaa, zstd, zlib, lz4, none
iaa_inst=$2 #options: 0 (if sw de/compression), 1, 2, 4, 8
iaa_wq_size=$3 #options: 1-128
data_pattern=$4 #options: readrandom, readrandomwriterandom
keysz_input=$5 #options: 4, 16
valsz_input=$6 #options: 32, 256
blocksz_input=$7 #options: 4, 8, 16
cpu_input=($8) #options: '8 14 22 28 42 56 60 64 70 84 96 98 112 120 128' (vCPUs/socket)
num_sockets=$9 #options: 1, 2, 4
source_data=${10} #options: default
nvme_drives=${11}   

for var in comp iaa_inst iaa_wq_size data_pattern keysz_input valsz_input blocksz_input cpu_input num_sockets source_data nvme_drives
do
    echo "$var:" "${!var}"
done

#check inputs
input_error="echo -e \"\n
   USAGE: ./db_bench_test_scaling.sh compression_type iaa_instances iaa_wq_size data_pattern key_size value_size cpu_list num_sockets source_data\n
	   compression_type: iaa, zstd, zlib, lz4, none\n
	   iaa_instances: 0, 1, 2, 4, 8\n
	   iaa_wq_size: 1-128\n
	   data_pattern: readrandom, readrandomwriterandom\n
	   key_size: 4, 8, 16\n
	   value_size: 32, 256\n
	   block_size: 4, 8, 16\n
	   cpu_list: '8 14 22 28 42 56 60 64 70 84 96 98 112 120 128' (vCPUs/socket, should be >=8)\n
	   num_sockets: 1, 2, 4 (SNC not supported)\n
	   source_data: default\n
     nvme_drives: 1, 2, 3, 4 ...
     
   example: ./db_bench_test_scaling.sh iaa 4 128 readrandomwriterandom 16 256 '8' 1 default 2 \n\n \"; exit 1"
if [ "$#" -ne 11 ]; then
  echo "Illegal number of parameters"
  eval $input_error
fi
case $comp in iaa|zlib|zstd|lz4|none) true ;; *) echo "$comp - Check compression_type"; eval $input_error ;; esac
case $iaa_inst in 0|1|2|4|8) true ;; *) echo "$iaa_inst - Check iaa_instances"; eval $input_error ;; esac
case $data_pattern in readrandom|readrandomwriterandom) true ;; *) echo "$data_pattern - Check data_pattern"; eval $input_error ;; esac
case $keysz_input in 4|8|16) true ;; *) echo "$keysz_input - Check key_size"; eval $input_error ;; esac
case $valsz_input in 32|256) true ;; *) echo "$valsz_input - Check value_size"; eval $input_error ;; esac
case $blocksz_input in 4|8|16) true ;; *) echo "$blocksz_input - Check block_size"; eval $input_error ;; esac
case $num_sockets in 1|2|4) true ;; *) echo "$num_sockets - Check num_sockets"; eval $input_error ;; esac
case $source_data in default) true ;; *) echo "$source_data - Check source_data"; eval $input_error ;; esac

# Detect HyperThreading
ht="n"
threads_per_core=$(lscpu | grep -E "Thread\(s\) per core" | awk -F '[:]' '{print $2}' | tr -d " ")
if [[ $threads_per_core -eq 2 ]]; then
  ht="y"
fi
echo "Hyperthreading: "$ht

# Directories
install_folder="/rocksdb"
rocksdb_folder=$install_folder"/rocksdb"          # folder containing RocksDB/db_bench executable
if [[ $comp == "iaa" ]]; then 
  comp_name="com.intel.iaa_compressor_rocksdb"
  export base_data_folder=$install_folder"/rocksdb_data/${blocksz_input}kB_${valsz_input}B_${data_pattern}_scaling_${comp}${iaa_inst}_wq${iaa_wq_size}_${num_sockets}socket_${ht}ht"   # folder for data output
else
  comp_name=$comp
  export base_data_folder=$install_folder"/rocksdb_data/${blocksz_input}kB_${valsz_input}B_${data_pattern}_scaling_${comp}_${num_sockets}socket_${ht}ht"   # folder for data output
fi

echo $base_data_folder
mkdir -p $base_data_folder
app_folder=$install_folder                        # folder where data collection applications (PAT, flame graphs...) are installed
src=$PWD

# Workload configuration - fixed
num_instances=$((4*num_sockets))
if [[ $data_pattern == "readrandomwriterandom" ]]; then
  num_instances=$(($num_instances*2))
fi
key_size="$keysz_input"
value_size="$valsz_input"
blksz=$((blocksz_input*1024))
ops=0                       # ops/thread
instance_ops=100000000      # ops/instance. If != 0, it overrides ops: ops = instance_ops/threads
if [[ $data_pattern == "readrandom" ]]; then
  duration=120                # If != 0, it overrides ops settings
elif [[ $data_pattern == "readrandomwriterandom" ]]; then
  duration=500
fi
bloom_bits=10
disable_wal=true
distribution=""           # empty for uniform. Example of non-uniform distribution: "--read_random_exp_range=10"
use_kmem=false

if [[ $value_size == 256 ]]; then
  entries=$((400000000*num_sockets/num_instances))  # entries/instance
else
  entries=$((2200000000*num_sockets/num_instances))
fi

value_src_data_file=""
value_src_data_type=""
if [[ $source_data == "calgary" ]]; then
  value_src_data_file=$install_folder/standard_calgary_corpus
  value_src_data_type="file_direct"
fi

# Workload configuration - by instance
# Use % as a placeholder for instance number. Use %% as a placeholder for node number. Use %%% as placeholder for nvme drive.
drive="/mnt/disk%%%"
db=$drive"/rockstest%"                 # db path

# Workload configuration - by run

# Detect CPU number in NUMA nodes
sys_sockets=$(lscpu | grep -E "Socket\(s\)" | awk -F '[:]' '{print $2}' | tr -d " ")
sys_numa_nodes=$(lscpu | grep -E "NUMA node\(s\)" | awk -F '[:]' '{print $2}' | tr -d " ")
sys_numa_nodes_per_socket=$((sys_numa_nodes/sys_sockets))
numa_nodes=$((sys_numa_nodes*num_sockets/sys_sockets))  # NUMA nodes for test. Only pick as many NUMA nodes to cover selected sockets
echo "System sockets: "$sys_sockets
echo "System NUMA nodes: "$sys_numa_nodes
echo "System NUMA nodes per socket: "$sys_numa_nodes_per_socket
echo "Selected sockets: "$num_sockets
echo "Selected NUMA nodes: "$numa_nodes

node_start_core=()
node_start_ht=()
for (( n=0; n<$numa_nodes; n++ ));
do
  node_start_core+=($(lscpu | grep -E "NUMA node${n}" | awk -F '[:,-]' '{print $2}' | tr -d " "))
  if [[ $ht == "y" ]]; then
    node_start_ht+=($(lscpu | grep -E "NUMA node${n}" | awk -F '[:,-]' '{print $4}' | tr -d " "))
  fi
done

declare -A cpus_per_run_val
for i in "${cpu_input[@]}"
do
  if [[ $ht == "y" ]]; then
    for (( n=0; n<$numa_nodes; n++ ));
    do
      cpus_per_run_val[$i,$n]=${node_start_core[$n]}-$((${node_start_core[$n]}+$i/(2*$sys_numa_nodes_per_socket)-1)),${node_start_ht[$n]}-$((${node_start_ht[$n]}+$i/(2*$sys_numa_nodes_per_socket)-1))
    done
  else
    for (( n=0; n<$numa_nodes; n++ ));
    do
      cpus_per_run_val[$i,$n]=${node_start_core[$n]}-$((${node_start_core[$n]}+$i/$sys_numa_nodes_per_socket-1))
    done
  fi
done

#90% util
if [[ $data_pattern == "readrandom" ]]; then
  for i in "${cpu_input[@]}"
  do
    thr=$(echo "scale=2;$i/4*0.9+0.5" | bc)       # reference: 90% CPU utilization (remove 0.9 for 100% util). 0.5 added for rounding
    threads_per_inst[$i]=$(printf "%.0f" "$thr")  # takes integer part
  done
elif [[ $data_pattern == "readrandomwriterandom" ]]; then
  # TODO Due to double instances compared to readrandom, rounding is more of an issue is assigning threads per instance
  for i in "${cpu_input[@]}"
  do
    thr=$(echo "scale=2;$i*10/112+0.5" | bc)       # reference: 10 threads with 56*2 vCPUs. 0.5 added for rounding
    threads_per_inst[$i]=$(printf "%.0f" "$thr")  # takes integer part
  done
fi

run_names=()
cache_size=()
compressed_cache_size=()
cache_numshardbits=()
threads=()
block_size=()
use_cache_dcpmm_allocator=()
use_direct_reads=()
use_direct_io_for_flush_and_compaction=()
compression=()
# prefill=()
workloads=()
cpus_per_run=()
for i in "${cpu_input[@]}"
do
  totalthreads=$((threads_per_inst[$i]*num_instances))
  totalcpus=$((${i}*num_sockets))
  if [[ $comp == "iaa" ]]; then
    run_names+=("${comp}${iaa_inst}_${blocksz_input}kB_${value_size}B_fillseq_${totalthreads}t_${totalcpus}c" "${comp}${iaa_inst}_${blocksz_input}kB_${value_size}B_${data_pattern}_${totalthreads}t_${totalcpus}c")
  else
    run_names+=("${comp}_${blocksz_input}kB_${value_size}B_fillseq_${totalthreads}t_${totalcpus}c" "${comp}_${blocksz_input}kB_${value_size}B_${data_pattern}_${totalthreads}t_${totalcpus}c")
  fi
  cache_size+=(-1 -1) # in bytes
  compressed_cache_size+=(-1 -1) #in bytes
  cache_numshardbits+=(6 6)
  threads+=(1 "${threads_per_inst[$i]}") # threads/instance
  block_size+=("$blksz" "$blksz")
  use_cache_dcpmm_allocator+=("false" "false") # true/false
  use_direct_reads+=("false" "false")
  use_direct_io_for_flush_and_compaction+=("false" "false")
  compression+=("${comp_name}" "${comp_name}")
  prefill+=("c" "n") # y/n, or c (cleanup only). When selecting this option, prefill runs without data collection. To collect data during prefill, use fillseq workload.
  workloads+=("fillseq" "$data_pattern") # options: readrandom, readrandomwriterandom, readwhilewriting, fillseq (disable prefill)
  for w in {1..2}  # Duplicate for fillseq and readrandom/readrandomwriterandom
  do
    for (( n=0; n<$numa_nodes; n++ ));
    do
      cpus_per_run+=(${cpus_per_run_val[$i,$n]}) # if specified, it overrides cpus setting. For each run, need as many entries as numa nodes
    done
  done

  # Workload configuration - by instance/run
  # %-based placeholders enabled
  other_options_prefill+=("" "") # for example, block size need to match in run and prefill
  if [[ $comp == "iaa" ]]; then
    if [[ "$data_pattern" == "readrandom" ]]; then
      other_options_run+=("--max_background_jobs=60 --subcompactions=10 --compression_ratio=0.25 --compressor_options=execution_path=hw;compression_mode=dynamic;level=0" \
                          "--compression_ratio=0.25 --compressor_options=execution_path=hw;compression_mode=dynamic;level=0")
    elif [[ "$data_pattern" == "readrandomwriterandom" ]]; then
      other_options_run+=("--max_background_jobs=30 --subcompactions=5 --compression_ratio=0.25 --compressor_options=execution_path=hw;compression_mode=dynamic;level=0 --max_write_buffer_number=20 --min_write_buffer_number_to_merge=1 --level0_file_num_compaction_trigger=10 --level0_slowdown_writes_trigger=60 --level0_stop_writes_trigger=120 --max_bytes_for_level_base=671088640 --stats_level=4" \
                          "--compression_ratio=0.25 --max_background_jobs=10 --subcompactions=5 --readwritepercent=80 --compressor_options=execution_path=hw;compression_mode=dynamic;level=0 --max_write_buffer_number=20 --min_write_buffer_number_to_merge=1 --level0_file_num_compaction_trigger=10 --level0_slowdown_writes_trigger=60 --level0_stop_writes_trigger=120 --max_bytes_for_level_base=671088640 --stats_level=4")
    fi
  else
    if [[ "$data_pattern" == "readrandom" ]]; then
      other_options_run+=("--max_background_jobs=60 --subcompactions=10 --compression_ratio=0.25" \
                          "--compression_ratio=0.25")
    elif [[ "$data_pattern" == "readrandomwriterandom" ]]; then
      other_options_run+=("--max_background_jobs=30 --subcompactions=5 --compression_ratio=0.25 --max_write_buffer_number=20 --min_write_buffer_number_to_merge=1 --level0_file_num_compaction_trigger=10 --level0_slowdown_writes_trigger=60 --level0_stop_writes_trigger=120 --max_bytes_for_level_base=671088640 --stats_level=4" \
                          "--compression_ratio=0.25 --max_background_jobs=10 --subcompactions=5 --readwritepercent=80 --max_write_buffer_number=20 --min_write_buffer_number_to_merge=1 --level0_file_num_compaction_trigger=10 --level0_slowdown_writes_trigger=60 --level0_stop_writes_trigger=120 --max_bytes_for_level_base=671088640 --stats_level=4")
    fi
  fi
done

#print all runs and inputs
for j in run_names cache_size compressed_cache_size cache_numshardbits threads block_size use_cache_dcpmm_allocator use_direct_reads use_direct_io_for_flush_and_compaction compression workloads cpus_per_run other_options_prefill other_options_run
do
        val1="echo \${!$j[@]}"
        echo -ne "$j = "
        for i in `eval ${val1}`; do val2="echo \${$j[$i]}"; echo -ne "[$i]`eval ${val2}` "; done
        echo -ne "\n"
done

# Data collection options
# db_bench stats
statistics="y"             # enable/disable statistics (y/n)
stats_interval_seconds=60  # every n seconds, report ops and ops/s for last interval and cumulative (for each thread). 0 to disable.
extra_interval_stats=1     # additional stats per interval. 0: disabled, 1:enabled

if [[ $comp == "iaa" ]]; then
	init_command="/rocksdb/scripts/configure_iaa_user 0 1,$((2*iaa_inst-1)) ${iaa_wq_size}"
else
	init_command=""
fi
echo "init_command:" $init_command

function cleanup() {
  echo "Cleaning up"
  rm -rf /mnt/disk0/rockstest*
  rm -rf /mnt/disk1/rockstest*
  rm -rf /mnt/disk2/rockstest*
  rm -rf /mnt/disk3/rockstest*

  sync; echo 3 > /proc/sys/vm/drop_caches
}

db_instances=()  # directories where DB is stored for each instance
function run_instance() {
  local instance=$1
  local node=$2
  local nvme=$3
  local data_prefix=$4
  local run=$5
  
  replace_instance_node $db $instance $node $nvme
  db_instance=$replace_output
  db_instances[$instance]=$db_instance
  
  replace_instance_node "${other_options_run[$run]}" $instance $node $nvme
  other_options_run_instance=$replace_output

  calculate_memnode $node
  memnode=$memnode_output
  
  numactl_cpu="--cpunodebind=$node"
  if [[ ${#cpus_per_run} -gt 0 ]]; then
    numactl_cpu="--physcpubind=${cpus_per_run[$((numa_nodes*run+node))]}"
  elif [[ ${cpus[$node]} != "all" ]]; then
    numactl_cpu="--physcpubind=${cpus[$node]}"
  fi
    
  if [[ $instance_ops -gt 0 ]]; then
    ops=$(($instance_ops/${threads[$run]}))
  fi
  
  duration_str=""
  if [[ $duration -gt 0 ]]; then
    duration_str="--duration="$duration
  fi
  
  statistics_str=""
  if [[ $statistics == "y" ]]; then
    statistics_str="--statistics"
  fi
  
  value_src_data_str=""
  if [[ $value_src_data_file != "" ]]; then
     value_src_data_str="--value_src_data_type=$value_src_data_type --value_src_data_file=$value_src_data_file"
  fi
  
  workload=${workloads[$run]}

  echo "Launching run instance:"$instance" node:"$node" memnode:"$memnode" nvme:"$nvme" workload:"$workload" ops:"$ops `date`

  if [[ $workload == "readrandom" ]]; then
    set -x
    numactl $numactl_cpu --membind=$memnode $rocksdb_folder/db_bench --benchmarks="readrandom,stats" $statistics_str --db=$db_instance --use_existing_db \
      --key_size=$key_size --value_size=$value_size $value_src_data_str --block_size=${block_size[$run]} --num=$entries --bloom_bits=$bloom_bits --compression_type=${compression[$run]} \
      $duration_str --reads=$ops $distribution --threads=${threads[$run]} --disable_wal=$disable_wal \
      --cache_size=${cache_size[$run]} --use_cache_memkind_kmem_allocator=${use_cache_dcpmm_allocator[$run]} --cache_index_and_filter_blocks=false --cache_numshardbits=${cache_numshardbits[$run]} \
      --compressed_cache_size=${compressed_cache_size[$run]} --row_cache_size=0 \
      --use_direct_reads=${use_direct_reads[$run]} --use_direct_io_for_flush_and_compaction=${use_direct_io_for_flush_and_compaction[$run]} $other_options_run_instance \
      --stats_interval_seconds=$stats_interval_seconds --stats_per_interval=$extra_interval_stats \
      &> $data_folder/run_stats_${data_prefix}_${instance}.txt &
    set +x
  elif [[ $workload == "readrandomwriterandom" ]]; then
    set -x
    numactl $numactl_cpu --membind=$memnode $rocksdb_folder/db_bench --benchmarks="readrandomwriterandom,stats" $statistics_str --db=$db_instance --use_existing_db \
      --key_size=$key_size --value_size=$value_size $value_src_data_str --block_size=${block_size[$run]} --num=$entries --bloom_bits=$bloom_bits --compression_type=${compression[$run]} \
      $duration_str --reads=$ops $distribution --threads=${threads[$run]} --disable_wal=$disable_wal \
      --cache_size=${cache_size[$run]} --use_cache_memkind_kmem_allocator=${use_cache_dcpmm_allocator[$run]} --cache_index_and_filter_blocks=false --cache_numshardbits=${cache_numshardbits[$run]} \
      --compressed_cache_size=${compressed_cache_size[$run]} --row_cache_size=0 \
      --use_direct_reads=${use_direct_reads[$run]} --use_direct_io_for_flush_and_compaction=${use_direct_io_for_flush_and_compaction[$run]} $other_options_run_instance \
      --stats_interval_seconds=$stats_interval_seconds --stats_per_interval=$extra_interval_stats \
      &> $data_folder/run_stats_${data_prefix}_${instance}.txt &
    set +x
  elif [[ $workload == "readwhilewriting" ]]; then
    set -x
    numactl $numactl_cpu --membind=$memnode $rocksdb_folder/db_bench --benchmarks="readwhilewriting,stats" $statistics_str --db=$db_instance --use_existing_db \
      --key_size=$key_size --value_size=$value_size $value_src_data_str --block_size=${block_size[$run]} --num=$entries --bloom_bits=$bloom_bits --compression_type=${compression[$run]} \
      $duration_str --reads=$ops $distribution --threads=${threads[$run]} --disable_wal=$disable_wal \
      --cache_size=${cache_size[$run]} --use_cache_memkind_kmem_allocator=${use_cache_dcpmm_allocator[$run]} --cache_index_and_filter_blocks=false --cache_numshardbits=${cache_numshardbits[$run]} \
      --compressed_cache_size=${compressed_cache_size[$run]} --row_cache_size=0 \
      --use_direct_reads=${use_direct_reads[$run]} --use_direct_io_for_flush_and_compaction=${use_direct_io_for_flush_and_compaction[$run]} $other_options_run_instance \
      --stats_interval_seconds=$stats_interval_seconds --stats_per_interval=$extra_interval_stats \
      &> $data_folder/run_stats_${data_prefix}_${instance}.txt &
    set +x
  elif [[ $workload == "overwrite" ]]; then
    set -x
    numactl $numactl_cpu --membind=$node $rocksdb_folder/db_bench --benchmarks="overwrite,stats" $statistics_str --db=$db_instance --use_existing_db \
      --key_size=$key_size --value_size=$value_size $value_src_data_str --block_size=${block_size[$run]} --num=$entries --bloom_bits=$bloom_bits --compression_type=${compression[$run]} \
      $duration_str --writes=$ops $distribution --threads=${threads[$run]} --disable_wal=$disable_wal \
      --cache_size=${cache_size[$run]} --use_cache_memkind_kmem_allocator=${use_cache_dcpmm_allocator[$run]} --cache_index_and_filter_blocks=false --cache_numshardbits=${cache_numshardbits[$run]} \
      --compressed_cache_size=${compressed_cache_size[$run]} --row_cache_size=0 \
      --use_direct_reads=${use_direct_reads[$run]} --use_direct_io_for_flush_and_compaction=${use_direct_io_for_flush_and_compaction[$run]} $other_options_run_instance \
      --stats_interval_seconds=$stats_interval_seconds --stats_per_interval=$extra_interval_stats \
      &> $data_folder/run_stats_${data_prefix}_${instance}.txt &
    set +x
  # For fillrandom, don't select --use_existing_db
  elif [[ $workload == "fillrandom" ]]; then
    set -x
    numactl $numactl_cpu --membind=$node $rocksdb_folder/db_bench --benchmarks="fillrandom,stats" $statistics_str --db=$db_instance \
      --key_size=$key_size --value_size=$value_size $value_src_data_str --block_size=${block_size[$run]} --num=$entries --bloom_bits=$bloom_bits --compression_type=${compression[$run]} \
      $duration_str --writes=$ops $distribution --threads=${threads[$run]} --disable_wal=$disable_wal \
      --cache_size=${cache_size[$run]} --use_cache_memkind_kmem_allocator=${use_cache_dcpmm_allocator[$run]} --cache_index_and_filter_blocks=false --cache_numshardbits=${cache_numshardbits[$run]} \
      --compressed_cache_size=${compressed_cache_size[$run]} --row_cache_size=0 \
      --use_direct_reads=${use_direct_reads[$run]} --use_direct_io_for_flush_and_compaction=${use_direct_io_for_flush_and_compaction[$run]} $other_options_run_instance \
      --stats_interval_seconds=$stats_interval_seconds --stats_per_interval=$extra_interval_stats \
      &> $data_folder/run_stats_${data_prefix}_${instance}.txt &
    set +x
  # For fillseq, don't select --use_existing_db, $duration_str, writes
  elif [[ $workload == "fillseq" ]]; then
    set -x
    numactl $numactl_cpu --membind=$node $rocksdb_folder/db_bench --benchmarks="fillseq,stats" $statistics_str --db=$db_instance \
      --key_size=$key_size --value_size=$value_size $value_src_data_str --block_size=${block_size[$run]} --num=$entries --bloom_bits=$bloom_bits --compression_type=${compression[$run]} \
      $distribution --threads=${threads[$run]} --disable_wal=$disable_wal \
      --cache_size=${cache_size[$run]} --use_cache_memkind_kmem_allocator=${use_cache_dcpmm_allocator[$run]} --cache_index_and_filter_blocks=false --cache_numshardbits=${cache_numshardbits[$run]} \
      --compressed_cache_size=${compressed_cache_size[$run]} --row_cache_size=0 \
      --use_direct_reads=${use_direct_reads[$run]} --use_direct_io_for_flush_and_compaction=${use_direct_io_for_flush_and_compaction[$run]} $other_options_run_instance \
      --stats_interval_seconds=$stats_interval_seconds --stats_per_interval=$extra_interval_stats \
      &> $data_folder/run_stats_${data_prefix}_${instance}.txt &
    set +x
  fi
}

replace_output="";
function replace_instance_node() {
  local str=$1  # string to do replacement on
  local instance=$2
  local node=$3
  local nvme=$4
  nvme=$((nvme+1))

  replace_output=$str
  if [[ $str != "" ]]; then
    replace_output=${replace_output//%%%/$nvme}    # replace %% with nvme number
    replace_output=${replace_output//%%/$node}     # replace %% with node number
    replace_output=${replace_output//%/$instance}  # replace % with instance number  
  fi
}


node_output=0
function calculate_node() {
  local instance=$1
  
  node_output=$((instance%numa_nodes))
}


memnode_output=0
function calculate_memnode() {
  local node=$1
  
  if [[ $use_kmem == "true" ]]; then
    # Assumes that kmem nodes align with cpu NUMA nodes 
    memnode_output="$node,$((instance%numa_nodes+numa_nodes))"
  else
    memnode_output=$node
  fi
}

nvme_output=0
function calculate_nvme() {
  local instance=$1
  
  nvme_output=$((instance%nvme_drives))
}

function run_instances() {
  local data_prefix=$1
  local run=$2

  for (( instance=0; instance<$num_instances; instance++ ));
  do
    calculate_node $instance
    calculate_nvme $instance
    run_instance $instance $node_output $nvme_output $data_prefix $run
  done
}

data_folder=""
function create_data_folders() {
  local run=$1

  echo "Creating data folders"
  data_folder=$base_data_folder"/data_"${run_names[$run]}
  mkdir -p $data_folder
}

function wait_dbbench() {
  local data_prefix=$1

  echo "Waiting for run to complete " `date`
  
  local active_instances=1
  while [[ $active_instances -gt 0 ]]; do 
    active_instances=$(ps -A | grep db_bench$ -c) 
    sleep 1
  done  
}

function prep_collection() {
  local data_prefix=$1
  local run=$2
  
  run_instances $data_prefix $run
  wait_dbbench $data_prefix"-prefill"
}

#Summary options
summary_ops=true
summary_block_cache_misses=false
summary_block_cache_hits=false
summary_block_cache_data_misses=false
summary_block_cache_data_hits=false
summary_block_cache_filter_misses=false
summary_block_cache_filter_hits=false
summary_block_cache_index_misses=false
summary_block_cache_index_hits=false
summary_compressed_block_cache_misses=false
summary_compressed_block_cache_hits=false
summary_p50_get_latency=true
summary_p99_get_latency=true
summary_p50_put_latency=true
summary_p99_put_latency=true
summary_p50_compression_nanos=true
summary_p50_decompression_nanos=true
summary_stall_micros=true

function aggregate_stats() {
  local data_prefix=$1
  local run=$2
  workload=${workloads[$run]}
  echo "Aggregate stats"

  if [[ $summary_ops == true ]]; then
    echo "OPS" > $data_folder/output_$workload.log
    total_ops=0
    for (( instance=0; instance<$num_instances; instance++ )); 
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "ops/sec " | cut -d ':' -f 2 | cut -d 'p' -f 2 | tr -d ' ' | tr -d 'o')
      total_ops=$((total_ops+inst))
      echo "Instance: "$instance" val: "$inst >> $data_folder/output_$workload.log
    done
    echo -e "Total ops: "$total_ops"\n" >> $data_folder/output_$workload.log
  fi
  
  if [[ $summary_block_cache_misses == true ]]; then
    echo "BLOCK CACHE MISSES" >> $data_folder/output_$workload.log
    total_bc_misses=0
    for (( instance=0; instance<$num_instances; instance++ )); 
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.block.cache.miss" | cut -d ':' -f 2  | tr -d ' ')
      total_bc_misses=$((total_bc_misses+inst))
      echo "Instance: "$instance" val: "$inst >> $data_folder/output_$workload.log
    done
    echo -e "Total block_cache_misses: "$total_bc_misses"\n" >> $data_folder/output_$workload.log
  fi
  
  if [[ $summary_block_cache_hits == true ]]; then
    echo "BLOCK CACHE HITS" >> $data_folder/output_$workload.log
    total_bc_hits=0
    for (( instance=0; instance<$num_instances; instance++ )); 
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.block.cache.hit" | cut -d ':' -f 2  | tr -d ' ')
      total_bc_hits=$((total_bc_hits+inst))
      echo "Instance: "$instance" val: "$inst >> $data_folder/output_$workload.log
    done
    echo -e "Total block_cache_hits: "$total_bc_hits"\n" >> $data_folder/output_$workload.log
  fi
  
  if [[ $summary_block_cache_misses == true && $summary_block_cache_hits == true ]]; then
    if [[ $total_bc_hits -gt 0 ]]; then
      echo -e "Block Cache Hit Rate: "$((total_bc_hits*100/(total_bc_misses+total_bc_hits)))"\n" >> $data_folder/output_$workload.log
    else
      echo -e "Block Cache Hit Rate: N/A\n" >> $data_folder/output_$workload.log
    fi
  fi
  
  
  if [[ $summary_block_cache_data_misses == true ]]; then
    echo "BLOCK CACHE DATA MISSES" >> $data_folder/output_$workload.log
    total_bc_data_misses=0
    for (( instance=0; instance<$num_instances; instance++ )); 
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.block.cache.data.miss" | cut -d ':'   -f 2  | tr -d ' ')
      total_bc_data_misses=$((total_bc_data_misses+inst))
      echo "Instance: "$instance" val: "$inst >> $data_folder/output_$workload.log
    done
    echo -e "Total block_cache_data_misses: "$total_bc_data_misses"\n" >> $data_folder/output_$workload.log
  fi
  
  if [[ $summary_block_cache_data_hits == true ]]; then
    echo "BLOCK CACHE DATA HITS" >> $data_folder/output_$workload.log
    total_bc_data_hits=0
    for (( instance=0; instance<$num_instances; instance++ )); 
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.block.cache.data.hit" | cut -d ':' -f 2  | tr -d ' ')
      total_bc_data_hits=$((total_bc_data_hits+inst))
      echo "Instance: "$instance" val: "$inst >> $data_folder/output_$workload.log
    done
    echo -e "Total block_cache_data_hits: "$total_bc_data_hits"\n" >> $data_folder/output_$workload.log
  fi
  
  if [[ $summary_block_cache_data_misses == true && $summary_block_cache_data_hits == true ]]; then
    if [[ $total_bc_data_hits -gt 0 ]]; then
      echo -e "Block Cache Data Hit Rate: "$((total_bc_data_hits*100/(total_bc_data_misses+total_bc_data_hits)))"\n" >> $data_folder/output_$workload.log
    else
      echo -e "Block Cache Data Hit Rate: N/A\n" >> $data_folder/output_$workload.log
    fi
  fi
  
  
  if [[ $summary_block_cache_filter_misses == true ]]; then
    echo "BLOCK CACHE FILTER MISSES" >> $data_folder/output_$workload.log
    total_bc_filter_misses=0
    for (( instance=0; instance<$num_instances; instance++ )); 
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.block.cache.filter.miss" | cut -d ':' -f 2  | tr -d ' ')
      total_bc_filter_misses=$((total_bc_filter_misses+inst))
      echo "Instance: "$instance" val: "$inst >> $data_folder/output_$workload.log
    done
    echo -e "Total block_cache_filter_misses: "$total_bc_filter_misses"\n" >> $data_folder/output_$workload.log
  fi
  
  if [[ $summary_block_cache_filter_hits == true ]]; then
    echo "BLOCK CACHE FILTER HITS" >> $data_folder/output_$workload.log
    total_bc_filter_hits=0
    for (( instance=0; instance<$num_instances; instance++ )); 
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.block.cache.filter.hit" | cut -d ':' -f 2  | tr -d ' ')
      total_bc_filter_hits=$((total_bc_filter_hits+inst))
      echo "Instance: "$instance" val: "$inst >> $data_folder/output_$workload.log
    done
    echo -e "Total block_cache_filter_hits: "$total_bc_filter_hits"\n" >> $data_folder/output_$workload.log
  fi
  
  if [[ $summary_block_cache_filter_misses == true && $summary_block_cache_filter_hits == true ]]; then
    if [[ $total_bc_filter_hits -gt 0 ]]; then
      echo -e "Block Cache Filter Hit Rate: "$((total_bc_filter_hits*100/(total_bc_filter_misses+total_bc_filter_hits)))"\n" >> $data_folder/output_$workload.log
    else
      echo -e "Block Cache Filter Hit Rate: N/A\n" >> $data_folder/output_$workload.log
    fi
  fi
  
  
  if [[ $summary_block_cache_index_misses == true ]]; then
    echo "BLOCK CACHE INDEX MISSES" >> $data_folder/output_$workload.log
    total_bc_index_misses=0
    for (( instance=0; instance<$num_instances; instance++ )); 
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.block.cache.index.miss" | cut -d ':' -f 2  | tr -d ' ')
      total_bc_index_misses=$((total_bc_index_misses+inst))
      echo "Instance: "$instance" val: "$inst >> $data_folder/output_$workload.log
    done
    echo -e "Total block_cache_index_misses: "$total_bc_index_misses"\n" >> $data_folder/output_$workload.log
  fi
  
  if [[ $summary_block_cache_index_hits == true ]]; then
    echo "BLOCK CACHE INDEX HITS" >> $data_folder/output_$workload.log
    total_bc_index_hits=0
    for (( instance=0; instance<$num_instances; instance++ )); 
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.block.cache.index.hit" | cut -d ':' -f 2  | tr -d ' ')
      total_bc_index_hits=$((total_bc_index_hits+inst))
      echo "Instance: "$instance" val: "$inst >> $data_folder/output_$workload.log
    done
    echo -e "Total block_cache_index_hits: "$total_bc_index_hits"\n" >> $data_folder/output_$workload.log
  fi
  
  if [[ $summary_block_cache_index_misses == true && $summary_block_cache_index_hits == true ]]; then
    if [[ $total_bc_index_hits -gt 0 ]]; then
      echo -e "Block Cache Index Hit Rate: "$((total_bc_index_hits*100/(total_bc_index_misses+total_bc_index_hits)))"\n" >> $data_folder/output_$workload.log
    else
      echo -e "Block Cache Index Hit Rate: N/A\n" >> $data_folder/output_$workload.log
    fi
  fi
  
  
  if [[ $summary_compressed_block_cache_misses == true ]]; then
    echo "COMPRESSED BLOCK CACHE MISSES" >> $data_folder/output_$workload.log
    total_cbc_misses=0
    for (( instance=0; instance<$num_instances; instance++ )); 
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.block.cachecompressed.miss" | cut -d ':' -f 2  | tr -d ' ')
      total_cbc_misses=$((total_cbc_misses+inst))
      echo "Instance: "$instance" val: "$inst >> $data_folder/output_$workload.log
    done
    echo -e "Total compressed_block_cache_misses: "$total_cbc_misses"\n" >> $data_folder/output_$workload.log
  fi
  
  if [[ $summary_compressed_block_cache_hits == true ]]; then
    echo "COMPRESSED BLOCK CACHE HITS" >> $data_folder/output_$workload.log
    total_cbc_hits=0
    for (( instance=0; instance<$num_instances; instance++ )); 
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.block.cachecompressed.hit" | cut -d ':' -f 2  | tr -d ' ')
      total_cbc_hits=$((total_cbc_hits+inst))
      echo "Instance: "$instance" val: "$inst >> $data_folder/output_$workload.log
    done
    echo -e "Total compressed_block_cache_hits: "$total_cbc_hits"\n" >> $data_folder/output_$workload.log
  fi
  
  if [[ $summary_compressed_block_cache_misses == true && $summary_compressed_block_cache_hits == true ]]; then
    if [[ $total_cbc_hits -gt 0 ]]; then
      echo -e "Compressed Block Cache Hit Rate: "$((total_cbc_hits*100/(total_cbc_misses+total_cbc_hits)))"\n" >> $data_folder/output_$workload.log
    else
      echo -e "Compressed Block Cache Hit Rate: N/A\n" >> $data_folder/output_$workload.log
    fi
  fi
  
  
  if [[ $summary_p50_get_latency == true ]]; then
    echo "P50 GET LATENCY" >> $data_folder/output_$workload.log
    total_p50_get_latency=0
    for (( instance=0; instance<$num_instances; instance++ )); 
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.db.get.micros" | cut -d ' ' -f 4)
      total_p50_get_latency=$(echo "scale=2; $total_p50_get_latency+$inst" | bc)
      echo "Instance: "$instance" val: "$inst >> $data_folder/output_$workload.log
    done
    avg_p50_get_latency=$(echo "scale=2; $total_p50_get_latency/$num_instances" | bc)
    echo -e "Avg p50_get_latency: "$avg_p50_get_latency"\n" >> $data_folder/output_$workload.log
  fi
  
  if [[ $summary_p99_get_latency == true ]]; then
    echo "P99 GET LATENCY" >> $data_folder/output_$workload.log
    total_p99_get_latency=0
    for (( instance=0; instance<$num_instances; instance++ )); 
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.db.get.micros" | cut -d ' ' -f 10)
      total_p99_get_latency=$(echo "scale=2; $total_p99_get_latency+$inst" | bc)
      echo "Instance: "$instance" val: "$inst >> $data_folder/output_$workload.log
    done
    avg_p99_get_latency=$(echo "scale=2; $total_p99_get_latency/$num_instances" | bc)
    echo -e "Avg p99_get_latency: "$avg_p99_get_latency"\n" >> $data_folder/output_$workload.log
  fi
  
  
  if [[ $summary_p50_put_latency == true ]]; then
    echo "P50 PUT LATENCY" >> $data_folder/output_$workload.log
    total_p50_put_latency=0
    for (( instance=0; instance<$num_instances; instance++ )); 
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.db.write.micros" | cut -d ' ' -f 4)
      total_p50_put_latency=$(echo "scale=2; $total_p50_put_latency+$inst" | bc)
      echo "Instance: "$instance" val: "$inst >> $data_folder/output_$workload.log
    done
    avg_p50_put_latency=$(echo "scale=2; $total_p50_put_latency/$num_instances" | bc)
    echo -e "Avg p50_put_latency: "$avg_p50_put_latency"\n" >> $data_folder/output_$workload.log
  fi
  
  if [[ $summary_p99_put_latency == true ]]; then
    echo "P99 PUT LATENCY" >> $data_folder/output_$workload.log
    total_p99_put_latency=0
    for (( instance=0; instance<$num_instances; instance++ )); 
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.db.write.micros" | cut -d ' ' -f 10)
      total_p99_put_latency=$(echo "scale=2; $total_p99_put_latency+$inst" | bc)
      echo "Instance: "$instance" val: "$inst >> $data_folder/output_$workload.log
    done
    avg_p99_put_latency=$(echo "scale=2; $total_p99_put_latency/$num_instances" | bc)
    echo -e "Avg p99_put_latency: "$avg_p99_put_latency"\n" >> $data_folder/output_$workload.log
  fi
  
  
  if [[ $summary_p50_compression_nanos == true ]]; then
    echo "P50 COMPRESSION NANOS" >> $data_folder/output_$workload.log
    total_p50_compression_nanos=0
    for (( instance=0; instance<$num_instances; instance++ )); 
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.compression.times.nanos" | cut -d ' ' -f 4)
      total_p50_compression_nanos=$(echo "scale=2; $total_p50_compression_nanos+$inst" | bc)
      echo "Instance: "$instance" val: "$inst >> $data_folder/output_$workload.log
    done
    avg_p50_compression_nanos=$(echo "scale=2; $total_p50_compression_nanos/$num_instances" | bc)
    echo -e "Avg p50_compression_nanos: "$avg_p50_compression_nanos"\n" >> $data_folder/output_$workload.log
  fi
  
  if [[ $summary_p50_decompression_nanos == true ]]; then
    echo "P50 DECOMPRESSION NANOS" >> $data_folder/output_$workload.log
    total_p50_decompression_nanos=0
    for (( instance=0; instance<$num_instances; instance++ )); 
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.decompression.times.nanos" | cut -d ' ' -f 4)
      total_p50_decompression_nanos=$(echo "scale=2; $total_p50_decompression_nanos+$inst" | bc)
      echo "Instance: "$instance" val: "$inst >> $data_folder/output_$workload.log
    done
    avg_p50_decompression_nanos=$(echo "scale=2; $total_p50_decompression_nanos/$num_instances" | bc)
    echo -e "Avg p50_decompression_nanos: "$avg_p50_decompression_nanos"\n" >> $data_folder/output_$workload.log
  fi
  
  
  if [[ $summary_stall_micros == true ]]; then
    echo "STALL MICROS" >> $data_folder/output_$workload.log
    total_stall_micros=0
    for (( instance=0; instance<$num_instances; instance++ )); 
    do
      inst=$(cat $data_folder/run_stats_${data_prefix}_$instance.txt | grep "rocksdb.stall.micros" | cut -d ':' -f 2  | tr -d ' ')
      total_stall_micros=$((total_stall_micros+inst))
      echo "Instance: "$instance" val: "$inst >> $data_folder/output_$workload.log
    done
    echo -e "Total total_stall_micros: "$total_stall_micros"\n" >> $data_folder/output_$workload.log
  fi
  
}

# Kill existing instances
pkill -x db_bench

eval $init_command

num_runs=${#run_names[@]}  
for (( i=0; i<$num_runs; i++ ));
do
  echo "Run "$i" started"
  create_data_folders $i
  if [[ "$i" == "1" ]]; then
    echo "begin region of interest"
  fi
  prep_collection "all" $i
  if [[ "$i" == "1" ]];then
    echo "end region of interest"
  fi
  echo "Run "$i" completed"
  aggregate_stats "all" $i
done

# Calculate result
