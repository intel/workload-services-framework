

The workload Dockerfile must meet certain requirements to facilitate image build, validation execution and data collection.  

### Use Template

You can use `m4` template in constructing Dockerfles, which avoids duplication of identical steps. Any files with the `.m4` suffix will be replaced with the corresponding files without the suffix, during the build process.  

### Set Build Order

If there are multiple Dockerfiles under the workload directory, the build order is determined by the filename pattern of the Dockerfile: `Dockerfile.[1-9].<string>`. The bigger the number in the middle of the filename, the earlier that the build script builds the Dockerfile. If there are two Dockerfiles with the same number, the build order is platform specific.  

### Specify Image Name

The first line of the Dockerfile is used to specify the docker image name, as follows:   

Final image:   
```
# resnet_50
...
```

Intermediate image:  
```
## resnet_50_model
```

Any final images will be pushed to the docker registry. Any intermediate images will be left on the build machine. As a convention, the image name uses the following pattern: `[<platform>-]<workload>-<other names>`. The platform prefix is a must have if the image is platform specific, and optional if the image can run on any platform.  

### List Ingredients 

Any significent ingredients used in the workload must be marked with the `ARG` statement, so that we can easily list ingredients of a workload:  

```
ARG IPP_CRYPTO_VER="ippcp_2020u3"
ARG IPP_CRYPTO_REPO=https://github.com/intel/ipp-crypto.git
...
```

The following `ARG` suffixes are supported:  
- **_REPO/_REPOSITORY**: Specify the ingredient source repository location.  
- **_VER/_VERSION**: Specify the ingredient version.  
- **_IMG/_IMAGE**: Specify an ingredient docker image.  
- **_PKG/_PACKAGE**: Specify an ingredient OS package, such as deb or rpm.  

> _VER and the corresponding _REPO/_PKACAGE/_IMAGE must be in a pair and in order to properly show up in the Wiki ingredient table. For example, if you define `OS_VER`, then there should be a following `OS_IMAGE` definition.  

### Export Status & Logs

It is the workload developer's responsibility to design how to start the workload and how to stop the workload. However, it is a common requirement for the validation runtime to reliably collect execution logs and any telemetry data for analyzing the results.  

#### Export to FIFO 

The workload image must create a fifo `/export-logs` and then archive (1) the workload exit code (in `status`) and (2) any workload-specifc logs to the fifo. The workload exit code is mandatory. Workload logs can be used to generate KPIs.  

```
RUN mkfifo /export-logs
CMD (<run-workload.sh>; echo $? > status) 2>&1 | tee output.logs && \
    tar cf /export-logs status output.logs && \
    sleep infinity
```

#### Import from FIFO

The validation backend (script/validate.sh) imports the logs data through the fifo, as follows:   

```
# docker
docker exec <container-id> cat /export-logs | tar xf -
```
```
# kubernetes
kubectl exec <pod-id> cat /export-logs | tar xf -
```

The above command blocks if the workload execution is in progress and exits after the execution is completed (thus it is time for cleanup.)  

### Reserved Feature

Do not use `ENTRYPOINT` in the Dockerfile. This is a reserved feature for future extension. 

### See Also

- [How to Create a Workload](workload.md)  
- [Provisioning Specification](cluster-config.md)  

