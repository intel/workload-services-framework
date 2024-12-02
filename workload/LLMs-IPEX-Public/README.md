>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
Getting started with AI workloads in WSF
This document is a guide for using AI workloads in WSF. It includes following contents:

AI Decoupling solution for the big image issue
Reason of introducing Decoupling solution into AI workloads
There are several reasons that AI workloads need more storge now:

The size of AI models is increasing: AI models are becoming increasingly complex, and this is increasing the amount of data that is required to train them. For example, the GPT-3 language model has 175 billion parameters, which requires a significant amount of storage space.
The amount of data that is being used for AI is increasing: AI models are being used to process more and more data, such as images, videos, and text. This is increasing the demand for storage space to store the data that is being used to train and deploy AI models.
It may spend much time to pull an AI WL image from docker registry if we put model file and dataset in one docker image. In some situation, e.g. slow network connection, it makes run AI workload using WSF impossible (always timeout when pulling AI workload docker image from docker registry) .

Decoupling solution for AI big images
Based on the issue of big images of AI workload, we introduce a Decoupling solution for that. Main idea is to decouple dataset (include both model file and dataset) contents and benchmark contents into different docker image and dataset image should be prepared before case execution. When dataset image preparing on SUT for one time, no need to pull the same model file and dataset again and again when execution the test case. currently, for the workload which image size is higher than 50G, we will use Decoupling solution for this AI workload. You can check which AI workload is using Decoupling solution from this table

The image preparation should be done on the dev machine, with terraform-config.static.tf points to the SUT (worker-0). According to the SUT type, if you use bare metal machine, please refer BM preparation for large dataset and models, and if you use public cloud VM machine, please refer CSP VM image preparation for large dataset and model

BM preparation for large dataset and model
Run cmake cmdline
cmake -DREGISTRY=xx.xx.xx.xx:20666 -DBACKEND=terraform -DTERRAFORM_OPTIONS="--owner=xxx" -DTERRAFORM_SUT=static -DBENCHMARK=image/dataset-ai ..
Note: -DBACKEND option MUST be terraform because there are part of auto-provisioning to check dataset readiness and add Label in terraform.

Build Dataset images Build image to prepare your dataset/model to BM. Please get dataset name for each workload from workload Readme and replace below XXX.
make build_dataset_ai_XXX
Note: You can check the progress of downloading dataset as shown below: image

Then build AI workload which used dataset/model above
cmake -DBENCHMARK=workload/<workload name> ..
cd workload/<workload name>
make
CSP VM image preparation for large dataset and model
Run cmake
cmake -DREGISTRY=xx.xx.xx.xx:20666 -DBACKEND=terraform -DTERRAFORM_OPTIONS="--owner=xxx" -DTERRAFORM_SUT=aws/gcp/alicloud/azure -DBENCHMARK=image/dataset-ai ..
Note: -DBACKEND option MUST be terraform because there are part of auto-provisioning to check dataset readiness and add Label in terraform.

Build Dataset images if there are no dataset in the CSP region Build image to prepare your dataset/model on csp. Please get dataset name for each workload from workload Readme and replace below XXX.
make build_dataset_ai_XXX
Note: You can check the progress of downloading dataset as shown below: image Please skip Step 2 if you want to run AI on below CSP zones. AI big imagess dataset are ready on them:

aws: us-west-2a
gcp: us-west1-a
alicloud: cn-beijing-a/cn-shanghai-m
azure: eastus-1
NOTE: The dataset images are CSP region specific. Users must prepare the dataset image for each new CSP region.

Clean up the dataset image when you don't use that anymore
make aws/gcp/alicloud/azure
cleanup --images
ERROR if dataset image is not ready
If you dataset image is not ready in your environment and you directly run the test case, you will get the error information in the log:

Dataset not available at /opt/dataset/**. This workload is enabling big image solution. Please prepare dataset first according to README.
Then you should follow BM preparation for large dataset and models or CSP VM image preparation for large dataset and model to prepare dataset image firstly.

AI Workload on Gaudi2
There are several OOB workloads are supported on Gaudi2 (on develop branch) which can be referred to README.md for detail information.

Steps below shows how to run workload on Gaudi2 IDC:

Once you got a Gaudi2 IDC, please follow the instruction SUT Connection via Jumpbox and Socks5 Proxy to setup a port mapping relationship between your dev system and Gaudi2 IDC.
The mapping relationship should be like:

<your dev ip>:12100 -> <guadi2 user>:<gaudi2 ip>:22
Modify the terraform config:
...
        "user_name": "<gaudi2 user>",
        "public_ip": "<your dev ip>",
        "private_ip": "<your dev ip>",
        "ssh_port": 12100,
...
Prepare environment:
./script/setup/setup-dev.sh
./script/setup/setup-sut-k8s.sh <gaudi2 user>@<your dev ip>:12100 <gaudi2 user>@<your dev ip>:12100
Use ./ctest.sh to run workload:
./ctest.sh -V -R _gaudi--prepare-sut
./ctest.sh -R _gaudi -V --reuse-sut
AI Workload Summary
The AISEF(Artificial Intelligence Strategic Execution Forum) has defined a set of top 25 artificial intelligence (AI) workloads that are considered to be the most important recently and related workloads are well-maintained in WSF repo. We suggest you use these workloads (with AISEF priority) for benchmarking.

