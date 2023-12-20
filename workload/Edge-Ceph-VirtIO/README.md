>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

Ceph is one of the storage backend in the Intel Edge platform, it provides the High performance IO caplibility for containerized application and VM based application. The Ceph is an open-source software (software-defined storage) storage platform, implements object storage on a single distributed computer cluster, and provides 3-in-1 interfaces for object-, block- and file-level storage.

For cloud native VM based, the kubevirt is basic framework to enable the VM based application in kubernetes platform. Please also refer to the [readme](./template/kubevirt/README.md) for more kubevirt details




### Test Case

This Edge Ceph provides `Block` storage function which provides serveral test cases with the following configuration parameters:

- **User Cases**: One of the major storage function for Edge Ceph, provide block device to client.
  - `virtIO`: Test IO performance with traditional virtio VM.
  - `vhost`: Test the Block IO in VM with vhost acclelerated.
- **IO Operations**: Common IO operation for storage functions, including:
  - `sequential_read`: Test the sequential read performance.
  - `sequential_write`: Test the IO sequential write performance.
  - `sequential_mixedrw`: Test the IO sequential Mixed Read/Write performance with R:W ratio.
  - `random_read`: Test the randomly IO read operation performance.
  - `random_write`: Test the randomly IO write operation performance.
  - `random_mixedrw`: Test the IO random Mixed Read/Write performance with R:W ratio.
- **VM Scaling Cases**: Test the throughput/IOPS with VM number scaling.
  - `virtIO_random_read_scale-1vm`: Test the virtio randomly IO read operation performance with 1 VM in each node.
  - `virtIO_random_read_scale-4vm`: Test the virtio randomly IO read operation performance with 4 VMs in each node.
  - `vhost_random_read_scale-1vm`: Test the vhost randomly IO read operation performance with 1 VM in each node.
  - `vhost_random_read_scale-4vm`: Test the vhost randomly IO read operation performance with 4 VMs in each node.
- **MISC**: This is optional parameter, specify `gated` or `pkm`.
  - `gated` represents running the workload with simple and quick case.
  - `pkm` represents the typical test case with performance analysis.

##### More Parameters

Each test case accepts configurable parameters like `TEST_BLOCK_SIZE`, `TEST_IO_DEPTH`, `TEST_DATASET_SIZE` ,`TEST_IO_THREADS`  in [validate.sh](validate.sh). More details as below.

