### Introduction

The WSF supports OpenEBS or local-static-provisioner as optional Kubernetes plugins for local persistent volumes.

### OpenEBS

#### Request OpenEBS support

Request to install the OpenEBS operator as follows in `cluster-config.yaml.m4`:  

```
cluster:
- labels:
    HAS-SETUP-DISK-SPEC-1: required

terraform:
  k8s_plugins: [openebs]
```

This requests that the OpenEBS operator be installed in the Kubernetes cluster. The default storage class is `local-hostpath`, which uses the storage path `/mnt/disk1`. You can define additional storage class in your workload.

#### Use Persistent Volume 

In your workload Kubernetes deployment script (or in helm charts), declare `PersistentVolumeClaim` and `VolumeMounts` as follows:

```
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: local-hostpath-pvc
spec:
  storageClassName: local-hostpath
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5G

---

apiVersion: batch/v1
kind: Job
metadata:
  name: dummy-benchmark
spec:
  template:
    spec:
      containers:
      - name: dummy-benchmark
        image: IMAGENAME(Dockerfile)
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
        - name: `SCALE'
          value: "SCALE"
        - name: `RETURN_VALUE'
          value: "RETURN_VALUE"
        - name: `SLEEP_TIME'
          value: "SLEEP_TIME"
        volumeMounts:
        - mountPath: /mnt/disk1
          name: local-storage
      volumes:
      - name: local-storage
        persistentVolumeClaim:
          claimName: local-hostpath-pvc
      restartPolicy: Never
```

### Local-Static-Provisioner

#### Request Local-Static-Provisioner Support

Request to install the local-static-provisioner plugin as follows in `cluster-config.yaml.m4`:  

```
cluster:
- labels:
    HAS-SETUP-DISK-SPEC-1: required
  
terraform:
  k8s_plugins:
  - local-storage-provisioner
```

This requests that the local-static-provisioner plugin be installed in the Kubernetes cluster. The default storage class is `local-static-storage`, which uses the storage path `/mnt/disk1`. You can define additional storage class in your workload.

#### Use Persistent Volume 

In your workload Kubernetes deployment script (or in helm charts), declare `PersistentVolumeClaim` and `VolumeMounts` as follows:

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

---

apiVersion: batch/v1
kind: Job
metadata:
  name: dummy-benchmark
spec:
  template:
    spec:
      containers:
      - name: dummy-benchmark
        image: IMAGENAME(Dockerfile)
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
        - name: `SCALE'
          value: "SCALE"
        - name: `RETURN_VALUE'
          value: "RETURN_VALUE"
        - name: `SLEEP_TIME'
          value: "SLEEP_TIME"
        volumeMounts:
        - mountPath: /mnt/disk1
          name: local-storage
      volumes:
      - name: local-storage
        persistentVolumeClaim:
          claimName: local-claim
      restartPolicy: Never
```
