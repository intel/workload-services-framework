#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
BEGIN {
}

function twodigits(t) {
  if (length(t)>1) return t
  return "0"t
}

function tokb(str) {
  value=0
  if (match(str,"k")>0) value=gensub("[k]","","g",str)
  if (match(str,"M")>0) value=gensub("[M]","","g",str)*1000
  return value
}

function save1(v, a) {
  n=asorti(a,ta,"@ind_num_asc")
  print "const data_"v"=["
  for (i=1;i<=n;i++) {
    if (ta[i]<mint || mint==0) mint=ta[i]
    if (ta[i]>maxt || maxt==0) maxt=ta[i]
    print "  ["ta[i]","a[ta[i]]"],"
  }
  print "];"
}

function save2(v, a) {
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
  section=""
  next
}

NF<3 {
  section=""
  next
}

NR>1 && NF>0 && section=="" {
  section=$1
  new_section=0
  next
}

section=="avg-cpu:" && NF==6 {
  usr[t]=gensub("[%]","","g",$1)
  nice[t]=gensub("[%]","","g",$2)
  sys[t]=gensub("[%]","","g",$3)
  iowait[t]=gensub("[%]","","g",$4)
  steal[t]=gensub("[%]","","g",$5)
  idle[t]=gensub("[%]","","g",$6)
}

section=="r/s" && NF==7 {
  r[$7][t]=$1
  rKB[$7][t]=tokb($2)
  rrqm[$7][t]=$3
  rrqm_ratio[$7][t]=gensub("[%]","","g",$4)
  rawait[$7][t]=$5
  rareq_sz[$7][t]=tokb($6)
}

section=="w/s" && NF==7 {
  w[$7][t]=$1
  wKB[$7][t]=tokb($2)
  wrqm[$7][t]=$3
  wrqm_ratio[$7][t]=gensub("[%]","","g",$4)
  wawait[$7][t]=$5
  wareq_sz[$7][t]=tokb($6)
}

section=="d/s" && NF==7 {
  d[$7][t]=$1
  dKB[$7][t]=tokb($2)
  drqm[$7][t]=$3
  drqm_ratio[$7][t]=gensub("[%]","","g",$4)
  dawait[$7][t]=$5
  dareq_sz[$7][t]=tokb($6)
}

section=="f/s" && NF==5 {
  f[$5][t]=$1
  fawait[$5][t]=$2
  faqu_sz[$5][t]=$3
  futil[$5][t]=gensub("[%]","","g",$4)
}


END {
  mint=0
  maxt=0
  save1("usr", usr);
  save1("nice", nice);
  save1("sys", sys);
  save1("iowait", iowait);
  save1("steal", steal);
  save1("idle", idle);
  save2("r",r)
  save2("rKB",rKB)
  save2("rrqm",rrqm)
  save2("rrqm_ratio",rrqm_ratio)
  save2("rawait",rawait)
  save2("rareq_sz",rareq_sz)
  save2("w",w)
  save2("wKB",wKB)
  save2("wrqm",wrqm)
  save2("wrqm_ratio",wrqm_ratio)
  save2("wawait",wawait)
  save2("wareq_sz",wareq_sz)
  save2("d",d)
  save2("dKB",dKB)
  save2("drqm",drqm)
  save2("drqm_ratio",drqm_ratio)
  save2("dawait",dawait)
  save2("dareq_sz",dareq_sz)
  save2("f",f)
  save2("fawait",fawait)
  save2("faqu_sz",faqu_sz)
  save2("futil",futil)
  print "const min_time="mint", max_time="maxt";"
}
