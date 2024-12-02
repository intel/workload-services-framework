>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

The STREAM benchmark is a simple synthetic benchmark program that measures sustainable memory bandwidth (in MB/s) and the corresponding computation rate for simple vector kernels.

### Test Case

This workload provides several tests  cases with the following configuration parameters to measure the sustained memory bandwidth.

- **instruction_set**: Specify the instruction set: `sse`, `avx2` or `avx3`, default is `sse`.
- **ntimes**: Specify the number of iterations of each kernel (Default:100, Min=2).
- **NO_OF_STREAM_ITERATIONS**: Specify the NO_OF_STREAM_ITERATIONS to run the workload internally in a loop and it will pick the maximum value among them, default is 1
- **THP_ENABLE**: Specify the THP_ENABLE: `always` or `never`, default is `never`,This will enable the transparanet huge pages if set to always else will disable it

Use the following commands to show the list of test cases:

```bash
cd build
cmake ..
cd workload/Stream
./ctest.sh -N
```
```
 **privileged mode ***
- the privileged mode is to run the workload with numactl with root access .if you wish to use it you can set the flag to true ,when executing workload through docker. In kubernetes it is set to true.

```bash
   ./ctest.sh -R <you_test_case> --set ENABLE_PRIVILEGED_MODE=true -V
```

Test cases:

Intel specific platform testcases with **ubuntu22.04** as base image  and **ubuntu 24.04** as base image with two oneapi kit,one is 2022 with icc compiler  and other is 2024 with icx as default compiler

**icc compiler with ubuntu22.04 testcase**
```plaintext
Test #1: test_stream_icc_sse
Test #2: test_stream_icc_avx2
Test #3: test_stream_icc_avx3
Test #4: test_stream_icc_sse_gated
```
**icc compiler with ubuntu24.04 testcase**
```plaintext
Test #1: test_static_stream_icc_ubuntu24_sse
Test #2: test_static_stream_icc_ubuntu24_avx2
Test #3: test_static_stream_icc_ubuntu24_avx3
Test #4: test_static_stream_icc_ubuntu24_pkm
Test #5: test_static_stream_icc_ubuntu24_avx512_icpc
```
**icx compiler with ubuntu22.04  testcase**
```plaintext
Test #1: test_static_stream_icx_ubuntu22_sse
Test #2: test_static_stream_icx_ubuntu22_avx2
Test #3: test_static_stream_icx_ubuntu22_avx3
Test #4: test_static_stream_icx_ubuntu22_pkm
Test #5: test_static_stream_icx_ubuntu22_avx512_icpc
Test #6: test_static_stream_icx_ubuntu22_sse_gated
```
**icx compiler with ubuntu24.04 testcase**
```plaintext
Test #1: test_static_stream_icx_ubuntu24_sse
Test #2: test_static_stream_icx_ubuntu24_avx2
Test #3: test_static_stream_icx_ubuntu24_avx3
Test #4: test_static_stream_icx_ubuntu24_pkm
Test #5: test_static_stream_icx_ubuntu24_avx512_icpc
Test #6: test_static_stream_icx_ubuntu24_sse_gated
```

AMD specific platform(ROME & MILAN) testcases

```plaintext
Test #1: test_stream_amd_sse
Test #2: test_stream_amd_avx2
Test #3: test_stream_amd_sse_gated
Test #4: test_stream_amd_pkm
```

AMD specific platform(GENOA) testcases

```plaintext
Test #1: test_stream_amd_sse
Test #2: test_stream_amd_avx2
Test #3: test_stream_amd_avx3
Test #4: test_stream_amd_sse_gated
Test #5: test_stream_amd_pkm
```

### Docker Image

The workload provides 4 docker images: `stream`, `stream-amd`, `stream-amd-zen4`  and `stream-arm`.

Run the workload as follows:

stream_icc is built on top of ubuntu22.04 and stream_icc_ubuntu24 is built on top of ubuntu24.04
- `stream_icc` `stream_icc_ubuntu24` is for Intel specific platform built with icc compiler

stream_icx_ubuntu22 is built on top of ubuntu22.04 and stream_icx_ubuntu24 is built on top of ubuntu24.04
- `stream_icx_ubuntu22` `stream_icx_ubuntu24` is for Intel specific platform built with icx compiler
- `stream-amd` is for AMD and built with AOCC4 compiler
- `stream-amd-zen4` is for AMD Zen4 platform using AMD's prebuilt binaries
- `stream-arm` is for ARM platforms, compiled with gcc12

```bash
mkdir -p logs
id=$(docker run --rm --detach -e INSTRUCTION_SET=sse -e NTIMES=100 stream)

# or
id=$(docker run --rm --detach -e INSTRUCTION_SET=sse -e NTIMES=100 stream-amd)
docker exec $id cat /export-logs | tar xf - -C logs
docker rm -f $id

# or
id=$(docker run --rm --detach -e INSTRUCTION_SET=sse -e NTIMES=100 stream-arm)
docker exec $id cat /export-logs | tar xf - -C logs
docker rm -f $id

```

### KPI

Run the [kpi.sh](kpi.sh) script to parse the KPIs from the validation logs.

KPI output example:

```log
Copy Best Rate (MB/s): 77748.9
Copy Avg time (s): 0.098781
Copy Min time (s): 0.098399
Copy Max time (s): 0.101331
Scale Best Rate (MB/s): 78363.0
Scale Avg time (s): 0.098296
Scale Min time (s): 0.097628
Scale Max time (s): 0.100837
Add Best Rate (MB/s): 78671.7
Add Avg time (s): 0.146458
Add Min time (s): 0.145867
Add Max time (s): 0.148147
*Triad Best Rate (MB/s): 78888.7
Triad Avg time (s): 0.146033
Triad Min time (s): 0.145466
Triad Max time (s): 0.148240
```



### Index Info

- Name: `Stream`
- Category: `Synthetic`
- Platform: `SPR`, `ICX`, `EMR`,`MILAN`,`GENOA`,`ROME`,`SKL`,`BERGAMO`,`CLX`,`ARMv8`,`ARMv9`,`ARMv10`
- Keywords:
- Permission:


