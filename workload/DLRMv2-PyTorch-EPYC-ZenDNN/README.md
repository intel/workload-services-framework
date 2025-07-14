>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

This workload is targeting for DLRMv2 benchmarking using Zentorch framework on Intel Xeon.

The DLRM is a popular Neural Network for recommendation, it's full name is deep learning recommendation model (DLRM). The core idea of the model is to capture the relative interest of the recommended items by using the historical behavior data for the user under the background of diversified user interests. The DLRM can help us to build a recommendation systems to predict what users might like, especially when there are lots of choices available. Current Workload in our framework provides methodologies for benchmark which can help us optimize the platform performance.

- **BENCHMARK_SCRIPT**: https://github.com/intel/models/tree/v3.1.1/models/recommendation/pytorch/torchrec_dlrm/dlrm_main.py


### Parameters
This DLRM workload provides test cases with the following configuration parameters:
- **TOPOLOGY**: Specify the topology: `DLRM-V2`.
- **MODE**: Specify the running mode: `throughput`. The default value is `throughput`.
- **FUNCTION**: Specify benchmarking scenario: `inference`.The default value is `inference`.
- **PRECISION**: Specify the model precision: `avx_fp32`, `avx_int8`, `amx_bfloat16`, `amx_int8` or `amx_fp16`.
- **DATA_TYPE**: Specify the input data type: `dummy` or `real`.  The default value is `dummy`.
- **BATCH_SIZE**: Specify the number of samples for each batch to inference or training. The default value is `16`.
- **STEPS**: Specify the number of inference iterations. The default value is `100`.
- **NUMA_NODES_USE**: Specify the node, the default value is `all`.
- **CASE_TYPE**: This is optional parameter, specify `gated` or `pkm`. Please refer to more details about [case type](../../doc/user-guide/executing-workload/testcase.md).
  - `gated` represents running the workload with reduced parameters.
  - `pkm` represents running the workload with the common parameters.
- **ONEDNN_VERBOSE**: Set to 1 to enable oneDNN verbose (default 0).
- **TORCH_TYPE**: Specify whether use which pytorch mode you want to use:
    * `IPEX`: use intel extension for pytorch (Default).
    * `COMPILE-INDUCTOR`: use pytorch compile method with inductor backend.
    * `COMPILE-OPENVINO`: use pytorch compile method with openvino backend.
- **USE_JEMALLOC** : Specify whether enable jemalloc (default `True`).
- **USE_TCMALLOC** : Specify whether enable tcmalloc (default `False`).

### Test Case

They are built-in test cases for `ctest`. The test case name is a combination of `<WORKLOAD_NAME>-<MODE>-<FUNCTION>-<DATA_TYPE>`. Not all combinations are supported.

```
cd <WSF REPO>
mkdir -p build

# cmake
cd build
cmake -DBACKEND=terraform -DTERRAFORM_OPTIONS="--docker --svrinfo --owner=<your id> --intel_publish" -DTERRAFORM_SUT=static -DBENCHMARK= ..

# Build the workload
cd <WSF REPO>/build/workload/DLRMv2-PyTorch-EPYC-ZenDNN
make

# Show all the test cases
./ctest.sh -N

# Run the specified the test case
./ctest.sh -R <test case key word> -V
```

### Docker Image

The DLRM-V2 workload provides 2 docker images:
- `Dockerfile.2.base`: for benchmarking
- `Dockerfile.1.inference`: for inference


### Index Info
- Name: `Deep Learning Recommendation Model V2, PyTorch EPYC-ZenDNN`
- Category: `ML/DL/AI`
- Platform: `AMD`

