#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

/^epoch,/ {
  split($0,headers,",")
  next
}

/^.*,[-]*nan/ {
  next
}

/^[0-9.]*,[-+0-9.e]*$/ {
  split($0,tv,",")
  if (tv[1] >= start && tv[1] <= stop) {
    split(FILENAME,files,"/")
    f1=files[length(files)-1]
    f2=files[length(files)]
    split(f2,fields,"-")
    f2=fields[1]
    for (i = 2; i<= length(fields)-3; i++)
      f2=f2"-"fields[i]
    data[f1"/"f2][int(tv[1]*1000)]=tv[2]
  }
}

/^[0-9.]*,[-+0-9.e]*,/ {
  split($0,tv,",")
  if (tv[1] >= start && tv[1] <= stop) {
    split(FILENAME,files,"/")
    f1=files[length(files)-1]
    f2=files[length(files)]
    split(f2,fields,"-")
    f2=fields[1]
    for (i = 2; i<= length(fields)-3; i++)
      f2=f2"-"fields[i]
    t=int(tv[1]*1000)
    for (i=2; i<= length(headers); i++)
      data[f1"/"f2"/"headers[i]][t]=tv[i]
  }
}

function save1(var, k) {
  if (length(data[k])>0) {
    n=asorti(data[k], ta, "@ind_num_asc")
    print "const "var"=["
    for (i=1;i<=n;i++) {
      if (ta[i] < mint || mint == 0) mint=ta[i]
      if (ta[i] > maxt || maxt == 0) maxt=ta[i]
      print "  ["ta[i]","data[k][ta[i]]"],"
    }
    print "];"
  }
}

function save2(var, k1, k2, r) {
  print "const "var"={"
  for (k in data) {
    if (index(k, k1)==1 && index(k,"/"k2)>0) {
      d=gensub(/\/.*$/,"","1",substr(k,length(k1)+1))
      if (match(d,r)>0) {
        print "  '"d"': ["
        n=asorti(data[k], ta, "@ind_num_asc")
        for (i=1;i<=n;i++) {
          if (ta[i] < mint || mint == 0) mint=ta[i]
          if (ta[i] > maxt || maxt == 0) maxt=ta[i]
          print "    ["ta[i]","data[k][ta[i]]"],"
        }
        print "  ],"
      }
    }
  }
  print "};"
}

END {
  mint=0
  maxt=0
  save1("cpu_idle", "aggregation-cpu-average/cpu-idle")
  save1("cpu_interrupt", "aggregation-cpu-average/cpu-interrupt")
  save1("cpu_nice", "aggregation-cpu-average/cpu-nice")
  save1("cpu_softirq", "aggregation-cpu-average/cpu-softirq")
  save1("cpu_steal", "aggregation-cpu-average/cpu-steal")
  save1("cpu_system", "aggregation-cpu-average/cpu-system")
  save1("cpu_user", "aggregation-cpu-average/cpu-user")
  save1("cpu_wait", "aggregation-cpu-average/cpu-wait")
  save1("cpu_freq", "aggregation-cpufreq-average/cpufreq")
  save1("memory_free", "memory/memory-free")
  save1("memory_used", "memory/memory-used")
  save1("memory_cached", "memory/memory-cached")
  save1("memory_buffered", "memory/memory-buffered")
  save1("memory_slab_recl", "memory/memory-slab_recl")
  save1("memory_slab_unrecl", "memory/memory-slab_unrecl")
  save2("if_packages_rx", "interface-", "if_packets/rx", ".*")
  save2("if_packages_tx", "interface-", "if_packets/tx", ".*")
  save2("disk_ops_read", "disk-", "disk_ops/read", ".*")
  save2("disk_ops_write", "disk-", "disk_ops/write", ".*")
  save2("cpu_x_idle", "cpu-", "cpu-idle", "[0-9]*")
  save2("cpu_x_nice", "cpu-", "cpu-nice", "[0-9]*")
  save2("cpu_x_interrupt", "cpu-", "cpu-interrupt", "[0-9]*")
  save2("cpu_x_softirq", "cpu-", "cpu-softirq", "[0-9]*")
  save2("cpu_x_steal", "cpu-", "cpu-steal", "[0-9]*")
  save2("cpu_x_system", "cpu-", "cpu-system", "[0-9]*")
  save2("cpu_x_user", "cpu-", "cpu-user", "[0-9]*")
  save2("cpu_x_wait", "cpu-", "cpu-wait", "[0-9]*")
  save2("cpu_x_freq", "cpufreq-", "cpufreq", "[0-9]*")
  print "const min_time="mint", max_time="maxt";"
}
