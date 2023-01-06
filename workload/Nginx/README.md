### Introduction

Nginx* is a high-performance HTTP/HTTPS and reverse proxy web server based on a BSD-like license. Nginx uses SSL/TLS to enhance web access security. Intel has introduced the Crypto-NI software solution which is based on 3rd generation Intel® Xeon® Scalable Processors (Codename Ice Lake/Whitley). It can effectively improve the security of web access. Intel_Asynch_Nginx is an Intel optimized version Nginx, used by Intel to support Async hardware and software acceleration for https. 
The main software used in this solution are IPP Cryptography Library, Intel Multi-Buffer Crypto for IPsec Library (intel-ipsec-mb) and Intel® QuickAssist Technology (Intel® QAT), which provide batch submission of multiple SSL requests and parallel asynchronous processing mechanism based on the new instruction set, greatly improving the performance.
Intel® QuickAssist Accelerator is a PCIe card that needs to be inserted into the PCIe slot in the server at the start.

This Workload is Client/Server Architecture.

the Nginx Server Pod and stress Client Pod(s) can running in one, two or three Kubernetes worker nodes.

---

### Test Case
  Test  #1: test_official_nginx_original_1node_https
  Test  #2: test_official_nginx_original_2node_https
  Test  #3: test_official_nginx_original_3node_https
  Test  #7: test_intel_async_nginx_qatsw_off_1node_https
  Test  #8: test_intel_async_nginx_qatsw_async_1node_https
  Test  #9: test_intel_async_nginx_qatsw_off_2node_https
  Test #10: test_intel_async_nginx_qatsw_async_2node_https
  Test #11: test_intel_async_nginx_qatsw_off_3node_https
  Test #12: test_intel_async_nginx_qatsw_async_3node_https
  Test #13: test_intel_async_nginx_qatsw_async_1node_https_gated

The workload provides test cases that are combination of the following aspects/concepts:

- **`official_nginx_original`/`intel_async_nginx`**: 
  official_nginx_original is the Nginx official latest stable version from https://nginx.org; 
  intel_async_nginx is Intel optimized async version Nginx which can use QAT engine async operations to accelerate https performance from https://github.com/intel/asynch_mode_nginx. 

- **`1node`/`2node`/`3node`**: 
  1node means one Nginx Server POD and one client Stress POD running on one Kubernetes worker node to save physical machine number. But this requires this Kubernetes worker node has at least $NGINX_WORKERS(default value 4) lcores to run Nginx Server POD, and plus additional $CLIENT_CPU_NUM(default it equals to $NGINX_WORKERS) lcores to run client POD on single kubernetes worker node.
  2node means one Nginx Server POD and one client stress POD running on two separate Kubernetes worker nodes. This requires each Kubernetes worker node has at least $NGINX_WORKERS(default value 4) lcores, because client POD $CLIENT_CPU_NUM by default equals to Nginx server POD $NGINX_WORKERS lcore number.  
  3node means one Nginx Server POD and two client stress PODs running on three separate Kubernetes worker nodes. This requires each Kubernetes worker node has at least $NGINX_WORKERS(default value 4) lcores, because client PODs $CLIENT_CPU_NUM by default equals to Nginx server POD $NGINX_WORKERS lcore number. 3node test cases is designed for some special https ciphers, eg ECDHE-ECDSA-AES128-SHA, those https ciphers single client POD running is  slower than Nginx server side with same lcore number, it cannot stress Nginx Server POD lcore too 100% usage, so we can add another client POD to two client PODs stress one server POD.
   Note:
    Nginx Server POD each lcore will bind to run one Nginx Worker process via taskset.
    client POD(s) each lcore will bind to run one Apache Bench stress process via taskset.


- **`https`**: Nginx Server access mode. for intel_async_nginx https mode: qatsw_async means use QAT engine QATSW acceleration for https; qatsw_off means not to use QAT engine QATSW acceleration(just like official_nginx_original did on https).

  test case test_intel_async_nginx_qatsw_async_1node_https_gated is designed for fast sanity/gated testing only on 1 node(minimum with 2 lcores, 1 lcore for nginx server POD, 1 lcore for client POD).
  test case test_intel_async_nginx_qatsw_async_1node_https_pkm is designed for Post-Si performance analysis.

Besides upper 11 test cases basic description, there are two very important environment parameters $CIPHER and $NGINX_WORKERS settings can be configured by user to generate more different testing:

- **`PROTOCOL`**: By default the https protocol is TLSv1.3 from release 22.44. You can also change https protocol to TLSv1.2 to reproduce the performance report before.
   eg, you can test a different https protocol performance for all test cases by this: export PROTOCOL=TLSv1.2; ctest -V;

- **`CIPHER`**:  For TLSv1.2, by default the https CIPHER is AES128-GCM-SHA256, you can change https CIPHER to AES128-SHA or AES128-GCM-SHA256 or ECDHE-ECDSA-AES128-SHA or ECDHE-RSA-AES128-SHA. For TLSv1.3, by default the https CIPHER is TLS_AES_128_GCM_SHA256, you can change https CIPHER to TLS_AES_256_GCM_SHA384 or TLS_CHACHA20_POLY1305_SHA256
   eg, you can test a different https cipher algorithms performance for all test cases by this: export CIPHER=ECDHE-RSA-AES128-SHA; ctest -V;

