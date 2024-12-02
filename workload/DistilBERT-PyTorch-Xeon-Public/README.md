>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

This workload is targeting for **DistilBERT** benchmarking using PyTorch framework on Intel Xeon.

**DistilBERT** is a natural language processing (NLP) purpose language representation model distilled from BERT. It is around 40% smaller in size and 60% faster, retaining 97% accuracy of the original.

- **DATASET**：https://dl.fbaipublicfiles.com/glue/data/SST-2.zip
- **MODEL_WEIGHTS**: https://huggingface.co/distilbert-base-uncased-finetuned-sst-2-english
- **BENCHMARK_SCRIPT**: https://github.com/huggingface/transformers/tree/main/examples/pytorch/text-classification/run_glue.py

### Parameters
This DistilBERT workload provides test cases with the following configuration parameters:
- **TOPOLOGY** - Speicify the topology: `distilbert_base`.
- **FUNCTION** - Specify benchmarking scenario: `inference`.
- **DATA_TYPE** - Specify the input data type: `real`.
- **MODE** - Specify the running mode: `throughput`, `latency` or `accuracy`.
- **PRECISION** - Specify the model precision:`amx_bfloat16` by default, `avx_int8`, `amx_int8`, `amx_bfloat16` and `amx_bfloat32` available.
- **STEPS** - Specify the step value: `100` by default.
- **WARMUP_STEPS**: Specify the number of steps for warming purpose before entering the formal stage.
- **CASE_TYPE**: This is an optional parameter, specify `gated` or `pkm`.  Please refer to more details about [case type](../../doc/user-guide/executing-workload/testcase.md).
- **BATCH_SIZE** - Specify the number of concurrently processed inputs, `1` by default.
- **CORES_PER_INSTANCE** - Specify the number of cores used by one instance, `CORES_PER_NUMA` by default.
- **WEIGHT_SHARING** - `True` when `MODE=latency` or `False` for other modes.
- **INSTANCE_NUMBER** - Specify the number of instances, `NUMA_NODES` by default.
- **MAX_SEQ_LENGTH**: Specify the maximum length of the input sequence of the model.
- **ONEDNN_VERBOSE**: Specify if print the oneDNN information `default` as `0`.

### Test Case

The test case name is a combination of `<FUNCTION>-<MODE>-<CASE_TYPE>` (CASE_TYPE is optional). Use the following commands to list and run test cases through service framework automation pipeline:
```
cd build
cmake ..
cd workload/DistilBERT-PyTorch-Xeon-Public
./ctest.sh -N (list all designed test cases)

or
./ctest.sh -V (run all test cases)

or
./ctest.sh -R <test case key word> -V (run specific test case(s), i.e. `./ctest.sh -R gated -V` to only run gated test case)
```

### Docker Image
The DistilBERT workload provides 4 docker images:
- `distilbert-pytorch-xeon-public-dataset` - the dataset
- `distilbert-pytorch-xeon-public-model` -  the model
- `distilbert-pytorch-xeon-public-benchmark` - downloads Intel public benchmark script
- `distilbert-pytorch-xeon-public-intel-public` -  inference

#### build docker image from scratch
do cmake and make to build a specific workload
Please refer to [cmake doc](../../doc/user-guide/executing-workload/cmake.md)

To run the workload, provide the set of environment variables described in the [Parameters](#Parameters) section as follows:
```
mkdir -p logs-distilbert_pytorch_xeon_public_inference_throughput_amx_bfloat16_gated
id=$(docker run  -e http_proxy -e https_proxy -e no_proxy  --privileged -e WORKLOAD=distilbert_pytorch_xeon_public -e PLATFORM=SPR -e MODE=throughput -e TOPOLOGY=distilbert -e FUNCTION=inference -e PRECISION=amx_bfloat16 -e BATCH_SIZE=1 -e STEPS=100 -e DATA_TYPE=real -e CORES_PER_INSTANCE= -e INSTANCE_NUMBER= -e WEIGHT_SHARING=False -e TRAIN_EPOCHS= -e CASE_TYPE=pkm -e MAX_SEQ_LENGTH=128 -e ONEDNN_VERBOSE=0 -e MAX_CPU_ISA= -e CUSTOMER_ENV=ONEDNN_VERBOSE=0 -e WARMUP_STEPS=10 --rm --detach distilbert-pytorch-xeon-public-inference:latest)
docker exec $id cat /export-logs | tar xf - -C logs-distilbert_pytorch_xeon_public_inference_throughput_amx_bfloat16_gated
docker rm -f $id
```

### KPI
There are 3 main KPIs, depending on the mode:
- **throughput (samples/sec)** - when `MODE=throughput`;
- **latency (ms)** - when `MODE=latency`;
- **accuracy (%)** - when `MODE=accuracy`.

Run the [`list-kpi.sh`](../../doc/user-guide/executing-workload/ctest.md#list-kpish) script to parse the KPIs from the validation logs.

KPI output example:
```
#================================================
#Key KPI
#================================================
*Throughput (samples/sec): 317.52

inference_accuracy_amx_bfloat16(%):      91.06
inference_latency_amx_bfloat16(ms):      2.58
inference_throughput_amx_bfloat16(samples/sec):  779.36

```
Refer to [AI](../../doc/user-guide/preparing-infrastructure/setup-ai.md) for more KPI details.

### System Requirements

See [AI Setup](../../doc/user-guide/preparing-infrastructure/setup-ai.md) for more system setup instructions.

#### Minimal Resource Configuration
  * When running test cases, the minimal resource configuration is
    ```
    Memory: 2 GB * NUMBER_OF_NUMA_CORE
    ```

### Index Info
- Name: `DistilBERT, PyTorch`
- Category: `ML/DL/AI`
- Platform: `SPR`, `ICX`, `EMR`
- Keywords: `AVX`, `AMX`, `CPU`
