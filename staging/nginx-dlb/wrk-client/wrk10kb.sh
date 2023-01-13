#!/bin/bash

ulimit -n 655350
http_proxy= https_proxy= ./wrk \
 -t 50 \
 -c 3100 \
 -d 300s \
 -s scripts/10ktext_query.lua \
 -T 10s \
 -L \
 http://192.168.100.1:8080
