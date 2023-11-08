>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

At its core, a CDN is a network of servers linked together with the goal of delivering content as quickly, cheaply, reliably, and securely as possible. In order to improve speed and connectivity, a CDN will place servers at the exchange points between different networks. Here the content server is origin nginx 's upstream server, and the origin nginx is the upstream server of cache nginx, big cache is used to setup a cache nginx server, and we use wrk as a pressure test tool to test the servers' performance.

The workload is optimized with qat sw features which are only supported in the platforms starting with [3rd Generation Intel&reg; Xeon&reg; Scalable Processors family](https://www.intel.com/content/www/us/en/products/docs/processors/xeon/3rd-gen-xeon-scalable-processors-brief.html).

### Test Case

```log
- workload: cdn_nginx_original
Test #1: test_cdn_nginx_original_vod_http
Test #2: test_cdn_nginx_original_vod_https_sync
Test #3: test_cdn_nginx_original_live_http
Test #4: test_cdn_nginx_original_live_https_sync
Test #5: test_cdn_nginx_original_live_http_gated
Test #6: test_cdn_nginx_original_live_https_sync_gated

- workload: cdn_nginx_qatsw
Test #7: test_cdn_nginx_qatsw_vod_https_async
Test #8: test_cdn_nginx_qatsw_live_https_async
Test #9: test_cdn_nginx_qatsw_live_https_async_gated
Test #10: test_cdn_nginx_qatsw_live_https_async_pkm

- workload: cdn_nginx_qathw
Test #11: test_cdn_nginx_qathw_vod_https_async
Test #12: test_cdn_nginx_qathw_live_https_async
```

The workload provides test cases that are combination of the following aspects:

- **`http`/`https`**: `http` refers to set up cache server in http mode, and `async` refers to set up cache server in https mode.
- **`sync`/`async`**: `sync` refers to use the public NGINX in software stack, `async` refers to use Intel(R) optimized async version NGINX.
- **`live`/`vod`**: refers to media mode, `live` used memory as cache medium, `vod` uses disk as cache medium.
- **`gated`/`pkm`**: `gated` refers to small test with single connection, 6s duration and all pods are deployed on single node; `pkm` refers to regular test on 2 nodes (seperate client and server) with 400 connections and cache filling, which shall be use memory as cache.

### Docker Image

The workload provides the following docker images:

- **`cdn-nginx-content-server`**: The image runs the object generator, which generate specific size web file, default size is 1M.
- **`cdn-nginx-original`**: The image runs the Nginx official latest stable version from [https://nginx.org](https://nginx.org), it serves as cache server (original cases) and original server (reverse proxy server).
- **`cdn-nginx-async-qatsw`**: The image runs Intel optimized async version Nginx which can use QAT engine async operations to accelerate https performance from [https://github.com/intel/asynch_mode_nginx](https://github.com/intel/asynch_mode_nginx).
- **`cdn-nginx-async-qathw`**: The image runs Intel optimized async version Nginx which can use QAT engine async operations to accelerate https performance from [https://github.com/intel/asynch_mode_nginx](https://github.com/intel/asynch_mode_nginx).
- **`cdn-nginx-wrk`**: The image uses `wrk` to simulate user connections and measure performance. The list of user access URLs is pre-defined and then randomly selected. The best test parameters is machine specific.
- **`cdn-nginx-wrklog`**: Process logs for wrk.

### Workload Configuration

Since this is a multi-container workload, we must use Kubernetes to schedule the workload execution. The Kubernetes script [kubernetes-config.yaml.m4](kubernetes-config.yaml.m4) takes the following configurations:

- **`NODE`**: Specify `2n` or `3n`, default to 2 nodes. This changes benchmark topology, please choose based on test scenario. [More information](../../doc/user-guide/preparing-infrastructure/setup-cdn.md#hw-prerequisites).

  ```shell
  ./ctest.sh --set NODE="3n"
  ```
- **`SYNC`**: Specify `sync` or `async`.
- **`GATED`**: Specify `gated` or left empty, gated is used for CI validation, only requires one node. Default to empty.
- **`NICIP_W1`, `NICIP_W2`**: Specify the real 100G IP of worker-1 and worker-2. Default to `192.168.2.200`, `192.168.2.201`
- **`QAT_RESOURCE_TYPE`**: QAT resource type, available after installing qat-plugin.Check with `kubectl describe node` section `Capacity`. Default is `qat.intel.com/cy`.

  - For kerner version >= 5.11: `qat.intel.com/generic`;
  - For kernel version >= 5.17: `qat.intel.com/cy`.
- **`QAT_RESOURCE_NUM`**: The number of QAT VF to request. Default to 16.
- **`CACHE_SIZE`**: Specify the memory size of the each cache device when using `live` mode. Default to `30G`.
- **`DISK_SIZE`**: Specify the disk size of the each cache device when using `vod` mode. Default to `1000Gi`.

- **`HTTPMODE`**: Specify `http` or `https`.
- **`PROTOCOL`**: TLS version, default to `TLSv1.3`, also support `TLSv1.2`.
- **`CERT`**: It represents the authentication mechanism specifying how the certificate presented by the server to the client is signed. Supported values are `secp384r1`, `prime256v1`, `rsa2048`, `rsa3072`, `rsa4096`, `ecdhersa`, `ecdheecdsa`. If **`CIPHER`** is specified to `ECDHE-ECDSA-AES128-SHA` or `ECDHE-RSA-AES128-SHA`, the **`CERT`** value is not configurable. Default to `rsa2048`.
- **`CIPHER`**:
  - For TLSv1.2, default to `AES128-GCM-SHA256`, available options: `AES128-SHA`, `AES128-GCM-SHA256`, `ECDHE-ECDSA-AES128-SHA`, `ECDHE-RSA-AES128-SHA`.
  - For TLSv1.3, default to `TLS_AES_128_GCM_SHA256`, available options: `TLS_AES_256_GCM_SHA384`, `TLS_CHACHA20_POLY1305_SHA256`.
- **`CURVE`**: Specify ecdh curve in for Nginx [`ssl_ecdh_curve`](https://nginx.org/en/docs/http/ngx_http_ssl_module.html#ssl_ecdh_curve). Default is `auto`.

- **`SINGLE_SOCKET`**: Specify test scenario. Default to "", if set to "true", will reduce cache device number from 4 to 2. For performance test, please ensure all disks are on the same socket with cores used by Nginx.
- **`NGINX_WORKERS`**: Specify the worker_processes number of cache server NGINX. Defaults to 4.
- **`CPU_AFFI`**: Specify whether to do Nginx core binding for cache server. Default to ``, set `true` will bind above NGINX_WORKERS to NGINX_CPU_LISTS.
- **`NGINX_CPU_LISTS`**: Specify the CPU list for Nginx core binding, for example 0-7,112-119. If not specified, use 0-${NGINX_WORKERS}.

- **`NUSERS`**: Specify the number of wrk simulated users (connection number). Default to 400.
- **`NTHREADS`**: Specify the number of wrk threads. Default to the number of "NGINX_WORKERS".
- **`DURATION`**: Specify the simulation duration in seconds. Default to 60.

### How to setup functionality test?

The workload supports both 2 nodes and 3 nodes deployment, 2 nodes is the default option. Tester could choose the node number based on their test environment, this is configurable by passing the parameter "NODE=3n" or "NODE=2n" when running the ctest.

- 2 nodes(*default): Benchmark runs on one host off-cluster(simulate client), other three pods run on single*worker-1* in Kubernetes cluster
- 3 nodes: Benchmark runs on one host off-cluster(simulate client), cache-nginx pod run on *worker-1*, origin-nginx & content-server pod run on *worker-2* of Kubernetes cluster (server)

Hardware Requirement:

- Memory: 120G memory is required on worker-1.
- Network: 100G Network interface is necessary for all hosts with IP configured, and they should be connected to the same 100G switch. The 100G NIC should be fully occupied by the workload.
- Hugepage: 4096*2M Hugepage is required on worker-1.
- Disk: 4*1.8T NVME disk is required on worker-1, then you need manually mount the 4 disks to /mnt/diskx, please follow  [setup-cdn](../../doc/user-guide/preparing-infrastructure/setup-cdn.md#storage-configuration).

Check the Kubernetes node label before running the test:

- *CDN server worker-1 (SPR):*

  - `HAS-SETUP-DISK-SPEC-1=yes`
  - `HAS-SETUP-NIC-100G=yes`
  - `HAS-SETUP-QAT=yes`
  - `HAS-SETUP-HUGEPAGE-2048kB-4096=yes`
- *CDN server worker-2 (only 3-node):*

  - `HAS-SETUP-NIC-100G=yes`

Run the ctest:

- Pass the 100G NIC IP of worker-1 (e.g. 192.168.2.200) with the parameter

  ```shell
  ./ctest.sh --set NICIP_W1=192.168.2.200
  ```
- For 3-node deployment, you will also need to pass the 100G NIC IP of worker-2 (e.g. 192.168.2.201) with the parameter

  ```shell
  ./ctest.sh --set NICIP_W2=192.168.2.201
  ```

### How to setup performance test?

For performance test, the workload should run on 3 nodes.

- 3 nodes: Benchmark runs on one host off-cluster(simulate client), cache-nginx pod run on *worker-1*, origin-nginx & content-server pod run on *worker-2* of Kubernetes cluster(server)

The performance test setup takes the same steps as functionality test, only with higher HW requirement:

- Memory: *1TB (32x32GB)* memory is required on worker-1.
- Network: 100G NIC for all machines with IP configured, connected to the same 100G switch.

  - worker-1 and client node: Use *E810-2CQDA2* network card, [bond](https://www.server-world.info/en/note?os=Ubuntu_22.04&p=bonding) the 2 network ports to reach 200Gbps bandwidth.
    ```shell
    root@server:~# ethtool bond0
    Settings for bond0:
            Supported ports: [  ]
            Supported link modes:   Not reported
            Supported pause frame use: No
            Supports auto-negotiation: No
            Supported FEC modes: Not reported
            Advertised link modes:  Not reported
            Advertised pause frame use: No
            Advertised auto-negotiation: No
            Advertised FEC modes: Not reported
            Speed: 200000Mb/s
            Duplex: Full
            Auto-negotiation: off
            Port: Other
            PHYAD: 0
            Transceiver: internal
            Link detected: yes
    # Then contact your lab admin to bond the two corresponding ports on switch. Ensure the iperf could reach 170Gbps+.
    ```
- Hugepage: 4096*2M Hugepage is required on worker-1.
- Disk: 4*1.8T NVME disk is required on worker-1, then you need manually mount the 4 disks to /mnt/diskx, please follow [setup-cdn](../../doc/user-guide/preparing-infrastructure/setup-cdn.md#storage-configuration).
- BIOS setting for worker-1


  | BIOS setting                     | Required setting |
  | ---------------------------------- | ------------------ |
  | Intel(R) VT for Directed I/O     | Enable           |
  | Intel(R) Turbo Boost Technology  | Enable           |
  | Hyper-Threading                  | Enable           |
  | CPU power and performance policy | Performance      |
  | SncEn                            | Disable          |

### KPI

Run the [`kpi.sh`](kpi.sh) script to generate KPIs out of the validation logs, assumed to be under the `logs-static_cdn_nginx_xxx` directory. Parse the primary KPI by following commandline:

```shell
./kpi.sh | grep "*"
```

#### WRK KPI

The `wrk` http simulator generates the following KPIs:

- **`threads`**: The number of threads used in simulation.
- **`duration`**: The simulation duration.
- **`connections`**: The number of connections used in simulation.
- **`requests`**: The number of requests.
- **`failed`**: The number of failed responses.
- **`read (MB)`**: The total number of metabytes read.
- **`latency avg (ms)`**: The average response latency in milliseconds.
- **`latency std (ms)`**: The response latency standard deviation in milliseconds.
- **`latency max (s)`**: The maximum response latency in seconds.
- **`latency std% (%)`**: The latency standard deviation variation percentage.
- **`req/s avg (reqs/s)`**: The average request rate in requests per second.
- **`req/s std (reqs/s)`**: The request rate standard deviation in requests per second.
- **`req/s max (reqs/s)`**: The maximum request rate in requests per second.
- **`req/s std% (%)`**: The request rate standard deviation variation percentage.
- **`latency 50% (ms)`**: The 50 percentile response latency in milliseconds.
- **`latency 75% (ms)`**: The 75 percentile response latency in milliseconds.
- **`latency 90% (ms)`**: The 90 percentile response latency in milliseconds.
- **`latency 99% (ms)`**: The 99 percentile response latency in milliseconds.
- **`Requests/sec (reqs/s)`**: The request rate in requests per second.
- **`Transfer/sec (GB/s)`**: The transaction throughput in gigabytes per second.
- **`*Total throughput (GB/s)`**: The primary KPI is defined as the transaction throughput in gigabytes per second.

### Setup Workload with RA

If you use the Reference Architecture to set up your system, use the On-Premises profile for best performance.
Detail please refer to https://networkbuilders.intel.com/solutionslibrary/network-and-edge-reference-system-architectures-integration-intel-workload-services-framework-user-guide

### Index Info

- Name: `Content Distribution Network, NGINX`
- Category: `uServices`
- Platform: `SPR`, `ICX`
- Keywords:
- Permission:

### See Also

- [WRK the HTTP Benchmarking Tool - Advanced Example](http://czerasz.com/2015/07/19/wrk-http-benchmarking-tool-example/)
