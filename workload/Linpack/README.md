>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

The benchmark used in the LINPACK Benchmark is to solve a dense system of linear equations. HPL is a software package that solves a (random) dense linear system in double precision (64 bits) arithmetic on distributed-memory computers. It can thus be regarded as a portable as well as freely available implementation of the High Performance Computing Linpack Benchmark.

For intel version, we use oneapi 2023.2.0 as Linpack binary.

### Parameters

This Linpack workload provides test cases with the following configuration parameters:
- **N_SIZE**: Speicify the order of the coefficient matrix to be solved. The default value is `auto`. If N_SIZE is `auto, it will be related to memory size. If the case failed and you find 'BAD TERMINATION OF ONE OF YOUR APPLICATION PROCESSES' in output log, it means N_SIZE is too large and you should try lower N_SIZE. For SPR with memory size: 512GB, you can try N_SIZE=120000. For other platforms whose memory size is less than 512GB, you can try lower N_SIZE, like 100000, 80000, 60000 and 40000.
- **P_SIZE**: Speicify the number of process rows. The default value is `auto`. If P_SIZE is `auto`, it should be the number of sockets(AMD ARM) or the number of total numas on the single node(Intel).
- **Q_SIZE**: Speicify the number of process columns. The default value is `auto`. If Q_SIZE is `auto`, it should be the number of numa nodes per socket(AMD ARM) or 1(Intel).
- **NB_SIZE**: Speicify the partitioning block factor. The default value is `auto`. If NB_SIZE is `auto`: On AMD, NB_SIZE=384 when ISA=`avx3` and NB_SIZE=240 when ISA=`avx2`. On Intel, NB_SIZE=384 when ISA=`avx3`, NB_SIZE=192 when ISA=`avx2` and NB_SIZE=240 when ISA=`sse2`. On ARM, NB_SIZE=192.
- **MPI_PROC_NUM**: Specify total MPI process number. The default value is `auto`. If MPI_PROC_NUM is `auto`, it shoud be numa nodes number. This parameter is used in Intel Docker image. (MPI_PROC_NUM shoud be P_SIZE * Q_SIZE)
- **MPI_PER_NODE**: Specify MPI process number per single node. The default value is `auto`. If MPI_PER_NODE is `auto`, it shoud be numa nodes number.This parameter is used in Intel Docker image.
- **NUMA_PER_MPI**: Specify numa nodes number per MPI process. The default value is `auto`. If NUMA_PER_MPI is `auto`, it shoud be 1. This parameter is used in Intel Docker image.
- **ISA**: On AMD, ISA supports `avx2` and `avx3`. On Intel, ISA supports `sse2`, `avx2` and `avx3`. The default value is `avx2`.
- **ARCH**: ARCH supports `intel`, `amd` and `arm`.

### Test Case

The test case name is a combination of `<WORKLOAD_NAME>_<ARCH>_<ISA>_<CASE_TYPE>` (CASE_TYPE is optional).
Use the following commands to show the list of test cases:

```
cd build
cmake ..
cd workload/Linpack
make
./ctest.sh -N
```

```
./ctest.sh -V
(run all test cases)
```
or
```
./ctest.sh -R <test case key word> -V
```
or
```
# Run with test-config which specified parameters
TEST_CONFIG=<WSF REPO>/workload/Linpack/test-config/<target test-config file> ./ctest.sh -R <test case key word> -V
```

```
Test cases:
  Test  #1: test_linpack_intel_avx2_gated
  Test  #2: test_linpack_intel_avx2_pkm
  Test  #3: test_linpack_intel_sse2
  Test  #4: test_linpack_intel_avx2
  Test  #5: test_linpack_intel_avx3
```

### Docker Image

The workload provides 3 docker images: `linpack-intel`, `linpack-amd` and `linpack-arm`. Run the workload as follows:

```
mkdir -p logs
id=$(docker run --rm --detach --shm-size=4gb linpack-intel)
docker exec $id cat /export-logs | tar xf - -C logs
docker rm -f $id
```

### KPI

Run the [`kpi.sh`](kpi.sh) script to parse the KPIs from the validation logs. The following KPIs are parsed:
- **`Gflops`**: Rate of execution for solving the linear system.
- **`Time`**: Time in seconds to solve the linear system.
- **`N`**: The order of the coefficient matrix A.
- **`NB`**: The partitioning blocking factor.
- **`P`**: The number of process rows.
- **`Q`**: The number of process columns.

### System Requirements

None

### Index Info
- Name: `Linpack`
- Category: `HPC`
- Platform: `SPR`, `ICX`, `EMR`, `GENOA`, `BERGAMO`, `ARMv8`, `ARMv9`
- Keywords:
- Permission:

### See Also

- [HPL](http://www.netlib.org/benchmark/hpl/)
- [HPCC](http://icl.cs.utk.edu/hpcc/)
