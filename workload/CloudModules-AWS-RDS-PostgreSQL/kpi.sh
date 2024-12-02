#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

awk '
BEGIN {
    i = 0
    vu_list[i]=0
    nopm_list[i]=0
    tpm_list[i]=0
    max_nopm=0
    max_nopm_tpm=0
    max_nopm_vu=0
}
/Active Virtual Users configured/{ 
    split($0, word," "); 
    split(word[2],result,":");
    vu_list[i] = result[2]
    }
/NOPM/{  
    split($0, word," "); 
    nopm_list[i] = word[7]
    }
/TPM/{ 
    split($0, word," "); 
    tpm_list[i] = word[10]
    }
/vudestroy success/{i += 1}
END {
    for (counter = 0; counter < i; counter++) {
        print "New Orders Per Minute VU" vu_list[counter] " (orders/min): " nopm_list[counter]
        print "Transactions Per Minute VU" vu_list[counter] " (trans/min): " tpm_list[counter]
        if (nopm_list[counter] > max_nopm){
            max_nopm=nopm_list[counter]
            max_nopm_tpm=tpm_list[counter]
            max_nopm_vu=vu_list[counter]
        }
    }
    primary="*"
    print "Peak Num of Virtual Users: " max_nopm_vu
    print primary "Peak New Orders Per Minute (orders/min): " max_nopm
    print "Peak Transactions Per Minute (trans/min): " max_nopm_tpm
}
' */output*.log 2>/dev/null || true