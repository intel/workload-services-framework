# Setup NFD

Node Feature Discovery (NFD) lists platform capabilities and can be used for intelligent workload scheduling in Kubernetes.

> **Note:** NFD + Intel Device Plugins can be achieved in SF through Ansible automation please refer to roles available [here][nfd ansible roles].

## Intel Device Plugins
The Intel Device Plugins for Kubernetes provides a collection of device plugins that advertise Intel hardware resources. 

Currently, the operator can support QAT, SGX device plugins etc…

## Benefits of Completing WL's With NFD Based Labels Accompanying Intel Device Plugins

* As much as possible, an Ansible role is designed to automate both NFD and Intel DP projects to reduce manual workload

* After NFD + Intel Device Plugins configured, WL’s can be triggered with no need for complicated or hardcoded values such as hardware type, hugepages, OS’s etc.
It is more robust for WL's to rely on NFD labels which will show whether SGX, QAT, etc. are properly configured and present in the system.
 
    > **Note:** Additionally, in testing, it was observed that Intel Device Plugins configured with NFD resulted in faster execution time for WL's such as OpenSSL3-RSAMB 

    **Required:** Installation of the drivers QAT, SGX etc is expected else Intel Device Plugins might end up with issues.

- Example of QAT labels is as under

  > **Note:** Please update labels in WL’s before execution, for example in OpenSSL3-RSAMB WL, QAT lables should be updated as under

**workload/OpenSSL3-RSAMB/kubernetes-config.yaml.m4**

```yaml
nodeSelector:
   intel.feature.node.kubernetes.io/qat: "true"
```

**workload/OpenSSL3-RSAMB/cluster-config.yaml.m4**

```yaml
- labels:
    intel.feature.node.kubernetes.io/qat: required
```

> **Note:** Same can be achieved with all SGX related / dependent WL's

```yaml
nodeSelector:
  intel.feature.node.kubernetes.io/sgx: "true"
```

and

```yaml
- labels:
    intel.feature.node.kubernetes.io/sgx: required
```

> **Note:** Same can be achieved with all DLB related / dependent WL's

```yaml
nodeSelector:
  intel.feature.node.kubernetes.io/dlb: "true"
```

and

```yaml
- labels:
    intel.feature.node.kubernetes.io/dlb: required
```

> **Note:** Same can be achieved with all DSA related / dependent WL's

```yaml
nodeSelector:
  intel.feature.node.kubernetes.io/dsa: "true"
```

and

```yaml
- labels:
    intel.feature.node.kubernetes.io/dsa: required
```

intel.feature.node.kubernetes.io/dsa

## Verify Node Feature Discovery

```text
kube-system node-feature-discovery-worker      1    1    1    1    1    <none>    61s
```

To verify that NFD in Kubernetes is running as expected, use the following command:

```shell
kubectl label node --list --all
```

