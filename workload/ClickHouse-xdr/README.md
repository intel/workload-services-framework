>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

ClickHouse® is an open-source column-oriented DBMS (Columnar Database Management System) for online analytical processing (OLAP) that allows users to generate analytical reports using SQL queries in real-time.
This benchmark can be used to evaluate the performance of ClickHouse in XDR (Extended Detection and Response) scenarios, and by using native Hyperscan and its support for AVX512, it can accelerate the query performance of ClickHouse on multi-regular expression matching operations.

### Test Architecture

```
+------------------------------------------------------+
|                                                      |
| +--------------------------------------------------+ |
| |                                                  | |
| | +------------------+        +------------------+ | |
| | |                  |        |                  | | |
| | |                  |   TCP  | ClickHouse Server| | |
| | |ClickHouse Client +--------+                  | | |
| | |                  |        | Hyperscan(AVX512)| | |
| | |                  |        |                  | | |
| | |                  |        |                  | | |
| | +------------------+        +------------------+ | |
| |                                   ClickHouse Pod | |
| +--------------------------------------------------+ |
|                                           K8S Node   |
+------------------------------------------------------+

```

### Test Case

There are several defined test cases:
- `clickhouse_xdr_public_hyperscan_baseline`: The baseline test case for public Hyperscan scenario.
- `clickhouse_xdr_public_hyperscan_avx512`: The AVX512 optimized test case for public Hyperscan scenario.
- `clickhouse_xdr_public_hyperscan_gated`: The gated test case for public Hyperscan scenario.
- `clickhouse_xdr_public_hyperscan_pkm`: The pkm test case for public Hyperscan scenario.

Note: Please ensure that the system executing the 'hyperscan_avx512' case is equipped with avx512vbmi instruction support, as this capability is required for building the Docker image associated with this test scenario.

Run designed test cases:
```
cd build
cmake ..
cd workload/Clickhouse-xdr
./ctest.sh -V ..
```

### Docker Image

The workload defines one Docker images.
* `clickhouse-xdr-public-hyperscan` is the image of the workload for public Hyperscan baseline testing scenario.
* `clickhouse-xdr-public-hyperscan-avx512` is the image of the workload for public Hyperscan avx512 testing scenario.

### Customize Test Configurations

Below are customized test parameters,
* `CLIENT_CORE_LIST` - ClickHouse client core list, default is 0-0. Normally, this parameter does not have much impact on the final performance, but need to make sure that it does not occupy the server core list.
* `SERVER_CORE_LIST` - ClickHouse server core list, default is 1-1.
* `SERVER_MAX_THREADS` - ClickHouse server max threads used for query operation, default is 1. Suggest to set this parameter to the core number of parameter SERVER_CORE_LIST.

### KPI

Run the [`kpi.sh`](kpi.sh) script to generate the KPIs.
Below 5 queries (query1 to query5) are used to measure Hyperscan regular expression performance,
- `Query 'query1' execution time(s)`: The execution time(s) of query1.
- `Query 'query2' execution time(s)`: The execution time(s) of query2.
- `Query 'query3' execution time(s)`: The execution time(s) of query3.
- `Query 'query4' execution time(s)`: The execution time(s) of query4.
- `Query 'query5' execution time(s)`: The execution time(s) of query5.
- `Average execution time(s) of query1 to query5`: The average execution time(s) of above 5 queries.

Below 2 queries (query6 and query7) are used to show Hyperscan benefits by comparing SQL fuzzy query performance and Hyperscan query performance,
- `Query 'query6' execution time(s)`: The execution time(s) of query6 for SQL fuzzy query.
- `Query 'query7' execution time(s)`: The execution time(s) of query7 for Hyperscan query.

### Index Info

- Name: `ClickHouse, Extended Detection and Response`
- Category: `XDR`
- Platform: `ICX`,`SPR`,`EMR`,`GNR`,`SRF`
- keywords:  AVX512, Hyperscan

### See Also

- [What is ClickHouse?](https://clickhouse.com/docs/en/intro)
- [Intel(R) Hyperscan](https://github.com/intel/hyperscan)
