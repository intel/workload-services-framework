
The `validate.sh` script initiates the workload execution, with a typical `validate.sh` shown as follows:  

```
#!/bin/bash -e

# Read test case configuration parameters
... 

# Logs Setting
DIR=$(dirname $(readlink -f "$0"))
. "$DIR/../../script/overwrite.sh"

# Workload Setting
WORKLOAD_PARAMS=""

# Docker Setting
DOCKER_IMAGE="$DIR/Dockerfile"
DOCKER_OPTIONS=""

# Kubernetes Setting
RECONFIG_OPTIONS="-DCONFIG=$CONFIG"
JOB_FILTER="job-name=benchmark"

. "$DIR/../../script/validate.sh"
```

The `validate.sh` saves any validation results to the current directory.  

> The following script variables are reserved. Avoid overwriting their values in `validate.sh`:    
> `PLATFORM`, `WORKLOAD`, `TESTCASE`, `REGISTRY`, `RELEASE`,  
> `IMAGEARCH`, `TIMEOUT`, and `SCRIPT`.   

### Validation Parameters

- **`WORKLOAD_PARAMS`**: Specify the workload configuration parameters as an array variable of `key:value` pairs. The configuration parameters will be shown as software configuration metadata associated with the workload.  
- **`WORKLOAD_TAGS`**: Specify any workload related tags as a space separated string.  
- **`DOCKER_IMAGE`**: If the workload is a single-container workload and support docker run, specify either the docker image name or the `Dockerfile` used to compile the docker image. If the workload does not support docker run, leave the variable value empty.  
- **`DOCKER_DATASET`**: Specify a set of dataset images as an array variable. The dataset image(s) will be volume-mounted to the running docker image.  
- **`DOCKER_OPTIONS`**: Specify any docker run options, if the workload supports docker run.  
- **`RECONFIG_OPTIONS`**: Specify any `m4` configuration parameters when `kubernetes-config.yaml.m4` and `cumulus-config.yaml.m4` are configured. This applies to the `kuberentes` and `cumulus` validation.    
- **`JOB_FILTER`**: Specify which job/deployment is used to monitor the validation progress and after validation completion, retrieve the validation logs.  
- **`SCRIPT_ARGS`**: Specify the script arguments for the `kpi.sh` or `setup.sh`. 

### Event Tracing Parameters

- **`EVENT_TRACE_PARAMS`**: Specify the event tracing parameters:  
  - `roi`: Specify the ROI-based trace parameters: `roi,<start-phrase>,<end-phrase>`. For example, the trace parameters can be `roi,begin region of interest,end region of interest`. The workload must be instrumented to print these phrases in the console output.  
  - `time`: Specify a time-based trace parameters: `time,<start-time>,<trace-duration>`. For example, if the trace parameters are `time,30,10`, the trace collection starts 30 seconds after the workload containers become ready and the collection duration is 10 seconds. 
  - For short-ROI workloads (less than a few seconds), it is recommended that you specify the `EVENT_TRACE_PARAMS` value as an empty string, meaning that the trace ROI should be the entirety of the workload execution, which ensures that the trace collection catches the short duration of the workload execution.  

> Between `roi` and `time`, use `roi` if possible and use `time` as the last resort if the workload does not output anything meaningful to indicate a ROI.  

> Note that none of the event tracing mechanisms is timing accurate. You need to define the event trace parameter values with a high timing tolerance, at least in seconds.  

