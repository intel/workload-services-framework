>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

<p align="center"><IMG src="images/arch.png" width="90%"></p>

Istio is an open source service mesh that layers transparently onto existing distributed applications. Istio’s powerful features provide a uniform and more efficient way to secure, connect, and monitor services.

Envoy is a high-performance proxy developed in C++ to mediate all inbound and outbound traffic for all services in the service mesh. Envoy proxies are the only Istio components that interact with data plane traffic.

Nighthawk is a L7 performance characterization tool.

### Test Case

The Istio-Envoy workload organizes the following common test cases:

```
Test  #1: test_static_istio_envoy_rps_max_http1_2n
Test  #2: test_static_istio_envoy_rps_max_http2_2n
Test  #3: test_static_istio_envoy_rps_max_https_2n
Test  #4: test_static_istio_envoy_rps_sla_http1_2n
Test  #5: test_static_istio_envoy_rps_sla_http2_2n
Test  #6: test_static_istio_envoy_rps_sla_https_2n
Test  #7: test_static_istio_envoy_rps_max_http1_1n
Test  #8: test_static_istio_envoy_rps_max_http1_1n_ebpf
Test  #9: test_static_istio_envoy_rps_max_http1_2n_ebpf
Test #10: test_static_istio_envoy_rps_max_http2_1n_ebpf
Test #11: test_static_istio_envoy_rps_max_http2_2n_ebpf
Test #12: test_static_istio_envoy_rps_max_http1_2n_avx512
Test #13: test_static_istio_envoy_rps_max_https_2n_avx512
Test #14: test_static_istio_envoy_rps_sla_http1_2n_avx512
Test #15: test_static_istio_envoy_rps_sla_https_2n_avx512
Test #16: test_static_istio_envoy_rps_max_http2_2n_pkm
Test #17: test_static_istio_envoy_rps_max_http1_1n_gated
Test #18: test_static_istio_envoy_rps_max_https_2n_cryptomb
Test #19: test_static_istio_envoy_rps_max_https_2n_qathw
Test #20: test_static_istio_envoy_rps_max_http1_2n_dlb
Test #21: test_static_istio_envoy_rps_max_http2_2n_dlb
Test #22: test_static_istio_envoy_rps_max_https_2n_dlb
Test #23: test_static_istio_envoy_rps_sla_https_2n_cryptomb
Test #24: test_static_istio_envoy_rps_sla_https_2n_qathw
Test #25: test_static_istio_envoy_rps_sla_http1_2n_dlb
Test #26: test_static_istio_envoy_rps_sla_http2_2n_dlb
Test #27: test_static_istio_envoy_rps_sla_https_2n_dlb
```

- **`rps_max`**: Increases the requested RPS so as to obtain the highest possible achieved RPS without blocking.
- **`rps_sla`**: Maximum number of achieved RPS with Latency P99 below rps_sla e.g. 50ms.
- **`ebpf`**: Using eBPF to let the traffic bypass the TCP/IP stack.
- **`avx512`**: Enable BoringSSL with AVX512 vAES+vPCLMULQDQ patch to accelerate symmetric encryption.
- **`cryptomb`**: CryptoMB Extension to implemented the Envoy crypto provider for QATSW.
- **`qathw`**: Intel QAT device plugin enabled and exposed QAT VF devices to the Envoy container.
- **`dlb`**: It benefit the queue management performance for enqueue and dequeue by hardware queue manager.
- **`_pkm`**: This test case will run the whole progress.
- **`gated`**: Designed for basic function verification.

The workload doesn't support multiple concurrency when executing the test case, which means only one case in the same Kubernetes cluster can be executed at a time.

### Docker Image

This workload provides the following docker images:

- **`server`**: The image contains a simple test server. Concurrency flows load balanced by Istio Ingress Gateway.
- **`client`**: The image is used to collect the following KPIs: RPS (Requests per Second), latency, response body and header size.

The parameters are:

- **`MODE`**: Specify `rps_max` or `rps_sla`.
- **`PROTOCOL`**: Protocol (currently support HTTP1, HTTP2) in packet generator Nighthawk client.
- **`NODES`**: The node number. 1 node case only for eBPF performance benchmarking and tuning.
- **`ISTIO_VERSION`**: The version of Istio.
- **`CRYPTO_ACC`**: Choose crypto acceleration, default none.
- **`QAT_RESOURCE_TYPE`**: QAT resource type, it will be display `kubectl describe node` available resource `Capacity` & `Allocatable` section after installing
- **`DLB_ACC`**: Choose DLB acceleration, default none.
- **`EBPF`**: Choose EBPF to let the traffic bypass the TCP/IP stack, default none.
- **`AVX512_PATCH`**: Apply AVX512 Patch in BoringSSL, default none.
- **`AUTO_EXTEND_INPUT`**: Automatically extend the input RPS range to try to get the best KPI. It may take more time when set true, default false.
- **`MORE_EXT_SLA_SCAN`**: More Automatically extend the input RPS range for SLA cases. It may take more time when set true, default false.
- **`SERVER_IP`**: The external IP of Istio ingress gateway.
- **`SERVER_PORT`**: The port of the Istio ingress gateway for nighthawk server entrance, default 32222.
- **`SERVER_REPLICA_NUM`**: Replica number for the nighthawk server pod, default 15.
- **`SERVER_DELAY_MODE`**: Nighthawk server use static or dynamic delay to simulate the real server loading, default dynamic.
- **`SERVER_DELAY_SECONDS`**: When use static delay, the seconds for delay, default 0.5.
- **`SERVER_RESPONSE_SIZE`**: The payload size of the response in bytes, default 10.
- **`SERVER_INGRESS_GW_CPU`**: 2, 4, 8, 16 cores for Istio ingress gateway, default 8.
- **`SERVER_INGRESS_GW_MEM`**: Memory size requested for Istio ingress gateway, default 8Gi.
- **`SERVER_INGRESS_GW_CONCURRENCY`**: The concurrency number used by istio ingress gateway, default 8.
- **`CLIENT_HOST_NETWORK`**: Use host network or not, default yes.
- **`CLIENT_CPU`**: the CPU cores for Nighthawk client.
- **`CLIENT_CONNECTIONS`**: The connection number of each worker, default 1000.
- **`CLIENT_CONCURRENCY`**: The worker number of each connection, default 40.
- **`CLIENT_RPS`**: Input request per second for each worker, default 10.
- **`CLIENT_RPS_MAX`**: If the input RPS scan enabled, the max input RPS number to stop the iteration, default 300.
- **`CLIENT_RPS_STEP`**: Input step number for each iteration to increase, default 10.
- **`CLIENT_LATENCY_BASE`**: The threshold used by RPS-SLA, default 50.
- **`CLIENT_MAR`**: The maximum allowed number of concurrently active requests, default 500.
- **`CLIENT_MCS`**: Max concurrent streams allowed on one HTTP/2 connection, default 100.
- **`CLIENT_MRPC`**: Max requests per connection, default 7.
- **`CLIENT_MPR`**: Max pending requests, default 100.
- **`CLIENT_RBS`**: Size of the request body to send, default 400.