```text
Listing labels for Node./node:
 feature.node.kubernetes.io/kernel-config.NO_HZ=true
 feature.node.kubernetes.io/cpu-pstate.turbo=true
 feature.node.kubernetes.io/cpu-cpuid.X87=true
 feature.node.kubernetes.io/cpu-cpuid.MOVDIR64B=true
 feature.node.kubernetes.io/cpu-rdt.RDTCMT=true
 kubernetes.io/arch=amd64
 feature.node.kubernetes.io/cpu-cpuid.AVX512FP16=true
 feature.node.kubernetes.io/cpu-cpuid.AVX512VPOPCNTDQ=true
 feature.node.kubernetes.io/cpu-power.sst_bf.enabled=true
 feature.node.kubernetes.io/system-os_release.VERSION_ID=22.04
 intel.power.node=true
 feature.node.kubernetes.io/cpu-cpuid.OSXSAVE=true
 intel.feature.node.kubernetes.io/dlb=true
 feature.node.kubernetes.io/cpu-cpuid.AVX512IFMA=true
 feature.node.kubernetes.io/cpu-cpuid.AVX512BF16=true
 feature.node.kubernetes.io/cpu-cpuid.AVX512BITALG=true
 feature.node.kubernetes.io/cpu-cpuid.AMXBF16=true
 feature.node.kubernetes.io/kernel-config.NO_HZ_IDLE=true
 feature.node.kubernetes.io/cpu-rdt.RDTL2CA=true
 feature.node.kubernetes.io/cpu-cstate.enabled=true
 feature.node.kubernetes.io/pci-0b40_8086.present=true
 feature.node.kubernetes.io/cpu-cpuid.VAES=true
 feature.node.kubernetes.io/kernel-version.revision=0
 intel.feature.node.kubernetes.io/qat=true
 feature.node.kubernetes.io/kernel-version.full=5.15.0-25-generic
 cndp=true
 feature.node.kubernetes.io/cpu-cpuid.FMA3=true
 feature.node.kubernetes.io/cpu-cpuid.SHA=true
 ethernet.intel.com/intel-ethernet-present=
 feature.node.kubernetes.io/cpu-cpuid.SERIALIZE=true
 feature.node.kubernetes.io/cpu-cpuid.CETIBT=true
 feature.node.kubernetes.io/pci-0b40_8086.sriov.capable=true
 feature.node.kubernetes.io/cpu-cpuid.TSXLDTRK=true
 kubernetes.io/hostname=node
 feature.node.kubernetes.io/cpu-cpuid.LAHF=true
 feature.node.kubernetes.io/kernel-version.minor=15
 feature.node.kubernetes.io/cpu-cpuid.MOVDIRI=true
 feature.node.kubernetes.io/system-os_release.VERSION_ID.major=22
 feature.node.kubernetes.io/cpu-cpuid.XSAVE=true
 feature.node.kubernetes.io/cpu-cpuid.AVX512VBMI2=true
 feature.node.kubernetes.io/cpu-cpuid.AVX512VBMI=true
 feature.node.kubernetes.io/cpu-hardware_multithreading=true
 feature.node.kubernetes.io/cpu-cpuid.WBNOINVD=true
 feature.node.kubernetes.io/cpu-model.id=143
 feature.node.kubernetes.io/cpu-cpuid.STIBP=true
 feature.node.kubernetes.io/kernel-version.major=5
 intel.feature.node.kubernetes.io/dsa=true
 feature.node.kubernetes.io/cpu-cpuid.SCE=true
 feature.node.kubernetes.io/system-os_release.ID=ubuntu
 feature.node.kubernetes.io/cpu-cpuid.WAITPKG=true
 feature.node.kubernetes.io/cpu-cpuid.IBPB=true
 feature.node.kubernetes.io/cpu-rdt.RDTMON=true
 feature.node.kubernetes.io/cpu-cpuid.VMX=true
 feature.node.kubernetes.io/cpu-rdt.RDTMBA=true
 feature.node.kubernetes.io/cpu-cpuid.CLDEMOTE=true
 feature.node.kubernetes.io/cpu-cpuid.MOVBE=true
 intel.feature.node.kubernetes.io/sgx=true
 feature.node.kubernetes.io/cpu-cpuid.FXSR=true
 feature.node.kubernetes.io/cpu-sgx.enabled=true
 feature.node.kubernetes.io/cpu-cpuid.AMXINT8=true
 feature.node.kubernetes.io/cpu-cpuid.CMPXCHG8=true
 feature.node.kubernetes.io/storage-nonrotationaldisk=true
 kubernetes.io/os=linux
 feature.node.kubernetes.io/cpu-cpuid.CETSS=true
 feature.node.kubernetes.io/memory-numa=true
 node-role.kubernetes.io/worker=
 feature.node.kubernetes.io/cpu-cpuid.ENQCMD=true
 feature.node.kubernetes.io/cpu-cpuid.AVX512VL=true
 feature.node.kubernetes.io/cpu-cpuid.VPCLMULQDQ=true
 feature.node.kubernetes.io/network-sriov.capable=true
 feature.node.kubernetes.io/cpu-pstate.status=active
 feature.node.kubernetes.io/cpu-cpuid.GFNI=true
 feature.node.kubernetes.io/cpu-cpuid.AVX512VNNI=true
 feature.node.kubernetes.io/cpu-cpuid.AVX=true
 beta.kubernetes.io/arch=amd64
 feature.node.kubernetes.io/cpu-cpuid.AESNI=true
 feature.node.kubernetes.io/cpu-cpuid.AVX512VP2INTERSECT=true
 feature.node.kubernetes.io/cpu-cpuid.AVX2=true
 feature.node.kubernetes.io/cpu-cpuid.AVX512BW=true
 feature.node.kubernetes.io/cpu-cpuid.AVX512CD=true
 feature.node.kubernetes.io/cpu-rdt.RDTL3CA=true
 feature.node.kubernetes.io/cpu-model.vendor_id=Intel
 feature.node.kubernetes.io/cpu-cpuid.AVX512F=true
 feature.node.kubernetes.io/system-os_release.VERSION_ID.minor=04
 feature.node.kubernetes.io/cpu-cpuid.ADX=true
 feature.node.kubernetes.io/cpu-pstate.scaling_governor=powersave
 feature.node.kubernetes.io/cpu-cpuid.AVX512DQ=true
 feature.node.kubernetes.io/pci-0300_1a03.present=true
 beta.kubernetes.io/os=linux
 feature.node.kubernetes.io/cpu-rdt.RDTMBM=true
 feature.node.kubernetes.io/cpu-cpuid.FXSROPT=true
 feature.node.kubernetes.io/cpu-cpuid.AMXTILE=true
 feature.node.kubernetes.io/cpu-model.family=6
Listing labels for Node./controller:
 kubernetes.io/os=linux
 node-role.kubernetes.io/control-plane=
 node.kubernetes.io/exclude-from-external-load-balancers=
 beta.kubernetes.io/arch=amd64
 beta.kubernetes.io/os=linux
 kubernetes.io/arch=amd64
 kubernetes.io/hostname=controller
 ```

