>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

Intel® Memory Latency Checker (Intel® MLC) is a tool used to measure memory latencies and bandwidth, and how they change with increasing load on the system. It also provides several options for more fine-grained investigation where bandwidth and latencies from a specific set of cores to caches or memory can be measured as well.

The performance test runs a few selected MLC options to measure memory latencies and bandwidth.

### Test Case

These test cases are added:

- Test  #1: test_mlc_local_latency
- Test  #2: test_mlc_local_latency_random
- Test  #3: test_mlc_remote_latency
- Test  #4: test_mlc_remote_latency_random
- Test  #5: test_mlc_llc_bandwidth
- Test  #6: test_mlc_local_read_bandwidth
- Test  #7: test_mlc_peak_remote_bandwidth
- Test  #8: test_mlc_peak_remote_bandwidth_reverse
- Test  #9: test_mlc_peak_bandwidth_rw_combo_1tpc
- Test #10: test_mlc_peak_bandwidth_rw_combo_2tpc
- Test #11: test_mlc_loaded_latency
- Test #12: test_mlc_local_socket_remote_cluster_memory_latency
- Test #13: test_mlc_local_socket_local_cluster_l2hit_latency
- Test #14: test_mlc_remote_socket_remotely_homed_l2hitm_latency
- Test #15: test_mlc_local_socket_remote_cluster_locally_homed_l2hitm_latency
- Test #16: test_mlc_local_socket_local_cluster_l3hit_latency
- Test #17: test_mlc_local_socket_remote_cluster_l3hit_latency
- Test #18: test_mlc_remote_socket_remotely_homed_l3hit_latency
- Test #19: test_mlc_idle_latency
- Test #20: test_mlc_latency_matrix
- Test #21: test_mlc_latency_matrix_random_access
- Test #22: test_mlc_peak_injection_bandwidth
- Test #23: test_static_mlc_cache_to_cache_transfer_latency
- Test #24: test_static_mlc_memory_bandwidth_matrix
- Test #25: test_mlc_local_latency_gated
- Test #26: test_mlc_local_latency_pkm

You can configure the duration of the workload:

- DURATION: Set time in seconds during which each measurement is captured. This option is valid in all modes except c2c_latency. In memory_bandwidth_scan mode, this option has a different meaning and will specify the # of threads that will be used to access the memory.
- ARGS: Set extra arguments


### Docker Image

The MLC workload provides docker images: `mlc`. The `mlc` is the normal workload image. To run the workload, specify the following environment variables:

MLC requires root access and `msr` kernel module loaded to disable hardware prefetchers to get accurate results, otherwise the results are not optimal.
Run `sudo modprobe msr` to load `msr` on the host machine if it's not built-in or loaded already.

```bash
mkdir -p logs
id=$(docker run --rm --detach --privileged -e TEST=local_latency -e WORKLOAD=mlc mlc)

### Test Case Requirement
1) **large pages**

   - *large pages* and *huge pages* terms are used interchangably and mean the same thing
   - Please note, Hugepages has to be enabled in order to run MLC testcases. It requires at least 1000 2M pages per numa. If "n" numa then will require atleat n*1000 2M pages.
   - `HUGEPAGE_MEMORY_NUM` is currently defaulted to "2Mb\*4Gi" which states
      a huge page size of 2Mb that will have a total memory allocation of 4Gi. *Note:* this will require (4*512)=2048 pages ( which is calculated automatically )
   - @example If "n" numa then set HUGEPAGE_MEMORY_NUM=2Mb*<new_value>Gi, where new_value=n*2.
   - *Note:* this value can and should be overridden depending on your machine configuration and test i.e `HUGEPAGE_MEMORY_NUM=2Mb*<new_value>Gi`

```bash
./ctest.sh -R <your_test_case> --set HUGEPAGE_MEMORY_NUM=2Mb*4Gi -V
```

2) **`TEST`**: The tests are required to have more than 2 sockets configured on the system: `remote_latency`,`remote_latency_random`,`peak_remote_bandwidth`,`peak_remote_bandwidth_reverse`,`remote_socket_remotely_homed_l3hit_latency`,`remote_socket_remotely_homed_l2hitm_latency`.

Following memory requirement is required to run SGX test cases on enclave

| Test Case                                               | Min Memory Requirement   |
| ------------------------------------------------------- | -------------------------|
| local_latency                                           | 4G                       |
| local_latency_random                                    | 4G                       |
| remote_latency                                          | 4G                       |
| remote_latency_random                                   | 4G                       |
| llc_bandwidth                                           | 32G                      |
| local_read_bandwidth                                    | 32G                      |
| peak_remote_bandwidth                                   | 32G                      |
| peak_remote_bandwidth_reverse                           | 32G                      |
| loaded_latency                                          | 256G                     |
| peak_bandwidth_rw_combo_1tpc                            | 256G                     |
| peak_bandwidth_rw_combo_2tpc                            | 256G                     |
| local_socket_remote_cluster_memory_latency              | 4G                       |
| local_socket_local_cluster_l2hit_latency                | 4G                       |
| remote_socket_remotely_homed_l2hitm_latency             | 4G                       |
| local_socket_remote_cluster_locally_homed_l2hitm_latency| 4G                       |
| local_socket_local_cluster_l3hit_latency                | 4G                       |
| local_socket_remote_cluster_l3hit_latency               | 4G                       |
| remote_socket_remotely_homed_l3hit_latency              | 4G                       |

### KPI

The [`kpi.sh`](kpi.sh) script parses the validation logs to generate the KPIs.

1. `idle_latency`
    - **Average Idle Latency (ns)**
2. `c2c_latency`
    - **Average C2C Latency (ns)**
3. `loaded_latency`
    - **X_Bandwidth (GB/sec)**: bandwidth of inject delay X

### System Setup

- ICX:
       default setting

- System:
       tuned-adm profile throughput-performance
       sudo cpupower frequency-set -g performance

### Performance BKM

- System:
       tuned-adm profile throughput-performance
       sudo cpupower frequency-set -g performance

- BIOS
  - ICX:
    - HT: ON
    - Turbo: ON
    - SNC: OFF

  - SPR:
    - HT: ON
    - Turbo: ON
    - SNC: OFF

  Note that you can try BIOSManager for checking and setting BIOS knobs.



### See Also

- [Intel Memory Latency Checker](https://software.intel.com/content/www/us/en/develop/articles/intelr-memory-latency-checker.html)
