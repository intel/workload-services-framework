>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

The HPC GEMM benchmark measures the floating point rate of execution of single/double precision real matrix-matrix multiplication.

### Test Case

Currently, there is only build-in single node support / test case.
There are three defined test cases: 
- `sgemm_gated`: This test case is a quick test designed for CI commit validation. It is single precision.
- `dgemm_gated`: This test case is a quick test designed for CI commit validation. It is double precision.
- `sgemm_pkm`: This test case is the common use case of GEMM designed for Post-Si performance analysis.

And this workload provides sub test cases with the following configurable parameters:
- **FLOAT_TYPE**: Specify which float type to use (single precision or double precision): 
> 1. `sgemm`
> 2. `dgemm`
- **MATH_LIB**: Specify which math library to use (For BLIS version, you should use skylake or higher version to run.): 
> 1. `mkl`
> 2. `blis`
- **PROBLEM_SIZE**: The problem size of square matrix. 
- **OMP_NUM_THREADS**: Number of OpenMP threads setting. The number of OMP threads should be at least 1 and no more than the number of physical cores in the single node. The following options can be used:
> 1. a specific number
> 2. `numa`: Using core number in one NUMA node
> 3. `socket`: Using core number in one socket
> 4. `max`: Using core number in one node

### Docker Image

The workload provides 2 Docker images: `gemm` and `gemm-srf`. `gemm` supports AVX512 and `gemm-srf` supports AVX2. Both images support double and single precision float; Run the workload as follows

```

There are two float types "sgemm" or "dgemm" and two math libaries  `mkl` or `blis` supported. Use the -e flag to pass the type of float(double or single precision); pass the type of math library (mkl or blis); pass the matrix size for multiplication; pass the number of threads for parallel run.
mkdir -p logs
id=$(docker run --rm --detach --privileged -e MATHLIB=mkl -e FLOAT_TYPE=sgemm gemm -e MATRIX_SIZE=4000 -e OMP_NUM_THREADS=64 gemm)
docker exec $id cat /export-logs | tar xf - -C logs
docker rm -f $id

```

### KPI

Run the [`kpi.sh`](kpi.sh) script to parse the KPIs from the validation logs. 
- **`Throughput (GFlop/s)`**: Billion floating operations per second.
The following KPIs are generated:
- **`SGEMM Performance`**: single precision matrix multiplication.
- **`DGEMM Performance`**: double precison matrix multiplication.


### System Requirements
Intel® AVX-512 support.

### Index Info

- Name: `GEMM`  
- Category: `HPC`  
- Platform: `GNR`, `SPR`, `ICX`, `SRF`, `EMR`
- Keywords: `SGEMM`, `DGEMM`, `AVX512`  
- Permission:
- Supported Labels:  
