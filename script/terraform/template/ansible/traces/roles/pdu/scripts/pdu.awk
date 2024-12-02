#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
BEGIN {
    total_power=0
    total_energy=0
    count=0
}
function save(v, a) {
  n=asorti(a,ta,"@ind_num_asc")
  print "const data_"v"=["
  for (i=1;i<=n;i++) {
    print "  ["ta[i]","a[ta[i]]"],"
  }
  print "];"
}
NR == 2 {
    split($0, min, ",")
    min_time = min[1]
}
NR > 1 {
    split($0, data, ",")
    total_power=total_power+data[2]
    total_energy=total_energy+data[3]
    count=count+1
    power[data[1]]=data[2]*1
    energy[data[1]]=data[3]*1
}
END {
    save("power", power);
    save("energy", energy);
    split($0, max, ",")
    print "const avg_power="total_power/count", avg_energy="total_energy/count", min_time="min_time", max_time="max[1]";"
}
