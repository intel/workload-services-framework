>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>

### Introduction

Welcome to the  **Workload Services Framework** repository. The repository contains a set of workloads optimized for Intel(R) Xeon(R) platforms. You can find the list of supported workloads in the [workload](workload) directory.  

### Prerequisite

Before you begin, ensure the following:

- Sync your system date and time. This is required for any credential authorization.  
- If you are behind a corporate firewall, please setup `http_proxy`, `https_proxy` and `no_proxy` in `/etc/environment`, and source the settings into the current shell environment.  
- Run the [`setup-dev.sh`](doc/user-guide/preparing-infrastructure/setup-wsf.md#setup-devsh) script to setup the development host for workload development and evaluation. Refer to [Cloud and On-Premises Setup](doc/user-guide/preparing-infrastructure/setup-wsf.md) for additional SUT setup. SUT stands for `System Under Test`, or `workload test machines`.   
  
### Evaluate Workload

Evaluate any workload as follows:  

```
mkdir build 
cd build
cmake ..                               # .. is required here
cd workload/OpenSSL-RSAMB              # Go to any workload folder
./ctest.sh -N                          # List all test cases
./ctest.sh -R test_openssl_rsamb_sw_rsa -V  # Evaluate a specific test case
./list-kpi.sh logs*                    # Show KPIs
```

---

The WSF supports multiple validation backends. By default, the [terraform](doc/user-guide/preparing-infrastructure/setup-terraform.md) backend covers on-premises or Cloud testing. You can also use the [`docker`](doc/user-guide/preparing-infrastructure/setup-docker.md) backend, or the [`Kubernetes`](doc/user-guide/preparing-infrastructure/setup-kubernetes.md) backend for evaluating any workload locally.   

---

### Build Workload

To build a workload, use the following commands:


```
mkdir -p build
cd build
cmake -DREGISTRY= -DBENCHMARK=ResNet-50 ..
cd workload/ResNet-50
make
./ctest.sh -N
```

> TIP: You can specify `BENCHMARK` to limit the repository scope to the specified workload. The build and test operations on all other workloads are disabled. See [Build Options](doc/user-guide/executing-workload/cmake.md) for details.  

Alternatively, you can use:

```
cd build
cmake -DBENCHMARK=ResNet-50
make
./ctest.sh -N
```



### Additional Resources

- [Build Options](doc/user-guide/executing-workload/cmake.md)   
- [Test Options](doc/user-guide/executing-workload/ctest.md)   
- [Setup Terraform](doc/user-guide/preparing-infrastructure/setup-terraform.md)  

