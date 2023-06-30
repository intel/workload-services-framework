>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

Nginx* is a high-performance HTTP/HTTPS and reverse proxy web server based on a BSD-like license. Nginx uses SSL/TLS to enhance web access security. Intel has introduced the Crypto-NI software solution which is based on 3rd generation Intel® Xeon® Scalable Processors (Codename Ice Lake/Whitley). It can effectively improve the security of web access. Intel_Asynch_Nginx is an Intel optimized version Nginx, used by Intel to support Async hardware and software acceleration for https.
The main software used in this solution are IPP Cryptography Library, Intel Multi-Buffer Crypto for IPsec Library (intel-ipsec-mb) and Intel® QuickAssist Technology (Intel® QAT), which provide batch submission of multiple SSL requests and parallel asynchronous processing mechanism based on the new instruction set, greatly improving the performance.
Intel® QuickAssist Accelerator is a PCIe card that needs to be inserted into the PCIe slot in the server at the start.

This Workload is Client/Server Architecture.

the Nginx Server Pod and stress Client Pod(s) can run in one, two or three Kubernetes worker nodes.

---

### Test Cases

```log
Test #1: test_official_nginx_original_1node_https
Test #2: test_official_nginx_original_2node_https
Test #3: test_official_nginx_original_3node_https
Test #4: test_intel_async_nginx_qatsw_off_1node_https
Test #5: test_intel_async_nginx_qatsw_async_1node_https
Test #6: test_intel_async_nginx_qatsw_off_2node_https
Test #7: test_intel_async_nginx_qatsw_async_2node_https
Test #8: test_intel_async_nginx_qatsw_off_3node_https
Test #9: test_intel_async_nginx_qatsw_async_3node_https
Test #10: test_intel_async_nginx_qatsw_async_1node_https_gated
Test #11: test_intel_async_nginx_qatsw_async_1node_https_pkm
Test #12: test_intel_async_nginx_qathw_async_1node_https
Test #13: test_intel_async_nginx_qathw_async_2node_https
Test #14: test_intel_async_nginx_qathw_async_3node_https
```

The workload provides test cases that are combination of the following aspects/concepts:

- **`official_nginx_original`/`intel_async_nginx`**:
  official_nginx_original is the Nginx official latest stable version from <https://nginx.org> while intel_async_nginx is Intel optimized async version Nginx which can use QAT engine async operations to accelerate https performance from <https://github.com/intel/asynch_mode_nginx>.

- **`1node`/`2node`/`3node`**:
  1node means one Nginx Server POD and one client Stress POD running on one Kubernetes worker node to save physical machine number. But this requires this Kubernetes worker node has at least $NGINX_WORKERS(default value 4) lcores to run Nginx Server POD, and plus additional $CLIENT_CPU_NUM(default it equals to $NGINX_WORKERS) lcores to run client POD on single kubernetes worker node.
  2node means one Nginx Server POD and one client stress POD running on two separate Kubernetes worker nodes. This requires each Kubernetes worker node has at least $NGINX_WORKERS(default value 4) lcores, because client POD $CLIENT_CPU_NUM by default equals to Nginx server POD $NGINX_WORKERS lcore number.  
  3node means one Nginx Server POD and two client stress PODs running on three separate Kubernetes worker nodes. This requires each Kubernetes worker node has at least $NGINX_WORKERS(default value 4) lcores, because client PODs $CLIENT_CPU_NUM by default equals to Nginx server POD $NGINX_WORKERS lcore number. 3node test cases is designed for some special https ciphers, eg ECDHE-ECDSA-AES128-SHA, those https ciphers single client POD running is  slower than Nginx server side with same lcore number, it cannot stress Nginx Server POD lcore too 100% usage, so we can add another client POD to two client PODs stress one server POD.
   Note:
    Nginx Server POD each lcore will bind to run one Nginx Worker process via taskset.
    client POD(s) each lcore will bind to run one Apache Bench stress process via taskset.

