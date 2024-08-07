#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

"sh" "-c" "until nc -z -w5 rtsp-service 8554; do echo waiting for rtsp service; sleep 1; done"
"sh" "-c" "until nc -z -w5 rtsp-service 1935; do echo waiting for rtsp service; sleep 1; done"
"sh" "-c" "until nc -z -w5 rtsp-service 8888; do echo waiting for rtsp service; sleep 1; done"

sleep 10

if [ ${VIDEO_DECODE} == 'CPU' ]
then
    numactl -C 0 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 1 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 2 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 3 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 4 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 5 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 6 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 7 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 8 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 9 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 10 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 11 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 12 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 13 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 14 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 15 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 16 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 17 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 18 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 19 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 20 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 21 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 22 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 23 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 24 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 25 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 26 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 27 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 28 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 29 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 30 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 31 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 32 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 33 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 34 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 35 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 36 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 37 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 38 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 39 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 40 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 41 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 42 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 43 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 44 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 45 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 46 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 47 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 48 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 49 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 50 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 51 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 52 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 53 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 54 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 55 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 56 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 57 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 58 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 59 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 60 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 61 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 62 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
    numactl -C 63 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "CPU"  &
else
    numactl -C 0 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD128"  &
    numactl -C 1 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD128"  &
    numactl -C 2 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD128"  &
    numactl -C 3 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD128"  &
    numactl -C 4 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD128"  &
    numactl -C 5 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD128"  &
    numactl -C 6 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD128"  &
    numactl -C 7 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD128"  &
    numactl -C 8 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD128"  &
    numactl -C 9 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD128"  &
    numactl -C 10 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD128"  &
    numactl -C 11 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD128"  &
    numactl -C 12 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD128"  &
    numactl -C 13 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD128"  &
    numactl -C 14 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD128"  &
    numactl -C 15 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD128"  &
    numactl -C 16 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD129"  &
    numactl -C 17 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD129"  &
    numactl -C 18 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD129"  &
    numactl -C 19 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD129"  &
    numactl -C 20 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD129"  &
    numactl -C 21 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD129"  &
    numactl -C 22 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD129"  &
    numactl -C 23 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD129"  &
    numactl -C 24 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD129"  &
    numactl -C 25 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD129"  &
    numactl -C 26 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD129"  &
    numactl -C 27 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD129"  &
    numactl -C 28 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD129"  &
    numactl -C 29 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD129"  &
    numactl -C 30 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD129"  &
    numactl -C 31 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD129"  &
    numactl -C 32 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD130"  &
    numactl -C 33 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD130"  &
    numactl -C 34 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD130"  &
    numactl -C 35 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD130"  &
    numactl -C 36 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD130"  &
    numactl -C 37 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD130"  &
    numactl -C 38 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD130"  &
    numactl -C 39 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD130"  &
    numactl -C 40 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD130"  &
    numactl -C 41 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD130"  &
    numactl -C 42 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD130"  &
    numactl -C 43 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD130"  &
    numactl -C 44 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD130"  &
    numactl -C 45 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD130"  &
    numactl -C 46 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD130"  &
    numactl -C 47 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD130"  &
    numactl -C 48 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD131"  &
    numactl -C 49 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD131"  &
    numactl -C 50 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD131"  &
    numactl -C 51 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD131"  &
    numactl -C 52 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD131"  &
    numactl -C 53 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD131"  &
    numactl -C 54 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD131"  &
    numactl -C 55 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD131"  &
    numactl -C 56 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD131"  &
    numactl -C 57 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD131"  &
    numactl -C 58 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD131"  &
    numactl -C 59 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD131"  &
    numactl -C 60 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD131"  &
    numactl -C 61 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD131"  &
    numactl -C 62 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD131"  &
    numactl -C 63 python3 smartlab_demo.py -tv 'rtsp://rtsp-service:8554/top' -sv 'rtsp://rtsp-service:8554/side' --mode mstcn -dp 'console' -vd "/dev/dri/renderD131"  &
fi

