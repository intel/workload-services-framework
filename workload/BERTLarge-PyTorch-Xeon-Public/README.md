>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

This workload is targeting for **BERT Large** benchmarking using PyTorch framework on Intel Xeon.

**BERT** stands for Bidirectional Encoder Representation for Transformers. BERT represents a set of state-of-art deep learning models that can perform a wide variety of natural language processing tasks. **BERT Large** is one of the BERT models that has 24 layers, 16 attention heads, and totally 340 million parameters. This version of **BERT Large** uses PyTorch framework.

- **DATASET**：https://rajpurkar.github.io/SQuAD-explorer/dataset/dev-v1.1.json
- **MODEL_WEIGHTS**:
  * json file: https://s3.amazonaws.com/models.huggingface.co/bert/bert-large-uncased-whole-word-masking-finetuned-squad-config.json
  * bin file: https://cdn.huggingface.co/bert-large-uncased-whole-word-masking-finetuned-squad-pytorch_model.bin
  * txt file: https://s3.amazonaws.com/models.huggingface.co/bert/bert-large-uncased-whole-word-masking-finetuned-squad-vocab.txt
- **BENCHMARK_SCRIPT**: https://github.com/huggingface/transformers/blob/v4.18.0/examples/legacy/question-answering/run_squad.py

### Parameters

The BERT Large workload provides test cases with the following configuration parameters:
- **MODE**: Specify the running mode: `latency`, `throughput` or `accuracy`.  
  * `latency`: For performance measurement only. 4 cores per test instance, KPI counts on all test instances result together. Only valid of `inference`.
  * `throughput`: For performance measurement only. 1 socket per test instance, KPI counts on all test instances result together.
  * `accuracy`: For accuracy measurement only. Only valid for `inference`.
```bash
  Note: The KPI depends on the CPU SKU,core count,cache size and memory capacity/performance, etc.
```
- **PRECISION**: Specify the model precision: `avx_fp32`, `amx_int8`, `amx_bfloat16` or `amx_bfloat32`. Default one is `avx_fp32`.(Note: `amx` precisions are not supported when `PLATFORM=ICX`, `avx_int8` precision is temporarily not supported due to known issues.) 
- **FUNCTION**: Specify whether the workload should run: `inference`, `training`(not support).
- **DATA_TYPE**: Specify the input/output data type: `real`. 
- **CASE_TYPE**: This is an optional parameter, specify `gated` or `pkm`.  Please refer to more details about [case type](../../doc/user-guide/executing-workload/testcase.md).
- **BATCH_SIZE**: Specify the batch size value: default as `BATCH_SIZE=1`.
- **WARMUP_STEPS**: Specify the number of steps for warming purpose before entering the formal stage.
- **STEPS**: Specify the inference steps value: default as `STEPS=30` for inference, `STEPS=51` for training. This parameter is **neither** tunable for **training** nor **accuracy** cases. (Note: make sure the `STEPS` large enough when the `BATCH_SIZE` is small, or may meet `division by zero` error.)
- **CORES_PER_INSTANCE**: Define the number of cores in one instance, decreasing it may cause higher memory consumption. Default as `cores per numa node`.
- **INSTANCE_NUMBER**: Define the number of instances. This value is calculated using `total cores/CORES_PER_INSTANCE` so far, and default as `number of numa nodes`.
- **WEIGHT_SHARING**: dafault value set to `False`. This parameter is case sensitive, possible values are: `True`, `False`.
- **MAX_SEQ_LENGTH**: Specify the maximum length of the input sequence of the model.
- **ONEDNN_VERBOSE**: Specify if print the oneDNN information `default` as `0`.
- **DISTRIBUTED**: **Only** available for training, to specify if enable TorchCCL to do distributed training on one or multiple nodes. *(nodes info should be specified in `hostfile`)* (Default to `False`)
- **CCL_WORKER_COUNT**: **Only** available for **distributed** training, to specify the number of logical cores used for each training process to communicate with others. Increasing it may cause higher memory consumption (Default to `4`)
- **NNODES**: Currently **Only** available for **distributed** training, to specify the number of nodes (machines) used for distributed training. (Default to `1`, must be less or equal to the number of available computing nodes in the kubernetes cluster) *Only support `BACKEND=kubernetes` or `BACKEND=terraform` w/kubernetes as the backend engine*

### Test Case

They are built-in test cases for `ctest`. The test case name is a combination of `<WORKLOAD_NAME>-<MODE>-<FUNCTION>-<DATA_TYPE>`. Not all combinations are supported.

> Additionally, the test cases with suffix `_gated` represents running the workload with reduced steps: `STEPS=10`.  

