
### Installation

Declare `HAS-SETUP-DISK-SPEC-1` to allocate disk storage to the SUT(s), and specify the `k8s_plugins` option to install the local-static-provisioner:

```
cluster:
- labels:
    HAS-SETUP-DISK-SPEC-1: required
  
terraform:
  k8s_plugins:
  - local-static-provisioner
```

### Use Persistent Volumes

Use the storage class name `local-static-storage` to request persistent volume allocation.  

```
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: local-claim
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: local-static-storage
```

