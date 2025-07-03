>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

This workload is targeting for DLRMv2 benchmarking using PyTorch framework on Intel Xeon.

The DLRM is a popular Neural Network for recommendation, it's full name is deep learning recommendation model (DLRM). The core idea of the model is to capture the relative interest of the recommended items by using the historical behavior data for the user under the background of diversified user interests. The DLRM can help us to build a recommendation systems to predict what users might like, especially when there are lots of choices available. Current Workload in our framework provides methodologies for benchmark which can help us optimize the platform performance.

- **BENCHMARK_SCRIPT**: https://github.com/facebookresearch/dlrm.git/dlrm_s_main.py

### Test Case
They are built-in test cases for `ctest`. The test case name is a combination of `<WORKLOAD_NAME>-<MODE>-<FUNCTION>`.

Use the following commands to show the list of test cases:
```
cd build
cmake ..
cd workload/DLRMv2-PyTorch-ARM
./ctest.sh -N

or
./ctest.sh -V
(run all test cases)

or
./ctest.sh -R <test case key word> -V

Test cases:
test_aws_dlrmv2_pytorch_arm_throughput_pkm

The DLRMv2-PyTorch-ARM workload provides test cases with the following configuration parameters:
- **BATCH_SIZE**: Specify the batch size value: default as `BATCH_SIZE=1`.
- **CORES_PER_INSTANCE**: Define the number of cores in one instance. Default as `CORES_PER_INSTANCE=1`.
- **TORCH_MKLDNN_MATMUL_MIN_DIM**: Minimum dimension size for which the MKL-DNN (oneDNN) library will be used. Default as `TORCH_MKLDNN_MATMUL_MIN_DIM=1024`.
- **PRECISION**:  Specify the precision. Default as `PRECISION=FP32`.

> **NOTE**: Different ARM version correspond different Machine type, eg:
> | CLOUD |	Machine type | Platform ARM |
> | ----- |	------------ | ------------ |
> | AWS	| Graviton4/r8g	| ARMv8 |
> | AWS	| Graviton4/r8g	| ARMv9 |
> | AZURE	| Cobalt/D8ps| ARMv9 |
> | AZURE	| Cobalt/D8ps| ARMv8 |


### Docker Image
DLRMv2-PyTorch-ARM workload provides following docker image:
* `dlrmv2-pytorch-arm-public`

### Index Info

- Name: `Deep Learning Recommendation Model V2, ARM`
- Category: `ML/DL/AI`
- Platform: `ARMv8`, `ARMv9`
- Keywords: `CPU`
