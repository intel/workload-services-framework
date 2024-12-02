#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

function save(v, a) {
  print "const data_"v"={"
  for (k in a) {
    n=asorti(a[k],ta,"@ind_num_asc")
    print "  '"k"': ["
    for (i=1;i<=n;i++) {
      if (ta[i]<mint || mint==0) mint=ta[i]
      if (ta[i]>maxt || maxt==0) maxt=ta[i]
      print "    ["ta[i]","a[k][ta[i]]"],"
    }
    print "  ],"
  }
  print "};"
}

/^[0-9]*-[0-9]*-[0-9]*T[0-9]*:[0-9]*:[0-9]*/ {
  date_cmd="date -u -d "$1" +%s"
  date_cmd | getline date_out
  close(date_cmd)
  t=date_out*1000
}

$1=="Numa_Hit"{
  for (i=2;i<NF;i++) {
    node="Node "(i-2)
    numa_hit[node][t]=$i
  }
  numa_hit["Total"][t]=$NF
}

$1=="Numa_Miss"{
  for (i=2;i<NF;i++) {
    node="Node "(i-2)
    numa_miss[node][t]=$i
  }
  numa_miss["Total"][t]=$NF
}

$1=="Numa_Foreign"{
  for (i=2;i<NF;i++) {
    node="Node "(i-2)
    numa_foreign[node][t]=$i
  }
  numa_foreign["Total"][t]=$NF
}

$1=="Interleave_Hit"{
  for (i=2;i<NF;i++) {
    node="Node "(i-2)
    interleave_hit[node][t]=$i
  }
  interleave_hit["Total"][t]=$NF
}

$1=="Local_Node"{
  for (i=2;i<NF;i++) {
    node="Node "(i-2)
    local_node[node][t]=$i
  }
  local_node["Total"][t]=$NF
}

$1=="Other_Node"{
  for (i=2;i<NF;i++) {
    node="Node "(i-2)
    other_node[node][t]=$i
  }
  other_node["Total"][t]=$NF
}

END {
  mint=0
  maxt=0
  save("numa_hit",numa_hit)
  save("numa_miss",numa_miss)
  save("numa_foreign",numa_foreign)
  save("interleave_hit",interleave_hit)
  save("local_node",local_node)
  save("other_node",other_node)
  print "const min_time="mint", max_time="maxt";"
}
