#!/bin/bash
ulimit -n 655350

http_proxy= https_proxy= ./wrk \
 -t 50 \
 -c 30700 \
 -d 300s \
 -s scripts/video_query.lua \
 -T 10s \
 -L \
 http://192.168.100.1:8082
