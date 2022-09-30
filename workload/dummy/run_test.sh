#!/bin/sh -e

# This dummy workload calcualtes the PI sequence.
time -p sh -c "echo \"scale=${SCALE:-20}; 4*a(1)\" | bc -l"

