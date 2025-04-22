#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

itr="$(pwd | rev | cut -f1 -d- | rev)"
output_logs="$(ls -1 */benchmark_*.log 2> /dev/null || true)"
pdu_logs="$(ls -1 ../worker-0-$itr-pdu/pdu-*.logs 2> /dev/null || true)"

server_info="$(ls -1 ../worker-0-svrinfo/*.json 2> /dev/null || true)"
results_csv="$(ls -1 */results/results_*/results.csv 2> /dev/null || true)"

update_results_csv () {
    if [[ -z "$server_info" || -z "$results_csv" ]]; then
            return
    fi
    find_str=$1
    replace_str=$2
    res=$(grep -o "\"$find_str\""': "[^"]*' $server_info | grep -o '[^"]*$'  | head -1)
    if [ -n "$res" ]; then
        sed -i "s#.*$replace_str.*,=\"Not Found\"#$replace_str,=\"$res\"#g" $results_csv
    fi
}

update_results_csv "TDP" "CPU TDP"
update_results_csv "All-core Maximum Frequency" "Non-AVX Max All Cores Turbo Frequency"
update_results_csv "Product Name" "SUT Model"
update_results_csv "Configured Speed" "Memory Speed"
update_results_csv "Base Frequency" "CPU Base Frequency"
update_results_csv "Power & Perf Policy" "Power and Policy"
update_results_csv "Intel Turbo Boost" "Intel Turbo"


if [ -r "$pdu_logs" ]; then
    awk -v time_spec="$(grep -m1 -v -- --- ../worker-0-$itr-pdu/TRACE_START)" '
        function run_date(cmd) {
            cmd | getline date_out
            close(cmd)
            return date_out
        }
        NR>FNR && FNR>1 {
            split($0,kv,",")
            power[kv[1]]=int(kv[2]*1000+0.5)/1000
            energy[kv[1]]=int(kv[3]*1000+0.5)/1000
        }
        NR==FNR && /Running test: / {
            t1=run_date("date -u -d "gensub(/T[0-9]*:[0-9]*:[0-9]*[,.][0-9]*.*/,"T"$2"+00:00",1,time_spec)" +%s")*1000
            suite[t1]=gensub(/"/,"","g",$7)
        }
        END {
            ns=asorti(suite,isuite,"@ind_num_asc")
            np=asorti(energy,ipdu,"@ind_num_asc")
            tj=(isuite[1]<ipdu[1])?isuite[1]-ipdu[1]:0
            for (i=1;i<=ns;i++) {
                ae=0; ap=0; me=0; mp=0; n=0
                for(j=1;j<=np;j++) {
                  if ((ipdu[j]+tj>=isuite[i]) && ((i+1>ns) || (ipdu[j]+tj<=isuite[i+1]))) {
                    if (energy[ipdu[j]]>me) me=energy[ipdu[j]]
                    if (power[ipdu[j]]>mp) mp=power[ipdu[j]]
                    ae=ae+energy[ipdu[j]]
                    ap=ap+power[ipdu[j]]
                    n++
                  }
                }
                if (n!=0) {
                    ae=ae/n; ap=ap/n
                } else {
                    ae=0; ap=0
                }
                print suite[isuite[i]]" avg pdu power (W): "ap
                print suite[isuite[i]]" max pdu power (W): "mp
                print suite[isuite[i]]" avg pdu energy (WH): "ae
                print suite[isuite[i]]" max pdu energy (WH): "me
            }
        }
    ' "$output_logs" "$pdu_logs"
fi

pcm_logs="$(ls -1 ../worker-0-$itr-pcm/roi-*/power.records 2> /dev/null || true)"
if [ -r "$pcm_logs" ]; then
    awk -v time_spec="$(grep -m1 -v -- --- ../worker-0-$itr-pcm/TRACE_START)" '
        function run_date(cmd) {
            cmd | getline date_out
            close(cmd)
            return date_out
        }
        BEGIN {
            t0=run_date("date -u -d "time_spec" +%s")*1000
        }
        NR>FNR && /^Time elapsed:/ {
            t0=t0+$3
            t1=t0
        }
        NR>FNR && /^S[0-9]*; Consumed energy units:/ {
            energy[t1]=energy[t1]+gensub(/;/,"",1,$10)
        }
        NR==FNR && /Running test: / {
            t1=run_date("date -u -d "gensub(/T[0-9]*:[0-9]*:[0-9]*[,.][0-9]*.*/,"T"$2"+00:00",1,time_spec)" +%s")*1000
            suite[t1]=gensub(/"/,"","g",$7)
        }
        END {
            ns=asorti(suite,isuite,"@ind_num_asc")
            ne=asorti(energy,ipcm,"@ind_num_asc")
            tj=(isuite[1]<ipcm[1])?isuite[1]-ipcm[1]:0
            for (i=1;i<=ns;i++) {
                ae=0
                me=0
                n=0
                for(j=1;j<=ne;j++) {
                  if ((ipcm[j]+tj>=isuite[i]) && ((i+1>ns) || (ipcm[j]+tj<=isuite[i+1]))) {
                    if (energy[ipcm[j]]>me) me=energy[ipcm[j]]
                    ae=ae+energy[ipcm[j]]
                    n++
                  }
                }
                if (n!=0) ae=ae/n; else ae=0
                print suite[isuite[i]]" avg socket power (W): "ae
                print suite[isuite[i]]" max socket power (W): "me
            }
        }
    ' "$output_logs" "$pcm_logs"
fi

awk '
BEGIN{
    pass=0
    fail=0
    primary="*"
}
/sub_test_name :/ {
    test=$3
}
/^Pass/ {
    pass=pass+1
}

/cpu_utilization/ {
    print test" cpu_utilization(%): "$3;
}

/density_instances/ {
    print test" "$0;
}

/cpu_threshold/ {
    print test" "$0;
}

/avg_cpu_frequency/ {
    avg_cpu_frequency=$3
    print test" avg_cpu_frequency(MHz): "$3;
}

/lowest_fps :/ {
    print test" lowest_fps: "$3;
}

/total_fps/ {
    total_fps=$3
    print primary test" total_fps(frames per seconds): "$3;
    primary=""
}

/fps_threshold/ {
    print test" "$0;
}

/logical_core_number/ {
    logical_core_number=$3
}

/transcodes/ {
    print test" transcodes(instances): "$3;
}

/num_tests_run/ {
    print "num_tests_run: "$3;
}

/num_tests_passed/ {
    print "num_tests_passed : "$3;
}

/success_percentage/ {
    print "success_percentage(%): "$3;
}

/run_time/ {
    print $0;
}

/fail/ {
    fail=fail+1
}
END {
    printf "fps/core: %.2f\n",(total_fps/logical_core_number)
    printf "fps/core/Ghz: %.2f\n",((total_fps/logical_core_number)/(avg_cpu_frequency/1000))
}
' $output_logs 2>/dev/null || true

