## Introduction

This is the **Workload Services Framework** repository. The repository contains a set of workloads that can be used to exercise multiple platforms. Each workload is a complete and standalone implementation that can be built and run collectively or individually. See the list of supported workloads under the [workload](workload/README.md) directory.  

### Prerequisite

- Sync your system date/time. It is required by docker credential authorization.  
- Install `cmake`, `make`, `m4`, and `gawk`.  
- Setup [docker](doc/setup-docker.md), [Kubernetes](doc/setup-kubernetes.md), or [cumulus](doc/setup-cumulus.md). [docker](doc/setup-docker.md) is the minimum requirement and can be used for single-container workload validation. [Kubernetes](doc/setup-kubernetes.md) can be used for multiple-node workload validation. Setup [cumulus](doc/setup-cumulus.md) for remote worker validation.  

### Build & Evaluate Workload

Evaluate a workload as follows:

```
mkdir -p build
cd build
cmake ..
cd workload/dummy
make
ctest -V
./list-kpi.sh logs*
```

> It takes a long time to rebuild all workload images. It is recommended that you only rebuild the workloads of interest by going to the workload sub-directory to make and test.  

You can optionally specify a `REGISTRY` value, `cmake -DREGISTRY=XYZ ..` to ask the build process to push the images to the docker registry. Please `docker login` beforehand if your docker registry requires authentication. A docker registry is optional except in the case of Kubernetes on-premises validation.   

### See Also

- [Build Options](doc/cmake.md)   
- [Test Options](doc/ctest.md)   
- [Develop New Workload](doc/workload.md)  
