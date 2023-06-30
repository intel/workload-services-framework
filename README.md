>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>

### Introduction

This is the **Workload Services Framework** repository. The repository contains a set of workloads optimized for Intel(R) Xeon(R) platforms. See the list of supported workloads under the [workload](workload) directory.  

### Setup

- Sync your system date/time. This is required by any credential authorization.  
- If you are behind a corporate firewall, please setup `http_proxy`, `https_proxy` and `no_proxy` in `/etc/environment`.
- Run the [`setup-dev.sh`](doc/user-guide/preparing-infrastructure/setup-wsf.md#setup-devsh) script to setup the development host for Cloud and On-Premises workload development and evaluation. See [Cloud and On-Premises Setup](doc/user-guide/preparing-infrastructure/setup-wsf.md) for more details on the setup.
  
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

- The WSF supports multiple validation backends. By default, the [`docker`](doc/user-guide/preparing-infrastructure/setup-docker.md) backend, or the [`Kubernetes`](doc/user-guide/preparing-infrastructure/setup-kubernetes.md) backend if available, is used to evaluate any workload locally. To evaluate workloads on Cloud or in an on-premises cluster, please use the [terraform](doc/user-guide/preparing-infrastructure/setup-terraform.md) backend. Additional setup required such as configuring Cloud account credentials.

---

### Build Workload

```
mkdir -p build
cd build
cmake -DREGISTRY= -DBENCHMARK=ResNet-50 ..
cd workload/ResNet-50
make
./ctest.sh -N
```

> TIP: You can specify `BENCHMARK` to limit the repository scope to the specified workload. The build and test operations on all other workloads are disabled. See [Build Options](doc/user-guide/executing-workload/cmake.md) for details.

```
cd build
cmake -DBENCHMARK=ResNet-50
make
./ctest.sh -N
```

### See Also

- [Build Options](doc/user-guide/executing-workload/cmake.md)
- [Test Options](doc/user-guide/executing-workload/ctest.md)
- [Setup Terraform](doc/user-guide/preparing-infrastructure/setup-terraform.md)

