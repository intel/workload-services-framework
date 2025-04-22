>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>

### Introduction

The High Performance Conjugate Gradients (HPCG) Benchmark project is an effort to create a new metric for ranking HPC systems. HPCG is intended as a complement to the High Performance LINPACK (HPL) benchmark, currently used to rank the TOP500 computing systems.


### Test Case

Currently, there is only build-in single node support / test case inside HPCG. 

And this wworkload provides sub test cases with the following configurable parameters:
- **CONFIG**: Specify if this test case has been optimized through options: 
> 1. `avx`
> 2. `avx2`
> 3. `avx512`
> 4. `generic` 
> - Note: generic means no optimization. 
- **X_DIMENSION, Y_DIMENSION, Z_DIMENSION**: the global problem size in X, Y and Z dimension. Different problem sizes will require different memory consumption.   
- **RUN_SECONDS**: the benchmarking time in seconds (should be 1800 at least for official runs). 
- **PROCESS_PER_NODE**: number of MPI processes to be launched per node for benchmarking. The following options can be used:
> 1. a specific number
> 2. `numa`: It will use the number of numa nodes
> 3. `socket`: It will use the number of sockets
- **OMP_NUM_THREADS**: number of OpenMP threads setting inside program. The following options can be used:
> 1. a specific number
> 2. `numa`: Using core number in one NUMA node
> 3. `socket`: Using core number in one socket
- **KMP_AFFINITY**: Setting to adjust OpenMP thread affinity. Here is a mapping between input parameters and detail settings supported now:
> 1. `compact1` maps to: compact,1
> 2. `compact0` maps to: compact
> 3. `scatter0` maps to: scatter
> 4. `threadcompact1` maps to: granularity=fine,compact,1
> 5. `threadcompact0` maps to: granularity=fine,compact
> 6. `threadscatter0` maps to: granularity=fine,scatter
> - Note: By default, it maps to: compact,1

- **MPI_AFFINITY**: Setting to adjust MPI process mapping. Here is a mapping between input parameters and detail settings supported now:
> 1. `socket` maps to: --map-by ppr:`OMP_NUM_THREADS`/`CORES_PER_SOCKET`:socket:PE:`OMP_NUM_THREADS`
> 2. `numa` maps to: --map-by ppr:`OMP_NUM_THREADS`/`CORES_PER_NUMA`:socket:PE:`OMP_NUM_THREADS`
> 3. `l3cache` maps to: --map-by L3cach
> - Note: By default, it will try to map to `numa` if core number per NUMA is greater than `OMP_NUM_THREADS`, otherwise it will map to `socket`. MPI processes will distribute balancely across the device.
- Note: The value of PROCESS_PER_NODE \* OMP_NUM_THREADS is recommended not to exceed number of processors in one node. 
- Note: There is a request: official runs must be at least 1800 seconds (30 minutes) as reported in the output file. So we define another gated test case for fast testing through parameter **TEST_GATED**=y, which will run only one case using setting: problem size 104\*104\*104, 30s duration, 1 process and thread num same as the core number in one socket

### Docker Image

The workload provides two docker images: `hpcg-generic` and `hpcg-mkl`. One contains hpcg program compiled using generic gcc and mpi. The other contains hpcg program compiled using intel compiler, OpenMP, MPI and MKL libraries. 

Below is one example to run the workload of local problem size 104\*104\*104, 60s duration, with 1 MPI process and 1 thread per process:

```
mkdir -p logs
id=$(docker run --rm --detach --shm-size=8gb -e CONFIG=avx512 -e PROCESS_PER_NODE=1 -e OMP_NUM_THREADS=1 -e X_DIMENSION=104 -e Y_DIMENSION=104 -e Z_DIMENSION=104 -e RUN_SECONDS=60 -e KMP_AFFINITY=threadcompact1 -e MPI_AFFINITY=numa hpcg-mkl)
docker exec $id cat /export-logs | tar xf - -C logs
docker rm -f $id
```


### KPI

Run the [`kpi.sh`](kpi.sh) script to parse the KPIs from the validation logs.The following is the parsed KPI:
- **`Throughput (GFlop/s)`**: Billion floating operations per second.


### System Setup
- **ICX:** 
  - DDR4 DRAM with 3200MT/s
  - Core Number >= 32 
- **SPR:** 
  - DDR5 DRAM with 4800MT/s
  - Core Number >= 56 

### Performance BKM
- System
    - Transparent Huge Page: Never
    - Auto NUMA Balancing: OFF
    - vm.zone_reclaim_mode: 1

 
```
#
# tuned configuration
#

[main]
summary=Optimize for HPCG
description=''

[cpu]
governor=performance
energy_perf_bias=performance
min_perf_pct=50

[vm]
transparent_hugepages=never

[sysctl]
vm.zone_reclaim_mode=1
kernel.numa_balancing=0

```

- BIOS 
  - **ICX:** 
      - HT: ON
      - Turbo: OFF
      - SNC: 2
      - DCU DATA Prefetcher: OFF
      - LLC Prefetch: ON
  - **SPR:** 
      - HT: on
      - Turbo: ON
      - SNC: 4
      - DCU Stream Prefetcher: OFF
      - LLC Prefetch: ON
      - Page Policy: Adaptive


### Index Info
- Name: `HPCG`  
- Category: `HPC`  
- Platform: `GNR`, `SPR`, `ICX`, `EMR`
- Keywords: `AVX512`  
- Permission:   