- **`https`**: Nginx Server access mode. for intel_async_nginx https mode: qatsw_async means use QAT engine QATSW acceleration for https; qathw_async means use Intel QuickAssist Accelerator Card for https; qatsw_off means not to use QAT engine QATSW acceleration(just like official_nginx_original did on https).

  test case test_intel_async_nginx_qatsw_async_1node_https_gated is designed for fast sanity/gated testing only on 1 node(minimum with 2 lcores, 1 lcore for nginx server POD, 1 lcore for client POD).
  test case test_intel_async_nginx_qatsw_async_1node_https_pkm is designed for Post-Si performance analysis.

Besides upper 11 test cases basic description, there are two very important environment parameters $CIPHER and $NGINX_WORKERS settings can be configured by user to generate more different testing:

- **`PROTOCOL`**: By default, the https protocol is TLSv1.3 from release 22.44. You can also change https protocol to TLSv1.2 to reproduce the performance report before.
   eg, you can test a different https protocol performance for all test cases by this: export PROTOCOL=TLSv1.2; ./ctest.sh -V;

- **`CIPHER`**:  For TLSv1.2, by default the https CIPHER is AES128-GCM-SHA256, you can change https CIPHER to AES128-SHA or AES128-GCM-SHA256 or ECDHE-ECDSA-AES128-SHA or ECDHE-RSA-AES128-SHA. For TLSv1.3, by default the https CIPHER is TLS_AES_128_GCM_SHA256, you can change https CIPHER to TLS_AES_256_GCM_SHA384 or TLS_CHACHA20_POLY1305_SHA256
   eg, you can test a different https cipher algorithms performance for all test cases by this: export CIPHER=ECDHE-RSA-AES128-SHA; ./ctest.sh -V;

