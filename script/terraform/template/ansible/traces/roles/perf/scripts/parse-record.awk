#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
BEGIN {
  date_cmd="date -u -d "time_spec" +%s"
  date_cmd | getline date_out
  close(date_cmd)
  base_t=date_out*1000
  t=base_t
  s0col="not-set"
}

function save2(v, a) {
  print "const data_"v"_series=["
  for (k in a) {
    n=asorti(a[k],ta,"@ind_num_asc")
    print "{"
    print "  'name': '"k"',"
    print "  'data': ["
    for (i=1;i<=n;i++) {
      if (ta[i]<mint || mint==0) mint=ta[i]
      if (ta[i]>maxt || maxt==0) maxt=ta[i]
      print "    ["ta[i]","a[k][ta[i]]"],"
    }
    print "  ],"
    print "},"
  }
  print "];"
}

/,S0,/ {
  split($0,columns,",")
  if (s0col=="not-set" || s0col==columns[6]) {
    t_prev=t
    t=base_t+columns[1]*1000
    s0col=columns[6]
  }
}

/Joules,power.energy-pkg./ {
  split($0,columns,",")
  socket=columns[2]
  t_delta=(t-t_prev)/1000
  power[socket][int(t)]=t_delta>0?columns[4]/t_delta:0
  power["all"][int(t)]+=power[socket][int(t)]
}

/,,cycles,/ || /,,cpu-cycles,/ {
  split($0,columns,",")
  socket=columns[2]
  cycles[socket][int(t)]=columns[7]
  cycles["all"][int(t)]+=cycles[socket][int(t)]
}

/,,instructions,/ || /,,cpu\/instructions\/,/ {
  split($0,columns,",")
  socket=columns[2]
  instructions[socket][int(t)]=columns[7]
  instructions["all"][int(t)]+=instructions[socket][int(t)]
}

END {
  mint=0
  maxt=0
  save2("power", power)
  save2("cycles", cycles)
  save2("instructions", instructions)
  print "const min_time="mint", max_time="maxt";"
}

