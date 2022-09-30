
The `kubernetes-config.yaml` script is a manifest that describes how the workload container(s) should be scheduled (to the machine cluster described by `cluster-config.yaml`.) This is the standard Kubernetes script.  

```
include(config.m4)
...
spec:
...
    spec:
      containers:
      - name: database
        image: IMAGENAME(wordpress5mt-defn(`DATABASE'))
...
```

where the `IMAGENAME` macro expands the image name to include the `REGISTRY` prefix and the `RELEASE` versions.   

#### About `imagePullPolicy`

To ensure that the validation runs always on the latest code, it is recommended to use `imagePullPolicy: Always`. However, this requires to use a private docker registry. In local development, `imagePullPolicy: IfNotPresent` is desired. The `config.m4` utility provides a macro, `IMAGEPOLICY`, to switch between `Always` and `IfNotPresent` depending on the `REGISTRY` setting.  

```
...
    spec:
      containers:
      - name: database
        image: IMAGENAME(wordpress5mt-defn(`DATABASE'))
        imagePullPolicy: IMAGEPOLICY(Always)
...
```

Not all docker images are built equally. Some are less frequently updated and less sensitive to performance. Thus it is preferrable to use `imagePullPolicy: IfNotPresent` in all cases.   

#### About `podAntiAffinity`

To spread the pods onto different nodes, use `podAntiAffinity` as follows:  

```
...
    metadata:
      labels:
        app: foo
    spec:
       PODANTIAFFINITY(preferred,app,foo)
...
```

where the convenient macro `PODANTIAFFINITY` expands to 

```
...
    metadata:
      labels:
        app: foo
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 1
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - foo
              topologyKey: "kubernetes.io/hostname"
...
```

#### About `CLUSTER_WORKERS`

Some workload uses the Kubernetes operator to launch new Kubernetes pods during the workload execution. It is critical to restrict any newly launched pods to be within the cluster workers that the workload is assigned to run. Define the `CLUSTER_WORKERS` environment variable as follows to retrieve the information about the list of worker node IP addresses.   

```
    spec:
      containers:
      - name: foo
        image: IMAGENAME(foo)
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
        - name: CLUSTER_WORKERS
          value: ""
```

The value will be replaced with the list of worker node IP addresses, separated by `,`, if the workload is restricted to a set of worker nodes. The value will remain unchanged if there is no such restriction.  

