>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

This workload is targeting for Diffusion models benchmarking using Pytorch framework on Intel® Xeon® processors.

Diffusion models are inspired by non-equilibrium thermodynamics. They define a Markov chain of diffusion steps to slowly add random noise to data and then learn to reverse the diffusion process to construct desired data samples from the noise. Unlike VAE or flow models, diffusion models are learned with a fixed procedure and the latent variable has high dimensionality (same as the original data).

This workload is enabled with AI decouple solution.

The workload supports model (which is also the parameter `MODEL_NAME` in this Workload):
1.  stabilityai/stable-diffusion-2-1

Below is an execution example of terraform static test:

- Create a build dir
```
cd <WSF REPO>
mkdir -p build
```
cd build
cmake -DBACKEND=terraform -DTERRAFORM_OPTIONS="--docker --svrinfo --owner=<your id> --intel_publish" -DTERRAFORM_SUT=static -DBENCHMARK=StableDiffusion-PyTorch-Xeon-Public ..
```

- Build the workload
```
cd <WSF REPO>/build/workload/StableDiffusion-PyTorch-Xeon-Public
make
```

- [CTEST](../../doc/user-guide/executing-workload/ctest.md)
  - Show all the test cases. There are 3 diffent modes can be choosen, including `latency`, `throughput` and `accuracy`, and 2 [case types](../../doc/user-guide/executing-workload/testcase.md), including `gated` and `pkm`.
    ```
    ./ctest.sh -N
    ```
  - Run specific test case(s) which shows in `./ctest.sh -N`. For example, `./ctest.sh -R pkm -V` is to run PKM test cases. This will use default parameters.
    ```
    ./ctest.sh -R <test case key word> -V
    ```
  - Run specific test case(s) with specified parameters which mentioned in section [Parameters](#parameters). For example, `./ctest.sh -R pkm --set "PRECISION=bfloat16/NUMA_NODE_USE=all" -V` is to run PKM test case with `PRECISION=bfloat16` and `NUMA_NODE_USE=2`.
    ```
    ./ctest.sh -R <test case key word> --set <specified parameters> -V
    ```

### Parameters

- **PRECISION**: Specify the model precision, the supported precisions are `bfloat16` (default) or `float16` or `bfloat32` or `float16`.
- **NUMA_NODE_USE**: Specify the which numa node you want to use (`0`, `1` and `all`), default as `0`.
- **WARMUP_STEPS**: Specify the warmup step value, the default value is `5`.
- **STEPS**: Specify the step value, the default value is `10`.
- **MODEL_NAME**: Specify the model name:
  - `stabilityai/stable-diffusion-2-1`
- **MODEL_PATH**: Specify the root path which stores the pre-downloaded model files. Please use the huggingface model cache as the value of this parameter, e.g. `/root/.cache/huggingface`. We highly recommand to use WSF's big image solution (pls refer to the steps in section
- **USE_JEMALLOC**: Specify whether use jemalloc to optimize. Default as `True`.
- **USE_TCMALLOC**: Specify whether use jemalloc to optimize. Default as `False`.
- **ONEDNN_VERBOSE**: Specify if print the oneDNN information. `1` means on, `0` means off. The default value is `0`.
- **TORCH_TYPE**: Specify the torch optimization method, you can choose of of `EAGER`, `IPEX-JIT`, `COMPILE-IPEX`, `COMPILE-INDUCTOR`, `COMPILE-OPENVINO`.


You can also run the workload using `docker run` directly, providing the set of environment variables described in the [Parameters](#parameters) section as follows:
```
mkdir -p logs-stablediffusion_pytorch__xeon_public_inference_latency
id=$(docker run -e http_proxy -e https_proxy -e no_proxy --privileged -e MODE=latency -e WORKLOAD=stablediffusion_pytorch_xeon_public -e TOPOLOGY= -e PRECISION=bfloat16 -e FUNCTION=inference -e DATA_TYPE= -e BATCH_SIZE=1 -e CORES_PER_INSTANCE=-1 -e NUMA_NODES_USE=0 -e ONEDNN_VERBOSE=0 -e WARMUP_STEPS=5 -e STEPS=10 -e USE_JEMALLOC=True -e USE_TCMALLOC=False -e MODEL_NAME=stabilityai/stable-diffusion-2-1 -e MODEL_PATH=/opt/dataset/stable-diffusion-2-1/hub -e TORCH_TYPE=COMPILE-IPEX -v /opt/dataset/stable-diffusion-2-1/hub:/root/.cache/huggingface/hub --rm --detach stablediffusion-pytorch-xeon-public-sd:latest)
docker exec $id cat /export-logs | tar xf - -C logs-stablediffusion_pytorch_xeon_public_inference_latency
docker rm -f $id
```


### Index Info
- Name: `StableDiffusion, PyTorch, Public`
- Category: `ML/DL/AI`
- Platform: `SPR`, `EMR`, `GNR`
- Keywords: `StableDiffusion`, `BIGIMAGE`, `CPU`

