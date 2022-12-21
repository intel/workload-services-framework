# Intel® Dynamic Load Balancer 

"Intel® Dynamic Load Balancer (Intel® DLB) is a hardware managed system of queues and arbiters connecting producers and consumers. It is a PCI device envisaged to live in the server CPU uncore and can interact with software running on cores, and potentially with other devices."

https://www.intel.com/content/www/us/en/download/686372/intel-dynamic-load-balancer.html


## Installation guide

### 1.) DLB driver

Download and build DLB driver base on user guide:
https://www.intel.com/content/www/us/en/download/686372/intel-dynamic-load-balancer.html 

```
$ tar xfJ dlb_linux_src_release_<rel-id>_<rel-date>.txz
$ cd dlb/driver/dlb2
$ make

$ modprobe mdev
$ modprobe vfio_mdev
$ cd driver/dlb2
$ insmod dlb2.ko
```
Verify driver installation:
```
$ lsmod | grep dlb
dlb2                  364544  0

$ ls -1 /dev/dlb*
/dev/dlb0
/dev/dlb1
```

### 2.) Intel DLB device plugin for Kubernetes

This Intel DLB device plugin provides support for Intel DLB devices under Kubernetes.
https://github.com/intel/intel-device-plugins-for-kubernetes/blob/main/cmd/dlb_plugin/README.md

```
$ kubectl apply -k https://github.com/intel/intel-device-plugins-for-kubernetes/deployments/dlb_plugin?ref=v0.24.0
```
Verify plugin registration:
```
$ kubectl get nodes -o go-template='{{range .items}}{{.metadata.name}}{{"\n"}}{{range $k,$v:=.status.allocatable}}{{"  "}}{{$k}}{{": "}}{{$v}}{{"\n"}}{{end}}{{end}}' | grep '^\([^ ]\)\|\(  dlb\)'

node1
  dlb.intel.com/pf: 2
```

### 3.) Build Istio Proxy - Envoy

Build Envoy manually by istio proxy repository that containing changes from envoy master branch in order to have DLB support implemented in Envoy.
```
$ git clone https://github.com/istio/proxy
```
Change value BUILD_WITH_CONTAINER from 0 to 1 in file Makefile.overrides.mk.

```
BUILD_WITH_CONTAINER ?= 1
```
It's required to add a two lines of code in the file bazel/extension_config/extensions_build_config.bzl:
```
    ENVOY_CONTRIB_EXTENSIONS = {
...
    "envoy.network.connection_balance.dlb":                     "//contrib/network/connection_balance/dlb/source:connection_balancer",
 
...
 
    ISTIO_ENABLED_CONTRIB_EXTENSIONS = [
...
    "envoy.network.connection_balance.dlb",
```
Build:

```
make build_envoy
```

### 4.) Build Istio

Build the whole Istio and put the previously built Envoy binary file into the proxyv2 image.
```
$ git clone https://github.com/istio/istio
$ make build
$ make docker
```
Tag built images with the new version e.g 1.16-dev
```
$ docker tag localhost:5000/*:latest istio/*:1.16-dev
```
Last step is making upgrade by istioctl:
```
$ ./istioctl upgrade
```

### 5.) Enable DLB

The next step is assignment the DLB physical function (dlb.intel.com/pf) to ingress deployment.

```
$ kubectl apply -f istio-ingressgateway-DLB-2vCPU.yaml
```
and applying the following setting of the Envoy filter:

```
$ kubectl apply -f envoy-filter-dlb.yaml
```
envoy-filter-dlb.yaml:
```
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: ingressgateway-dlb
  namespace: istio-system
spec:
  workloadSelector:
    labels:
      istio: ingressgateway
  configPatches:
  - applyTo: LISTENER
    match:
      context: GATEWAY
    patch:
      operation: MERGE
      value:
        connection_balance_config:
          extend_balance:
            name: envoy.network.connection_balance.dlb
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.network.connection_balance.dlb.v3alpha.Dlb
```
Verify filter registration:
```
$ kubectl describe envoyfilter.networking.istio.io/ingressgateway-dlb -n istio-system

Name:         ingressgateway-dlb
Namespace:    istio-system
Labels:       <none>
Annotations:  <none>
API Version:  networking.istio.io/v1alpha3
Kind:         EnvoyFilter
Metadata:
  Creation Timestamp:  2022-11-29T12:03:23Z
  Generation:          1
  Managed Fields:
    API Version:  networking.istio.io/v1alpha3
    Fields Type:  FieldsV1
    fieldsV1:
      f:metadata:
        f:annotations:
          .:
          f:kubectl.kubernetes.io/last-applied-configuration:
      f:spec:
        .:
        f:configPatches:
        f:workloadSelector:
          .:
          f:labels:
            .:
            f:istio:
    Manager:         kubectl-client-side-apply
    Operation:       Update
    Time:            2022-11-29T12:03:23Z
  Resource Version:  8095896
  UID:               2556a32f-e69f-4ee6-8062-2a123d2b6fd9
Spec:
  Config Patches:
    Apply To:  LISTENER
    Match:
      Context:  GATEWAY
    Patch:
      Operation:  MERGE
      Value:
        connection_balance_config:
          extend_balance:
            Name:  envoy.network.connection_balance.dlb
            typed_config:
              @type:  type.googleapis.com/envoy.extensions.network.connection_balance.dlb.v3alpha.Dlb
  Workload Selector:
    Labels:
      Istio:  ingressgateway
Events:       <none>
```


### Useful links:

https://intel.github.io/intel-device-plugins-for-kubernetes/cmd/dlb_plugin/README.html

https://www.envoyproxy.io/docs/envoy/latest/configuration/other_features/dlb#config-connection-balance-dlb

https://www.envoyproxy.io/docs/envoy/latest/api-v3/extensions/network/connection_balance/dlb/v3alpha/dlb.proto#extension-envoy-network-connection-balance-dlb

https://github.com/intel/intel-device-plugins-for-kubernetes