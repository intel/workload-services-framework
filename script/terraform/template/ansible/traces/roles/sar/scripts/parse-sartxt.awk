#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

BEGIN {
  section=$1
  dev_col=10
  iface_col=10
}

function twodigits(t) {
  if (length(t)>1) return t
  return "0"t
}

function timestamp(str) {
  return mktime(time_spec" "gensub(/:/," ","g",str))*1000
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

/^[0-9]*:[0-9]*:[0-9]* *[aA][mM] / {
  $2=""
  $0=$0
}

/^[0-9]*:[0-9]*:[0-9]* *[pP][mM] / {
  h=gensub(/^([0-9]*).*/,"\\1","1",$1)
  if (h!=12) h=h+12
  $1=twodigits(h)":"gensub(/^[0-9]*:(.*)$/,"\\1","1",$1)
  $2=""
  $0=$0
}

NF>0 && section=="" {
  section=$2
  new_section=0
  next
}

NF==0 {
  section=""
}

$1=="Average:" {
  next
}

section=="CPU" && NF==12 {
  t=timestamp($1)
  usr[$2][t]=$3
  nice[$2][t]=$4
  sys[$2][t]=$5
  iowait[$2][t]=$6
  steal[$2][t]=$7
  irq[$2][t]=$8
  soft[$2][t]=$9
  guest[$2][t]=$10
  gnice[$2][t]=$11
  idle[$2][t]=$12
}

section=="CPU" && NF==7 {
  t=timestamp($1)
  totalps[$2][t]=$3
  dropdps[$2][t]=$4
  squeezdps[$2][t]=$5
  rxrpsps[$2][t]=$6
  flwlimps[$2][t]=$7
}

section=="CPU" && NF==3 {
  t=timestamp($1)
  mhz[$2][t]=$3
}

section=="proc/s" && NF==3 {
  t=timestamp($1)
  procps[t]=$2
  cswchps[t]=$3
}

section=="INTR" && $2=="sum" && NF==3 {
  t=timestamp($1)
  intrps[t]=$3
}

section=="pgpgin/s" && NF==10 {
  t=timestamp($1)
  pgpginps[t]=$2
  pgpgoutps[t]=$3
  faultps[t]=$4
  majfltps[t]=$5
  pgfreeps[t]=$6
  pgscankps[t]=$7
  pgscandps[t]=$8
  pgstealps[t]=$9
  vmeff[t]=$10
}

section=="tps" && NF==8 {
  t=timestamp($1)
  tps[t]=$2
  rtps[t]=$3
  wtps[t]=$4
  breadps[t]=$6
  bwrtnps[t]=$7
}

section=="kbmemfree" && NF==12 {
  t=timestamp($1)
  memused[t]=$5
  commit[t]=$9
  kbmemused[t]=$4
  kbcommit[t]=$8
  kbmemfree[t]=$2
  kbbuffers[t]=$6
  kbcached[t]=$7
}

section=="kbhugfree" && NF==6 {
  t=timestamp($1)
  kbhugfree[t]=$2
  kbhugused[t]=$3
  hugused[t]=$4
  kbhugrsvd[t]=$5
  kbhugsurp[t]=$6
}

section=="dentunusd" && NF==5 {
  t=timestamp($1)
  dentunusd[t]=$2
  filenr[t]=$3
  inodenr[t]=$4
  ptynr[t]=$5
}

section=="runq-sz" && NF==7 {
  t=timestamp($1)
  runqsz[t]=$2
  plistsz[t]=$3
  ldavg1[t]=$4
  ldavg5[t]=$5
  ldavg15[t]=$6
  blocked[t]=$7
}

section=="DEV" && NF==10 {
  dev_col=2
  section="tps"
}

section=="tps" && NF==10 && dev_col==2 {
  tmp=$2
  $11=tmp
  $2=""
  $0=$0
}

section=="tps" && NF==10 && ($10 ~ /^nvme[0-9]*n[0-9]*$/ || $10 ~ /^[a-z]d[a-z][0-9]*$/) {
  t=timestamp($1)
  devtps[$10][t]=$2
  devrkbps[$10][t]=$3
  devwkbps[$10][t]=$4
  devdkbps[$10][t]=$5
  devareqsz[$10][t]=$6
  devaqusz[$10][t]=$7
  devawait[$10][t]=$8
  devutil[$10][t]=$9
}

section=="IFACE" && NF==10 {
  iface_col=2
  section="rxpck/s"
}

section=="rxpck/s" && NF==10 && iface_col==2 {
  tmp=$2
  $11=tmp
  $2=""
  $0=$0
}

section=="rxpck/s" && NF==10 && ($10 ~ /^ens/ || $10 ~ /^eno/) {
  t=timestamp($1)
  ifrxpckps[$10][t]=$2
  iftxpckps[$10][t]=$3
  ifrxkbps[$10][t]=$4
  iftxkbps[$10][t]=$5
  ifrxcmpps[$10][t]=$6
  iftxcmpps[$10][t]=$7
  ifrxmcstps[$10][t]=$8
  ififutil[$10][t]=$9
}

section=="rxerr/s" && NF==11 && ($11 ~ /^ens/ || $10 ~ /^eno/) {
  t=timestamp($1)
  ifrxerrps[$11][t]=$2
  ifrxerrps[$11][t]=$3
  ifcolps[$11][t]=$4
  ifrxdropps[$11][t]=$5
  iftxdropps[$11][t]=$6
  ifrxcarrps[$11][t]=$7
  ifrxframps[$11][t]=$8
  ifrxfifops[$11][t]=$9
  iftxfifops[$11][t]=$10
}

section=="totsck" && NF==7 {
  t=timestamp($1)
  totsck[t]=$2
  tcpsck[t]=$3
  udpsck[t]=$4
  rawsck[t]=$5
  ipfrag[t]=$6
  tcptw[t]=$7
}

END {
  mint=0
  maxt=0
  save2("usr", usr);
  save2("nice", nice);
  save2("sys", sys);
  save2("iowait", iowait);
  save2("steal", steal);
  save2("irq", irq);
  save2("soft", soft);
  save2("guest", guest);
  save2("gnice", gnice);
  save2("idle", idle);
  save2("mhz", mhz);
  save1("memused", memused);
  save1("kbmemused", kbmemused);
  save1("kbmemfree", kbmemfree);
  save1("kbcommit", kbcommit);
  save1("kbbuffers", kbbuffers);
  save1("kbcached", kbcached);
  save1("commit", commit);
  save1("tps", tps);
  save1("breadps", breadps);
  save1("bwrtnps", bwrtnps);
  save1("rtps", rtps);
  save1("wtps", wtps);
  save1("runqsz", runqsz);
  save1("ldavg1", ldavg1);
  save1("ldavg5", ldavg5);
  save1("ldavg15", ldavg15);
  save1("plistsz", plistsz);
  save1("blocked", blocked);
  save1("pgpginps", pgpginps);
  save1("pgpgoutps", pgpgoutps);
  save1("faultps", faultps);
  save1("majfltps", majfltps);
  save1("pgfreeps", pgfreeps);
  save1("pgscankps", pgscankps);
  save1("pgscandps", pgscandps);
  save1("pgstealps", pgstealps);
  save1("pswpinps", pswpinps);
  save1("pswpoutps", pswpoutps);
  save1("cswchps", cswchps);
  save1("intrps", intrps);
  save1("procps", procps);
  save1("vmeff", vmeff);
  save1("totsck", totsck);
  save1("tcpsck", tcpsck);
  save1("udpsck", udpsck);
  save1("rawsck", rawsck);
  save2("devtps", devtps);
  save2("devrkbps", devrkbps);
  save2("devwkbps", devwkbps);
  save2("ifrxkbps", ifrxkbps);
  save2("iftxkbps", iftxkbps);
  print "const min_time="mint", max_time="maxt";"
}
