>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

Apache Doris is a high-performance, real-time analytic database based on the MPP architecture and is known for its extreme speed and ease of use. It takes only sub-second response times to return query results under massive amounts of data, and can support not only highly concurrent point query scenarios, but also high-throughput complex analytic scenarios. version, install and run it on a single node, including creating databases, data tables, importing data and queries, etc.


### Docker Image

The workload contains 3 docker images: `doris-benchmark`, `doris-fe` and `doris-be`. The container interact with each other using Kubernetes Service. Due to this configuration, it is recommended to run this workload using Kubernetes instead of docker.

* `doris-benchmark` - ssb benchmark
* `doris-fe` - Doris FE, for running Doris FE
* `doris-be` - Doris BE, for running Doris BE

```
# Deploy Doris workload
docker run --rm -v ${PWD}/helm:/apps:ro alpine/helm:3.7.1 template /apps --set DORIS_BE_NUM=1 --set DATA_SIZE_FACTOR=10 --set  DATA_GEN_THERADS=20 > kubernetes-config.yaml
kubectl apply -f kubernetes-config.yaml

# Retrieve logs
mkdir -p logs-doris
pod=$(kubectl get pod --selector=job-name=benchmark -o=jsonpath="{.items[0].metadata.name}")
kubectl exec $pod -- cat /export-logs | tar xf - -C logs-doris

# Delete Doris workload deployment
kubectl delete -f kubernetes-config.yaml
```

### Test Cases

* doris_gated - Gated test case, for this test case, DORIS_BE_NUM, DATA_SIZE_FACTOR and DATA_GEN_THERADS will be set to 1, and cannot be changed.
* doris_pkm - Used for [pkm](../../doc/developer-guide/component-design/cmakelists.md#special-test-cases) testing.
* doris_ssb - For customize paramters test case.

### Customize Test Configurations

Refer to [`ctest.md`](../../doc/user-guide/executing-workload/ctest.md#Customize%20Configurations) to customize test parameters.

Parameters for workload configure:
* `DORIS_BE_NUM` - Number of Dories BE. (default: 1)
* `DATA_SIZE_FACTOR` - Test set size factor, total file size is about 60GB when set to 100. (default: 100)
* `DATA_GEN_THERADS` - Number of concurrent threads generate data for the lineorder table, also determines the number of files in the final lineorder table. (default: 100). 


### KPI

Run the [`kpi.sh`](kpi.sh) script to parse the KPIs from the validation logs. 

The expected output should be similar to this. Please note that the numbers might be different. 

There are 2 parts in KPI result, 1st is SSB query, 2nd is Flat SSB query
```

[sfdev@owrlnxor0002 logs-doris_gated]$ ./kpi.sh
SSB query q1.1: 0.195 seconds
SSB query q1.2: 0.108 seconds
SSB query q1.3: 0.090 seconds
SSB query q2.1: 0.371 seconds
SSB query q2.2: 0.367 seconds
SSB query q2.3: 0.360 seconds
SSB query q3.1: 0.362 seconds
SSB query q3.2: 0.272 seconds
SSB query q3.3: 0.295 seconds
SSB query q3.4: 0.221 seconds
SSB query q4.1: 0.429 seconds
SSB query q4.2: 0.487 seconds
SSB query q4.3: 0.414 seconds
SSB Query Total Time(seconds): 3.971
Flat SSB query q1.1: 0.028 seconds
Flat SSB query q1.2: 0.030 seconds
Flat SSB query q1.3: 0.032 seconds
Flat SSB query q2.1: 0.090 seconds
Flat SSB query q2.2: 0.106 seconds
Flat SSB query q2.3: 0.087 seconds
Flat SSB query q3.1: 0.098 seconds
Flat SSB query q3.2: 0.089 seconds
Flat SSB query q3.3: 0.087 seconds
Flat SSB query q3.4: 0.039 seconds
Flat SSB query q4.1: 0.105 seconds
Flat SSB query q4.2: 0.070 seconds
Flat SSB query q4.3: 0.060 seconds
*Flat SSB Query Total Time(seconds): 0.921
```

### Performance Configuration

None.

### Performance BKM

None.

### Performance Report

None.


### Index Info
- Name: `Doris`
- Category: `DataServices`
- Platform: `GNR`, `SPR`, `ICX`, `EMR`, `SRF`
- Keywords:
- Permission:

### See Also

- [Star-Schema-Benchmark](https://doris.apache.org/docs/benchmark/ssb)
