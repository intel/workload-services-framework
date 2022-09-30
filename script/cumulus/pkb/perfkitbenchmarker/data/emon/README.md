### EMON

This telemetry data collection tool can be used to collect EMON data on the SUT(s) while the workload is running on the same SUT(s). This is one of the traces based tool set in the Perfkitbenchmark (PKB) framework. By default, the telemetry tool will be fired at the same time the benchmark is launched, and terminated when the benchmark run is completed.  The result will be pulled back to the PKB host in the PKB output folder.

"--emon" is the only required command line flag for EMON collection. All other EMON related flags are optional.

⚠️ **Please note that currently EMON runs only on bare metal instances.**

```

Note :- By default the latest emon is available for you to run. If you want to use a custom version,
use --emon_tarball=<emon_version>

For AMD runs, download and use the emon AMD version from emon website with --emon_tarball=<emon_amd_version>

```

#### Use Case 1: Collect EMON data and conduct EDP post-processing on-prem.

```
python3 ./pkb.py --emon --benchmarks=sysbench_cpu --benchmark_config_file=sysbench_cpu_config.yaml
```

##### Here is an example of sysbench_cpu_config.yaml:
```bash
static_vms:
  - &worker
    ip_address: 10.165.57.29
    user_name: pkb
    ssh_private_key: ~/.ssh/id_rsa
    internal_ip: 10.165.57.29
    tag: server
sysbench_cpu:
  vm_groups:
    vm_1:
      static_vms:
        - *worker

flags:
  sysbench_cpu_time: 60           # run for 60 seconds
  sysbench_cpu_events: 0          # don't limit runtime by event count
  sysbench_cpu_thread_counts: 1,0 # zero sets threadcount to number of VCPUs
```
