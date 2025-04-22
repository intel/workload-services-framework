#!/usr/bin/gawk
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

BEGIN {
  date_cmd="date -u -d '"time_spec"' +%s"
  date_cmd | getline date_out
  close(date_cmd)
  base_time=date_out*1000
}

{
  dev=gensub(/^.*igt-(.*)-[0-9]*[.]logs$/,"\\1",1,FILENAME)
}
layer[dev]>0 && /^[ \t]*".*":[ \t]*{/ {
  section[dev][layer[dev]]=gensub(/[":]/,"","g",$1)
}
layer[dev]==2 && /^[ \t]*"duration":[ \t]/ && section[dev][1]=="period" {
  t[dev]=t[dev]+int(gensub(/,/,"",1,$2)+0.5)
}
layer[dev]==2 && /^[ \t]*".*":[ \t][0-9.][0-9.]*,[ \t]*$/ && section[dev][1]!="period" {
  key = gensub(/[":]/,"","g",$1)
  igt_data[dev][section[dev][1]][key][t[dev]]=gensub(/,/,"",1,$2)
}
layer[dev]==3 && section[dev][1]=="engines" && /"busy"|"sema"|"wait"/ {
  key = gensub(/[":]/,"","g",$1)
  element = section[dev][2]
  if (element ~ /\/[0-9]*$/) {
    key=key""gensub(/^.*(\/[0-9]*)$/,"\\1",1,element)
    element=gensub(/\/[0-9]*$/,"",1,element)
  }
  igt_data[dev][element][key][t[dev]]=gensub(/,/,"",1,$2)
}
/[{]/ {
  layer[dev]++
}
/[}]/ {
  layer[dev]--
}

END {
  mint=0
  maxt=0
  print "var igt_data={"
  for (dev in igt_data) {
    print "  '"dev"': {"
    for (c in igt_data[dev]) {
      print "    '"c"': {"
      for (d in igt_data[dev][c]) {
        if (length(igt_data[dev][c][d])==0) continue
        n=asorti(igt_data[dev][c][d],tt,"@ind_num_asc")
        print "      '"d"': ["
        for (i=1;i<=n;i++) {
          if (tt[i]<mint || mint==0) mint=tt[i]
          if (tt[i]>maxt || maxt==0) maxt=tt[i]
          print "        ["int(tt[i]+0.5)+base_time","igt_data[dev][c][d][tt[i]]"],"
        }
        print "      ],"
      }
      print "    },"
    }
    print "  },"
  }
  print "};"
  print "const min_time="int(mint+0.5)+base_time", max_time="int(maxt+0.5)+base_time";"
}
