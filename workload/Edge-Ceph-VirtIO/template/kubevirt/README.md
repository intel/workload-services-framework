### Introduction
Kubevirt is a cloud native method to deploy and manage the VMs in kubernetes environment. The kubeVirt technology addresses the needs of development teams that have adopted or want to adopt Kubernetes, but possess existing Virtual Machine-based workloads that cannot be easily containerized. More specifically, the technology provides a unified development platform where developers can build, modify, and deploy applications residing in both Application Containers as well as Virtual Machines in a common, shared environment.
VMs with KubeVirt can be installed using the KubeVirt operator, which manages the lifecycle of all the KubeVirt core components.

### Deployment kubevirt environment
```
kubectl create -f kubevirt-operator-crd.yaml
kubectl create -f kubevirt-operator.yaml
kubectl create -f kubevirt-cr.yaml
```
### Reference:
- [kubevirt offical homesite](https://kubevirt.io)
- [kubevirt quickstart](https://kubevirt.io//quickstart_minikube/)
- [deploy VM on kubevirt](https://kubevirt.io/labs/kubernetes/lab1.html)