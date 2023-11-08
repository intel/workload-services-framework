>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction
iPerf is a tool for network performance measurement and tuning. It is a cross-platform tool that can produce standardized performance measurements for any network. For each test it reports the bandwidth, loss, and other parameters.

### Docker Image
The workload provides two docker images: `iperf2` that serves both as client and server, and `iperf_nginx` used to check the status of iperf server. You can simply use iperf with docker image directly.

```
Build Docker Image:
cd <wsf-repo-path>/workload/Iperf
docker build -f Dockerfile.1.iperf -t iperf2:latest . 
Server Side(TCP):
sudo docker run --privileged -p 5201:5201 -e CLIENT_OR_SERVER=server iperf2:latest
Client Side(TCP):
sudo docker run --privileged -p 5201:5201 -e CLIENT_OR_SERVER=client -e SERVER_POD_IP=< server ip > -e SERVER_POD_PORT=5201 iperf2:latest
```

### Test Case
There are 6 test cases available:
- test_static_iperf2-pod2pod_tcp_base
```
Base test case, which is used to test the bandwidth between pod and pod with TCP protocol
```
- test_static_iperf2-pod2pod_udp_base
```
Base test case, which is used to test the bandwidth between pod and pod with UDP protocol
```
- test_static_iperf2-pod2svc_tcp_base
```
Base test case, which is used to test the bandwidth between pod and svc with TCP protocol
```
- test_static_iperf2-pod2svc_udp_base
```
Base test case, which is used to test the bandwidth between pod and svc with UDP protocol
```
- test_static_iperf2-pod2pod_tcp_pkm
```
This test case will run the whole progress with some system data( like emon ) collection for further performance analysis.
```
- test_static_iperf2-pod2pod_tcp_gated
```
Designed for basic function verification
```

### Customization
All the configurable parameters are listed in [`validate.sh`](validate.sh). You can use [`TEST_CONFIG`](https://github.com/intel/workload-services-framework/blob/main/doc/user-guide/executing-workload/ctest.md#customize-configurations) to set those parameters. Besides, CLIENT_OPTIONS & SERVER_OPTIONS can be used to set those options supported by iperf but not listed in validate.sh.

### KPI
Run the [`kpi.sh`](kpi.sh) script to parse the KPIs from the output logs.
The following KPIs are generated:
- **`Transfer`**: The amount of data exchanged between client and server, unit is Mbits or Gbits, extracted from server side.
- **`Bandwidth`**: Measured bandwidth, calculated by (transfer data/transfer time), unit is Mbits/sec or Gbits/sec, extracted from server side. This is the primary KPI.
- Notice: If specific unit is needed, you can add -f flag in SERVER_OPTIONS. For example, you can set the output format to GBytes and GBytes/sec by set SERVER_OPTIONS to "-f G".

- Known Issues:  
  - None  

