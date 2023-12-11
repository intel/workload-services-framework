
### Introduction

The benchmark used in the LINPACK Benchmark is to solve a dense system of linear equations. HPL is a software package that solves a (random) dense linear system in double precision (64 bits) arithmetic on distributed-memory computers. It can thus be regarded as a portable as well as freely available implementation of the High Performance Computing Linpack Benchmark.

For intel version, we use oneapi 2023.2.0 as Linpack binary.

### Parameters

This Linpack workload provides test cases with the following configuration parameters:
- **N_SIZE**: Speicify the order of the coefficient matrix to be solved. The default value is `auto`. If N_SIZE is `auto`, it will be related to memory size. If the case failed and you find 'BAD TERMINATION OF ONE OF YOUR APPLICATION PROCESSES' in output log, it means N_SIZE is too large and you should try lower N_SIZE. For SPR with memory size: 512GB, you can try N_SIZE=120000. For other platforms whose memory size is less than 512GB, you can try lower N_SIZE, like 100000, 80000, 60000, 40000, 20000 and 10000.
- On cloud, the N_SIZE depends on the number of vCPUs. If vCPU=2, N_SIZE=10000. If vCPU=4, N_SIZE=20000. If vCPU=8, N_SIZE=40000. If vCPU=16, N_SIZE=60000. If vCPU is larger than or equal to 32, N_SIZE=80000.
- **P_SIZE**: Speicify the number of process rows. The default value is `auto`. If P_SIZE is `auto`, it should be the number of sockets.
- **Q_SIZE**: Speicify the number of process columns. The default value is `auto`. If Q_SIZE is `auto`, it should be the number of numa nodes per socket.
- **NB_SIZE**: Speicify the partitioning block factor. The default value is `auto`. If NB_SIZE is `auto`, on AMD, it will be 384 when ASM is avx3 and 240 when ASM is avx2, on Intel, it will be 384 when ASM is avx3, 256 when ASM is sse and 192 when ASM is avx2. 
- **ASM**: ASM supports `sse`, `avx2`, `avx3` and `default_instruction`. The default value is `default_instruction`.
- **ARCH**: ARCH supports `intel` and `amd`.

### Test Case

The test case name is a combination of `<WORKLOAD_NAME>-<ARCH>-<ASM>-<CASE_TYPE>` (CASE_TYPE is optional).
Use the following commands to show the list of test cases:

```cd build
cmake ..
cd workload/Linpack
./ctest.sh -N
```
or 
```
./ctest.sh -V 
(run all test cases)
```
or
```
./ctest.sh -R <test case key word> -V 
```

```
Test cases:
  Test  #1: test_linpack_intel_gated
  Test  #2: test_linpack_intel_pkm avx2
  Test  #3: test_linpack_intel_avx2
  Test  #4: test_linpack_intel_avx3
  Test  #5: test_linpack_intel_sse
  Test  #6: test_linpack_intel_default_instruction
```

### Docker Image

The workload provides 2 docker images: `linpack-intel` and `linpack-amd`. Run the workload as follows:

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
- Platform: `GNR`, `SPR`, `ICX`, `EMR`, `GENOA`
- Keywords:   
- Permission:   
- Stage1 Contact: `Chenfei Zhang`
- Stage2 Contact: `James Zhou`, `Alex H Zhang`
- Linpack Benchmark: `Goodman, Martin D`.
- Software Stack: `Goto, Kazushige`; `Huh, Joonmoo`.
- Validation: `Wu Yanping`.

### Validation Notes

- Validated with release [`v23.26.6`](https://github.com/intel-innersource/applications.benchmarking.benchmark.platform-hero-features/releases/tag/v23.26.6) on `SPR`, `SPR_AWS`, `GENOA_AWS`, `SPR_ALICLOUD`, passed on platform `SPR`,`SPR_AWS`,`SPR_ALICLOUD`,`GENOA_AWS` .

- Known Issues:  
  - [`External Linpack - 3 linpack_intel cases failed on SPR`](https://github.com/intel-innersource/applications.benchmarking.benchmark.platform-hero-features/issues/10761)  

<!-- START PRE-SILICON VALIDATION NOTES -->
- Pre-silicon partially validated with release [`v23.09`](https://github.com/intel-innersource/applications.benchmarking.benchmark.platform-hero-features/releases/tag/v23.09) on plaforms: EMR, GNR, ICX, SPR

- Pre-silicon reported issues with release [`v23.09`](https://github.com/intel-innersource/applications.benchmarking.benchmark.platform-hero-features/releases/tag/v23.09):
  - [XMGPLAT-987](https://jira.devtools.intel.com/browse/XMGPLAT-987)

### See Also

- [HPL](http://www.netlib.org/benchmark/hpl/)
- [HPCC](http://icl.cs.utk.edu/hpcc/)
- [Cumulus HPL](https://github.com/intel-innersource/frameworks.benchmarking.cumulus.perfkitbenchmarker/blob/main/perfkitbenchmarker/linux_benchmarks/intel_hpc_hpl_benchmark.py)
