>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>

### Introduction

This workload is targeting for **BERT Large** benchmarking using PyTorch on AWS Graviton.


**BERT** stands for Bidirectional Encoder Representation for Transformers. BERT represents a set of state-of-art deep learning models that can perform a wide variety of natural language processing tasks. **BERT Large** is one of the BERT models that has 24 layers, 16 attention heads, and totally 340 million parameters. This version of **BERT Large** uses PyTorch framework.

- **DATASET**：https://rajpurkar.github.io/SQuAD-explorer/dataset/dev-v1.1.json
- **MODEL_WEIGHTS**:
  * json file: https://huggingface.co/google-bert/bert-large-uncased-whole-word-masking-finetuned-squad/resolve/b77a1101fca72fb51279d8aba154bddd61bff81c/config.json
  * bin file: https://huggingface.co/google-bert/bert-large-uncased-whole-word-masking/resolve/e0c83dfe42deb7fa17ed39b35aaf1948fb5417c8/pytorch_model.bin
  * txt file: https://huggingface.co/google-bert/bert-large-uncased/resolve/2f07d813ca87c8c709147704c87210359ccf2309/vocab.txt
- **BENCHMARK_SCRIPT**: https://github.com/huggingface/transformers/blob/v4.38.1/examples/legacy/question-answering/run_squad.py

### Test Case
They are built-in test cases for `ctest`. The test case name is a combination of `<WORKLOAD_NAME>-<MODE>-<FUNCTION>`.

Use the following commands to show the list of test cases:  
```
cd build
cmake ..
cd workload/BERTLarge-PyTorch-ARM
./ctest.sh -N

or 
./ctest.sh -V 
(run all test cases)

or
./ctest.sh -R <test case key word> -V 

Test cases:
test_aws_bertlarge_pytorch_arm_throughput_pkm

The BERTLarge-PyTorch-ARM workload provides test cases with the following configuration parameters:
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

### System Requirements
See [AI Setup](../../doc/setup-ai.md) for system setup instructions.

### Docker Image
BERTLarge-PyTorch-ARM workload provides following docker image:
* `bertlarge-pytorch-arm-public`

### KPI
Run the [`list-kpi.sh`](../../doc/ctest.md#list-kpish) script to parse the KPIs from the validation logs. 

### Contact
- Stage1 Contact: `Ramkumar Mishra, Dipali`
- Stage2 Contact: `Viswanathan, Kasi A`

### Index Info

- Name: `BERTLarge PyTorch, ARM`
- Category: `ML/DL/AI`
- Platform: `ARMv8`, `ARMv9`
- Keywords: `CPU`

 