The workload should run on a 2-worker kubernetes cluster as follows:

```shell
mkdir -p logs-<REPLACE_YOUR_TESTCASE_HERE>
pod=$(kubectl get pod --selector="job-name-benchmark" -o=jsonpath="{.items[0].metadata.name}")
kubectl exec $pod -- cat output.logs | tar xf - -C <REPLACE_YOUR_TESTCASE_HERE>
```

### KPI

Run the [`kpi.sh`](kpi.sh) script to generate KPIs out of the validation logs.

The following KPI is defined:

- **`*Requests(Per Second)`**: The number requests received per second, which HTTP status code is 2xx.
- **`Latency9`**: The 90 percentile response latency in milliseconds.
- **`Latency99`**: The 99 percentile response latency in milliseconds.
- **`Latency999`**: The 999 percentile response latency in milliseconds.

### Performance BKM

The Istio-Envoy workload works with the `terraform` validation backend. For simplicity, the workload supports the following limited SUT:

- On-Premesis System
- AWS
- GCP

The eBPF case only support On-Premesis System.

#### Network Configuration

To run this workload for benchmarking and turning, make sure one 100Gb back-to-back connections between device.

#### BIOS Configuration

| Item                             | Setting     |
| -------------------------------- | ----------- |
| Turbo Boost Technology           | Disable     |
| SNC Mode                         | Quadrant    |
| IRQ balance                      | Disable     |
| CPU power and performance policy | Performance |
| Package C State                  | C0/C1 state |
| Hyper Threading                  | Enable      |
| Hardware P-States                | Native Mode |

#### System Configuration

On BM, the operating frequency and uncore frequency should be set to 2.0G.

##### QAT Configuration

[QAT Setup](../../doc/user-guide/preparing-infrastructure/setup-qat-in-tree.md)

Notes for configuration:
1. Add kernel parameters: intel_iommu=on vfio-pci.ids=8086:4941
2. Change the containerd memory limit larger by modify /etc/systemd/system/containerd.service.d/memlock.conf
```shell
[Service]
LimitMEMLOCK=167772160
```
then restart containerd service
```shell
systemctl daemon-reload
systemctl restart containerd
```
3. Sometimes the access right for files under /dev/vfio/ are not correct
```shell
chmod a+wr /dev/vfio/*
```

##### DLB Configuration

Please refer below guide:
[DLB Setup](../../doc/user-guide/preparing-infrastructure/setup-dlb.md)
Latest DLB can be found here:
[Intel DLB](https://www.intel.com/content/www/us/en/download/686372/intel-dynamic-load-balancer.html)

Note:

- "HAS-SETUP-DLB=yes" is not necessary for this workload
- for the 5.19+ kernel, the v8+ version of dlb is required

#### Kubernetes Configuration

* In this sample, the NIC used by the cluster is on NUMA node 0, core number is 224.

* CPU Manager Policy: static

* Reserve the CPUs belongs to NUMA 1 for system usage. Use CPU cores on NUMA 0 for benchmark.

* BM Configuration ARGs of `/var/lib/kubelet/kubeadm-flags.env`:

  ```
  KUBELET_KUBEADM_ARGS="--network-plugin=cni --pod-infra-container-image=k8s.gcr.io/pause:3.5 --max-pods=224 --reserved-cpus=0,56-111,112,168-223 --cpu-manager-policy=static”
  ```

#### AWS Configuration

On AWS cloud, instance type m6i/m7i.12xlarge was used as client node to have 40 cores for nighthawk client. Different instance types are configured for the ingress gateway CPU core number scaling. For the detail configurations, please refer to the performance report.



### See Also

- [Envoy Official Web Site](https://www.envoyproxy.io/)
- [Istio Official Web Site](https://istio.io)
- [Nighthawk](https://github.com/envoyproxy/nighthawk)
- [Istio Official Performance Guidance](https://istio.io/latest/docs/ops/deployment/performance-and-scalability/)
