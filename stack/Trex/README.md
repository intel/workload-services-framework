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
