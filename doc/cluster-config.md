
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
| <pre>`HAS-SETUP-QAT`</pre> | This label specifies that the QAT kernel driver must be installed and configured on the system.<br>See also: [QAT Setup](setup-qat.md). |   
| <pre>`HAS-SETUP-DISK-SPEC`</pre> | This set of labels specify that NVME disks be mounted on the worker node(s).<br>See also: [Storage Setup](setup-storage.md). | 
| <pre>`HAS-SETUP-MODULE`</pre> | This set of labels specify the kernel modules that the workload must use.<br>See also: [Module Setup](setup-module.md). |
| <pre>`HAS-SETUP-HUGEPAGE`</pre> | This set of labels specify the kernel hugepage settings.<br>See also: [Hugepage Setup](setup-hugepage.md) | 
| <pre>`HAS-SETUP-GRAMINE-SGX`</pre> | This label specifies the SGX is enabled and GRAMINE software is installed on the system.<br>See also: [Gramine-SGX Setup](setup-gramine-sgx.md) |

The label value is either `required` or `preferred` as follows:

```
cluster:
- labels:
    HAS-SETUP-HUGEPAGE-2048kB-2048: required
```

### cluster.vm_group

The `cluster.vm_group` section describes the worker group that this worker node belongs to. If not specified, assume it is the `worker` group.

```
cluster:
- labels: {}
  vm_group: client
```

### cluster.sysctls

The `cluster.sysctls` section describes the sysctls that the workload expects to use. The sysctls are specified per worker group. Multiple sysctls are merged together and applied to all the worker nodes in the same workgroup.  

```
cluster:
- labels: {}
  sysctls:
    net.bridge.bridge-nf-call-iptables: 1
```

### cluster.sysfs

The `cluster.sysfs` section describes the `sysfs` controls that the workload expects to use. The `sysfs` controls are specified per worker group. Multiple controls are merged together and applied to all the worker nodes in the same workgroup.  

```
cluster:
- labels: {}
  sysfs:
    /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor: performance
```

### terraform

The `terraform` section overwrites the default configuration parameters of the terraform validation backend default. See [Terraform Options](`terraform-options#ansible-configuration-parameters`) for specific options.  

```
terraform:
  k8s_cni: flannel
```

> Note that any specified options in `TERRAFORM_OPTIONS` take precedent. They will not be overriden by the parameters specified in this section.  

