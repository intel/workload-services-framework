#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

awk '
function kvformat(key, value) {
    unit=gensub(/^[0-9+-.]+ *(.*)/,"\\1",1, value);
    value=gensub(/^([0-9+-.]+).*/,"\\1",1, value)
    key=gensub(/(.*): *$/,"\\1",1, key);
    if (unit!="") key=key" ("unit")";
    return key": "value;
}
BEGIN {
    i = 0
    op_rate_sum=0
    partion_rate_sum=0
    row_rate_sum=0
    op_rate_list[i]=0
    partion_rate_list[i]=0
    row_rate_list[i]=0
    latency_mean_list[i]=0
    latency_median_list[i]=0
    latency_95th_percentile_list[i]=0
    latency_99th_percentile_list[i]=0
    latency_99_9th_percentile_list[i]=0
    latency_max[i]=0
    total_errors[i]=0
    total_insert_errors[i]=0
    total_simple_errors[i]=0
    total_gc_count[i]=0
    total_gc_memory[i]=0
    total_gc_time[i]=0
    avg_gc_time[i]=0
    total_operation_time_list[i]=0
}
/Op rate/{
    op=$0
    gsub(",", "", op)
    split(op, opValueColumn, ":");
    split(opValueColumn[2], opValues, "op/s");
    split(opValues[1], opValue, " ");
    op_rate_list[i] = opValue[1]
    }

/Partition rate/{
    p_rate=$0
    gsub(",", "", p_rate)
    split(p_rate, opValueColumn, ":");
    split(opValueColumn[2], opValues, "pk/s");
    split(opValues[1], opValue, " ");
    partion_rate_list[i] = opValue[1]
    }
/Row rate/{
    r_rate=$0
    gsub(",", "", r_rate)
    split(r_rate, opValueColumn, ":");
    split(opValueColumn[2], opValues, "row/s");
    split(opValues[1], opValue, " ");
    row_rate_list[i] = opValue[1]
    }
/Latency mean/{
    mean=$0
    gsub(",", "", mean)
    split(mean, opValueColumn, ":");
    split(opValueColumn[2], opValues, "ms");
    split(opValues[1], opValue, " ");
    latency_mean_list[i] = opValue[1]
    }
/Latency median/{
    median=$0
    gsub(",", "", median)
    split(median, opValueColumn, ":");
    split(opValueColumn[2], opValues, "ms");
    split(opValues[1], opValue, " ");
    latency_median_list[i] = opValue[1]
    }
/Latency 95th percentile/{
    p_95=$0
    gsub(",", "", p_95)
    split(p_95, opValueColumn, ":");
    split(opValueColumn[2], opValues, "ms");
    split(opValues[1], opValue, " ");
    latency_95th_percentile_list[i] = opValue[1]
    }
/Latency 99th percentile/{
    p_99=$0
    gsub(",", "", p_99)
    split(p_99, opValueColumn, ":");
    split(opValueColumn[2], opValues, "ms");
    split(opValues[1], opValue, " ");
    latency_99th_percentile_list[i] = opValue[1]
    }
/Latency 99.9th percentile/{
    p_99_9=$0
    gsub(",", "", p_99_9)
    split(p_99_9, opValueColumn, ":");
    split(opValueColumn[2], opValues, "ms");
    split(opValues[1], opValue, " ");
    latency_99_9th_percentile_list[i] = opValue[1]
    }
/Latency max/{
    p_99_9=$0
    gsub(",", "", p_99_9)
    split(p_99_9, opValueColumn, ":");
    split(opValueColumn[2], opValues, "ms");
    split(opValues[1], opValue, " ");
    latency_max[i] = opValue[1]
    }

/Total errors/{
    errors=$0
    gsub(",", "", errors)
    split(errors, opValueColumn, ":");
    split(opValueColumn[2], opValues, "[");
    split(opValues[1], err_all, " ");
    total_errors[i] = err_all[1]
    split(opValueColumn[2], insert, " ");
    split(opValueColumn[3], simple, " ");
    total_insert_errors[i]=insert[1]
    total_simple_errors[i]=simple[1]
}

/Total GC count/{
    gc_count=$0
    gsub(",", "", gc_count)
    split(gc_count, opValueColumn, ":");
    split(opValueColumn[2], opValue, " ");
    total_gc_count[i] = opValue[1]
}

/Total GC memory/{
    gc_memory=$0
    gsub(",", "", gc_memory)
    split(gc_memory, opValueColumn, ":");
    split(opValueColumn[2], opValues, "KiB");
    split(opValues[1], opValue, " ");
    total_gc_memory[i] = opValue[1]
}

/Total GC time/{
    gc_time=$0
    gsub(",", "", gc_time)
    split(gc_time, opValueColumn, ":");
    split(opValueColumn[2], opValues, "seconds");
    split(opValues[1], opValue, " ");
    total_gc_time[i] = opValue[1]
}

/Avg GC time/{
    avg_time=$0
    gsub(",", "", avg_time)
    split(avg_time, opValueColumn, ":");
    split(opValueColumn[2], opValues, "ms");
    split(opValues[1], opValue, " ");
    avg_gc_time[i] = opValue[1]

}

/Total operation time/{
    op_time=$0
    gsub(",", "", op_time)
    split(op_time, opValueColumn, " ");
    split(opValueColumn[5], timeArry, ":")
    total_operation_time_list[i] = timeArry[1]*60 + timeArry[2]
    i += 1;
    }

END {
    for (counter = 0; counter < i; counter++) {
        printf "Stress " counter
        print kvformat(" Op rate",op_rate_list[counter] "op/s")
        printf "Stress " counter
        print kvformat(" Partition rate",partion_rate_list[counter] "pk/s")
        printf "Stress " counter
        print kvformat(" Row rate",row_rate_list[counter] "row/s")
        printf "Stress " counter
        print kvformat(" Latency mean",latency_mean_list[counter] "ms")
        printf "Stress " counter
        print kvformat(" Latency median",latency_median_list[counter] "ms")
        printf "Stress " counter
        print kvformat(" Latency 95th percentile",latency_95th_percentile_list[counter] "ms")
        printf "Stress " counter
        print kvformat(" Latency 99th percentile",latency_99th_percentile_list[counter] "ms")
        printf "Stress " counter
        print kvformat(" Latency 99.9th percentile",latency_99_9th_percentile_list[counter] "ms")
        printf "Stress " counter
        print kvformat(" Latency max",latency_max[counter] "ms")
        printf "Stress " counter
        print kvformat(" Total errors",total_errors[counter] "")
        printf "Stress " counter
        print kvformat(" Total operation time",total_operation_time_list[counter] "minute")
        op_rate_sum += op_rate_list[counter]
        all_errors += total_errors[counter]
        all_insert_errors += total_insert_errors[counter]
        all_simple_errors += total_simple_errors[counter]
    }
    print kvformat("*Final Op rate",op_rate_sum "op/s")
}
' */benchmark_output*.log 2>/dev/null || true
