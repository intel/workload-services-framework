#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
BEGIN {
}

#print nested array
function save2(v, a) {
  print "var data_"v"={"
  for (k in a) {
    n=asorti(a[k],ta,"@ind_num_asc")
    print "  '"k"': ["
    for (i=1;i<=n;i++) {
      if (ta[i]<mint || mint==0) mint=ta[i]
      if (ta[i]>maxt || maxt==0) maxt=ta[i]
      #if((a[k][ta[i]] != "req") && (a[k][ta[i]] != "act") && (a[k][ta[i]] != "/s") && (a[k][ta[i]] != "%") && (a[k][ta[i]] != "gpu") && (a[k][ta[i]] != "pkg") && (a[k][ta[i]] != "se") && (a[k][ta[i]] != "wa") && (a[k][ta[i]] != ""))
      #{
        print "    ["ta[i]","a[k][ta[i]]"],"
      #}
    }
    print "  ],"
  }
  print "};"
}

#starting point
NR>1 && NF>0 && section=="" {
  section=$3
  next
}

#regular expression convert to UTC timesbased
/^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}/ {
  date_cmd="date -u -d \""$1" "$2"\" +%s"
  date_cmd | getline date_out
  close(date_cmd)
  t=date_out*1000
}

#assinging data into two dimensional array
section=="req"  {
  FreqREQ["FreqREQ"][t]=$3
  FreqACT["FreqACT"][t]=$4
  IRQ["IRQ"][t]=$5
  RC6["RC6"][t]=$6
  if(NF == 21)
  {
    RCS["RCS"][t]=gensub("[%]","","g",$7)
    BCS["BCS"][t]=gensub("[%]","","g",$10)
    VCS0["VCS0"][t]=gensub("[%]","","g",$13)
    VCS1["VCS1"][t]=gensub("[%]","","g",$16)
    VECS["VECS"][t]=gensub("[%]","","g",$19)
  }
  else if (NF == 22)
  {
    PowerPKG["PowerPKG"][t]=$7
    RCS["RCS"][t]=gensub("[%]","","g",$8)
    BCS["BCS"][t]=gensub("[%]","","g",$11)
    VCS0["VCS0"][t]=gensub("[%]","","g",$14)
    VECS["VECS"][t]=gensub("[%]","","g",$17)
    CCS["CCS"][t]=gensub("[%]","","g",$20)
  }
  else
  {
    PowerGPU["PowerGPU"][t]=$7
    PowerPKG["PowerPKG"][t]=$8
    RCS["RCS"][t]=gensub("[%]","","g",$9)
    BCS["BCS"][t]=gensub("[%]","","g",$12)
    VCS0["VCS0"][t]=gensub("[%]","","g",$15)
    VCS1["VCS1"][t]=gensub("[%]","","g",$18)
    VECS["VECS"][t]=gensub("[%]","","g",$21)
    CCS["CCS"][t]=gensub("[%]","","g",$24)
  }

}


END {
  mint=0
  maxt=0
  save2("FreqREQ",FreqREQ)
  save2("FreqACT",FreqACT)
  save2("IRQ",IRQ)
  save2("RC6",RC6)
  save2("PowerGPU",PowerGPU)
  save2("PowerPKG",PowerPKG)
  save2("RCS",RCS)
  save2("BCS",BCS)
  save2("VCS0",VCS0)
  save2("VCS1",VCS1)
  save2("VECS",VECS)
  save2("CCS",CCS)
  print "const min_time="mint", max_time="maxt";"
}
