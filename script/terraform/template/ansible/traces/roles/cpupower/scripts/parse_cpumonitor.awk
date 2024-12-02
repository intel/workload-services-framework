#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
BEGIN {
  FS="|"
}

function save(v, a) {
  print "const data_"v"={"
  for (k in a) {
    n=asorti(a[k],ta,"@ind_num_asc")
    print "  '"k"': ["
    for (i=1;i<=n;i++) {
      print "    ["ta[i]","a[k][ta[i]]"],"
    }
    print "  ],"
  }
  print "};"
}

{
  $0=gensub(/ */,"","g",$0)
}

/^intel*/ || $1=="0" {
  next
}
  
/^[0-9]*-[0-9]*-[0-9]*T[0-9]*:[0-9]*:[0-9]*/ {
  date_cmd="date -u -d "$1" +%s"
  date_cmd | getline date_out
  close(date_cmd)
  t=date_out*1000
  if (t<mint || mint==0) mint=t
  if (t>maxt || maxt==0) maxt=t
  next
}

(NF==16 || NF==15) && $1!="PKG" {
    c3[$3][t]=$4
    c6[$3][t]=$5
    pc3[$3][t]=$6
    pc6[$3][t]=$7
    c0[$3][t]=$9
    cx[$3][t]=$10
    freq[$3][t]=$11
    poll[$3][t]=$13
    c1[$3][t]=$14
    c1e[$3][t]=$15
}

(NF==19) && $1!="PKG" {
    c3[$3][t]=$4
    c6[$3][t]=$5
    pc3[$3][t]=$6
    pc6[$3][t]=$7
    c0[$3][t]=$9
    cx[$3][t]=$10
    freq[$3][t]=$11
    poll[$3][t]=$16
    c1[$3][t]=$17
    c1e[$3][t]=$18
}

(NF==12 || NF==14) && $1!="CPU" {
    c0[$1][t]=$7
    cx[$1][t]=$8
    freq[$1][t]=$9
    poll[$1][t]=$11
    c1[$1][t]=$12
}

(NF==14) && $1!="CPU" {
    c1e[$1][t]=$13
}

END {
  save("c3", c3);
  save("c6", c6);
  save("pc3", pc3);
  save("pc6", pc6);
  save("c0", c0);
  save("cx", cx);
  save("freq", freq);
  save("poll", poll);
  save("c1", c1);
  save("c1e", c1e);
  print "const min_time="mint", max_time="maxt";"
}

