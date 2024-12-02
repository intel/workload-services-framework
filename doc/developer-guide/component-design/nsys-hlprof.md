
### Introduction

The trace tools nsys and hlprof are workload profiling tools for CUDA and Habana Gaudi accelerators, respectively. This document describes the steps required to integrate nsys and hlprof.     

### The nsys Trace Tool

#### Restrictions

The nsys trace tool does not like other trace tools, which work on the host system, independent of the workload execution. The nsys tool requires that the workload be launched by the `nsys launch` command. This limitation restricts the tool usage scenarios:
- The nsys tool does not support `:0` or `:host` tracing placements.  
- The nsys tool must be used to launch the workload executable. The current implementation limits nsys to containerized workloads only, run under the docker engine. 

#### Create nsys Containers

The nsys tool must be installed within the workload containers. Since the nsight-system installation alone occupies about 1.2GB, you might want to create different container images with and without nsys. You can use the condition `[[ " $TERRAFORM_OPTIONS $CTESTSH_OPTIONS " = *" --nsys "* ]]` to switch between container images. 

```
ARG  OS_VER=24.04
ARG  OS_IMAGE=ubuntu
FROM ${OS_IMAGE}:${OS_VER}
RUN  apt-get update -y && apt-get install -y --no-install-recommends gnupg curl && \
     apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install nsight-systems
ARG  NVIDIA_DEVTOOLS_VER=3bf863cc
ARG  NVIDIA_DEVTOOLS_REPO=http://developer.download.nvidia.com/compute/cuda/repos
RUN  curl --netrc-optional --retry 10 --retry-connrefused -fsSL -o /tmp/${NVIDIA_DEVTOOLS_VER}.pub ${NVIDIA_DEVTOOLS_REPO}/$(. /etc/os-release;echo $ID$VERSION_ID | tr -d .)/$(uname -m)/${NVIDIA_DEVTOOLS_VER}.pub && \
     gpg --yes --dearmor -o /usr/share/keyrings/nvidia-devtools.gpg /tmp/${NVIDIA_DEVTOOLS_VER}.pub && \
     echo "deb [signed-by=/usr/share/keyrings/nvidia-devtools.gpg] ${NVIDIA_DEVTOOLS_REPO}/$(. /etc/os-release;echo $ID$VERSION_ID | tr -d .)/$(uname -m) /" > /etc/apt/sources.list.d/nvidia-devtools.list && \
     apt-get update -y && apt-get install -y --no-install-recommends nsight-systems && \
     apt-get clean -y && rm -rf /var/lib/apt/lists/*

ENV  PATH=/usr/lib/nsight-systems/host-linux-x64:$PATH
...
RUN  mkfifo /export-logs
CMD  (nsys launch /run_test.sh; echo $? > status) 2>&1 | tee output.logs && \
     echo "status output.logs" > /export-logs && \
     sleep infinity
```
where in addition to installing nsys, you must start your workload with **`nsys launch`**. 

The following points must be followed:
- The executable `nsys` must be on the `PATH`.  
- The executable `QdstrmImporter` must be on the `PATH`.  

If successful, your logs directory should contain the trace data:
```
$ ls
nsys-c0r1.logs                                nsys-c0r1.nsys-rep.logs
nsys-c0r1.nsys-rep                            nsys-c0r1.nsys-rep_nvtx_sum.csv
nsys-c0r1.nsys-rep_cuda_api_sum.csv           nsys-c0r1.nsys-rep_openacc_sum.csv
nsys-c0r1.nsys-rep_cuda_api_sync.csv          nsys-c0r1.nsys-rep_opengl_khr_gpu_range_sum.csv
nsys-c0r1.nsys-rep_cuda_gpu_kern_sum.csv      nsys-c0r1.nsys-rep_opengl_khr_range_sum.csv
nsys-c0r1.nsys-rep_cuda_gpu_mem_size_sum.csv  nsys-c0r1.nsys-rep_openmp_sum.csv
nsys-c0r1.nsys-rep_cuda_gpu_mem_time_sum.csv  nsys-c0r1.nsys-rep_osrt_sum.csv
nsys-c0r1.nsys-rep_cuda_memcpy_async.csv      nsys-c0r1.nsys-rep_um_cpu_page_faults_sum.csv
nsys-c0r1.nsys-rep_cuda_memcpy_sync.csv       nsys-c0r1.nsys-rep_um_sum.csv
nsys-c0r1.nsys-rep_cuda_memset_sync.csv       nsys-c0r1.nsys-rep_um_total_sum.csv
nsys-c0r1.nsys-rep_dx11_pix_sum.csv           nsys-c0r1.nsys-rep_vulkan_gpu_marker_sum.csv
nsys-c0r1.nsys-rep_dx12_gpu_marker_sum.csv    nsys-c0r1.nsys-rep_vulkan_marker_sum.csv
nsys-c0r1.nsys-rep_dx12_mem_ops.csv           nsys-c0r1.nsys-rep_wddm_queue_sum.csv
nsys-c0r1.nsys-rep_dx12_pix_sum.csv           nsys-collect.logs
nsys-c0r1.nsys-rep_gpu_gaps.csv               TRACE_START
nsys-c0r1.nsys-rep_gpu_time_util.csv          TRACE_STOP
```

### The hlprof Trace Tool

#### Restrictions

The hlprof trace tool does not like other trace tools, which work on the host system, independent of the workload execution. The hlprof tool requires that the workload be launched with the environment variable `HL_PROFILE=true`. This limitation restricts the tool usage scenarios:
- The hlprof tool does not support `:0` or `:host` tracing placements.  
- The hlprof tool must be used to launch the workload executable. The current implementation limits hlprof to containerized workloads only, run under the docker engine. 
- The hlprof tool cannot precisely stop a trace collection based on a stop phrase, unlike other trace tools. The stopping mechanism is controlled by the `hlprof_options` variable, which by default is defined as `-g 1-2 -b 250`, or capturing traces up to 2 enqueue invocations. 

#### Create hlprof Containers

The `hl-prof-config` tool must be installed within the workload containers. This is usually preinstalled in the Habana Gaudi base-image containers.  

```
ARG HABANA_VER="1.16.0-526"
ARG HABANA_IMG=vault.habana.ai/gaudi-docker/1.16.0/ubuntu22.04/habanalabs/pytorch-installer-2.2.2
FROM ${HABANA_IMG}:${HABANA_VER}

...

RUN  mkfifo /export-logs
CMD  (HABANA_PROFILE=1 /run_test.sh; echo $? > status) 2>&1 | tee output.logs && \
     echo "status output.logs" > /export-logs && \
     sleep infinity
```
where **`HABANA_PROFILE=1`** enables the Habana Gaudi trace system. 

If successful, your logs directory should contain the trace data:
```
$ ls -1 -R workload/LLMs-PyTorch-OOB/logs-mygaudi_llms_pytorch_gaudi_inference_throughput_bfloat16_pkm/worker-0-1-hlprof/
workload/LLMs-PyTorch-OOB/logs-mygaudi_llms_pytorch_gaudi_inference_throughput_bfloat16_pkm/worker-0-1-hlprof/:
hlprof-c0r1
hlprof-c0r1.logs
hlprof-collect.logs
TRACE_START

workload/LLMs-PyTorch-OOB/logs-mygaudi_llms_pytorch_gaudi_inference_throughput_bfloat16_pkm/worker-0-1-hlprof/hlprof-c0r1:
hlprof-c0r1_84.hltv
```