Use the following commands to show the list of test cases:  
```bash
cd build
cmake ..
cd workload/BERTLarge-PyTorch-Xeon-Public
./ctest.sh -N

or 
./ctest.sh -V 
(run all test cases)

or
./ctest.sh -R <test case key word> -V 
(run specific test case(s), i.e. `./ctest.sh -R pkm -V` to run PKM test cases. This will use default parameter to run cases, such as BATCH_SIZE=1, STEPS=10, PRECISION=avx_fp32)

Test cases:
  Test #1: test_bertlarge-pytorch-xeon-public_inference_throughput_amx_bfloat16
  Test #2: test_bertlarge-pytorch-xeon-public_inference_latency_amx_bfloat16
  Test #3: test_bertlarge-pytorch-xeon-public_inference_accuracy_amx_bfloat16
  Test #4: test_bertlarge-pytorch-xeon-public_inference_throughput_amx_bfloat16_gated
  Test #5: test_bertlarge-pytorch-xeon-public_inference_throughput_amx_bfloat16_pkm
```

### Docker Image

The BERT Large workload provides 4 docker images for exeternal release: 
- `bertlarge-pytorch-xeon-public-inference-24.02`.
- `bertlarge-pytorch-xeon-public-benchmark-24.04`.
- `bertlarge-pytorch-xeon-public-model-24.04`. 
- `bertlarge-pytorch-xeon-public-inference-dataset-24.04`.

#### build docker image from scrach

# Cmake Configuration

This will help to generate native build tool that uses platform independent configuration 
files to generate native build tool files. You can execute inside `build` directory.

## Build examples

```shell
cd build
cmake -DREGISTRY=xxyyzz.com:1234 ..
```

## Customize the Build Process

You can use the following build options to customize the build process:

- **PLATFORM**: Specify the platform names.
- **REGISTRY**: Must end with forward slash (`/`). Specify the privacy docker registry URL. If specified, all built images will be pushed to given docker registry.
- **REGISTRY_AUTH**: Specify the registry authentication method. The only supported value is `docker`, which uses the docker configuration file.
- **RELEASE**: Must begin with colon (`:`). Specify the release version. All built images will be tagged with it. Defaults to `:latest`
- **BACKEND**: Specify the validation backend: docker, kubernetes or terraform.
  - **TERRAFORM_OPTIONS**: Specify the `terraform` options.
  - **TERRAFORM_SUT**: Specify the target System Under Test (SUT) list.
- **TIMEOUT**: Specify the validation timeout, which contains the execution timeout and docker pull timeout. Default to 28800,300 seconds.
- **BENCHMARK**: Specify a workload pattern. Workloads not matching the pattern will be disabled. The workload pattern is in the format of `<workload-path>/<workload-sub-target>`, where `<workload-path>` is the workload path relative to the project root, and `<workload-sub-target>` is any sub-component defined in the workload. For example, some workload defines multiple versions thus have multiple builds and testcase targets.  
- **SPOT_INSTANCE**: If specified, overwrite the `spot_instance` variable in the Cloud configuration files.

```shell
cmake -DPLATFORM=xyz -DREGISTRY=xxyyzz.com:1234 -DBACKEND=xxyzz ..
```

```shell
cmake -DBENCHMARK=workload/SpecCpu-2017 ..  # all build targets of SpecCpu-2017
cmake -DBENCHMARK=workload/SpecCpu-2017/speccpu_2017_v119_gcc13_ubuntu24 .. # specific build target of SpecCpu-2017
```

## Command Make Targets

- **bom**: Print out the BOM list of each workload.
- **clean**: Purge the `logs`.

```shell
cd build
cmake ..
make bom
```

To run the workload, provide the set of environment variables described in the [Test Case](#Test-Case) section as follows:
```bash
mkdir -p logs_bertlarge-pytorch-xeon-public_training_throughput_amx_bfloat16
id=$(docker run --detach --rm --privileged -e TOPOLOGY=bert_large -e MODE=throughput -e PRECISION=amx_bfloat16 -e FUNCTION=inference -e DATA_TYPE=real -e BATCH_SIZE=16 -e STEPS=330 bertlarge-pytorch-xeon-public-inference)
docker exec $id cat /export-logs | tar xf - -C logs_bertlarge-pytorch-xeon-public_training_throughput_amx_bfloat16
docker rm -f $id
```

### System Requirements

See [AI Setup](../../doc/user-guide/preparing-infrastructure/setup-ai.md) for system setup instructions.

### Minimal Requirment

The minimum memory for this workload is `12 GB per instance (>=1)`

### KPI

Run the [`list-kpi.sh`](../../doc/user-guide/collecting-results/list-kpi.md) script to parse the KPIs from the validation logs. 

KPI output example:
```bash
#================================================
#Key KPI
#================================================
*Throughput (samples/sec): 186.18

accuracy_amx_bfloat16(%): 87.01040681
throughput_amx_bfloat16(samples/sec): 77.556
latency_amx_bfloat16(ms): 26.1804

```
Refer to [AI](../../doc/user-guide/preparing-infrastructure/setup-ai.md) for more KPI details.


### Index Info
- Name: `Bert Large, PyTorch`  
- Category: `ML/DL/AI`  
- Platform: `SPR`, `ICX`, `EMR`
- Keywords: `AMX`, `TMUL`, `CPU`
