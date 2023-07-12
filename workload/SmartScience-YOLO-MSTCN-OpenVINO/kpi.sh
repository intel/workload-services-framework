#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

awk '
    BEGIN{
        sum_of_avgs = 0
        no_avgs = 0
    }
    /^Average FPS is:/{
        split($(NF-1), out_arr, ":")
        sum_of_avgs = sum_of_avgs + out_arr[2]
        no_avgs = no_avgs + 1
        print "Average_"no_avgs" (frames/s): "out_arr[2]
    }
    END{
        printf("*Mean average (frames/s): %.2f",sum_of_avgs/no_avgs)
    }
' */output.logs 2>/dev/null || true
