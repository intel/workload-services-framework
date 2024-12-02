#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

awk '
function kvformat(key, value) {
    unit=gensub(/^[0-9+-.]+ *(.*)/,"\\1",1, value);
    value=gensub(/^([0-9+-.]+).*/,"\\1",1, value);
    key=gensub(/(.*): *$/,"\\1",1, key);
    if (unit!="") key=key" ("unit")";
    return key": "value;
}

# For --idle-latency
/--idle_latency / {
    while (getline) {
        primary="*"
        if (/^Each iteration took [0-9+-.]+ base frequency clocks/) {
            sum+=$(NF-1);
            count++;
            metric=substr($NF,1,length($NF-1))
            print kvformat("clocks per iteration (clocks)",$4);
            print kvformat("time per iteration (ns)",$9);
        }
    }
    print primary kvformat("Average Idle Latency (ns)", sum/count);
}

# For --c2c_latency
/Measuring cache-to-cache transfer latency/ {
    while (getline) {
        primary="*"
        if (/^Latency = [0-9+-.]+ base frequency clocks/) {
            sum+=substr($(NF-1),2);
            count++;
            metric=substr($NF,1,length($NF-1))
            print kvformat("Latency= ",$3);
            print kvformat("time per iteration (ns)",substr($(NF-1),2));
        }
    }
    print primary kvformat("Average C2C Latency (ns)", sum/count);
}

# For cache-to-cache transfer latency
/Measuring cache_to_cache_transfer_latency/ {
    while (getline) {
        primary="*";
        if (/^Local Socket L2->L2 HIT  latency/) {
            l2_hit_latency = $NF;
            print primary kvformat("Local Socket L2->L2 HIT Latency (ns)", l2_hit_latency);
        } else if (/^Local Socket L2->L2 HITM latency/) {
            l2_hitm_latency = $NF;
            print kvformat("Local Socket L2->L2 HITM Latency (ns)", l2_hitm_latency);
        }
    }
}

# For --loaded_latency
/^Delay\s+\(ns\)\s+MB\/sec/ && NF==3 {
    primary="*";
    while (getline) {
        if (/^Command line parameters/) {
            print("\n");
            print ($0);
        }
        if ($1~/[0-9]+/ && NF==3) {
            if ($1 == "00000" && count == 1) {
                print primary kvformat($1"_Bandwidth (GB/sec)", $3/1000);
            }
            else {
                print kvformat($1"_Bandwidth (MB/sec)", $3);
                print kvformat($1"_Latency (ns)", $2);
            }
            print kvformat($1"_Bandwidth (GB/sec)", $3/1000);
            print kvformat($1"_Bandwidth (MB/sec)", $3);
        }
        count++;
    }
}

# For --latency_matrix
(/^Numa node/ && NF>=3) || (/^Socket/ && NF>=2) {
    primary="*";
    while (getline) {
        if ($1~/[0-9]+/ && NF>=2) {
            for (node = 0; node < NF - 1; node++) {
                node_lat = node + 2;
                if ($1 == "0" && node == "0")
                    print primary kvformat("Numa node "$1"-"node" (ns)",$node_lat);
                else
                    print kvformat("Numa node "$1"-"node" (ns)",$node_lat);
            }
        } else {
            break;
        }
    }
}

# For --peak_injection_bandwidth
/^Measuring Peak Injection Memory Bandwidths for the system/ {
    while (getline) {
        primary="*";
        if (/^ALL Reads/) {
            print kvformat($1" "$2" (MB/sec)", $4);
        }
        if (/^4:1 Reads-Writes/ ||
            /^3:1 Reads-Writes/ ||
            /^2:1 Reads-Writes/ ||
            /^1:1 Reads-Writes/) {
            print kvformat($1" "$2" (MB/sec)", $4);
        }
        if ($1 == "00000") {
            print kvformat("3:2 Reads-Writes (MB/sec)", $3);
        }
        if (/^Stream-triad like:/) {
            print primary kvformat("Stream-triad like (MB/sec):", $NF);
        }
    }
}

' */output.logs 2>/dev/null || true
