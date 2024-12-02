#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

awk '
BEGIN {
    Dhrystone_2_using_register_variables="";
    Double_Precision_Whetstone="";
    Execl_Throughput="";
    File_Copy_1024_bufsize_2000_maxblocks="";
    File_Copy_256_bufsize_500_maxblocks="";
    File_Copy_4096_bufsize_8000_maxblocks="";
    Pipe_Throughput="";
    Pipe_based_Context_Switching="";
    Process_Creation="";
    Shell_Scripts_1_concurrent="";
    Shell_Scripts_8_concurrent="";
    System_Call_Overhead="";
    System_Benchmarks_Index_Score="";
}

#parse results
/Dhrystone 2 using register variables/{
    Dhrystone_2_using_register_variables=$NF;
}
/Double-Precision Whetstone/{
    Double_Precision_Whetstone=$NF;
}
/Execl Throughput/{
    Execl_Throughput=$NF;
}
/File Copy 1024 bufsize 2000 maxblocks/{
    File_Copy_1024_bufsize_2000_maxblocks=$NF;
}
/File Copy 256 bufsize 500 maxblocks/{
    File_Copy_256_bufsize_500_maxblocks=$NF;
}
/File Copy 4096 bufsize 8000 maxblocks/{
    File_Copy_4096_bufsize_8000_maxblocks=$NF;
}
/Pipe Throughput/{
    Pipe_Throughput=$NF;
}
/Pipe-based Context Switching/{
    Pipe_based_Context_Switching=$NF;
}
/Process Creation/{
    Process_Creation=$NF;
}
/1 concurrent/{
     Shell_Scripts_1_concurrent=$NF;
}
/8 concurrent/{
    Shell_Scripts_8_concurrent=$NF;
}
/System Call Overhead/{
    System_Call_Overhead=$NF;
}
/System Benchmarks Index Score/{
    System_Benchmarks_Index_Score=$NF;
}

END {
      primary="*"
      if (Dhrystone_2_using_register_variables != "") print "Dhrystone_2_using_register_variables:  " Dhrystone_2_using_register_variables
      if (Double_Precision_Whetstone != "") print "Double_Precision_Whetstone:            " Double_Precision_Whetstone
      if (Execl_Throughput != "") print "Execl_Throughput:                      " Execl_Throughput
      if (File_Copy_1024_bufsize_2000_maxblocks != "") print "File_Copy_1024_bufsize_2000_maxblocks: " File_Copy_1024_bufsize_2000_maxblocks
      if (File_Copy_256_bufsize_500_maxblocks != "") print "File_Copy_256_bufsize_500_maxblocks:   " File_Copy_256_bufsize_500_maxblocks
      if (File_Copy_4096_bufsize_8000_maxblocks != "") print "File_Copy_4096_bufsize_8000_maxblocks: " File_Copy_4096_bufsize_8000_maxblocks
      if (Pipe_Throughput != "") print "Pipe_Throughput:                       " Pipe_Throughput
      if (Pipe_based_Context_Switching != "") print "Pipe_based_Context_Switching:          " Pipe_based_Context_Switching
      if (Process_Creation != "") print "Process_Creation:                      " Process_Creation
      if (Shell_Scripts_1_concurrent != "") print "Shell_Scripts_1_concurrent:            " Shell_Scripts_1_concurrent
      if (Shell_Scripts_8_concurrent != "") print "Shell_Scripts_8_concurrent:            " Shell_Scripts_8_concurrent
      if (System_Call_Overhead != "") print "System_Call_Overhead:                  " System_Call_Overhead
      if (System_Benchmarks_Index_Score != "") print primary "System_Benchmarks_Index_Score:        " System_Benchmarks_Index_Score
}
' */output.logs 2>/dev/null || true
