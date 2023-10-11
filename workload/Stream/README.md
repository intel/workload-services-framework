>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

The STREAM benchmark is a simple synthetic benchmark program that measures sustainable memory bandwidth (in MB/s) and the corresponding computation rate for simple vector kernels.

### Test Case

This workload provides several tests  cases with the following configuration parameters to measure the sustained memory bandwidth.

- **instruction_set**: Specify the instruction set: `sse`, `avx2` or `avx3`, default is `sse`.
- **ntimes**: Specify the number of iterations of each kernel (Default:100, Min=2).

Use the following commands to show the list of test cases:

```bash
cd build
cmake ..
cd workload/Stream
./ctest.sh -N
```

Test cases:

Intel specific platform testcases

```plaintext
Test #1: test_stream_sse
Test #2: test_stream_avx2
Test #3: test_stream_avx3
Test #4: test_stream_sse_gated
```

### Docker Image

The workload provides a docker image: `stream`. 
Run the workload as follows:

```bash
mkdir -p logs
id=$(docker run --rm --detach -e INSTRUCTION_SET=sse -e NTIMES=100 stream)
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
- Platform: `SPR`, `ICX`
- Keywords:
- Permission:

### Performance BKM

- System
  - Auto NUMA Balancing: ON

- BIOS
  - **ICX:**
    - HT: ON
    - Turbo: ON
    - NUMA: 2
    - LLC Prefetch: ON
  - **SPR:**
    - HT: ON
    - Turbo: ON
    - NUMA: 2
    - LLC Prefetch: ON    