## Verify Intel Device Plugin Operator

```shell
kubectl get pods --all-namespaces | grep 'inteldeviceplugins'
```

```text
inteldeviceplugins-system       inteldeviceplugins-controller-manager-59b46b7949-hkp4g       2/2     Running   0          17m
```

## Verify Intel QAT Device Plugin

```shell
kubectl get node "Update Node Name" -o json | jq '.status.allocatable'
```

```json
{
  "cndp/e2e": "1",
  "cpu": "125",
  "ephemeral-storage": "282566437625",
  "hugepages-1Gi": "8Gi",
  "hugepages-2Mi": "64Gi",
  "intel.com/ens107_intelnics_1": "1",
  "intel.com/ens107_intelnics_2": "4",
  "intel.com/ens107_intelnics_3": "1",
  "memory": "186797444Ki",
  "pods": "110",
  "power.intel.com/balance-performance": "76",
  "power.intel.com/balance-performance-node": "76",
  "power.intel.com/balance-power": "102",
  "power.intel.com/balance-power-node": "102",
  "power.intel.com/performance": "51",
  "power.intel.com/performance-node": "51",
  "qat.intel.com/generic": "32",
  "sgx.intel.com/enclave": "20",
  "sgx.intel.com/provision": "20"
}
```

```shell
kubectl get no -o json | jq .items[].metadata.labels | grep qat
```

```json
 "intel.feature.node.kubernetes.io/qat": "true",
```

## Verify Intel SGX Device Plugin

```shell
kubectl get node "Update Node Name" -o json | jq '.status.allocatable'
```

