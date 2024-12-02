
# Intiating workload execution

The `validate.sh` script initiates the workload execution.

## Example

An example of typical `validate.sh` is shown as follows:

```shell
#!/bin/bash -e

# Read test case configuration parameters
... 

# Logs Setting
DIR=$(dirname $(readlink -f "$0"))
. "$DIR/../../script/overwrite.sh"

# Workload Setting
WORKLOAD_PARAMS=(CONFIG1 CONFIG2 CONFIG3)

# Docker Setting
DOCKER_IMAGE="Dockerfile"
DOCKER_OPTIONS=""

# Kubernetes Setting
RECONFIG_OPTIONS="-DCONFIG=$CONFIG"
JOB_FILTER="job-name=benchmark"

. "$DIR/../../script/validate.sh"
```

where `. "$DIR/../../script/overwrite.sh"` is a script to support workload parameter overwrite via [`ctest.sh`][ctest] command line, and `. "$DIR/../../script/validate.sh"` is a script for workload execution. The `validate.sh` saves any validation results to the current directory.

## Reserved variables

The following script variables are reserved. Avoid overwriting their values in `validate.sh`:
- `PLATFORM`
- `WORKLOAD`
- `TESTCASE`
- `DESCRIPTION`
- `REGISTRY`
- `RELEASE`
- `IMAGEARCH`
- `IMAGESUFFIX`
- `TIMEOUT`
- `SCRIPT`

## Optional parameters

Optionally, after `. "$DIR/../../script/overwrite.sh"`, you can invoke the `. "$DIR/../../script/sut-info.sh"`, which queries the Cloud CLI for SUT information. The SUT information is saved as shell variables, example as follows:

```shell
SUTINFO_CSP=gcp
SUTINFO_WORKER_VCPUS=6
SUTINFO_WORKER_MEMORY=4096
SUTINFO_CLIENT_VCPUS=2
SUTINFO_CLIENT_MEMORY=2048
SUTINFO_CONTROLLER_VCPUS=2
SUTINFO_CONTROLLER_MEMORY=2048
```
where memory size is in MiB.  

## Validation Parameters

- **`WORKLOAD_PARAMS`**: Specify the workload configuration parameters as an array variable of workload variables. The configuration parameters will be shown as software configuration metadata in the WSF dashboard. Workload configuration parameters can be also be accessed in Ansible using `wl_tunables.<VARIABLE_NAME>` e.g. `wl_tunables.SCALE`.

  ```shell
  WORKLOAD_PARAMS=(SCALE RETURN_VALUE SLEEP_TIME)
  ```
  - You can add a `-` prefix to the workload parameter to specify that this workload parameter is a secret. The script will ensure that the value is not exposed to any console print out.  

  ```shell
  WORKLOAD_PARAMS=(SCALE -TOKEN)
  ```
  - You can append, after `#`, workload parameter description to the workload parameter variable to print help messages to the user. You can use backslash escapes or the cat workaround for multiple line descriptions.  

  ```shell
  WORKLOAD_PARAMS=(
  "SCALE#This parameter specifies the number of PI digits."
  "RETURN_VALUE#$(cat <<EOF
  You can emulate the workload exit code by explicitly
  specifying the return exit code.
  EOF
  )"
  )
  ```

- **`WORKLOAD_TAGS`**: Specify any workload related tags as a space separated string.
- **`DOCKER_IMAGE`**: If the workload is a single-container workload and support docker run, specify either the docker image name or the `Dockerfile` used to compile the docker image. If the workload does not support docker run, leave the variable value empty.
- **`DOCKER_OPTIONS`**: Specify any docker run options, if the workload supports docker run.
- **`J2_OPTIONS`**: Specify any configuration parameters when expanding the Jinja2 `.j2` templates.
- **`RECONFIG_OPTIONS`**: Specify any configuration parameters when expanding any Kubernetes deployement script as a `.m4` template.
- **`HELM_OPTIONS`**: Specify any helm charts build options. This applies to any Kubernetes workloads with the deployment scripts written as helm charts.
- **`JOB_FILTER`**: Specify which job/deployment is used to monitor the validation progress and after validation completion, retrieve the validation logs. You can specify multiple job/deployment filters, using the `,` as a separator. The first filter is for the benchmark pods, and the rest are service pods. For jobs with multiple containers, you can specify the container name as a qualifier, for example, `job-name=dummy-benchmark:dummy-benchmark`
- **`SCRIPT_ARGS`**: Specify the script arguments for the `kpi.sh` or `setup.sh`.


## Event Tracing Parameters

- **`EVENT_TRACE_PARAMS`**: Specify the event tracing parameters:  
  - `roi`: Specify the ROI-based trace parameters: `roi,<start-phrase>,<end-phrase>[,roi,<start-phase>,<stop-phrase> ...]`. For example, the trace parameters can be `roi,begin region of interest,end region of interest`. The workload must be instrumented to print these phrases in the console output.

> For more sophisticated multi-line context-based ROI, if the string of the start-phrase or stop-phrase starts with and ends with `/`, then the string is a regular expression. Use `~` to represent any new line character. For example, `/~iteration 10.*start workload/` triggers the start of the ROI after the 10th iteration. 

> Additional delay can be appended to the start/stop string as follows: `START_BENCHMARK+5s`, which specifies that the ROI starts 5 seconds after identifying the starting phrase `START_BENCHMARK`.  

  - `time`: Specify a time-based trace parameters: `time,<start-time>,<trace-duration>[,time,<start-time>,<end-time>]`. For example, if the trace parameters are `time,30,10`, the trace collection starts 30 seconds after the workload containers become ready and the collection duration is 10 seconds.

> For short-ROI workloads (less than a few seconds), it is recommended that you specify the `EVENT_TRACE_PARAMS` value as an empty string, meaning that the trace ROI should be the entirety of the workload execution, which ensures that the trace collection catches the short duration of the workload execution.

> Between `roi` and `time`, use `roi` if possible and use `time` as the last resort if the workload does not output anything meaningful to indicate a ROI.

> Note that none of the event tracing mechanisms is timing accurate. You need to define the event trace parameter values with a high timing tolerance, at least in seconds.

## PRESWA Parameters

The Pre-Si analysis pipeline requires to additionally identify the Process of Interest (POI) of a workload. For example, in a client-server workload, the POI is the service process. The POI is specified as a regular expression that can be used to match the workload process. If the workload uses Kubernetes orchestration, the workload must specify a pod filter to uniquely identify the pod.

- **`PRESWA_POI_PARAMS`**: Specify the Pre-Si POI parameters as follows: `process-name-filter [pod-label-filter]`, where the process filter is a regular expression string to filter the process names, and the pod-filer (optional for docker) is the Kubernetes label filter to uniquely identify the pod. Some example: `mongo app=server`

> With docker, the process info can be obtained through `/sys/fs/cgroup/systemd/docker/<container-id>/cgroup.procs`.

> With Kubernetes with containerd runtime, the process info can be obtained through `/sys/fs/cgroup/systemd/system.slice/containerd.service/kubepods-besteffort-pod<pod-uid>.slice:cri-containerd:<container-uid>/cgroup.procs`, where `<pod-uid>` and `container-uid` can be obtained from `kubectl get pod -A -o json`.

[ctest]: ../../user-guide/executing-workload/ctest.md
