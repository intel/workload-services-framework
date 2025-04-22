>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
Introduction
This workload is targeting for Large Language Models (LLMs) benchmarking using Intel® Extension for PyTorch (IPEX) solution on Intel® Xeon® processors.

In the very beginning, please follow the terraform setup guide to setup terraform environment first.

Below is an execution example terraform static test:

Create a build dir
cd <WSF REPO>
mkdir -p build
CMAKE
cd build
cmake -DBACKEND=terraform -DTERRAFORM_OPTIONS="--docker --svrinfo --owner=<your id> --intel_publish" -DTERRAFORM_SUT=static -DBENCHMARK= ..
Note: Input your huggingface token at ../../script/csp/.ai when you try to execute Llama2, gptj. 
Example:

mkdir -p <WSF REPO>/script/csp/.ai/
cd <WSF REPO>/script/csp/.ai
echo "{ \"hf_token\": \"$(read -p token: token;echo $token)\" }" > config.json
Build the workload
cd <WSF REPO>/build/workload/LLMs-IPEX-Public
make
CTEST
Show all the test cases. There are 3 diffent modes can be choosen, including latency, throughput, accuracy, and 2 case types, including gated and pkm.
./ctest.sh -N
Run specific test case(s) which shows in ./ctest.sh -N. For example, ./ctest.sh -R pkm -V is to run PKM test cases. This will use default parameters.
./ctest.sh -R <test case key word> -V
Run specific test case(s) with specified parameters which mentioned in section Parameters. For example, ./ctest.sh -R pkm --set "PRECISION=woq_int8/USE_DEEPSPEED=True" -V is to run PKM test case with PRECISION=woq_int8 and USE_DEEPSPEED=True.
./ctest.sh -R <test case key word> --set <specified parameters> -V
Parameters
PRECISION: Specify the model precision, the supported precisions are bfloat16 (default) or woq_int8 (Weight only quantzation INT8) or woq_int4 (Weight only quantzation INT4) or static_int8 (Static quantzation INT8).
BATCH_SIZE: Specify the size of batch, the default value is 1.
STEPS: Specify the step value, the default value is 20.
INPUT_TOKENS: Specify the number of input_tokens, the default value is 1024.
OUTPUT_TOKENS: Specify the number of output_tokens, the default value is 128.
MODEL_NAME: Specify the model name, the default model is meta-llama/Llama-2-7b-chat-hf or you can choose the models as following:
meta-llama/Llama-2-7b-chat-hf
meta-llama/Llama-2-13b-chat-hf
EleutherAI/gpt-j-6b

Note:

Precision woq_int4 does not support for chatglm2, chatglm3, flan-t5, baichuan-13b, baichuan2-7b, baichuan2-13b, mpt-30b.
Precision woq_int8 does not support for mpt-30b.
Precision static_int8 does not support for mistral-7b, mpt-30b, Qwen-7B, Qwen-14B.
MODEL_PATH: Specify the root path which stores the pre-downloaded model files. Please use the huggingface model cache as the value of this parameter, e.g. /root/.cache/huggingface/hub. We highly recommand to use WSF's big image solution (pls refer to the steps in section Workload Execution). The default path is: /opt/dataset/chatglm2/6b.
USE_DEEPSPEED: Specify whether using deepspeed. You can choose True or False. The default value is False.
Note:

Only precisions bfloat16 and woq_int8 support DeepSpeed.
THUDM/chatglm2-6b and THUDM/chatglm3-6b do not support DeepSpeed.
meta-llama/Llama-2-7b-chat-hf and meta-llama/Llama-2-13b-chat-hf do not support accuracy+DeepSpeed.
CORES_PER_INSTANCE: Specify how many cores will be used for single instance. The default value is number of cores per numa node. (This parameter only works when USE_DEEPSPEED=False)
GREEDY: Specify whether to use greedy search.
False: beam number is 4.
True: beam number is 1.
ONEDNN_VERBOSE: Specify if print the oneDNN information. 1 means on, 0 means off. The default value is 0.
RANK_USE: Specify the socket you want to use for DeepSpeed:
0: Use numa nodes on 1st socket
1: Use numa nodes on 2nd socket
all: Use all numa nodes in system.
BENCHMARKING_TRACE: Specify when to stat/stop traces (emon, sar, vtune, ...). Default is True:
True: Collect traces during benchmarking time.
False: Collect traces during whole workload process, including preconditonal check, model loading, warmup and benchmarking.
CSP VM image preparasion for large dataset and model
See AI Setup for coresponding part

BM preparasion for large dataset and model
See AI Setup for coresponding part

Docker Image
The LLMs-IPEX-Public workload provides 2 docker images: llms-ipex-public-base and llms-ipex-public-inference-lite

build docker image from scrach
do cmake and make to build a specific workload Please refer to cmake doc You can also run the workload using docker run directly, providing the set of environment variables described in the Parameters section as follows:

mkdir -p logs-llms-ipex-public_inference_latency
id=$(docker run --network host --privileged -e MODE=latency -e WORKLOAD=llms_ipex_public -e PRECISION=bfloat16 -e NUMA_NODES_USE=0 -e FUNCTION=inference -e DATA_TYPE=real -e BATCH_SIZE=1 -e INPUT_TOKENS=32 -e OUTPUT_TOKENS=32 -e STEPS=20 -e GREEDY=False -e WARMUP_STEPS=2 -e MODEL_NAME=THUDM/chatglm2-6b -e MODEL_PATH=/opt/dataset/chatglm2/6b -e USE_DEEPSPEED=False -e ONEDNN_VERBOSE=0 -e TARGET_PLATFORM=SPR -e RANK_USE=all -e CORES_PER_INSTANCE= -v /opt/dataset/chatglm2/6b:/root/.cache/huggingface/hub --rm --detach llms-ipex-public-inference-lite:latest)
docker exec $id cat /export-logs | tar xf - -C logs-llms-ipex-public_inference_latency
docker rm -f $id
KPI
Run the list-kpi.sh script to parse the KPIs from the validation logs.

For example:

./list-kpi.sh --all logs-llms-ipex-public_inference_latency
Please refer to AI for more KPI details.


Furthermore, in order to reduce the workload docker image size and save cloud execution time, Big image solution is implemented on this Workload.

This dataset name is build_dataset_ai_llama2-7b. The dataset will be located at /opt/dataset/llama2/7b, it will occupy 28G disk space.
This dataset name is build_dataset_ai_llama2-13b. The dataset will be located at /opt/dataset/llama2/13b, it will occupy 50G disk space.
This dataset name is build_dataset_ai_gptj-6b. The dataset will be located at /opt/dataset/gptj/6b, it will occupy 38G disk space.


Index Info
Name: LLMs, IPEX, Pytorch
Category: ML/DL/AI
Platform: SPR, EMR, GNR
Keywords: LLMs, BIGIMAGE, CPU
