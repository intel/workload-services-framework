#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

awk '/^Final Score/ { print "*Score: " $5 }' */benchmark_*.log 2>/dev/null | tail -1 || true
awk '/^Wasm Execution Score/ { print "*Overall Execution Score: " $6 }' */benchmark_*.log 2>/dev/null | tail -1 || true
awk '/^Wasm Efficiency Score/ { print "Overall Efficiency Score: " $6 }' */benchmark_*.log | tail -1 2>/dev/null || true
awk '/ai-wasmscore/ { print "Ai Execution Score: " $3 }' */benchmark_*.log | tail -1 2>/dev/null || true
awk '/ai-wasmscore/ { print "Ai Efficiency Score: " $4 }' */benchmark_*.log | tail -1 2>/dev/null || true
awk '/app-wasmscore/ { print "App Execution Score: " $3 }' */benchmark_*.log | tail -1 2>/dev/null || true
awk '/app-wasmscore/ { print "App Efficiency Score: " $4 }' */benchmark_*.log | tail -1 2>/dev/null || true
awk '/core-wasmscore/ { print "Core Execution Score: " $3 }' */benchmark_*.log | tail -1 2>/dev/null || true
awk '/core-wasmscore/ { print "Core Efficiency Score: " $4 }' */benchmark_*.log | tail -1 2>/dev/null || true
awk '/crypto-wasmscore/ { print "Crypto Execution Score: " $3 }' */benchmark_*.log | tail -1 2>/dev/null || true
awk '/crypto-wasmscore/ { print "Crypto Efficiency Score: " $4 }' */benchmark_*.log | tail -1 2>/dev/null || true
