# Specifying the cluster configuration

The `cluster-config.yaml` manifest describes the machine specification to run the workloads. The specification is still evolving and subject to change.  

The following example describes a 3-node cluster to be used in some workload:

```yaml
cluster:
  - labels: {}
  - labels: {}
  - labels: {}
```

The `cluster-config.yaml` consists of the following sections: 

- **`cluster`**: This section defines the post-Sil cluster configurations. 

## cluster.labels

The `cluster.labels` section describes any must have system level setup that a workload must use. The setup is specified in terms of a set of Kubernetes node labels as follows:

| Label | Description |
|:-----:|:------------|
| `HAS-SETUP-DATASET` | This set of labels specifies the available dataset on the host.<br>See also: [Dataset Setup][Dataset Setup]. |
| `HAS-SETUP-DISK-AVAIL` | This set of labels probe the disk availablibility to ensure there is enough data space available for workload execution.<br>See also: [Disk Avail Setup][Disk Avail Setup]. | 
| `HAS-SETUP-DISK-SPEC` | This set of labels specify that SSD or NVME disks be mounted on the worker node(s).<br>See also: [Storage Setup][Storage Setup]. | 
| `HAS-SETUP-HUGEPAGE` | This set of labels specify the kernel hugepage settings.<br>See also: [Hugepage Setup][Hugepage Setup] | 
| `HAS-SETUP-MEMORY` | This label specifies the minimum memory required by the workload. See also: [Memory Setup][Memory Setup]. | 
| `HAS-SETUP-MODULE` | This set of labels specify the kernel modules that the workload must use.<br>See also: [Module Setup][Module Setup]. |

The label value is either `required` or `preferred` as follows:

```yaml
cluster:
- labels:
    HAS-SETUP-HUGEPAGE-2048kB-2048: required
```

## cluster.cpu_info

The `cluster.cpu_info` section describes any CPU-related constraints that a workload must use. The `cpu_info` section is currently declarative and is not enforced.  

```yaml
cluster:
- cpu_info:
    flags:
    - "avx512f"
```

where the CPU flags must match what are shown by `lscpu` or `cat /proc/cpuinfo`.  

## cluster.mem_info

The `cluster.mem_info` section describes any memory constraints that a workload must use. The `mem_info` section is currently declarative and is not enforced. 

> Please also use the Kubernetes [resource constraints][resource constraints] to specify the workload memory requirements.)   

```yaml
cluster:
- mem_info:
    available: 128
```

where the available memory is in the unit of GBytes. 

## cluster.vm_group

The `cluster.vm_group` section describes the worker group that this worker node belongs to. Each worker group is a set of SUTs of similar specification. If not specified, the worker group is assumed to be `worker`.  

> Enforced by the terraform backend.  

```yaml
cluster:
- labels: {}
  vm_group: client
```

## cluster.off_cluster

The `cluster.off_cluster` section describes whether the worker node should be part of the Kubernetes cluster. This is ignored if the workload is not a Cloud Native workload or the execution is not through Kuberentes.  

```yaml
cluster:
- labels: {}
- labels: {}
  off_cluster: true
```

If not specified, all nodes are part of the Kubernetes cluster.  

## cluster.sysctls

The `cluster.sysctls` section describes the sysctls that the workload expects to use. The sysctls are specified per worker group. Multiple sysctls are merged together and applied to all the worker nodes in the same workgroup.  

> Enforced by the terraform backend.  

```yaml
cluster:
- labels: {}
  sysctls:
    net.bridge.bridge-nf-call-iptables: 1
```

## cluster.sysfs

The `cluster.sysfs` section describes the `sysfs` or `procfs` controls that the workload expects to use. The controls are specified per worker group. Multiple controls are merged together and applied to all the worker nodes in the same workgroup.  

> Enforced by the terraform backend.  

```yaml
cluster:
- labels: {}
  sysfs:
    /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor: performance
```

### cluster.bios

The `cluster.bios` section describes the bios settings that the workload expects to use. The controls are specified per worker group. Multiple controls are merged together and applied to all the worker nodes in the same workgroup.

> Enforced by the terraform backend.

```
cluster:
- labels: {}
  bios:
    SE5C620.86B:
      "Intel(R) Hyper-Threading Tech": Enabled          # Disabled
      "CPU Power and Performance Policy": Performance   # "Balanced Performance", "Balanced Power", or "Power"
```

### cluster.msr

The `cluster.msr` section describes the msr register settings that the workload expects to use. The controls are specified per worker group. Multiple controls are merged together and applied to all the worker nodes in the same workgroup.

> Enforced by the terraform backend.

```
cluster:
- labels: {}
  msr:
    0x0c90: 0x7fff
    0x0d10: 0xff
```

## terraform

The `terraform` section overwrites the default configuration parameters of the terraform validation backend default. See [Terraform Options][Terraform Options] for specific options.  

```yaml
terraform:
  k8s_cni: flannel
```

> Note that any specified options in `TERRAFORM_OPTIONS` or by the CLI takes precedent. They will not be overriden by the parameters specified in this section. 

### Example of Enabling Kubernetes NUMA Controls

```yaml
terraform:
  k8s_kubeadm_options:
    KubeletConfiguration:
      cpuManagerPolicy: static
      systemReserved:
        cpu: 200m
      topologyManagerPolicy: single-numa-node
      topologyManagerScope: pod
      memoryManagerPolicy: Static
      reservedMemory:
        - numaNode: 0
          limits:
            memory: 100Mi
      featureGates:
        CPUManager: true
        TopologyManager: true
        MemoryManager: true
```

### Example of Enabling Kubernetes Per-Socket Topology Aware Controls

Below configuration enables topology aware scheduling - including hardware cores and socket awareness. Only integral values for CPU reservations are allowed and misconfiguration of k8s deployment will result in SMTAlignmentError. This should be considered advanced users only example. Required Kubernetes version of 1.26.1 or higher.

```yaml
terraform:
  k8s_kubeadm_options:
    KubeletConfiguration:
      cpuManagerPolicy: static
      cpuManagerPolicyOptions:
        align-by-socket: "true"
        distribute-cpus-across-numa: "true"
        full-pcpus-only: "true"
      systemReserved:
        cpu: 1000m
      topologyManagerPolicy: best-effort
      topologyManagerPolicyOptions:
        prefer-closest-numa-nodes: "true"
      topologyManagerScope: pod
      memoryManagerPolicy: Static
      reservedMemory:
        - numaNode: 0
          limits:
            memory: 100Mi
      featureGates:
        CPUManager: true
        CPUManagerPolicyAlphaOptions: true
        CPUManagerPolicyBetaOptions: true
        CPUManagerPolicyOptions: true
        MemoryManager: true
        TopologyManager: true
        TopologyManagerPolicyAlphaOptions: true
        TopologyManagerPolicyBetaOptions: true
        TopologyManagerPolicyOptions: true
```

[Module Setup]: ../../user-guide/preparing-infrastructure/setup-module.md
[Hugepage Setup]: ../../user-guide/preparing-infrastructure/setup-hugepage.md
[Terraform Options]: ../../user-guide/executing-workload/terraform-options.md#ansible-configuration-parameters
[Dataset Setup]: ../../user-guide/preparing-infrastructure/setup-dataset.md
[Memory Setup]: ../../user-guide/preparing-infrastructure/setup-memory.md
[Disk Avail Setup]: ../../user-guide/preparing-infrastructure/setup-disk-avail.md
