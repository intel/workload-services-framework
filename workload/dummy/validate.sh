#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# The validate.sh scirpt runs the workload. See doc/validate.sh.md for details. 

# define the workload arguments
SCALE=${SCALE:-${1:-1}}
RETURN_VALUE=${RETURN_VALUE:-${2:-0}}
SLEEP_TIME=${SLEEP_TIME:-${3:-0}}
ROI=${ROI:-${4:-1}}

# Logs Setting
  # DIR is the workload script directory. When validate.sh is executed, the 
  # current directory is usually the logs directory. 
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
  # This script allows the user to overwrite any environment variables, 
  # given a TEST_CONFIG yaml configuration. 
  # See doc/user-guide/executing-workload/ctest.md for details. 
. "$DIR/../../script/overwrite.sh"

# Workload Setting
  # The workload parameters will be saved to the cumulus dashboard. Specify 
  # an array of configuration parameters as environmental scalars. 
WORKLOAD_PARAMS=(
"SCALE#The number of PI digits to be generated"
"RETURN_VALUE#Return exit code"
"SLEEP_TIME#Sleep time before exit"
"ROI#Repeat times"
)

  # Workload tags can be used to track Intel values across multple versions 
  # of workload implementations. See doc/intel-values.md for details.  
#WORKLOAD_TAGS="BC-BASELINE"

# Docker Setting
  # If the workload supports docker execution, specify the options in 
  # docker-config.yaml. 

# Kubernetes Setting
  # You can optionally specify HELM_CONFIG, HELM_OPTIONS, or 
  # RECONFIG_OPTIONS. See doc/developer-guide/component-design/validate.md.

  # Specify which job/pod to monitor for execution completion. 
  # See doc/developer-guide/component-design/validate.md. 
JOB_FILTER="job-name=dummy-benchmark"

# kpi args
  # SCRIPT_ARGS will be passed to the kpi.sh command line
SCRIPT_ARGS="${SCALE}"

# Trace parameters
  # you can specify trace requirements in EVENT_TRACE_PARAMS. The roi trace
  # mechanism detects the ROI start and stop points by matching the console
  # outputs. Multiple ROIs can be specified.
EVENT_TRACE_PARAMS=$(for i in $(seq $ROI); do echo -n ",roi,START-ROI-$i,STOP-ROI-$i";done | cut -f2- -d,)

# Let the common validate.sh takes over to manage the workload execution.
. "$DIR/../../script/validate.sh"

