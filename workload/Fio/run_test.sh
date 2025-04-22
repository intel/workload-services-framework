#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

#configuration_parameters

BASE_PATH=/home
LOG_PATH=${BASE_PATH}/logs

test_type=${TEST_TYPE:-"sequential_read"}
block_size=${BLOCK_SIZE:-512}
io_depth=${IO_DEPTH:-4}
file_size=${FILE_SIZE:-6}
io_size=${IO_SIZE:-6}
io_engine=${IO_ENGINE:-"libaio"}
num_jobs=${NUM_JOBS:-1}
cpus_allowed=${CPUS_ALLOWED:-1}
cpus_allowed_policy=${CPUS_ALLOWED_POLICY:-"split"}
run_time=${RUN_TIME:-10}
ramp_time=${RAMP_TIME:-10}
rwmix_read=${RWMIX_READ:-50}
rwmix_write=${RWMIX_WRITE:-50}
buffer_compress_percentage=${BUFFER_COMPRESS_PERCENTAGE:-0}
buffer_compress_chunk=${BUFFER_COMPRESS_CHUNK:-0}
file_name=${FILE_NAME:-"nvme0n1"} # for example "FILE_NAME=nvme0n1,nvme1n1".
invalidate=${INVALIDATE:-0}
overwrite=${OVERWRITE:-0}

case "$test_type" in
  "sequential_read")
    name=sequential_read_test
    invalidate=1
    overwrite=0
    rw=read
  ;;
  "sequential_write")
    name=sequential_write_test 
    overwrite=0
    rw=write
  ;;
  "random_read")
    name=random_read_test
    invalidate=1
    rw=randread
  ;;
  "random_write")
    name=random_write_test
    overwrite=1
    rw=randwrite
  ;;
  "sequential_read_write")
    name=sequential_read_write_test
    invalidate=1
    rw=readwrite
  ;;
  "random_read_write")
    name=random_read_write_test
    invalidate=1
    rw=randrw
  ;;
esac

echo "Start the benchmark operation ${test_type}, rw=${rw}"
FIO_CONFIG_FILE="${test_type}_${block_size}"
cat>>${BASE_PATH}/${FIO_CONFIG_FILE}.fio<<EOF
[global]
ioengine=$io_engine
name=$name
invalidate=$invalidate
overwrite=$overwrite
rw=$rw
filesize=$file_size$FILE_SIZE_UNIT
blocksize=$block_size$BLOCK_SIZE_UNIT
size=$io_size$IO_SIZE_UNIT
iodepth=$io_depth
direct=1
numjobs=$num_jobs
thread
cpus_allowed=$cpus_allowed
cpus_allowed_policy=$cpus_allowed_policy
runtime=$run_time
ramp_time=$ramp_time
rwmixread=$rwmix_read
rwmixwrite=$rwmix_write
buffer_compress_percentage=$buffer_compress_percentage
buffer_compress_chunk=$buffer_compress_chunk
time_based
EOF

file_name_array=($(echo ${file_name} | tr -t ',' ' ' )) # (nvme0n1,nvme1n1,nvme2n1) -> (nvme0n1 nvme1n1 nvme2n1)
i=1
for device in ${file_name_array[*]}; do
    cat >>${BASE_PATH}/${FIO_CONFIG_FILE}.fio<<EOF
[job$i]
filename=${device}
EOF
    i=$((i+1))
done

# Show fio config file
cat ${BASE_PATH}/${FIO_CONFIG_FILE}.fio

# ROI: Benchmark start flag for emon data collection
echo "Start benchmark"

${BASE_PATH}/fio ${BASE_PATH}/${FIO_CONFIG_FILE}.fio

# ROI: Benchmark end flag for emon data collection
echo "Finish benchmark"
echo "== End of the test =="
