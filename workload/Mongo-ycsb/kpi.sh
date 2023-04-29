#!/bin/bash -e

awk '
BEGIN{
    i=0
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
}

{
    i=ARGIND-1
}

/\[LOAD PHASE\]/ {
    print "Counter of [LOAD PHASE]: "i
    run_phase=0
}

/\[OVERALL\], Throughput/ {
    split($0, throughput, ",")
    if(run_phase==1){ 
        print "[OVERALL] Throughput(ops/sec): " throughput[3]
        run_overall_throughput_list[i]=throughput[3]
    } else 
    {
        print "[OVERALL] Throughput(ops/sec): " throughput[3]
        load_overall_throughput_list[i]=throughput[3]
    }
}

/\[INSERT\], AverageLatency/ {
    split($0, inst_avl, ",")
    if(run_phase==1){ 
        print "[INSERT] AverageLatency(us): " inst_avl[3]
        run_insert_averagelatency_list[i]=inst_avl[3]
    } else 
    {
        print "[INSERT] AverageLatency(us): " inst_avl[3]
        load_insert_averagelatency_list[i]=inst_avl[3]
    }
}

/\[INSERT\], MinLatency/ {
    split($0, inst_min_lat, ",")
    if(run_phase==1){ 
        print "[INSERT] MinLatency(us): " inst_min_lat[3]
        run_insert_minlatency_list[i]=inst_min_lat[3]
    } else 
    {
        print "[INSERT] MinLatency(us): " inst_min_lat[3]
        load_insert_minlatency_list[i]=inst_min_lat[3]
    }
}

/\[INSERT\], MaxLatency/ {
    split($0, inst_max_lat, ",")
    if(run_phase==1){ 
        print "[INSERT] MaxLatency(us): " inst_max_lat[3]
        run_insert_maxlatency_list[i]=inst_max_lat[3]
    } else 
    {
        print "[INSERT] MaxLatency(us): " inst_max_lat[3]
        load_insert_maxlatency_list[i]=inst_max_lat[3]
    }
}

/\[INSERT\], 99thPercentileLatency/ {
    split($0, inst_p99_lat, ",")
    if(run_phase==1){ 
        print "[INSERT] 99thPercentileLatency(us): " inst_p99_lat[3]
        run_insert_p99latency_list[i]=inst_p99_lat[3]
    } else 
    {
        print "[INSERT] 99thPercentileLatency(us): " inst_p99_lat[3]
        load_insert_p99latency_list[i]=inst_p99_lat[3]
    }
}

/\[RUN PHASE\]/ {
    print "Counter of [RUN PHASE]: "i
    run_phase=1
}

/\[READ\], AverageLatency\(us\)/ {
    split($0, read_avl, ",")
    print "[READ] AverageLatency(us): " read_avl[3]
    run_read_averagelatency_list[i]=read_avl[3]
}

/\[READ\], MinLatency\(us\)/ {
    split($0, read_min_lat, ",")
    print "[READ], MinLatency(us):" read_min_lat[3]
    run_read_minlatency_list[i]=read_min_lat[3]
}

/\[READ\], MaxLatency\(us\)/ {
    split($0, read_man_lat, ",")
    print "[READ], MaxLatency(us):" read_man_lat[3]
    run_read_maxlatency_list[i]=read_man_lat[3]
}

/\[READ\], 99thPercentileLatency/ {
    split($0, read_p99_lat, ",")
    print "[READ], 99thPercentileLatency(us):" read_p99_lat[3]
    run_read_p99latency_list[i]=read_p99_lat[3]
}


/\[UPDATE\], AverageLatency\(us\)/ {
    split($0, updt_avl, ",")
    print "[UPDATE] AverageLatency(us): " updt_avl[3]
    run_update_averagelatency_list[i]=updt_avl[3]
}

/\[UPDATE\], MinLatency\(us\)/ {
    split($0, upd_min_lat, ",")
    print "[UPDATE], MinLatency(us): " upd_min_lat[3]
    run_update_minlatency_list[i]=upd_min_lat[3]
}

/\[UPDATE\], MaxLatency\(us\)/ {
    split($0, upd_max_lat, ",")
    print "[UPDATE], MaxLatency(us): " upd_max_lat[3]
    run_update_maxlatency_list[i]=upd_max_lat[3]
}

/\[UPDATE\], 99thPercentileLatency/ {
    split($0, upd_p99_lat, ",")
    print "[UPDATE], 99thPercentileLatency(us): " upd_p99_lat[3]
    run_update_p99latency_list[i]=upd_p99_lat[3]
}

/\[CLEANUP\], AverageLatency\(us\)/ {
    split($0, cle_avl, ",")
    print "[CLEANUP], AverageLatency(us): " cle_avl[3]
    if(run_phase==1){ 
        run_cleanup_averagelatency_list[i]=cle_avl[3]
    } else 
    {
        load_cleanup_averagelatency_list[i]=cle_avl[3]
    }
}

END{
    print "Summary:"
   
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
    print "Mean of [run phase] Throughput(ops/sec): "sum_of_run_throughput/length(run_overall_throughput_list)
    print "*Sum of [run phase] Throughput(ops/sec): "sum_of_run_throughput

}

' $(find . -name 'output*.logs') 2>/dev/null || true
