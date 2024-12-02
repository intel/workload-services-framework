#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

awk '
    /TEST RESULT/ { 
        nopm_total += $7
        count++
    }
    END { 
        primary="*"
        print primary "Total NOPM: " nopm_total
        if (count > 0) {
            print "Average NOPM: " nopm_total / count
        } else {
            print "No TEST RESULT lines found."
        }
    }
' */client.logs 2>/dev/null || true