- **`NGINX_WORKERS`**: By default nginx worker number is 4. This means Nginx server POD will use 4 lcores(lcore 0-3) to run worker process;  You can configure NGINX_WORKERS as 1/2/4/8/16/32/64, Nginx Server POD will use lcore 0-N run Nginx worker processes.
   eg, you can test a different https Nginx worker number server POD performance for all test cases by this: export NGINX_WORKERS=8; ctest -V; 

   you can configure $CIPHER and $NGINX_WORKERS at the same time. eg.
     export CIPHER=AES128-SHA;
     export NGINX_WORKERS=16;
     ctest -V;
	
   *NOTICE HERE*: Very Very Important Info for how to calculate Kubernetes node(s) CPU lcores needed for test cases:
   
      If you run 1node test cases on single Kubernetes worker node, this Kubernetes worker node need 2x$NGINX_WORKERS CPU lcores as minimum. 
	   Nginx Server POD will use $NGINX_WORKERS lcores as Nginx workers processes; 
	   Client Stress POD will also use $CLIENT_CPU_NUM(by default equals to $NGINX_WORKERS) number lcores on the same Kubernetes node to stress Nginx Server POD.

      If you run 2node or 3node test cases on two Kubernetes nodes, make sure each Kubernetes node CPU lcores number equal to or bigger than $NGINX_WORKERS number;

  === Other Tier2 Environment parameters
   - **`REQUESTS`**: Specify the Client POD stress tool Apache Bench each process raised https request number. This is optional. Default value is 200000. You can override it before testing. eg. export REQUESTS=500000; ctest -V;
   - **`CONCURRENCY`**: Specify the Client POD stress tool Apache Bench each process raised https concurrency requests. This is optional. Default value is 100. You can override it before testing. Once you find the stress to Nginx server is not enough(CPU utilization of Nginx server is low), you can increase the value. Notice that too much concurrency may lead to packet loss, you'd better ensure "Failed Requests" is 0. eg. export CONCURRENCY=150; ctest -V;
   - **`HTTPS_PORT`**: Specify the nginx https service TCP port number. This is optional. Default value is 4400, to avoid conflicts with other application. You can override it before testing. eg. export HTTPS_PORT=600; ctest -V;
   - **`PROTOCOL`**: Specify the TLS version. This is optional. By default is TLSv1.3 from 22.44. TLSv1.2 is also supported.


### Docker Image

The workload contains these docker images: `nginx-original`, `async-nginx-qatsw`, and `nginx-client-openssl`.
   nginx-original: official Nginx docker image for test cases:
     Test #1: test_official_nginx_original_1node_https
     Test #2: test_official_nginx_original_2node_https
     Test #3: test_official_nginx_original_3node_https

   async-nginx-qatsw: Intel async Nginx docker image for test cases:
     Test #7: test_intel_async_nginx_qatsw_off_1node_https
     Test #8: test_intel_async_nginx_qatsw_async_1node_https
     Test #9: test_intel_async_nginx_qatsw_off_2node_https
     Test #10: test_intel_async_nginx_qatsw_async_2node_https
     Test #11: test_intel_async_nginx_qatsw_off_3node_https
     Test #12: test_intel_async_nginx_qatsw_async_3node_https
     Test #13: test_intel_async_nginx_qatsw_async_1node_https_gated
     Test #14: test_intel_async_nginx_qatsw_async_1node_https_pkm

   nginx-client-openssl: client stress docker image which will run a lot of "openssl s_time -connect server_ip:port -new -cipher $CIPHER –time 60s" instances to simulate virtual clients simultaneously.

 This Workload currently cannot support Docker running via "docker run ...". This Workload can support Kubernetes, Cumulus and Terraform running.

### KPI

Run the [`kpi.sh`](kpi.sh) script to generate the KPIs. 
The following KPIs are defined:
- `Nginx_Worker_Number-AES128-GCM-SHA256:`: The number means how many lcores to running Nginx service(nginx worker number) in Nginx Server POD, it will also display the https $CIPHER name.
- `Client_Node1_Configured_Core_Number`: This is the Client POD lcore numbers to run Apache Bench to do the stress.
- `Client_Node1_Reqeuest_per_vclient`: This is defined by $REQUESTS before ctest. one vclient means one Apache Bench process.
- `Client_Node1_Concurrency_per_vclient`: This is defined by $CONCURRENCY before ctest. one vclient means one Apache Bench process.
- `*Total requests per second (Requests/s)`: This is Clients successful https request per second.


Here is an example:
```
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

### Performance BKM (TLSv1.3)
- **ICX**

  | BIOS setting                     | Required setting |
  | -------------------------------- | ---------------- |
  | Hyper-Threading                  | Enable           |
  | CPU power and performance policy | Performance      |
  | turbo boost technology           | Enable           |
  | Package C State                  | C0/C1 state      |
  
  System(In this example, physical core: 0-31,64-95, logical core: 32-63,96-127):
  - 2M hugepages: 4096
  - irqbalance: disable
  - Ethernet 100G Switch

  IRQs Binding: Bind IRQs to the core on Socket2. First get the currently bound irq list of the NIC used by nginx. For example: you can use this command: 
  ```
  irq_list=($(cat /proc/interrupts | grep "$dev_name" | awk -F: '{print $1}'))
  ```
  Then you can modify the smp_affinity_list of irq_list to the core index of socket2. You can refer to the following logic to complete the modification:
  ```
  for(( i = 0; i < $irq_list_len; i ++ ))
  do
    echo "$core" > /proc/irq/${irq_list[$i]}/smp_affinity_list
  done
  ```

### Index Info
- Name: `Nginx`
- Category: `uServices`
- Platform: `ICX`
- Keywords: `Nginx`, `https`
- Permission: 

### See Also
- [Nginx Official website](https://nginx.org/)
- [Intel Async Nginx website](https://github.com/intel/asynch_mode_nginx)
- [OpenSSL website](https://www.openssl.org/)
- [QAT_Engine website](https://github.com/intel/QAT_Engine)
- [intel-ipsec-mb website](https://github.com/intel/intel-ipsec-mb)
- [intel-ipp-crypto website](https://github.com/intel/ipp-crypto)
