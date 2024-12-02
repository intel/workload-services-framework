#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
BEGIN {
  split("", time_db)
  day_offset=0
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

/^[0-9]*:[0-9]*:[0-9]* / {
  if (!($1 in time_db)) {
    date_cmd="date -u -d "gensub(/T[0-9:,]*/,"T"$1,1,time_spec)" +%s"
    date_cmd | getline date_out
    close(date_cmd)
    if (last_t ~ /^23:/ && $1 ~ /^00:/) day_offset=8640000
    time_db[$1]=date_out*1000+day_offset
    last_t=$1
  }
  t=time_db[$1]
}

NF<3 || $3=="0/s" {
  section=""
  next
}

NR>1 && NF>0 && section=="" {
  section=$2"_"$3
  new_section=0
  next
}

section=="CPU_%usr" && NF==12 {
  cpu_usr["cpu-"$2][t]=$3
  cpu_nice["cpu-"$2][t]=$4
  cpu_sys["cpu-"$2][t]=$5
  cpu_iowait["cpu-"$2][t]=$6
  cpu_irq["cpu-"$2][t]=$7
  cpu_soft["cpu-"$2][t]=$8
  cpu_steal["cpu-"$2][t]=$9
  cpu_guest["cpu-"$2][t]=$10
  cpu_gnice["cpu-"$2][t]=$11
  cpu_idle["cpu-"$2][t]=$12
}

section=="CPU_intr/s" && NF==3 {
  cpu_intrs["cpu-"$2][t]=$3
}

section=="NODE_%usr" && NF==12 {
  node_usr["node-"$2][t]=$3
  node_nice["node-"$2][t]=$4
  node_sys["node-"$2][t]=$5
  node_iowait["node-"$2][t]=$6
  node_irq["node-"$2][t]=$7
  node_soft["node-"$2][t]=$8
  node_steal["node-"$2][t]=$9
  node_guest["node-"$2][t]=$10
  node_gnice["node-"$2][t]=$11
  node_idle["node-"$2][t]=$12
}

section=="CPU_HI/s" && NF==12 {
  cpu_hi["cpu-"$2][t]=$3
  cpu_timer["cpu-"$2][t]=$4
  cpu_net_tx["cpu-"$2][t]=$5
  cpu_net_rx["cpu-"$2][t]=$6
  cpu_block["cpu-"$2][t]=$7
  cpu_irq_poll["cpu-"$2][t]=$8
  cpu_tasklet["cpu-"$2][t]=$9
  cpu_sched["cpu-"$2][t]=$10
  cpu_hrtimer["cpu-"$2][t]=$11
  cpu_rcu["cpu-"$2][t]=$12
}

END {
  mint=0
  maxt=0
  save2("cpu_usr",cpu_usr)
  save2("cpu_nice",cpu_nice)
  save2("cpu_sys",cpu_sys)
  save2("cpu_iowait",cpu_iowait)
  save2("cpu_irq",cpu_irq)
  save2("cpu_soft",cpu_soft)
  save2("cpu_steal",cpu_steal)
  save2("cpu_guest",cpu_guest)
  save2("cpu_gnice",cpu_gnice)
  save2("cpu_idle",cpu_idle)
  save2("cpu_intrs",cpu_intrs)
  save2("node_usr",node_usr)
  save2("node_nice",node_nice)
  save2("node_sys",node_sys)
  save2("node_iowait",node_iowait)
  save2("node_irq",node_irq)
  save2("node_soft",node_soft)
  save2("node_steal",node_steal)
  save2("node_guest",node_guest)
  save2("node_gnice",node_gnice)
  save2("node_idle",node_idle)
  save2("cpu_hi",cpu_hi)
  save2("cpu_timer",cpu_timer)
  save2("cpu_net_tx",cpu_net_tx)
  save2("cpu_net_rx",cpu_net_rx)
  save2("cpu_block",cpu_block)
  save2("cpu_irq_poll",cpu_irq_poll)
  save2("cpu_tasklet",cpu_tasklet)
  save2("cpu_sched",cpu_sched)
  save2("cpu_hrtimer",cpu_hrtimer)
  save2("cpu_rcu",cpu_rcu)
  print "const min_time="mint", max_time="maxt";"
}
