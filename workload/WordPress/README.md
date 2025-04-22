>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

  [WordPress](https://wordpress.com) is a widely-used website building software. The WordPress workload simulates the blogging activities and measures the performance of the WordPress blogging operations.   

### System Configuration 

  The WordPress can be run in a single-node(1n) mode. Operating system of target server should be set as Ubuntu24.04 for successful running and best performance.

#### Parameters and attentions when set parameters in validate.sh:

##### Parameters defined by ctest command and workload itself when it runs (transparent to users)
The parameters below needn't change under normal circumstances. The only thing you do is to choose different testcase.
- **WORKLOAD**: This workload's name.
- **TESTCASE**: Testcase chosen when runs ctest.
- **WP_VERSION**: Gotten from name of testcase.
- **PHP_VERSION**: Gotten from name of testcase.
- **HTTPMODE**: http, https, https-crytomb for Intel's platform, http, https for other platform (like MILAN, GENOA); Run different testcase to determine the value of this parameter.
- **OPT_DEGREE**: base (Native), opt (with QATSW).

##### Parameters for tunning
- **NUSERS**: Virtual clients, default `200`.
- **DURATION**: Official benchmark time, default `60`.
- **NGINX_WORKER_PROCESSES**: Default `auto`, each instance's nginx worker processes equals to `number of cores used / instance count`, or you can set a specific number for each instance.
- **CERT**: Default `rsa2048`, options: [secp384r1, prime256v1, rsa3072, rsa4096, rsa2048].
- **NSERVERS**: PHP workers, default `auto`, in this case, each instance's PHP workers number equals to `number of cores used / instance count`, or you can set a specific number for each instance.
- **PHP_NUMA_OPTIONS**: Default `--interleave=all`, or use `-C 0-47,96-143 -m 0` to given a scope for all instances to run on.
- **NGINX_NUMA_OPTIONS**: Default `--interleave=all`, or use `-C 0-47,96-143 -m 0` to given a scope for all instances to run on.
- **MARIADB_NUMA_OPTIONS**: Default `--interleave=all`, or use `-C 0-47,96-143 -m 0` to given a scope for all instances to run on.
- **SIEGE_NUMA_OPTIONS**: Default `--interleave=all`, or use `-C 0-47,96-143 -m 0` to numactl siege to run on.
- **HUGEPAGE_NUM**: Define number of 2M hugepages for each instance to use, which means total hugepages used will be `HUGEPAGE_NUM * INSTANCE_COUNT`, default `2048`.

### Test Case

  The workload provides test cases that are combination of the following aspects:

  - **`wp6.7_php8.3`**: certain Wordpress + PHP versions to run, when make this workload, you can use `make build_wordpress_wp6.7_php8.3` to build the certain version of combination only.
  - **`http`/`https`**: `http` refers to run using HTTP and `https` refers to run using HTTPS.
  - **`openssl3.1.4`**: openssl versions to run.
  - **`sync`/`async`**: using qatsw or not (sync means qatsw off, async means qatsw on).
  - **`1n`/`2n`**: using 1node or 2node.

  The test case name follows: 

  ```
  Test #1: test_static_wordpress_wp6.7_php8.3_nojit_http_1n
  Test #2: test_static_wordpress_wp6.7_php8.3_nojit_https_openssl3.3.1_sync_1n
  Test #3: test_static_wordpress_wp6.7_php8.3_nojit_https_openssl3.3.1_async_1n
  Test #4: test_static_wordpress_wp6.7_php8.3_nojit_http_2n
  Test #5: test_static_wordpress_wp6.7_php8.3_nojit_https_openssl3.3.1_sync_2n
  Test #6: test_static_wordpress_wp6.7_php8.3_nojit_https_openssl3.3.1_async_2n
  Test #7: test_static_wordpress_wp6.7_php8.0_nojit_https_openssl3.3.1_sync_1n_gated
  Test #8: test_static_wordpress_wp6.7_php8.3_nojit_https_openssl3.3.1_async_1n_pkm
  ```

### KPI

  Run the [`kpi.sh`](kpi.sh) script to generate KPIs out of the validation logs. The script uses the following commandline:  

#### Siege KPI

  The `Siege` http simulator generates the following KPIs:

  - **`transactions (hits)`**: The number of total transactions.  
  - **`availability (%)`**: The percentage of the transaction availability.  
  - **`elapsed_time (s)`**: The total simulation time in seconds.  
  - **`data_transferred (MB)`**: The total amount of data transferred in megabytes. 
  - **`response_time (s)`**: The server response time in seconds.  
  - **`transaction_rate (trans/s)`**: The transaction rate in transactions per second.  
  - **`throughput (MB/s)`**: The total throughput in megabytes per second.  
  - **`concurrency`**: The total number of transactions divided by total elapsed time.  
  - **`successful_transactions`**: The number of successful transactions.  
  - **`failed_transactions`**: The number of failed transactions.  
  - **`longest_transaction (s)`**: The response time of the longest transaction in seconds.  
  - **`shortest_transaction (s)`**: The response time of the shortest transction in seconds.  

  The primary KPI is defined as the `transaction_rate` value. 

### Performance BKM

- **System**
  - hugepagesize: 2M
  - 2M hugepages: 2048 * INSTANCE_COUNT
  - Autumatic NUMA Balancing: Enabled

