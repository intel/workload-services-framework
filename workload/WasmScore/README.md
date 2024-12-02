>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

This Wasm benchmark reports an aggregate score of a suite of benchmarks representing common algorithms and real codes targeted by standalone Wasm. The suite composed is comprised of subcategories (ex. FaaS, Machine Learning, and BlockChain) which represent important use cases for standalone (primarily cloud-based) Wasm.

---

This benchmark is in development so scores from different versions will have no basis for comparison.

---

### Configurations

There are no configuration options for this benchmark.
### Docker Image

The workload contains a single docker image: `wasmscore`.  The workload does not expose any knobs and simply runs a predefined set of benchmarks that are then summarized by a final score where higher is considered better performing. The workload is the git clone download
of a similarly named framework that does expose configuration for validation and analysis.

### KPI

Run the [`list-kpi.sh`](./list-kpi.sh) script to generate the KPIs.

### Index Info

- Name: `WasmScore`
- Category: `Synthetic`
- Platform: `EMR`, `SPR`, `ICX`,`GNR`, `SRF`,`MILAN`,`ROME`,`ARMv8`,`ARMv9`
- Keywords: `WASM`

### Limitations

  - This workload only support the `docker` backend (with `DTERRAFORM_OPTIONS="--docker"` or `DCUMULUS_OPTIONS='--docker-run"` options). k8s is not supported.

### See Also

- [WasmScore](https://github.com/bytecodealliance/wasm-score)
