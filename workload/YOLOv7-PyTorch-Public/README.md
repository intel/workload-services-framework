>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

This workload is targeting for YOLOv7 benchmarking using Pytorch framework on Intel® Xeon® processors.

The YOLO version 7 algorithm surpasses previous object detection models and YOLO versions in both speed and accuracy. It requires several times cheaper hardware than other neural networks and can be trained much faster on small datasets without any pre-trained weights.
Read more at: https://viso.ai/deep-learning/yolov7-guide/

- **MODEL_WEIGHTS**: https://github.com/WongKinYiu/yolov7/releases/download/v0.1/yolov7.pt
- **BENCHMARK_SCRIPT**: https://github.com/WongKinYiu/yolov7/blob/main/test.py

The building method is mentioned in [Workload Execution](#workload-execution) section.

### Workload Execution

To execute a workload, you can refer to the [executing-workload](../../doc/user-guide/executing-workload) for details including `cmake`, `ctest`, `terraform-options` and `testcase`.

In the very beginning, please follow the [terraform setup guide](../../doc/user-guide/preparing-infrastructure/setup-terraform.md) to setup terraform environment first.

Below is an execution example of terraform static test:

- Create a build dir
```
cd <WSF REPO>
mkdir -p build
```

- [CMAKE](../../doc/user-guide/executing-workload/cmake.md)
```
cd build
cmake -DBACKEND=terraform -DTERRAFORM_OPTIONS="--docker --svrinfo --owner=<your id> --intel_publish" -DTERRAFORM_SUT=static -DBENCHMARK= ..
```

- Build the workload
```
cd <WSF REPO>/build/workload/YOLOv7-PyTorch-Public
make
```
- [CTEST](../../doc/user-guide/executing-workload/ctest.md)
  - Show all the test cases. There are 3 diffent modes can be choosen, including `latency`and `throughput`, and 2 [case types](../../doc/user-guide/executing-workload/testcase.md), including `gated` and `pkm`.
    ```
    ./ctest.sh -N
    ```
  - Run specific test case(s) which shows in `./ctest.sh -N`. For example, `./ctest.sh -R pkm -V` is to run PKM test cases. This will use default parameters.
    ```
    ./ctest.sh -R <test case key word> -V
    ```
  - Run specific test case(s) with specified parameters which mentioned in section [Parameters](#parameters). For example, `./ctest.sh -R pkm --set "PRECISION=bfloat16/CORES_PER_INSTANCE=4" -V` is to run PKM test case with `PRECISION=bfloat16` and `CORES_PER_INSTANCE=4`.
    ```
    ./ctest.sh -R <test case key word> --set <specified parameters> -V
    ```

### Parameters

- **PRECISION**: Specify the model precision.
  - CPU: the supported precisions are `float32` or `bfloat16`(default).
- **CORES_PER_INSTANCE**: Specify the how many cores needed for one instance, the default value is the cores per numa node.
- **WARMUP_STEPS**: Specify the warmup step.
  - CPU: the default value is `5`..
- **STEPS**: Specify the steps.
  - CPU: the default value is `20`.
- **ONEDNN_VERBOSE**: This parameter is only worked when `HARDWARE=cpu`, Specify if print the oneDNN information. you can choose `1` or `0`. `1` means on, `0` means off. The default value is `0`.
- **TORCH_TYPE**: This parameter is only worked when `HARDWARE=cpu`, Specify the torch optimization method, you can choose of of `EAGER`, `COMPILE-IPEX`(default) or `COMPILE-INDUCTOR`.

### Docker Image

This workload provides following docker image:
- `yolov7-pytorch-public` for xeon inference benchmarking.

#### build docker image from scrach
do cmake and make to build a specific workload
Please refer to [cmake doc](../../doc/user-guide/executing-workload/cmake.md).

### KPI

Run the [`list-kpi.sh`](../../doc/user-guide/executing-workload/ctest.md#list-kpish) script to parse the KPIs from the validation logs. 

For example:
```
./list-kpi.sh --all logs-yolov7_pytorch_public_inference_throughput
```

Please refer to [AI](../../doc/user-guide/preparing-infrastructure/setup-ai.md) for more KPI details.

### System Requirements

See [AI Setup](../../doc/user-guide/preparing-infrastructure/setup-ai.md) for system setup instructions.

### Index Info
- Name: `YOLOv7-PyTorch-Public`
- Category: `ML/DL/AI`
- Platform: `SPR`, `EMR`
- Keywords: `YOLO`, `CPU`

### See Also
- [ YOLOv7: Trainable bag-of-freebies sets new state-of-the-art for real-time object detectors](https://arxiv.org/abs/2207.02696)
