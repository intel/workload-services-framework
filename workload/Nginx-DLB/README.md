>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction
Nginx-DLB workload is used to measure the RPS (requests per second) performance of Nginx w/ and w/o [Intel® Dynamic Load Balancer](https://www.intel.com/content/www/us/en/download/686372/intel-dynamic-load-balancer.html). To improve the performance, NGINX introduces AIO thread module and in this workload, Intel® DLB hardware queue is used to replace the software queue in the AIO thread module to improve the performance.

### Test Architecture
Below is test architecture of this workload,

```
+------------------+        +------------------------------------------+
|    Client Node   |        |             Cache Server Node            |
|                  |        |                                          |
| +---------+  +---+        +---+  +------------------+                |
| |         |  |   |        |   |  |                  |   +----------+ |
| | WRK Pod +--+NIC+--+  +--+NIC+--+ Cache Server Pod +---+NVMe Cache| |
| |         |  |   |  |  |  |   |  |     (Nginx)      |   +----------+ |
| +---------+  +---+  |  |  +---+  +------------------+                |
|                  |  |  |  |                                          |
|                  |  |  |  |                                          |
+------------------+  |  |  +------------------------------------------+
                      |  |
                    +-+--+-+
                    |Switch|
                    +--+---+
                       |
                       |    -------------------------------+
                       |    |      Content Server Node     |
                       |    |                              |
                       |    +---+  +--------------------+  |
                       |    |   |  |                    |  |
                       +----+NIC+--+ Content Server Pod |  |
                            |   |  |      (Nginx)       |  |
                            +---+  +--------------------+  |
                            |                              |
                            |                              |
                            +------------------------------+
```

This workload only supports terraform backend since needs to set the environment with ansible. Below is a sample configuration of `terraform-config.static.tf`, please update "user_name", "public_ip", "private_ip" and "ssh_port" according to your test environment,
```
...
variable "worker_profile" {
  default = {
    vm_count = 2
    hosts = {
      "worker-0": {
        "user_name": "user",
        "public_ip": "10.10.10.1",
        "private_ip": "192.168.1.1",
        "ssh_port": 22,
      }
    },
    hosts = {
      "worker-1": {
        "user_name": "user",
        "public_ip": "10.10.10.2",
        "private_ip": "192.168.1.2",
        "ssh_port": 22,
      }
    }
  }
}

variable "client_profile" {
  default = {
    vm_count = 1
    hosts = {
      "client-0": {
        "user_name": "user",
        "public_ip": "10.10.10.3",
        "private_ip": "192.168.1.3",
        "ssh_port": 22,
      }
    }
  }
}

variable "controller_profile" {
  default = {
    vm_count = 1
    hosts = {
      "controller-0": {
        "user_name": "user",
        "public_ip": "10.10.10.2",
        "private_ip": "192.168.1.2",
        "ssh_port": 22,
      }
    }
  }
}
...
```

### System Requirements
- Need 3 servers for this workload, 1 for Nginx Content Server deployment, 1 for Nginx Cache Server and another for WRK Client.
- WRK Client: There is no special system requirements for client.
- Nginx Cache Server: This workload needs DLB driver and kubernetes [DLB Device Plugin](https://github.com/intel/intel-device-plugins-for-kubernetes/blob/main/cmd/dlb_plugin/README.md) on worker-0, so please use worker-0 as the cache server. DLB driver need to be manually installed at first, please refer to "DLB Configuration" part. DLB Device Plugin will be automatically installed. Besides, there is also some storage requirements for cache, please see [setup-nginx-cache](../../doc/user-guide/preparing-infrastructure/setup-nginx-cache.md). If CACHE_TYPE is set to memory, please make sure there is at least 300G memory available on cache server node.
- Nginx Content Server: There is no special system requirements for content server.
- For performance cases, the NIC bandwidth between two servers should be at least 100Gbps.

### DLB Configuration
Please refer below guide:
[DLB Setup](../../doc/user-guide/preparing-infrastructure/setup-dlb.md)
Latest DLB can be found here:
[Intel DLB](https://www.intel.com/content/www/us/en/download/686372/intel-dynamic-load-balancer.html)

Note:
- "HAS-SETUP-DLB=yes" is not necessary for this workload
- for the 5.19+ kernel, the v8+ version of dlb is required

### Docker Image
The workload provides 4 docker images: `nginx-content-server`/`nginx-cache-server-native`/`nginx-cache-server-dlb`/`wrk-client`.

### Test Case
There are 4 test cases available:
- test_<SUT>_nginx-dlb_native
```
Base test case, which is used to test the RPS performance of native nginx.
```
- test_<SUT>_nginx-dlb_dlb
```
This test case is used to test the RPS performance of nginx with dlb.
```
- test_<SUT>_nginx-dlb_pkm
```
This test case is based on native nginx and will run the whole progress with some system data( like emon ) collection for further performance analysis.
```
- test_<SUT>_nginx-dlb_gated
```
Designed for basic function verification based on native nginx.
```

### Customization
All the configurable parameters are listed below, you can also refer to [`validate.sh`](validate.sh). 

- **`CACHE_SERVER_WORKER`**: Specify Nginx Cache Server worker number, default is 1.
- **`CACHE_SERVER_CORE`**: Specify Nginx Cache Server core list, default is core 1.
- **`CACHE_TYPE`**: Specify Nginx Cache type, default is disk, can be disk or memory.

- **`CONTENT_SERVER_WORKER`**: Specify Nginx CONTENT Server worker number, default is 1.
- **`CONTENT_SERVER_WORKER`**: Specify Nginx CONTENT Server core list, default is core 1.

- **`WRK_CORE`**: Specify WRK Client core list, default is core 1.
- **`WRK_THREADS`**: Specify wrk thread number, default is 1.
- **`WRK_DURATION`**: Specify wrk duration time, unit is second, default is 30.
- **`WRK_TEXT_CONNECTIONS`**: Specify wrk concurrency number for TEXT file requests, default is 100.
- **`WRK_AUDIO_CONNECTIONS`**: Specify wrk concurrency number for AUDIO file requests, default is 100.
- **`WRK_VIDEO_CONNECTIONS`**: Specify wrk concurrency number for VIDEO file requests, default is 100.

### KPI
Run the [`kpi.sh`](kpi.sh) script to parse the KPIs from the output logs.
The following KPIs are generated (By default test 3 kinds of file sizes, will generate a combination of below kpis for each file size):
- **`Requests/sec`**: Measured RPS, this is the main KPI for this workload.
- **`Transfer/sec`**: Measured throughput, unit could be MB/s or GB/s.
- **`Latency 90%`**: Measured Latency 90, unit could be ns, ms and s.
- **`Latency 99%`**: Measured Latency 99, unit could be ns, ms and s.

Below is an example,
```
Latency 90% (ms): 1.28
Latency 99% (ms): 1.54
*Requests/sec: 65653.22
Transfer/sec (GB): 8.03
```
