>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

This is Trex base image

### Configuration

N/A 

### Usage

Construct your dedicated workload based on this base image, refer to Dockerfile.N.trex in [`Calico-VPP`](../../workload/Calico-VPP)

```
ARG RELEASE
FROM trex-base${RELEASE}
```
### Contact

- Stage1 Contact: `Dylan Chen`

### See Also
