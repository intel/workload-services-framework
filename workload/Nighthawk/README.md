>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
# SF Nighthawk Workload

## Introduction

This workload leverages Nighthawk, which is a L7 performance characterization tool, to perform L7 latency performance tests.

## Test Case

There are 3 test cases designed for basic function verification:
- test_nighthawk
- test_nighthawk_gated
- test_nighthawk_pkm

## Docker Image

This workload contains one docker image `Nighthawk`, which servers both as client and server.
This workload can run with kubernetes backend.

## Customization

Workload can be customized using following parameters:

- `DURATION` - The number of seconds that the test should run.
- `CONNECTIONS` - The maximum allowed number of concurrent connections per event loop.
- `CONCURRENCY` - The number of concurrent event loops that should be used.
- `RPS` - The target requests-per-second rate.

## KPI

Run the `kpi.sh` script to parse the KPIs from the output logs. The following KPIs are generated:

- **Latency**: The time from the start of the request to the end of the response, unit is ms. The number means percentage of total examplesmeans.
  - Latency9(ms): xxx.xxx
  - *Latency99(ms): xxx.xxx
- **Requests**: The number requests received per second, which HTTP status code is 2xx.
  - Requests(Per Second): xxx.xxx

### Index Info

- Name: `Nighthawk`
- Category: `uServices`
- Platform: `SPR`, `ICX`, `EMR`, `SRF`
- Keywords: `L7`, `HTTP`
- Permission:
