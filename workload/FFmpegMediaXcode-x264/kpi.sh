#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

awk '
BEGIN{
    pass=0
    fail=0
}
/^Pass/ {
    pass=pass+1
}

/cpu_utilization/ {
    print "cpu_utilization(%): "$3;
}

/density_instances/ {
    print $0;
}

/cpu_threshold/ {
    print $0;
}

/avg_cpu_frequency/ {
    print "avg_cpu_frequency(MHz): "$3;
}

/lowest_fps :/ {
    print "lowest_fps: "$3;
}

/total_fps/ {
    print "*""total_fps(frames per seconds): "$3;
}

/fps_threshold/ {
    print $0;
}

/transcodes/ {
    print "transcodes(instances): "$3;
}

/num_tests_run/ {
    print "num_tests_run: "$3;
}

/num_tests_passed/ {
    print "num_tests_passed : "$3;
}

/success_percentage/ {
    print "success_percentage(%): "$3;
}

/run_time/ {
    print $0;
}

/fail/ {
    fail=fail+1
}
' */benchmark_*.log 2>/dev/null || true

