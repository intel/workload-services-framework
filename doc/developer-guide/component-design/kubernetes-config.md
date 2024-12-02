# Containers scheduling

The `kubernetes-config.yaml` script is a manifest that describes how the workload container(s) should be scheduled (to the machine cluster described by `cluster-config.yaml`.) This is the standard Kubernetes script.  

## Templating possibilities

You can choose to write `kubernetes-config.yaml` in any of the following formats:
- `kubernetes-config.yaml`: For simple workloads, you can directly write the Kubernetes deployment scripts.  
- `kubernetes-config.yaml.m4`: Use the `.m4` template to add conditional statements in the Kuberentes deployment scripts.  
- `kuberentes-config.yaml.j2`: Use the `.j2` template to add conditional statements in the Kubernetes deployment scripts.  
- `helm charts`: For complex deployment scripts, you can use any helm charts under the `helm` directory.   

### Image Name

The container image in `kubernetes-config.yaml` should use the full name in the format of `<REGISTRY><image-name><IMAGESUFFIX><RELEASE>`, where `<REGISTRY>` is the docker registry URL (if any), `<IMAGESUFFIX>` is the platform suffix, and the `<RELEASE>` is the release version, (or `:latest` if not defined.)

If you use the `.m4` template, the `IMAGENAME` macro can expand an image name to include the registry and release information:

```m4
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

If you use the `.j2` template or helm charts, you must write the image name as follows:

```jinja
...
spec:
...
    spec:
      containers:
      - name: database
        image: "{{ REGISTRY }}wordpress5mt-{{ DATABASE }}{{ IMAGESUFFIX }}{{ RELEASE }}"
...
```

### About `imagePullPolicy`

To ensure that the validation runs always on the latest code, it is recommended to use `imagePullPolicy: Always`. However, this requires to use a private docker registry. In a local development, `imagePullPolicy: IfNotPresent` is desired. 

If you use the `.m4`, `.j2`, or helm template, the variable `IMAGEPULLPOLICY` is defined to be either `IfNotPresent` or `Always`.  

```m4
...
    spec:
      containers:
      - name: database
        image: IMAGENAME(wordpress5mt-defn(`DATABASE'))
        imagePullPolicy: IMAGEPULLPOLICY
...
```

If you use the `.j2` template, use the following conditions:

```jinja
...
spec:
...
    spec:
      containers:
      - name: database
        image: "{{ REGISTRY }}wordpress5mt-{{ DATABASE }}{{ IMAGESUFFIX }}{{ RELEASE }}"
        imagePullPolicy: "{{ IMAGEPULLPOLICY }}"
...
```

If you use helm charts, use the following conditions:

```jinja
...
spec:
...
    spec:
      containers:
      - name: database
        image: "{{ REGISTRY }}wordpress5mt-{{ DATABASE }}{{ IMAGESUFFIX }}{{ RELEASE }}"
        imagePullPolicy: "{{ IMAGEPULLPOLICY }}"
...
```

Not all docker images are built equally. Some are less frequently updated and less sensitive to performance. Thus it is preferrable to use `imagePullPolicy: IfNotPresent` in all cases.   

### About `podAntiAffinity`

To spread the pods onto different nodes, use `podAntiAffinity` as follows:  

```yaml
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

If you use the `.m4` template, you can use the `PODANTIAFFINITY` macro:

```m4
...
    metadata:
      labels:
        app: foo
    spec:
       PODANTIAFFINITY(preferred,app,foo)
...
```

If you use the `.j2` template or helm charts, there is no convenient function for above. You have to write the `podAntiAffinity` terms in explicit.  

## See Also

- [Requirements for Internet Hosts - RFC-1123](https://www.rfc-editor.org/rfc/rfc1123)
- [Choosing a name for your computer - RFC-1178](http://www.faqs.org/rfcs/rfc1178.html)
- [K8s Label - syntax and character set](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set)

