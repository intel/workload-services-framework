### Introduction

It is not a general requirement to align container time zone with what is on the SUT host. However, if you need to sync the container date time with an external PDU, it is desired to align the container time zone with what is on the SUT host.  

The time zone information is in the file `/etc/localtime` and optionally with an environment variable `TZ`. 

### Docker Execution

For workloads that run with docker, the validation script automatically exposes the `TZ` environment variable. 

The workload should perform the following steps to properly use the `TZ` value:
- Install the `tzdata` package. 
- Link `/etc/localtime`: `ln -sf /usr/share/zoneinfo/$TZ /etc/localtime`.  

Most of the time, however, you can bypass the above steps by just mounting `/etc/localtime` from the host, i.e., specify `-v /etc/localtime:/etc/localtime:ro` in `DOCKER_OPTIONS`.  

### Docker Compose

The `TZ` environment variable is exposed to the `docker-compose` file. You should use it in your `docker-compose` file:
```
services:
  my-service:
    environment:
      TZ: ${TZ}
```

### Kubernetes

The validation script automatically exposes a `workload-config` secret in your namespace. The secret contains:   
- `TZ`: The time zone string.

You can configure it in your Kubernetes/Helm scripts:

```
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  containers:
  - name: my-pod
    image: my-pod-image
    env:
      - name: TZ
        valueFrom:
          SecretKeyRef:
            name: workload-config
            key: TZ
```
