>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction
In industry there is a common solution called kubevirt, which open-sourced from Redhat, it can match the industry needs. It targets to resolve the VM based application in the huge amount nodes environment, addresses the needs of development teams that have adopted or want to adopt Kubernetes but possess existing Virtual Machine-based workloads that cannot be easily containerized. More specifically, the technology provides a unified development platform where developers can build, modify, and deploy applications residing in both Application Containers as well as Virtual Machines in a common, shared environment.

And in this stack,there are some patchs for support spdk-vhost-user in kubevirt to accelerate the virtualized IO in VM.


### See Also
- [kubevirt code repo](https://github.com/kubevirt/kubevirt)
- [kubevirt officaial website](https://kubevirt.io/)

