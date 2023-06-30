>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

Intelligent Connection Management (CM) xApp is developed based on the O-RAN network architecture to optimize user association and load balancing to improve the quality of service (QoS) requirements of a user equipment (UE). The connection management is formulated as a combinatorial graph optimization problem. A deep reinforcement learning (DRL) solution is proposed to learn the weights of a graph neural network (GNN) for an optimal UE association. 

### Preparation

1.Please install Smart Edge Open Developer Experience Kit first. Intel® Smart Edge Open Developer Experience Kit provides customized infrastructure deployments for common network and on-premises edge use cases. Combining Intel Cloud Native technologies, and high-performance compute, this kit provide a blueprint to help building AI, video and edge services covering diverse IoT segments with diverse optimization at the edge. 

Refer to :  https://www.intel.com/content/www/us/en/developer/articles/reference-implementation/smart-edge-open-developer-experience-kit.html

2.Anyone that has a NDA agreement with Intel can download the necessary files to run the workload , including:
```
├── Connection-Management-xApp.tar.gz
├── cm-xapp-charts-v5.tar.gz
├── xApp_ONF
```
After download it, please  put the files in workload folder . The whole folder structure should be as follows. 
```
workload/
├── helm
├── helm/cm-xapp-charts-v5.tar.gz
├── scripts
├── .gitignore
├── build.sh
├── cluster-config.yaml.m4
├── CMakeLists.txt
├── Connection-Management-xApp.tar.gz
├── Dockerfile.1.cmxapp
├── kpi.sh
├── README.md
├── validate.sh
├── xApp_ONF
```
Please decompress cm-xapp-charts-v5.tar.gz
### Test Case
The CM xApp workload provides following test cases:
- cm_xapp_openvino
- cm_xapp_openvino_gated
- cm_xapp_openvino_pkm

All the test cases use OpenVINO inference for handover requests, run for a certain time. Default test case runs for 1080 seconds. `_gated` runs for 120 seconds, the _pkm test case is identical to the default test case.

Kubernetes nodes must have following label:
- `HAS-SETUP-SMART-DEK=yes`

### Performance BKM
- **ICX**

  | BIOS setting                     | Required setting |
  | -------------------------------- | ---------------- |
  | Hyper-Threading                  | Disable          |
  | CPU power and performance policy | Performance      |
  | turbo boost technology           | Enable           |



### Docker Image
The workload provides the following docker image:
- **`cmxapp`**: The image runs CM xApp main program.

CM xApp parameters can be changed through setting Helm chart values. These parameters will be passed into the container as container environmental variables.
- **`xAppRunTime`**: Specify running time.
- **`initiationTime`**: Specify initiation time, valid range is 60-300 seconds.
- **`cellIndLimit`**: Specify number of indications to consider for cell id gathering, valid range is 100-2000.
- **`parallelLoop`**: Specify whether to enable inference optimizations, false for python based inferencing, true for other types of inferencing.
- **`qValue`**: Specify inference method, 0(tensorflow) / 1(C++) / 2(C++ with multiple NN evals per call) / 3(C++ with action list also) / 10(use single-inference sync OpenVINO).
- **`preprocessing`**: Specify pre-processing method, true for python based pre-processing, false for c++ based pre-processing.
- **`corebind`**: Specify the cores that CM xApp runs on. CM xApp needs to be bound to specified cores to achieve optimal performance. By default, CM xApp is bound to core 0.


### Run with Kubernetes manually

[Intel® Smart Edge Open Developer Experience Kit 22.03](https://github.com/smart-edge-open/open-developer-experience-kits) must be installed.

CM xApp requires a SD-RAN deployment. Install atomix-controller , atomix-raft-storage and onos-operator in `kube-system` namespace before running the workload.
```
helm install atomix-controller atomix/atomix-controller -n kube-system --version 0.6.8
helm install atomix-raft-storage atomix/atomix-raft-storage -n kube-system --version 0.1.15
helm install onos-operator onos/onos-operator -n kube-system --version 0.5.4
```
Notes:
If you want to install the above pod on the specified server.
First, you should use the `helm pull` command to download and unpack the chart file.
```
helm pull atomix/atomix-controller --untar
helm install atomix/atomix-raft-storage --untar
helm install onos/onos-operator --untar
```
Then, Go to the unpacked file as atomix-controller for example : atomix-controller/templates/deployment.yaml , 
find `nodeSelector` in the yaml file, and fill in the server label you need.

To run the workload without Services Framework, execute the following commands: 

Install the Helm chart
```
helm dependency build ./helm
helm template cm-xapp ./helm > kubernetes-config.yaml
kubectl apply -f kubernetes-config.yaml --namespace $NAMESPACE
```
Run and retrieve logs
```
kubectl --namespace=$NAMESPACE wait pod --all --for=condition=ready --timeout=300s
pod=$(kubectl get pod --namespace=$NAMESPACE --selector=job-name=cm-xapp -o=jsonpath="{.items[0].metadata.name}")
timeout 300s kubectl exec --namespace=$NAMESPACE $pod -c cm-xapp -- bash -c 'cat /export-logs' | tar -xf 
```


### KPI

Run the [`kpi.sh`](kpi.sh) script to parse the KPIs from the output.
The `parse_log.py` script reads CM xApp output and generate KPIs. For each handover request there are 4 performance indicators: `Pre HO processing time`, `OpenVINO HO processing time`, `Post HO processing time`, `Total HO processing time`. For each of them there are 4 results as follows:
- **`HO processing time avg (ms)`**: The average processing time in milliseconds. (Focus on)
- **`HO processing time std (ms)`**: The processing time standard deviation in milliseconds.
- **`HO processing time max (ms)`**: The maximum processing time in milliseconds. (Focus on)
- **`HO processing time min (ms)`**: The minimum processing time in milliseconds.


### Index Info

- Name: `CM xApp`
- Category: `Edge`
- Platform: `ICX`
- Keywords: `5G`, `O-RAN`, `RIC`
- Permission:


### See Also

- [Intelligent Connection Management for Automated Handover Reference Implementation](https://www.intel.com/content/www/us/en/developer/articles/reference-implementation/intelligent-connection-management.html)
- [Connection Management xAPP for O-RAN RIC: A Graph Neural Network and Reinforcement Learning Approach](https://arxiv.org/abs/2110.07525)
