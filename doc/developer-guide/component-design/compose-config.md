# Scheduling containers

The `compose-config.yaml` script is a manifest that describes how the workload container(s) should be scheduled (to the machine cluster described by `cluster-config.yaml`.) This is the standard docker-compose script.  

You can choose to write `compose-config.yaml` in any of the following formats:
- `compose-config.yaml`: For simple workloads, you can directly write the docker-compose script.  
- `compose-config.yaml.m4`: Use the `.m4` template to add conditional statements in the docker-compose script.  
- `compose-config.yaml.j2`: Use the `.j2` template to add conditional statements in the docker-compose script.  

## Image Name

The container image in `compose-config.yaml` should use the full name in the format of `<REGISTRY><image-name><RELEASE>`, where `<REGISTRY>` is the docker registry URL (if any) and the `<RELEASE>` is the release version, (or `:latest` if not defined.)

If you use the `.m4` template, the `IMAGENAME` macro can expand an image name to include the registry and release information:

```m4
include(config.m4)
...
services:
  dummy-benchmark:
    image: IMAGENAME(Dockerfile)
...
```
where `dummy-benchmark` must match what defined in `JOB_FILTER`.  

If you use the `.j2` template, you must write the image name as follows:

```jinja
...
services:
  dummy-benchmark:
    image: "{{ RELEASE }}dummy{{ RELEASE }}"
...
```

