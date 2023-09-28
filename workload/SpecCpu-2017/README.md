>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>

### Introduction

[SPEC&reg;CPU 2017](https://www.spec.org/cpu2017) is a platform benchmark suite.  

#### SpecCPU binaries

SPECCpu 2017 is a commercial benchmark a requires a licensed version. Before you run `make` to build the workload you need to do the following ( to specify the location of where your licensed version of SPECcpu 2017 is ).

Intel pre-compiled binaries are pre-requisite in order to use the workload. Currently this workload support icc2023 intel pre-compiles binary and gcc12 intel pre-compiles binary. SpecCpu config files are internally used by workload only through the binaries. External config's are not supported.

```bash
FOR URL
# Note: SPECcpu has multiple versions v1.1.x series and v1.0.x sercies
export SPEC2017_ISO_VER="1.1.9"

# Note: must be a .iso file of the following format "cpu2017-${SPEC2017_ISO_VER}.iso"
export SPEC_CPU_PKG=<location.of.your.licensed.version/cpu2017-${SPEC2017_ISO_VER}.iso>

# ic2023 intel pre-compiled binary
export SPEC_CPU_ICC_BINARIES_VER=ic2023.0-linux-binaries-20221201
export SPEC_CPU_ICC_BINARIES_REPO=<location.of.your.licensed.version/FOR-INTEL-cpu2017-$SPEC2017_ISO_VER-$SPEC_CPU_ICC_BINARIES_VER.tar.xz>

# gcc12 intel pre-compiled binary
export SPEC_CPU_GCC_BINARIES_VER=gcc12.1.0-lin-binaries-20220509
export SPEC_CPU_GCC_BINARIES_REPO=<location.of.your.licensed.version/FOR-INTEL-cpu2017-$SPEC2017_ISO_VER-$SPEC_CPU_GCC_BINARIES_VER.tar.xz>

# Now run make to build your workload
make 

For Local File
# Create a data directory in build context. i.e workload/SpecCpu-2017/v119_external/data
mkdir -p workload/SpecCpu-2017/v119_external/data
#Rename your intel precompiled binaries as below
ic2023 intel pre-compiled binary  :  icc_binaries.tar.xz 
gcc12 intel pre-compiled binary : gcc_binaries.tar.xz 
SPECcpu ISO File  : spec.iso  # speccpu must be a .iso File
# Copy the intel precompiled binaries from local path to data folder for the cases based on compilers
cp -r icc_binaries.tar.xz gcc_binaries.tar.xz spec.iso workload/SpecCpu-2017/v119_external/data
make
```

### Test Case

The following test cases are defined:

- **`fprate`**: This suite runs 13 floating-point benchmarks.  
- **`fpspeed`**: This suite runs 10 floating-point benchmarks.  
- **`intrate`**: This suite runs 10 integer benchmarks.  
- **`intspeed`**: This suite runs 10 integer benchmarks.

The different between `speed` and `rate` is that the `speed` suite always runs one copy of each benchmark while the `rate` suite runs multiple concurrent copies of each benchmark.

The test case is prefixed with the compiler abbreviation to indicate which compiler is used to compile the workload. An example, `icc_fprate`.

### Docker Image

The workload provides multiple docker images: `speccpu-2017-v119-icc-2023.0-20221201-nda`, `speccpu-2017-v119-gcc-12.1.0-20220509-nda`. The version is the SPEC&reg;CPU 2017 release version.

The docker image supports the following configurations:  

- **`BENCHMARK`**: `fprate`, `fpspeed`, `intrate`, or `intspeed`.  
- **`RUNMODE`**: Specify the publishing mode: `reportable` or `estimated`. The former runs a few more iterations and reports the performance average.  
- **`COPIES`**: Specify the number of concurrent copies that the workload should run.  
- **`TUNE`**: Specify `base`, `peak` or `base,peak`.  
- **`PLATFORM1`**: Specify the platform name.
- **`RELEASE1`**: Specify the release version.
- **`RELEASE2`**: Specify the release version on the Dockerfile.
- **`NUMA`**: Specify 0 (no NUMA) or 1 (NUMA).
- **`ARGS`**: Speccpu rest of the options could be passed in ARGS param. For example --threads.
- **`ITERATION`**: Specify the number of iterations. Default value is 1.

```bash
mkdir -p logs-v119-gcc-fprate
id=$(docker run --rm --detach --privileged -e BENCHMARK=fprate -e RUNMODE=estimated -e COPIES= -e TUNE=base -e PLATFORM1=icelake-server -e COMPILER=gcc12.1.0-lin -e NUMA=0 -e RELEASE1=20220509 -e ARGS= -e ITERATION=1 speccpu-2017-v119-gcc-12.1.0-20220509-nda)
docker exec $id cat /export-logs | tar xf - -C logs-v119-gcc-fprate
docker rm -f $id
```

### KPI

Run the [`kpi.sh`](kpi.sh) script to extract KPIs out of the validation logs.

See the [CPU 2017 Metrics](https://www.spec.org/cpu2017/Docs/overview.html) section for an overview of the [SPEC&reg;CPU 2017](https://www.spec.org/cpu2017) metrics.  

The primary KPI is defined as the overall basemean ratio.  
