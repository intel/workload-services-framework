#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

totalStorageSize=0
totalIndexSize=0
totalSize=0
fileCount=0

for file in benchmark*/ycsb_output.json
do
    totalStorageSize=$(awk "BEGIN {print $totalStorageSize + $(jq '.storageSize' $file)}")
    totalIndexSize=$(awk "BEGIN {print $totalIndexSize + $(jq '.totalIndexSize' $file)}")
    totalSize=$(awk "BEGIN {print $totalSize + $(jq '.totalSize' $file)}")
    fileCount=$((fileCount + 1))
done

# avgStorageSize=$(echo "scale=2; $totalStorageSize / $fileCount" | bc)
# avgIndexSize=$(echo "scale=2; $totalIndexSize / $fileCount" | bc)
# avgTotalSize=$(echo "scale=2; $totalSize / $fileCount" | bc)

printf "Total storageSize: %.2f\n" $totalStorageSize
printf "Total IndexSize: %.2f\n" $totalIndexSize
printf "Total Size: %.2f\n" $totalSize

awk '
BEGIN{
    i=0
}

BEGINFILE {
    i=ARGIND-1
    load_overall_throughput_list[i]=0
    load_cleanup_averagelatency_list[i]=0
    load_insert_avergelatency_list[i]=0
    load_insert_minlatency_list[i]=0
    load_insert_maxlatency_list[i]=0
    load_insert_p99latency_list[i]=0
    run_overall_throughput_list[i]=0
    run_cleanup_averagelatency_list[i]=0
    run_read_averagelatency_list[i]=0
    run_read_minlatency_list[i]=0
    run_read_maxlatency_list[i]=0
    run_read_p99latency_list[i]=0
    run_update_averagelatency_list[i]=0
    run_update_minlatency_list[i]=0
    run_update_maxlatency_list[i]=0
    run_update_p99latency_list[i]=0
    run_insert_averagelatency_list[i]=0
    run_insert_minlatency_list[i]=0
    run_insert_maxlatency_list[i]=0
    run_insert_p99latency_list[i]=0
    run_logs[i]=""
    job_index=-1
    run_target=""
    load_phase_rc="1"
    run_phase_rc="1"
}

/JOB_INDEX is/ {
    split($0, job_data, " ")
    job_index=job_data[3]
}

/YCSB load succeeded/ {
    load_phase_rc="0"
}

/YCSB run succeeded/ {
    run_phase_rc="0"
    run_successes[i]=1
}

/start mongodb, connect to/ {
    split($0, run_data, " ")
    run_target=run_data[5]
}

/\[LOAD_PHASE\]/ {
    print "Counter of [LOAD_PHASE]: "i
    run_phase=0
}

/\[RUN_PHASE\]/ {
    print "Counter of [RUN_PHASE]: "i
    run_phase=1
}

/\[OVERALL\], Throughput/ {
    split($0, throughput, ",")
    if(run_phase==1){
        print "[OVERALL RUN]["job_index"] Throughput(ops/sec): " throughput[3]
        run_overall_throughput_list[i]=throughput[3]
    } else {
        print "[OVERALL LOAD]["job_index"] Throughput(ops/sec): " throughput[3]
        load_overall_throughput_list[i]=throughput[3]
    }
}

/\[INSERT\], AverageLatency/ {
    split($0, inst_avl, ",")
    if(run_phase==1){
        print "[INSERT RUN]["job_index"] AverageLatency(us): " inst_avl[3]
        run_insert_averagelatency_list[i]=inst_avl[3]
    } else {
        print "[INSERT LOAD]["job_index"] AverageLatency(us): " inst_avl[3]
        load_insert_averagelatency_list[i]=inst_avl[3]
    }
}

/\[INSERT\], MinLatency/ {
    split($0, inst_min_lat, ",")
    if(run_phase==1){
        print "[INSERT RUN]["job_index"] MinLatency(us): " inst_min_lat[3]
        run_insert_minlatency_list[i]=inst_min_lat[3]
    } else {
        print "[INSERT LOAD]["job_index"] MinLatency(us): " inst_min_lat[3]
        load_insert_minlatency_list[i]=inst_min_lat[3]
    }
}

/\[INSERT\], MaxLatency/ {
    split($0, inst_max_lat, ",")
    if(run_phase==1){
        print "[INSERT RUN]["job_index"] MaxLatency(us): " inst_max_lat[3]
        run_insert_maxlatency_list[i]=inst_max_lat[3]
    } else {
        print "[INSERT LOAD]["job_index"] MaxLatency(us): " inst_max_lat[3]
        load_insert_maxlatency_list[i]=inst_max_lat[3]
    }
}

