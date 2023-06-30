>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction


Malconv is short for Malware detection in executables using Convolutional neural networks. It is applied in Network AI security to block out malware efficiently & accurately.

The current generation of anti-virus and malware detection products typically use a signature-based approach, where a set of manually crafted rules attempt to identify different groups of known malware types. These rules are generally specific and brittle, and usually unable to recognize new malware even if it uses the same functionality. 
This approach is insufficient because most environments have unique binaries that will have never been seen before and millions of new malware samples are found every day.

Malconv is a convolutional neural network trained to differentiate between benign and malicious executable files with only the raw byte sequence of the executable as input. This approach has several practical advantages:
- No hand-crafted features or knowledge of the compiler used are required. This means the trained model is generalizable and robust to natural variations in malware.
- The computational complexity is linearly dependent on the sequence length (binary size), which means inference is fast and scalable to very large files.
- Important sub-regions of the binary can be identified for forensic analysis.
- This approach is also adaptable to new file formats, compilers and instruction set architectures—all we need is training data.


Malconv is first open sourced by Endgame company in the repo elastic/ember (https://github.com/elastic/ember). The open sourced Malconv model is referred to as 'Ember Malconv' hereafter. We tuned the embedding & convolution parameters to accelerate its inference on Intel oneDNN. The tuned hyper-parameters are: input size=1 MB, embedding=4, filters=32 & kernel=2500 & stride=600 (for both conv layers). The other hyper-parameters are the same with Ember Malconv. With the tuned hyper-parameters, the inference speed can be greatly improved on SPR platform. There is very limited impact on the AUC with the tuned hyper-parameters. Because of training dataset license issue, we cannot release the tuned model file for benchmarking but recommend the tuned hyper-parameters if your application is highly latency sensitive.  

### Test Case
The test cases are based on a fake random dataset of 2000 malicious and 2000 benign binary files for testing. Because of dataset license issue, we cannot release a real dataset for the test. 
The gated tests use only 200 files for rapid validation. The other test cases use all 4000 files. 
The Malconv workload provides test cases with the following configuration parameters:
- **FRAMEWORK**: Specify the running backend: `tf` or `onnx`.
  * `tf`: use tensorflow as the backend for running malconv
  * `onnx`: use onnx as the backend for running malconv
- **PRECISION**: Specify the model precision:`fp32` or `bf16` or `int8`
  * `fp32`: Floating point format converted from h5 model using Intel neural compressor
  * `bf16`: 16-bit floating point data type converted from fp32 using Intel neural compressor
  * `int8`: 8-bit integer data type converted from fp32 using Intel neural compressor
- **ISA**: Specify the ISA: `avx` or `amx`.
  * `avx`: AVX512_CORE for h5 format, AVX512_CORE_BF16 for bf16 format, AVX512_CORE_VNNI for others.  
  * `amx`: AVX512_CORE_AMX for int8 and bf16 format.
- **MODE**: Specify the test mode:`single` or `multi`
  * `single`: start 1 instance on a single core, all other cores stay idle
- **CORES**: Specify the number of cores per each instance:`1`
  * `1`: 1 core per each instance
- **TAG**
  * `gated`: a quick test of all KPIs with a single iteration. 
  * `pkm`: the common use case of Malconv. 

Use the following commands to show the list of test cases:
```
cd build
cmake -DPLATFORM=SPR -DREGISTRY= ..
cd workload/Malconv
ctest -N
```

### Docker Image

The workload contains a single docker image: `malconv`. Configure the docker image with the environment variable `CONFIG`: `pass` for the workload to return successfully and `fail` for the workload to return a failure status.  

```
mkdir -p logs-malconv
id=$(docker run --detach --rm --privileged --model intel --framework tf --precision int8 --tag pkm malconv:latest)
docker exec $id cat /export-logs | tar xf - -C logs-malconv
docker rm -f $id
```

### KPI

Run the [`kpi.sh`](kpi.sh) script to generate the KPIs. The KPI script uses the following command line options:  

```
cd build
cmake -DPLATFORM=SPR -DREGISTRY= -DBACKEND=docker ..
cd workload/Malconv
ctest -kpi_malconv_intel_tf_int8_amx_pkm
```

The following KPI are generated:

- **`inference time`: Time spent for each suspicious  file. Unit: ms
- **`throughput`: number of files processed each second. calculation: 1000\*number_of_instance/inference_time. Unit: file per second
- **`AUC`: Area Under Curve Receiver Operator Characteristic, which measures how well a model is able to distinguish between classes
As the testing set is random data, the AUC yield does not represent the accuracy of this model. Nevertheless, the average inference time (latency) is enough to show the speed of inference.  


### Performance BKM

The recommended system setup on ICX platform
- CPU: Intel(R) Xeon(R) Platinum 8380 CPU
- Memory: 512GB (16x32GB DDR4 3200 MT/s [3200 MT/s])
- Disk: >= 512 GB
- Host OS: CentOS Stream8
- Kernel version: 5.11.0-27-generic
- Governor: performance
- Autonomous core C-state: Enabled
- CPU C6 report: Enabled
- Enhanced Halt State(C1E): Enabled
- Hyperthreading: Disabled
- Turbo Boost: Enabled

The recommended system setup on SPR platform
- CPU: Intel(R) Xeon(R) Platinum 8481C(Fox Creek Pass)
- Memory: 512GB (16x32GB DDR5 4800 MT/s [4800 MT/s])
- Disk: >= 512 GB
- Host OS: CentOS 8
- Kernel version: 5.15.0-spr.bkc.pc.2.10.0.x86_64 or later
- Governor: performance
- CPU C1 auto demotion: Enabled
- CPU C1 auto undemotion: Enabled
- CPU C6 report: Enabled
- Enhanced Halt State (C1E): Enabled
- Hyperthreading: Disabled
- Turbo Boost: Enabled


### Index Info

- Name: `Malconv`
- Category: `ML/DL/AI`
- Platform: `SPR`, `ICX`
- Keywords: `Malware_detection`, `CNN`
- Permission: 

### Setup Workload with RA
- If you use the Reference Architecture to set up your system, use the basic profile for best performance.

### See Also

- [Malconv: Malware Detection by Eating a Whole EXE](https://arxiv.org/pdf/1710.09435.pdf)
- [Malconv open sourced model](https://github.com/elastic/ember)
