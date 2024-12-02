>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

The application implements a Django workload using django framework.

Supported actions:
* View inbox -The inbox view in a mobile app for the current user
* View feed-timeline - A simple per-user feed of entries in time
* View timeline - A ranked feed of entries from other users
* View bundle_tray - A feed of current bundles, with nested content, from other users

### Supported OS
Centos stream9

### Test Case
The workload deploys frontend service to receive http requests, uses the pod `benchmark` as the on-cluster workload generator and measure the performance.

Test #1: test_static_django_native_tls_on_1_nodes_django_native_pkm
Test #2: test_static_django_native_tls_off_1_nodes_django_native_pkm
Test #3: test_static_django_native_tls_off_1_nodes_django_native_gated

Run workload manually with parameters
```
mkdir -p build
cd build
cmake -DBENCHMARK=Django-Native ..
cd workload/Django-Native/
TEST_CONFIG=<test_config_path>/test_config.yaml ./ctest.sh -V
```

### KPI
Run the [`kpi.sh`](kpi.sh) script to generate KPIs out of the validation logs. The script uses the following commandline:
```
Usage: ./kpi.sh
```

#### WRK KPI

The `siege` http simulator generates the following KPIs:
- **`Transactions (hits)`**: The number of server hits.
- **`Availability (%)`**: This is the percentage of socket connections successfully handled by the server.
- **`Elapsed time (secs)`**: The duration of the entire siege test.
- **`Data transferred (MB)`**: The sum of data transferred to every siege simulated user.
- **`Response time (secs)`**: The average time it took to respond to each simulated user's requests.
- **`Transaction rate (trans/sec)`**: The average number of transactions the server was able to handle per second, in a nutshell: transactions divided by elapsed time.
- **`Throughput (MB/sec)`**: The average number of bytes transferred every second from the server to all the simulated users.
- **`Concurrency`**: The average number of simultaneous connections, a number which rises as server performance decreases.
- **`Successful transactions`**: The number of times the server responded with a return code < 400
- **`Failed transactions`**: The number of times the server responded with a return code >= 400 plus the sum of all failed socket transactions which includes socket timeouts.
- **`Longest transaction`**: The greatest amount of time that any single transaction took, out of all transactions.
- **`Shortest transaction`**: The smallest amount of time that any single transaction took, out of all transactions.