/\[INSERT\], 99thPercentileLatency/ {
    split($0, inst_p99_lat, ",")
    if(run_phase==1){
        print "[INSERT RUN]["job_index"] 99thPercentileLatency(us): " inst_p99_lat[3]
        run_insert_p99latency_list[i]=inst_p99_lat[3]
    } else {
        print "[INSERT LOAD]["job_index"] 99thPercentileLatency(us): " inst_p99_lat[3]
        load_insert_p99latency_list[i]=inst_p99_lat[3]
    }
}

/\[READ\], AverageLatency\(us\)/ {
    split($0, read_avl, ",")
    print "[READ]["job_index"] AverageLatency(us): " read_avl[3]
    run_read_averagelatency_list[i]=read_avl[3]
}

/\[READ\], MinLatency\(us\)/ {
    split($0, read_min_lat, ",")
    print "[READ]["job_index"], MinLatency(us):" read_min_lat[3]
    run_read_minlatency_list[i]=read_min_lat[3]
}

/\[READ\], MaxLatency\(us\)/ {
    split($0, read_man_lat, ",")
    print "[READ]["job_index"], MaxLatency(us):" read_man_lat[3]
    run_read_maxlatency_list[i]=read_man_lat[3]
}

/\[READ\], 99thPercentileLatency/ {
    split($0, read_p99_lat, ",")
    print "[READ]["job_index"], 99thPercentileLatency(us):" read_p99_lat[3]
    run_read_p99latency_list[i]=read_p99_lat[3]
}

/\[UPDATE\], AverageLatency\(us\)/ {
    split($0, updt_avl, ",")
    print "[UPDATE]["job_index"] AverageLatency(us): " updt_avl[3]
    run_update_averagelatency_list[i]=updt_avl[3]
}

/\[UPDATE\], MinLatency\(us\)/ {
    split($0, upd_min_lat, ",")
    print "[UPDATE]["job_index"], MinLatency(us): " upd_min_lat[3]
    run_update_minlatency_list[i]=upd_min_lat[3]
}

/\[UPDATE\], MaxLatency\(us\)/ {
    split($0, upd_max_lat, ",")
    print "[UPDATE]["job_index"], MaxLatency(us): " upd_max_lat[3]
    run_update_maxlatency_list[i]=upd_max_lat[3]
}

/\[UPDATE\], 99thPercentileLatency/ {
    split($0, upd_p99_lat, ",")
    print "[UPDATE]["job_index"], 99thPercentileLatency(us): " upd_p99_lat[3]
    run_update_p99latency_list[i]=upd_p99_lat[3]
}

/\[CLEANUP\], AverageLatency\(us\)/ {
    split($0, cle_avl, ",")
    print "[CLEANUP]["job_index"], AverageLatency(us): " cle_avl[3]
    if(run_phase==1){
        run_cleanup_averagelatency_list[i]=cle_avl[3]
    } else
    {
        load_cleanup_averagelatency_list[i]=cle_avl[3]
    }
}

ENDFILE{
    print "[LOAD PHASE RC]["job_index"](return code): " load_phase_rc
    print "[RUN PHASE RC]["job_index"](return code): " run_phase_rc
}

END{
    sum_of_run_p99_insert_latency=0
    for(i in run_insert_p99latency_list){
        sum_of_run_p99_insert_latency+=run_insert_p99latency_list[i]
    }
    print "Mean of [RUN PHASE] P99 insert latency(us): "sum_of_run_p99_insert_latency/length(run_insert_p99latency_list)

    sum_of_run_p99_read_latency=0
    for(i in run_read_p99latency_list){
        sum_of_run_p99_read_latency+=run_read_p99latency_list[i]
    }
    print "Mean of [RUN PHASE] P99 read latency(us): "sum_of_run_p99_read_latency/length(run_read_p99latency_list)

    sum_of_run_p99_update_latency=0
    for(i in run_update_p99latency_list){
        sum_of_run_p99_update_latency+=run_update_p99latency_list[i]
    }
    print "Mean of [RUN PHASE] P99 update latency(us): "sum_of_run_p99_update_latency/length(run_update_p99latency_list)

    sum_of_run_throughput=0
    for(i in run_overall_throughput_list){
        sum_of_run_throughput+=run_overall_throughput_list[i]
    }
    print "Mean of [RUN PHASE] Throughput(ops/sec): "sum_of_run_throughput/length(run_overall_throughput_list)
    print "*Sum of [RUN PHASE] Throughput(ops/sec): "sum_of_run_throughput
}

' $(find . -name 'output*.logs') 2>/dev/null || true