```json
{
  "cndp/e2e": "1",
  "cpu": "125",
  "ephemeral-storage": "282566437625",
  "hugepages-1Gi": "8Gi",
  "hugepages-2Mi": "64Gi",
  "intel.com/ens107_intelnics_1": "1",
  "intel.com/ens107_intelnics_2": "4",
  "intel.com/ens107_intelnics_3": "1",
  "memory": "186797444Ki",
  "pods": "110",
  "power.intel.com/balance-performance": "76",
  "power.intel.com/balance-performance-node": "76",
  "power.intel.com/balance-power": "102",
  "power.intel.com/balance-power-node": "102",
  "power.intel.com/performance": "51",
  "power.intel.com/performance-node": "51",
  "qat.intel.com/generic": "32",
  "sgx.intel.com/enclave": "20",
  "sgx.intel.com/provision": "20"
}
```

```shell
kubectl get no -o json | jq .items[].metadata.labels | grep sgx
```

```json
"feature.node.kubernetes.io/cpu-sgx.enabled": "true",
"intel.feature.node.kubernetes.io/sgx": "true",
```


## Verify Intel DLB Device Plugin

```shell
kubectl get node "Update Node Name" -o json | jq '.status.allocatable'
```

```json
{
  "cndp/e2e": "0",
  "cpu": "125",
  "dlb.intel.com/pf": "0",
  "dsa.intel.com/wq-user-dedicated": "0",
  "ephemeral-storage": "282566437625",
  "hugepages-1Gi": "4Gi",
  "hugepages-2Mi": "2Gi",
  "memory": "256095196Ki",
  "pods": "110",
  "power.intel.com/balance-performance": "76",
  "power.intel.com/balance-performance-node": "76",
  "power.intel.com/balance-power": "102",
  "power.intel.com/balance-power-node": "102",
  "power.intel.com/performance": "51",
  "power.intel.com/performance-node": "51",
  "qat.intel.com/generic": "16",
  "sgx.intel.com/enclave": "0",
  "sgx.intel.com/provision": "0"
}
```

```shell
kubectl get no -o json | jq .items[].metadata.labels | grep dlb
```

```json
"intel.feature.node.kubernetes.io/dlb": "true",
```

## Verify Intel DSA Device Plugin

```shell
kubectl get node "Update Node Name" -o json | jq '.status.allocatable'
```

```json
{
  "cndp/e2e": "0",
  "cpu": "125",
  "dlb.intel.com/pf": "0",
  "dsa.intel.com/wq-user-dedicated": "0",
  "ephemeral-storage": "282566437625",
  "hugepages-1Gi": "4Gi",
  "hugepages-2Mi": "2Gi",
  "memory": "256095196Ki",
  "pods": "110",
  "power.intel.com/balance-performance": "76",
  "power.intel.com/balance-performance-node": "76",
  "power.intel.com/balance-power": "102",
  "power.intel.com/balance-power-node": "102",
  "power.intel.com/performance": "51",
  "power.intel.com/performance-node": "51",
  "qat.intel.com/generic": "16",
  "sgx.intel.com/enclave": "0",
  "sgx.intel.com/provision": "0"
}
```

```shell
kubectl get no -o json | jq .items[].metadata.labels | grep dsa
```

```json
"intel.feature.node.kubernetes.io/dsa": "true",
```

## Ensure Intel Device Plugins Are Working After Deployment

```shell
kubectl get pods --all-namespaces | grep inteldeviceplugins-system
```

```text
inteldeviceplugins-system       intel-dlb-plugin-2plwt                                        1/1     Running   12 (16m ago)   48m
inteldeviceplugins-system       intel-dsa-plugin-l946v                                        1/1     Running   12 (15m ago)   47m
inteldeviceplugins-system       intel-qat-plugin-7dxmj                                        1/1     Running   1 (13m ago)    49m
inteldeviceplugins-system       intel-sgx-plugin-dwjkg                                        1/1     Running   12 (16m ago)   49m
inteldeviceplugins-system       inteldeviceplugins-controller-manager-59b46b7949-55hvg        2/2     Running   0              10m
```

[nfd ansible roles]: ../../../script/terraform/template/ansible/kubernetes/roles