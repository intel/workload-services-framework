>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>

### Introduction

Flexible IO(FIO) simulates a given IO workload. It accepts different configuration parameters such as Block size, IO size, IO depth and measures IOPS, Bandwidth and latencies for the given IO size.

### Test Cases

There are 6 different test cases `sequential_read`, `sequential_write`, `random_read`, `random_write`, `sequential_read_write`, `random_read_write`.  Each test case accepts configurable parameters like `BLOCK_SIZE`, `IO_DEPTH`, `FILE_SIZE` ,`IO_SIZE`  in [validate.sh](validate.sh) and to individual docker run commands. More details below.

### Docker Image

The workload provides a single docker image: `fio`. Run the workload as follows:

```
mkdir -p logs
id=$(docker run --rm --detach fio)
docker exec $id cat /export-logs | tar xf - -C logs
docker rm -f $id
```
This will run the workload with pre-coded default values for parameters. Below section mentions the exposed parameters and their default values.

### Workload Configuration parameters

The Docker image supports environment variables to configure the benchmark parameters. The following is a list of the supported variables and their default values:

```
TEST_TYPE=sequential_read
BLOCK_SIZE=512
IO_DEPTH=4
FILE_SIZE=6
IO_SIZE=6
NUM_JOBS="1"
CPUS_ALLOWED="1"
CPUS_ALLOWED_POLICY="split"
RUN_TIME="10"
RAMP_TIME="10"
RWMIX_READ="50"
RWMIX_WRITE="50"
BUFFER_COMPRESS_PERCENTAGE="0"
BUFFER_COMPRESS_CHUNK="0"
IO_ENGINE="libaio"
FILE_NAME="fio_test_file"
```
`BLOCK_SIZE` accepts size in KB, `FILE_SIZE` and `IO_SIZE` accepts size in GB, `RUN_TIME` accepts time in seconds.
- Description of some of the above parameters.
- `IO_ENGINE`: IO engine for fio test tool, default is `libaio`.
- `IO_DEPTH`: IO count in each IO queue when test the block IO with fio.
- `BLOCK_SIZE`: Block size for each operation in IO test.
- `RUN_TIME`: Define the test runtime duration in seconds.
- `RAMP_TIME`: The warm up time in seconds for FIO benchmark.
- `NUM_JOBS`: The Job count for fio process run, it's thread count if thread mode enable.
- `RWMIX_READ`: The Ratio for read operation in Mixed R/W operation
- `RWMIX_WRITE`: The Ratio for write operation in Mixed R/W operation

To override these default parameters when running a docker container, pass them to `docker run` with the `-e` flag. For .e.g, to specify a `BLOCK_SIZE` of 4 and `sequential_read_write` test, run the docker image as shown below.

```
mkdir -p logs
id=$(docker run --rm --detach -e TEST_TYPE=sequential_read_write -e BLOCK_SIZE=4 fio)
docker exec $id cat /export-logs | tar xf - -C logs
docker rm -f $id
```

### Log Output

Workload produces validation logs to `output.logs` file in its output directory.

### KPI

Run the [kpi.sh](kpi.sh) script to parse the KPIs from validation logs.

Fio kpi shows `IOPS`, `Bandwidth`, `Submission Latency`(time it took to submit the IO), `Completion Latency`(time from submission to completion of I/O) and `Total Latency`(time from when fio created the I/O unit to completion of the I/O operation).

`Total Bandwidth in MB/sec`(both read and write) is defined as primary KPI.

### Index Info

- Name: `Fio`
- Category: `Synthetic`
- Platform: `SPR`, `ICX`
- Keywords: `IO`
- Permission:
