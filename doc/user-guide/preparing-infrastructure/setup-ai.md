### Overview
This document is a guide for using AI workload.

### AI Workload Naming
AI workload naming following this format: \<Model Name\>-\<Framework\>-[Platform][-Additions] e.g. "3DUNet-OpenVINO-MLPerf".  [Platform] will be ignored if Platform="Xeon".

- **Model Name**: Specify AI deep learning Model Name
- **Framework**: Specify Framework used: `TensorFlow`, `PyTorch` ,`OpenVINO` (Intel CPU only)  or `TensorRT`(Nvidia GPU only).
- **Platform**: Specify Platform based: ``(empty for Intel Xeon CPU), `EPYC`(AMD EPYC CPU), `ARMv8`/`ARMv9`(AWS Graviton based CPU), `Nvidia` (Nvidia GPU) or `Inferentia` (AWS inference accerlator card)
- **Additions**: Specify Additions information for workload

### AI Test Case Naming
\<WL name\>_inference_throughput_gated        
\<WL name\>_inference_throughput_pkm         
\<WL name\>_inference_latency                     
\<WL name\>_inference_accuracy                 
\<WL name\>_training_throuphput               
\<WL name\>_training_accuracy


###  Configuration:
AI workload can be run on BareMetal and Cloud VM both.  AWS, GCP and Azure cloud have been suggested to use.

Suggested cloud instance type:

#### Intel ICX:
- AWS cloud: m6i
- GCP cloud: n2-highmem-96
- Azure cloud: Dv5-series

#### AMD Milan: 
- AWS cloud: m6a
- GCP cloud: 
- Azure cloud: Dasv5 and Dadsv5-series

#### AMD Roma: 
- AWS cloud: m5a
- GCP cloud: 
- Azure cloud: Dav4 and Dasv4-series

#### AWS Graviton2: 
- AWS cloud: m6g

#### AWS Graviton3: 
- AWS cloud: c7g

#### AWS Inferentia: 
- AWS cloud: inf

#### Nivida GPU:
- AWS cloud: g4dn  (T4)


### Best Configuration:
- **For ICX platforms based AI workload**:
[Tuning Guide for Deep Learning][Tuning Guide for Deep Learning]

- **For SPR platforms based AI workload**:
[Tuning Guide for Deep Learning][Tuning Guide for Deep Learning 4th gen]


### Restriction

- N/A

### Node Labels

Setup the following node labels for AI workloads:

- HAS-SETUP-BKC-AI=yes: Optional.


### KPI output
KPI output example:
```
#================================================
#Workload Configuration
#================================================
##FRAMEWORK: PyTorch 1.13.0a0+gitd7607bd
##MODEL_NAME: DLRM
##MODEL_SIZE: 89137319
##MODEL_SOURCE: Facebook
##DATASET: Criteo 1TB Click Logs (terabyte)
##FUNCTION: inference
##MODE: throughput
##PRECISION: avx_fp32
##DATA_TYPE: real
##BATCH_SIZE: 1
##STEPS: 1
##INSTANCE_NUMBER: 2
##CORES_PER_INSTANCE: 56
#================================================
#Application Configuration
#================================================
##SCENARIO: offline
##SERVING_STACK: -
##MODEL_WORKERS: -
##REQUEST_PER_WORK: -
#================================================
#Metrics
#================================================
Average Throughput (samples/sec): 27168.18
Max Latency (ms): -1
Min Latency (ms): -1
Mean Latency (ms): 4.33
P50 Latency (ms): -1
P90 Latency (ms): -1
P95 Latency (ms): -1
P99 Latency (ms): -1
P999 Latency (ms): -1
TTT: -1
Samples: -1
Compute Utilization: -1
Memory Utilization: 89.79 GB
FLOPs: -1
Model Quality Metric Name: -1
Model Quality Value: -1
Cost Per Million Inferences: -1
#================================================
#Key KPI
#================================================
*Throughput (samples/sec): 27168.18
```

**NOTE**: Make sure gprofiler telemetry data is accurate. You need to use the `_pkm` case or set a larger `STEPS`.


[Tuning Guide for Deep Learning]: https://www.intel.com/content/www/us/en/developer/articles/guide/deep-learning-with-avx512-and-dl-boost.html
[Tuning Guide for Deep Learning 4th gen]: https://www.intel.com/content/www/us/en/developer/articles/guide/deep-learning-avx512-and-dl-boost-4th-gen-xeon.html