- **`CURVE`**:  Specify ecdh curve in for Nginx [`ssl_ecdh_curve`](https://nginx.org/en/docs/http/ngx_http_ssl_module.html#ssl_ecdh_curve). Default is `auto`.

- **`NGINX_WORKERS`**: By default, nginx worker number is 4. This means Nginx server POD will use 4 lcores(lcore 0-3) to run worker process;  You can configure NGINX_WORKERS as 1/2/4/8/16/32/64, Nginx Server POD will use lcore 0-N run Nginx worker processes.
   eg, you can test a different https Nginx worker number server POD performance for all test cases by this: export NGINX_WORKERS=8; ./ctest.sh -V; 

   you can configure $CIPHER and $NGINX_WORKERS at the same time. eg.
     export CIPHER=AES128-SHA;
     export NGINX_WORKERS=16;
     ./ctest.sh -V;
	
   *NOTICE HERE*: Very Important Info for how to calculate Kubernetes node(s) CPU lcores needed for test cases:
   
      If you run 1node test cases on single Kubernetes worker node, this Kubernetes worker node need 2x$NGINX_WORKERS CPU lcores as minimum. 
	   Nginx Server POD will use $NGINX_WORKERS lcores as Nginx workers processes; 
	   Client Stress POD will also use $CLIENT_CPU_NUM(by default equals to $NGINX_WORKERS) number lcores on the same Kubernetes node to stress Nginx Server POD.

  - If you run 2node or 3node test cases on two Kubernetes nodes, make sure each Kubernetes node CPU lcores number equal to or bigger than $NGINX_WORKERS number;
- **`SWEEPING`**: Do sweeping for parameter CONCURRENCY and choose the best performance, by default it's off, you can enable it by setting SWEEPING=on
- **`PACE`**: Step size of sweeping parameter CONCURRENCY, It takes effect when SWEEPING=on, default value is 10
- **`MAX_CORE_WORKER_CLIENT`**: If set it as true, this workload use the whole system cores both for client and server, to achieve best performance, it's suggested to set it as true for cloud >=2node test cases

=== Other Tier2 Environment parameters

- **`REQUESTS`**: Specify the Client POD stress tool Apache Bench each process raised https request number. This is optional. Default value is 200000. You can override it before testing. eg. export REQUESTS=500000; ./ctest.sh -V;
- **`CONCURRENCY`**: Specify the Client POD stress tool Apache Bench each process raised https concurrency requests. This is optional. Default value is 100. You can override it before testing. Once you find the stress to Nginx server is not enough(CPU utilization of Nginx server is low), you can increase the value. Notice that too much concurrency may lead to packet loss, you'd better ensure "Failed Requests" is 0. eg. export CONCURRENCY=150; ./ctest.sh -V;
- **`HTTPS_PORT`**: Specify the nginx https service TCP port number. This is optional. Default value is 4400, to avoid conflicts with other application. You can override it before testing. eg. export HTTPS_PORT=600; ./ctest.sh -V;
- **`PROTOCOL`**: Specify the TLS version. This is optional. By default is TLSv1.3 from 22.44. TLSv1.2 is also supported.
- **`CLIENT_CPU_LISTS`**: Specify the cpu core list bound by client. This is optional. If not specified, the cpu core list bound to client will be specified as 0-${NGINX_WORKERS} by default. You can override it before testing. eg. export CLIENT_CPU_LISTS=0-31; ./ctest.sh -V;
  > Note: If you want to run 1c2t scenario on a single node, you need to override `CLIENT_CPU_LISTS` to avoid core overlaping with workers.
- **`NGINX_CPU_LISTS`**: Specify the cpu core list bound by nginx. This is optional. If not specified, the cpu core list bound to nginx will be specified as 0-${NGINX_WORKERS} by default. You can override it before testing. eg. export NGINX_CPU_LISTS=56-87; ./ctest.sh -V;
  > Note: If you run 1c2t scenario, you need to override cpu list to match 2 workers to 1 physical core
  >
  > **e.g** For server: NUMA node0 CPU(s): 0-55,112-167, to run 4c8t, you need to set `NGINX_WORKERS=8` and `NGINX_CPU_LISTS=0-3,112-115`
- **`GETFILE`**: Specify the file size requested by the client to nginx. This is optional. The default is index.html, which is a 0KB file. Other optional files are: random_content_1KB, random_content_2KB, random_content_4KB, random_content_512KB, random_content_1MB, random_content_4MB. You can override it before testing. eg. export GETFILE=random_content_512KB; ./ctest.sh -V;
- **`QAT_RESOURCE_TYPE`**: QAT resource type, it will be display `kubectl describe node` available resource `Capacity` & `Allocatable` section after installing qat-plugin. For kerner version >= 5.11: `qat.intel.com/generic`; for kernel version >= 5.17 `qat.intel.com/cy`: Default is `qat.intel.com/generic`
- **`QAT_RESOURCE_NUM`**: The number of QAT resouce to request. Default is all qat resource on the host(32).

### Docker Image

The workload contains these docker images: `nginx-original`, `async-nginx-qatsw`, `async-nginx-qathw`, `spr-nginx-qat-hw-setup`, `nginx-client-ab`, `nginx-client-openssl`, `nginx-client-wrk`.

- nginx-original: official Nginx docker image for test cases:
  - Test #1: test_official_nginx_original_1node_https
  - Test #2: test_official_nginx_original_2node_https
  - Test #3: test_official_nginx_original_3node_https
- async-nginx-qatsw: Intel async Nginx docker image for test cases:
  - Test #7: test_intel_async_nginx_qatsw_off_1node_https
  - Test #8: test_intel_async_nginx_qatsw_async_1node_https
  - Test #9: test_intel_async_nginx_qatsw_off_2node_https
  - Test #10: test_intel_async_nginx_qatsw_async_2node_https
  - Test #11: test_intel_async_nginx_qatsw_off_3node_https
  - Test #12: test_intel_async_nginx_qatsw_async_3node_https
  - Test #13: test_intel_async_nginx_qatsw_async_1node_https_gated
  - Test #14: test_intel_async_nginx_qatsw_async_1node_https_pkm
- async-nginx-qathw: Intel async Nginx docker image for test cases:
  - Test #23: test_intel_async_nginx_qathw_async_1node_https
  - Test #24: test_intel_async_nginx_qathw_async_2node_https
  - Test #25: test_intel_async_nginx_qathw_async_3node_https

- nginx-client-openssl: client stress docker image which will run a lot of `openssl s_time -connect server_ip:port -new -cipher $CIPHER –time 60s` instances to simulate virtual clients simultaneously.
- nginx-client-ab & nginx-client-wrk used Apache Bench & wrk respectively to collect benchmark results. 

This Workload currently cannot support Docker running via `docker run ...`.
This Workload can also support Kubernetes, Cumulus and Terraform running.

### KPI

Run the [`kpi.sh`](kpi.sh) script to generate the KPIs.
The following KPIs are defined:

- `Nginx_Worker_Number-AES128-GCM-SHA256:`: The number means how many lcores to running Nginx service(nginx worker number) in Nginx Server POD, it will also display the https $CIPHER name.
- `Client_Node1_Configured_Core_Number`: This is the Client POD lcore numbers to run Apache Bench to do the stress.
- `Client_Node1_Reqeuest_per_vclient`: This is defined by $REQUESTS before ctest. one vclient means one Apache Bench process.
- `Client_Node1_Concurrency_per_vclient`: This is defined by $CONCURRENCY before ctest. one vclient means one Apache Bench process.
- `*Total requests per second (Requests/s)`: This is Clients successful https request per second.

Here is an example:

```console
Nginx_Worker_Number-AES128-GCM-SHA256: 16
Client_Node1_Configured_Core_Number: 16
Client_Node1_Reqeuest_per_vclient: 200000
Client_Node1_Concurrency_per_vclient: 100
Client_Node1_Complete_requests: 3200000
Client_Node1_Failed_requests: 0
Client_Node1_requests_per_second: 29155.7
Client transferred (bytes): 732800000
Client HTML transferred (bytes): 0
Client_Node2_Configured_Core_Number: 16
Client_Node2_Reqeuest_per_vclient: 200000
Client_Node2_Concurrency_per_vclient: 100
Client_Node2_Complete_requests: 3200000
Client_Node2_Failed_requests: 0
Client_Node2_requests_per_second: 29124.8
Client transferred (bytes): 732800000
Client HTML transferred (bytes): 0
Client Stress Latency Min (ms): 2
Client Stress Latency Mean (ms): 55
Client Stress Latency Std: 63.7
Client Stress Latency Median (ms): 37
Client Stress Latency Max (ms): 2224
*Total requests per second (Requests/s): 58280.5
Built target kpi_intel_async_nginx_qatsw_async_3node_https
```

The primary KPI is defined as the `Total requests per second (Requests/s)` value.

### Performance BKM (TLSv1.2)

- System
  - intel_iommu: OFF

- BIOS
  - **ICX:**
    - Turbo: ON
    - SNC: OFF
    - Intel VT for directed I/O: OFF
  - **SPR:**
    - Turbo: ON
    - SNC: ON
    - Intel VT for directed I/O: OFF

### Performance BKM (TLSv1.3 and QATHW)

#### **ICX**

| BIOS setting                     | Required setting |
| -------------------------------- | ---------------- |
| Hyper-Threading                  | Enable           |
| CPU power and performance policy | Performance      |
| turbo boost technology           | Enable           |
| Package C State                  | C0/C1 state      |

#### **SPR**

| BIOS setting                     | Required setting |
| -------------------------------- | ---------------- |
| Hyper-Threading                  | Enable           |
| CPU power and performance policy | Performance      |
| turbo boost technology           | Enable           |
| Package C State                  | C0/C1 state      |

### Index Info

- Name: `Nginx`
- Category: `uServices`
- Platform:  `SPR`, `ICX`
- Keywords: `Nginx`, `https`
- Permission:

### See Also

- [Nginx Official website](https://nginx.org/)
- [Intel Async Nginx website](https://github.com/intel/asynch_mode_nginx)
- [OpenSSL website](https://www.openssl.org/)
- [QAT_Engine website](https://github.com/intel/QAT_Engine)
- [intel-ipsec-mb website](https://github.com/intel/intel-ipsec-mb)
- [intel-ipp-crypto website](https://github.com/intel/ipp-crypto)
