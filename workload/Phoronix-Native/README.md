>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

The application implements Phoronix Test Suite (PTS)  which is an open-source, cross-platform benchmarking tool designed to evaluate system performance across a wide range of hardware and software configurations. Developed by Phoronix Media, PTS is widely used by system administrators, hardware reviewers, and developers to measure CPU, GPU, storage, and memory performance with real-world and synthetic workloads.

### Supported Benchmarks:
* pts/stream-1.3.4
* pts/nginx-3.0.0
* pts/nginx-3.0.1

### Steps to build the workload

**`mkdir build`** <br>
**`cd build`** <br>
**`cmake -DPLATFORM=ICX -DREGISTRY= -DREGISTRY_AUTH= -DRELEASE=:latest -DTIMEOUT=54000,5600 -DBENCHMARK=Phoronix -DBACKEND=terraform -DTERRAFORM_OPTIONS='--docker --svrinfo --tags=phoronix_test' -DTERRAFORM_SUT='static' -DSPOT_INSTANCE=false ..`** <br>
**`make`** <br>

### To list all the testcases

**`./ctest.sh -N`**


### Test Case

  - Test #1: test_static_phoronix_nginx_3.0.0_1node
  - Test #2: test_static_phoronix_nginx_3.0.0_1node_gated
  - Test #3: test_static_phoronix_nginx_3.0.0_1node_pkm
  - Test #4: test_static_phoronix_nginx_3.0.1_1node
  - Test #5: test_static_phoronix_nginx_3.0.1_1node_gated
  - Test #6: test_static_phoronix_nginx_3.0.1_1node_pkm
  - Test #7: test_static_phoronix_stream_1.3.4_1node
  - Test #8: test_static_phoronix_stream_1.3.4_1node_gated
  - Test #9: test_static_phoronix_stream_1.3.4_1node_pkm

### To Run the testacse

**`./ctest.sh -N`** (select the testcase that needs to be executed from the list) <br>
**`./ctest.sh -R "testcase_name" -V`** <br>
**Ex:** ./ctest.sh -R test_static_Phoronix_nginx-3.0.0_1node  -V <br>

### Configuration Options
Please pay special attention to:
**Nginx**
- PTS_NGINX301_DURATION: Default option set to 90s
- PTS_NGINX301_CONNECTIONS: Default option set to 400. Value should always be >= threads

User can change these by passing through ctest @example <ctest.sh -R test_static_Phoronix_nginx-3.0.0_1node --set PTS_NGINX301_DURATION=90s --set PTS_NGINX301_CONNECTIONS=400 >


### KPI
Run the [`kpi.sh`](kpi.sh) script to generate KPIs out of the validation logs. The script uses the following commandline:
```
Usage: ./kpi.sh
```

#### WRK KPI

The `Stream` generates the following KPIs:

The primary KPI is defined as the **`Triad Best Rate (MB/s)`** value.
- **`Triad Best Rate (MB/s)`**: Allows chained/overlapped/fused multiply/add operations.
- **`Scale Best Rate (MB/s))`**: Adds a simple arithmetic operation.
- **`Copy Best Rate (MB/s)`**:  Measures transfer rates in the absence of arithmetic.
- **`Add Best Rate (MB/s)`**: Adds a third operand to allow multiple load/store ports on vector machines to be tested.

The `Nginx` generates the following KPIs:
The primary KPI is defined as the **`Total requests per second (Requests/s)`** value.
- **`Total requests per second (Requests/s)`**: This is Clients successful https request per second.


### Index Info
- Name: `Phoronix`
- Category: `Synthetic`
- Keywords: `Stream-1.3.4`,`Nginx-3.0.0`,`Nginx-3.0.1`
- Platform: `SPR`, `ICX`, `EMR`,`GENOA`,`GNR`,`MILAN`,`SRF`



### See Also
https://github.com/phoronix-test-suite/phoronix-test-suite