- **Workload**
  - `CLUSTER_NODES`: Node count will be used for building Ceph Storage Cluster, typical cluster size is 3 nodes.
  - `BENCHMARK_CLIENT_NODES`: The count of client benchmark pod to test the Ceph Storage, default is 1.
  - `NODE_SELECT`: Build Ceph Stroage on `ALL` Nodes or `PARTIAL` of nodes.
  - `DEVICE_SELECT`: Build Ceph Stroage on `ALL` disk device or `PARTIAL` of disk device on all of Nodes.
  - `DEBUG_MODE`: Used for developer debug during development, more details refer to [validate.sh](validate.sh).
  - `OSD_PER_DEVICE`: Create Multi OSD on each disk device, default is create 1 osd per drive.
  - `TEST_DURATION`: Define the test runtime duration.
  - `PG_COUNT`: The pg count in replicapool pool.
    - Less than 5 OSDs set pg_num to 128
    - Between 5 and 10 OSDs set pg_num to 512
    - Between 10 and 50 OSDs set pg_num to 1024
    - If you have more than 50 OSDs, for calculating pg_num yourself please make use of [the pgcalc tool](https://old.ceph.com/pgcalc/)
- **Block Function**
  - `TEST_BLOCK_SIZE`: Block size for each operation in IO test.
  - `TEST_IO_THREADS`: Test thread count for block io test.
  - `TEST_DATASET_SIZE`: Total data size for block io test with fio.
  - `TEST_IO_DEPTH`: IO count in each IO queue when test the block IO with fio.
  - `TEST_IO_ENGINE`: IO engine for fio test tool, we can support `libaio` and `librbd`.
  - `RBD_IMAGE_NUM`: Create number of RBD image per benchmark pod.
  - `FIO_CPU`: The CPU cores allocated to FIO application.
  - `TEST_RAMP_TIME`: The FIO run warm up time.

### System Requirements

 - Please setup K8S and rook-ceph, and the preferred namespace for rook-ceph storage is `rook-ceph`. It is recommended to repare K8S Env with 100G NIC.

- Need to allocate enough Hugepages in each node before running vhost-vm test cases.(Default: 64Gi, for 32G-Memory VM), then restart kubelet.(Need to confirm the default hugepage size is 2M)

```
echo 32768 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
```

- Add the configuration to enable the qemu-kvm privilege of the container.

```
vim /etc/apparmor.d/usr.sbin.libvirtd
...
/usr/libexec/qemu-kvm PUx,
...
apparmor_parser -r /etc/apparmor.d/usr.sbin.libvirtd # or systemctl reload apparmor.service
```

- Check hardware virtualization enabled for each node

```shell
sudo apt install libvirt-daemon-system libvirt-clients
```

- Run 'virt-host-validate qemu' in each node, you need to see hardware virtualization check passed like this :

```
  QEMU: Checking for hardware virtualization                                 : PASS
  QEMU: Checking if device /dev/kvm exists                                   : PASS
  QEMU: Checking if device /dev/kvm is accessible                            : PASS
  QEMU: Checking if device /dev/vhost-net exists                             : PASS
  QEMU: Checking if device /dev/net/tun exists                               : PASS
  QEMU: Checking for cgroup 'cpu' controller support                         : PASS
  QEMU: Checking for cgroup 'cpuacct' controller support                     : PASS
  QEMU: Checking for cgroup 'cpuset' controller support                      : PASS
  QEMU: Checking for cgroup 'memory' controller support                      : PASS
  QEMU: Checking for cgroup 'devices' controller support                     : PASS
  QEMU: Checking for cgroup 'blkio' controller support                       : PASS
  QEMU: Checking for device assignment IOMMU support                         : PASS
  QEMU: Checking if IOMMU is enabled by kernel                               : PASS
  QEMU: Checking for secure guest support                                    : WARN (Unknown if this platform has Secure Guest support)
```

- Set static cpu (set once for each machine), modify this file `/var/lib/kubelet/kubeadm-flags.env` to like this,

```
KUBELET_KUBEADM_ARGS="--network-plugin=cni --pod-infra-container-image=k8s.gcr.io/pause:3.6 --topology-manager-policy=single-numa-node --cpu-manager-policy=static --system-reserved=cpu=2"
rm -rf /var/lib/kubelet/cpu_manager_state
rm -rf /var/lib/kubelet/memory_manager_state
```

- Restart the kubelet. Then in the process of running the test, it will become cpumanager=true.

```
kubectl describe no | grep cpumanager
          cpumanager=true
          cpumanager=true
          cpumanager=true
```

- Add the no_proxy configuration of "virt-api.kubevirt.svc" and "kubevirt-operator-webhook.kubevirt.svc" in /etc/environment.

```
source /etc/environment
```

### Deploy the Ceph toolbox and kubevirt operator CRD

Assuming you have deploied Ceph, you also need

- Deploy the Ceph toolbox.

```
   In the [workload directory](./template/ceph_toolbox.yaml):
   kubectl apply -f ceph_toolbox.yaml
```

- Apply the kubevirt operator CRD previously before run test.

```
   In the [workload directory](./template/kubevirt/kubevirt-operator-crd.yaml):
   kubectl apply -f kubevirt-operator-crd.yaml # copy to master node and run
```

### Node Labels:

Label each node with the following node labels:

- `HAS-SETUP-CEPH-STORAGE=yes`
- `HAS-SETUP-HUGEPAGE-2048kB-32768=yes`

For example,

```
kubectl label nodes <hostname> HAS-SETUP-CEPH-STORAGE=yes
```

### Docker Image

Current workload don't support standalone docker run, it's cloud native workload.

### Kubernetes run manually

User can run the workload manually, but it's more perfer to run in SF following the [SF-Guide](../../README.md#evaluate-workload). And please make sure the docker image is ready before kubernetes running. Alternatively, user also can utilize Internal docker registry

```
RELEASE=":latest"
REGISTRY="<IP>:<port>/"
```

For example,

```
/build# cmake -DREGISTRY="<IP>:<port>/" -DRELEASE=":latest" -DBENCHMARK="" -DBACKEND="kubernetes" ..
/build/workload/Edge-Ceph-VirtIO# make
```

#### Create kubernetes-config.yaml to test

```
In the [`workload`](./) directory:
namespace="rook-ceph"
m4 -Itemplate -I../../template -DNAMESPACE=$namespace -DREGISTRY=$REGISTRY -DRELEASE=$RELEASE -DTESTCASE=block -DTEST_LAYER=pool -DBENCH_OPERATOR_NAME="ceph-benchmark-operator" kubernetes-config.yaml.m4 > kuberentes-config.yaml
kubectl create ns $namespace
kubectl apply -f kubernetes-config.yaml
```

#### Run the workload and retrieve logs

```
kubectl --namespace=$namespace wait pod --all --for=condition=ready --selector=app=ceph-benchmark-operator --timeout=300s
pod=$(kubectl get pod --namespace=$namespace --selector=app=ceph-benchmark-operator -o=jsonpath="{.items[0].metadata.name}")
timeout 300s kubectl exec --namespace=$namespace $pod -c ceph-benchmark-operator -- bash -c 'cat /export-logs' | tar -xf
```

### KPI

Run the [`kpi.sh`](kpi.sh) script to generate KPIs out of the validation logs.

```
/build/workload/Edge-Ceph-VirtIO# ./list-kpi.sh logs*
```

### Performance BKM

- **ICX**

  | BIOS setting                     | Required setting |
  | -------------------------------- | ---------------- |
  | Hyper-Threading                  | Enable           |
  | CPU power and performance policy | Performance      |
  | turbo boost technology           | Enable           |
  | processor C6                     | Disable          |
  | C1E                              | Enable           |
  | Package C State                  | C0/C1 state      |
  | Hardware P-States                | Native Mode      |
  | Set Fan Profile                  | Performance      |
  | Intel VT for directed I/O        | Enable           |

  System:

  - 2M hugepages:32768
  - intel_iommu: ON
  - numa_balancing: enable

- **SPR**

  | BIOS setting                     | Required setting |
  | -------------------------------- | ---------------- |
  | Hyper-Threading                  | Enable           |
  | CPU power and performance policy | Performance      |
  | turbo boost technology           | Enable           |
  | processor C6                     | Disable          |
  | C1E                              | Enable           |
  | Package C State                  | C0/C1 state      |
  | Hardware P-States                | Native Mode      |
  | Set Fan Profile                  | Performance      |
  | Intel VT for directed I/O        | Enable           |

  System:

  - 2M hugepages:32768
  - intel_iommu: ON
  - numa_balancing: enable

 - **Drop cache for environment**

 ```
  For each node of the cluster:
  sync; echo 3 > /proc/sys/vm/drop_caches
 ```

### See Also

- [Ceph source code](https://github.com/ceph/ceph)