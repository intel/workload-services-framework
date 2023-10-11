>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>

### Introduction

The benchmark used in the LINPACK Benchmark is to solve a dense system of linear equations. HPL is a software package that solves a (random) dense linear system in double precision (64 bits) arithmetic on distributed-memory computers. It can thus be regarded as a portable as well as freely available implementation of the High Performance Computing Linpack Benchmark.

### Parameters

This Linpack workload provides test cases with the following configuration parameters:
- **N_SIZE**: Speicify problem size. If N_size is `auto`, it will calculate the problem size according to memory size. The default value is `auto`. If the case failed and you find 'BAD TERMINATION OF ONE OF YOUR APPLICATION PROCESSES' in outputlog, it means N_SIZE is too large and you should try lower N_SIZE. For SPR with memory size: 512GB, you can try N_SIZE=120000. For other platforms whose memory size is less than 512GB, you can try lower N_SIZE, like 100000, 80000, 60000 and 40000.
- **ASM**: ASM supports `sse`, `avx2`, `avx3` and `default_instruction`. The default value is `default_instruction`.
- **ARCH**: ARCH supports `intel`.

### Test Case

There are four test cases for the number of socket connections(1,2,4,8) and each one has a specific case for different instructions(avx2, avx3, ss3, default_instruction). All measure the floating point rate of execution for solving a linear system of equations. Each test case specifies the number of socket connections, `SOCKET_OPTION` combined with the instruction `ASM`. In order to run each test case, the system must have more NUMA nodes than the number of sockets selected.

### Docker Image

The workload provides 2 docker images: `linpack-intel`. Run the workload as follows:

```
mkdir -p logs
id=$(docker run --rm --detach --shm-size=4gb linpack-intel)
docker exec $id cat /export-logs | tar xf - -C logs
docker rm -f $id
```

#### Customize Build

The image builds OpenBLAS with a target based on the Platform. This behavior
can be overridden by specifying the `OPENBLAS_TARGET` option.

The following is the defined behavior for `OPENBLAS_TARGET`
- Platform:
  - **`SPR`** - `OPENBLAS_TARGET` = `SAPPHIRERAPIDS`
  - **`ICX`** - `OPENBLAS_TARGET` = `SKYLAKEX`

The `SKYLAKEX` OpenBLAS target enables AVX512 support in OpenBLAS. The
`SAPPHIRERAPIDS` OpenBLAS target enables `SPR` specific optimizations in
OpenBLAS.

The `OPENBLAS_TARGET` can be overridden at build time with values from the
following list:
- [`OpenBLAS TargetList`](https://github.com/xianyi/OpenBLAS/blob/develop/TargetList.txt)

### KPI

Run the [`kpi.sh`](kpi.sh) script to parse the KPIs from the validation logs. The following KPIs are parsed:
- **`Gflops`**: Rate of execution for solving the linear system.
- **`Time`**: Time in seconds to solve the linear system.
- **`N`**: The order of the coefficient matrix A.
- **`NB`**: The partitioning blocking factor.
- **`P`**: The number of process rows.
- **`Q`**: The number of process columns.

### System Requirements

Minimum memory requirement: 64GB

### Index Info
- Name: `Linpack`
- Category: `HPC`
- Platform: `SPR`, `ICX`
- Keywords:

### See Also

- [HPL](http://www.netlib.org/benchmark/hpl/)
- [HPCC](http://icl.cs.utk.edu/hpcc/)
