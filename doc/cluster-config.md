
The `cluster-config.yaml` manifest describes the machine specification to run the workloads. The specification is still evolving and subject to change.  

The following example describes a 3-node cluster to be used in some workload:

```
cluster:
  - labels: {}
  - labels: {}
  - labels: {}
```

The `cluster-config.yaml` consists of the following sections: 

- **`cluster`**: This section defines the post-Sil cluster configurations. 

### cluster.labels

The `cluster.labels` section describes any must have system level setup that a workload must use. The setup is specified in terms of a set of Kubernetes node labels as follows:

| Label | Description |
|:-----:|:------------|
| <pre>`HAS-SETUP-DISK</pre> | This set of labels specify that SSD disks be mounted on the worker node(s).<br>See also: [Storage Setup](setup-storage.md). | 
| <pre>`HAS-SETUP-MODULE`</pre> | This set of labels specify the kernel modules that the workload must use.<br>See also: [Module Setup](setup-module.md). |
| <pre>`HAS-SETUP-HUGEPAGE`</pre> | This set of labels specify the kernel hugepage settings.<br>See also: [Hugepage Setup](setup-hugepage.md) | 

The label value is either `required` or `preferred` as follows:

```
cluster:
- labels:
    HAS-SETUP-HUGEPAGE-2048kB-2048: required
```

### cluster.cpuinfo

The `cluster.cpuinfo` section describes any CPU-related constraints that a workload must use. The cpuinfo section is currently declarative and is not enforced.  

```
cluster:
- cpuinfo:
    flags:
    - "avx512f"
```

where the CPU flags must match what are shown by `lscpu` or `cat /proc/cpuinfo`.  

### cluster.meminfo

The `cluster.meminfo` section describes any memory constraints that a workload must use. The meminfo section is currently declarative and is not enforced. 

> Please also use the Kubernetes [resource constraints](https://kubernetes.io/docs/tasks/configure-pod-container/assign-memory-resource) to specify the workload memory requirements.)   

```
cluster:
- meminfo:
    available: 128
```

where the available memory is in the unit of GBytes. 

### kubernetes

The `kubernetes` section describes the Kubernetes configurations. This section is currently optionally enforced.  
- `cni`: Specify the CNI plugin: `flannel` or `calico`.  
- `cni-options`: Specify the CNI option: `vxlan` (calico).  
- `kubelet-options`: Specify the kubelet options as described in [`KubeletConfiguration`](https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/#kubelet-config-k8s-io-v1beta1-KubeletConfiguration).  
- `kubevirt`: Specify whether to enable kubevirt: `true/false`.  

```
kubernetes:
  cni: flannel
  kubelet-options:
    runtimeRequestTimeout: 10m
```

> Note that CNIs may behave differently on CSPs. Calico BGP and VXLAN work on AWS but only VXLAN works on GCP and AZure.   

