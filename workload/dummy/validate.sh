#!/bin/bash -e

# The validate.sh scirpt runs the workload. See doc/validate.sh.md for details. 

# define the workload arguments
SCALE=${1:-1}

# Logs Setting
  # DIR is the workload script directory. When validate.sh is executed, the current 
  # directory is usually the logs directory. 
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
  # This script allows the user to overwrite any environment variables, given a 
  # TEST_CONFIG yaml configuration. See doc/ctest.md for details. 
. "$DIR/../../script/overwrite.sh"

# Workload Setting
  # The workload parameters will be saved to the cumulus database. Specify an array of
  # configuration parameters in the format of "key:value" pairs. 
WORKLOAD_PARAMS=("scale:$SCALE")
  # Workload tags can be used to track Intel values across multple versions of workload
  # implementations. See doc/intel-values.md for details.  
#WORKLOAD_TAGS="BC-BASELINE"

# Docker Setting
  # if the workload does not support docker run, leave DOCKER_IMAGE empty. Otherwise
  # specify the image name and the docker run options.
DOCKER_IMAGE="$DIR/Dockerfile"
DOCKER_OPTIONS="-e SCALE=$SCALE"

# Kubernetes Setting
  # You can alternatively specify HELM_CONFIG and HELM_OPTIONS
RECONFIG_OPTIONS="-DSCALE=$SCALE"
JOB_FILTER="job-name=dummy-benchmark"

# kpi args
SCRIPT_ARGS="${SCALE}"

# Let the common validate.sh takes over to manage the workload execution.
. "$DIR/../../script/validate.sh"

