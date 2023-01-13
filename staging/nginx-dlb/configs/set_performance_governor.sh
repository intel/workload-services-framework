#!/bin/bash

GOVERNOR=performance
for CPUFREQ in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
        do
                [ -f $CPUFREQ ] || continue
                echo -n $GOVERNOR > $CPUFREQ
        done

