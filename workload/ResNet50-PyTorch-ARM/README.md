>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

This workload is targeting for ResNet50 benchmarking using the PyTorch framework on ARM. ResNet50 is a variant of ResNet model which has 48 Convolution layers along with 1 MaxPool and 1 Average Pool layer. It has 3.8 x 10^9 Floating points operations. It is a widely used ResNet model and we have explored ResNet50 architecture in depth.

### Test Case

The Resnet50-PyTorch-ARM workload provides test cases with the following configuration parameters:
- **BATCH_SIZE**: Specify the batch size value: default as `BATCH_SIZE=1`.
- **CORES_PER_INSTANCE**: Define the number of cores in one instance. Default as `CORES_PER_INSTANCE=1`.
- **TORCH_MKLDNN_MATMUL_MIN_DIM**: Minimum dimension size for which the MKL-DNN (oneDNN) library will be used. Default as `TORCH_MKLDNN_MATMUL_MIN_DIM=1024`.
- **PRECISION**:  Specify the precision. Default as `PRECISION=FP32`.

> **NOTE**: Different ARM version correspond different Machine type, eg:
> | CLOUD |	Machine type | Platform ARM |
> | ----- |	------------ | ------------ |
> | AWS	| Graviton2/m6g	| ARMv8 |
> | AWS	| Graviton3/m7g	| ARMv9 |
> | GCP	| c4a-standard	| ARMv9 |
> | AZURE | Dpsv6 | Cobalt 100 |

### System Requirements
See [AI Setup](../../doc/setup-ai.md) for system setup instructions.

### Docker Image
ResNet-50-ARM workload provides 1 docker image:
* `resnet-pytorch-inference`

### KPI
Run the [`list-kpi.sh`](../../doc/ctest.md#list-kpish) script to parse the KPIs from the validation logs.

### Index Info

- Name: `ResNet-50 PyTorch, ARM`
- Category: `ML/DL/AI`
- Platform: `ARMv8`, `ARMv9`
- Keywords: `CPU`