#!/bin/bash

ulimit -n 655350

./wrk1mb.sh  2>&1 | tee logs/1MB.log &
./wrk100kb.sh 2>&1 | tee logs/100KB.log &
./wrk10kb.sh 2>&1 | tee logs/10KB.log &
