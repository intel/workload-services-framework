# One node cluster configuation
## Clone repositories
**BMRA**
```bash
$ git clone https://github.com/intel/container-experience-kits.git
$ git submodule update --init --recursive
```
and proceed according to guidelines in [repository](https://github.com/intel/container-experience-kits/blob/master/README.md).
> Chosen environmental variable for `PROFILE` is `full_nfv`

> NOTE: If you create one node cluster, it is important to change the filename `<your_path>/containers.orchestrators.kubernetes.container-experience-kits/host_vars/node1.yaml` to `<your_path>/containers.orchestrators.kubernetes.container-experience-kits/host_vars/controller1.yaml`

> Used network plugin: Calico 3.21.4 and MTU=1500. You can set Calico in `<your_path>/containers.orchestrators.kubernetes.container-experience-kits/group_vars/all.yml`:
```bash
kube_network_plugin: calico
calico_version: "v3.21.4"
calico_backend: bird 
wireguard_enabled: false
kube_network_plugin_multus: false
kube_pods_subnet: <subnet>
kube_service_addresses: <service_address>
kube_proxy_mode: iptables
calico_bpf_enabled: false
kube_proxy_remove: false
```

and comment out preflight check in the file: `<your_path>/containers.orchestrators.kubernetes.container-experience-kits/playbooks/preflight.yml`
```bash
#Multus is required for CEK deployment
#- name: assert that Multus is enabled in the config
#  assert:
#    that:
#      - "kube_network_plugin_multus"
#    fail_msg: "Multus must be enabled to have fully functional cluster deployment"
```

Deployment of Istio is automated and defined in `<your_path>/containers.orchestrators.kubernetes.container-experience-kits/group_vars/all.yml` (in BMRA directory):
```
# Service mesh deployment
        # https://istio.io/latest/docs/setup/install/istioctl/
 
        # for all available options, please, refer to the 'roles/service_mesh_install/vars/main.yml;
        service_mesh:
            enabled: true
            profile: default
```

**CPU Power Management**

There are scripts to manage CPU power and performance settings in *CommsPowerManagement* [repository](https://github.com/intel/CommsPowerManagement).
Recommended script is *power.py* to set uncore frequency, p-state and frequency governor. Clone to the machines on which you want to set parameters.

```bash
$ git clone https://github.com/intel/CommsPowerManagement.git
```
## Kubernetes CPU Management Policies
The CPU manager static policy allows pods with QoS: Guaranteed access to exclusive CPUs on the node also it is preferable to explicitly assign the cores to kublet itself.
This can be configured in the file: `/var/lib/kubelet/kubeadm-flags.env`

```
KUBELET_KUBEADM_ARGS="--network-plugin=cni --pod-infra-container-image=k8s.gcr.io/pause:3.5 --max-pods=240 --reserved-cpus=94-95 --cpu-manager-policy static"
```
To make sure all pods are set to the correct policy you can use the command below:

```
$ kubectl describe pods | grep QoS
```
If the output of the above command shows for all nighthawk server pods:
```
QoS Class:                   Guaranteed
QoS Class:                   Guaranteed
...
QoS Class:                   Guaranteed
QoS Class:                   Guaranteed
```
It means that Quality of Service - [QoS](https://kubernetes.io/docs/tasks/configure-pod-container/quality-service-pod/) for specific pods is correctly defined.
Else, we notice such output (or any other output):
```
QoS Class:                   Burstable
QoS Class:                   Burstable
...
QoS Class:                   Burstable
QoS Class:                   Burstable
```
We should then proceed the following steps in order to set proper values for CPU and memory request/limit in the config map below:
```bash
$ kubectl edit cm istio-sidecar-injector -n istio-system
```
and change the values for `"resources"` to 1 CPU and memory: 1 Gi (both are applicable for `"limits"` and `"requests"`):
```
    "proxy": {
      "autoInject": "enabled",
      "clusterDomain": "cluster.local",
      "componentLogLevel": "misc:error",
      "enableCoreDump": false,
      "excludeIPRanges": "",
      "excludeInboundPorts": "",
      "excludeOutboundPorts": "",
      "holdApplicationUntilProxyStarts": false,
      "image": "proxyv2",
      "includeIPRanges": "*",
      "includeInboundPorts": "*",
      "includeOutboundPorts": "",
      "logLevel": "warning",
      "privileged": false,
      "readinessFailureThreshold": 30,
      "readinessInitialDelaySeconds": 1,
      "readinessPeriodSeconds": 2,
      "resources": {
        "limits": {
          "cpu": "1",
          "memory": "1Gi"
        },
        "requests": {
          "cpu": "1",
          "memory": "1Gi"
        }
      },
      "statusPort": 15020,
      "tracer": "zipkin"
    },
    "proxy_init": {
      "image": "proxyv2",
      "resources": {
        "limits": {
          "cpu": "2000m",
          "memory": "1024Mi"
        },
        "requests": {
          "cpu": "10m",
          "memory": "10Mi"
        }
      }
    },
```
Then, reload/do rollout for sm-nighthawk-server deployment
```bash
$ kubectl rollout restart deployment sm-nighthawk-server
```
Wait till all pods are in `Running` state. If so, check again the QoS. There should be `Guaranteed` for all nighthawk server pods now.

## Cluster configuration

The [config](https://github.com/intel-sandbox/benchmark_release/tree/main/config) folder contains several configuration files of Istio and Nighthawk services for the measurement.
The files can be used to deploy the appropriate configuration. The example gives the http1 configuration.

Nighthawk server configmap:
```
$ kubectl create configmap nighthawk --from-file nighthawk-server-cm.yaml
```

Nighthawk server deployment (replace hostname `localhost` with your node name in `nighthawk-server-deploy.yaml` for both keys: `kubernetes.io/hostname`):
```
$ kubectl apply -f nighthawk-server-deploy.yaml
```

Nighthawk server service:
```
$ kubectl apply -f nighthawk_svc_http1.yaml
```

Istio gateway and virtual service:
```
$ kubectl apply -f istio-gateway_http1.yaml
```

Istio ingress gateway e.q running on 8 vCPU:
```
$ kubectl apply -f istio-ingressgateway-8vCPU.yaml
```

Enable sidecar injection:
```
$ kubectl label namespace default istio-injection=enabled
```

Change Istio horizontal scaling (targetCPUUtilizationPercentage) from 80% to 100%.
```
$ kubectl edit -n istio-system horizontalpodautoscaler.autoscaling/istio-ingressgateway
```

It's required to add an additional port to istio-ingressgateway service and change type to NodePort:
```
$ kubectl edit svc -n istio-system istio-ingressgateway
```
<pre>
apiVersion: v1
kind: Service
metadata:
  annotations:
...
  ports:
  - name: status-port
    nodePort: 31075
    port: 15021
    protocol: TCP
    targetPort: 15021
  - name: http2
    nodePort: 32245
    port: 80
    protocol: TCP
    targetPort: 8080
  - name: https
    nodePort: 31124
    port: 443
    protocol: TCP
    targetPort: 8443
  <b>- name: nighthawk
    nodePort: 32222
    port: 10000
    protocol: TCP
    targetPort: 10000</b>
  selector:
    app: istio-ingressgateway
    istio: ingressgateway
  sessionAffinity: None
  <b>type: NodePort</b>
status:
  loadBalancer: {}

</pre>
