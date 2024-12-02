# Dockerfile

The workload Dockerfile must meet certain requirements to facilitate image build, validation execution and data collection.  

## Use Template

You can use `m4` template in constructing Dockerfiles, which avoids duplication of identical steps. Any files with the `.m4` suffix will be replaced with the corresponding files without the suffix, during the build process.  

<!-- TODO: Ensure Jinja2 templating for Dockerfile is described -->

## Set Build Order

If there are multiple Dockerfiles under the workload directory, the build order is determined by the filename pattern of the Dockerfile: `Dockerfile.[1-9].<string>`. The bigger the number in the middle of the filename, the earlier that the build script builds the Dockerfile. If there are two Dockerfiles with the same number, the build order is platform-specific.

Filename:

```text
Dockerfile.1.xyz
```

## Specify Image Name

The first line of the Dockerfile is used to specify the docker image name, as follows:

> **Note:** If optional `# syntax=` line is added, it should preceed the name line.

Final images, that are pushed to the docker registry:

```Dockerfile
# resnet_50
...
```

Intermediate images, that are not pushed to the docker registry:

```Dockerfile
## resnet_50_model
```

Output:
```text
REPOSITORY            TAG
resnet_50             latest
resnet_50_model       latest
```

> **Note:** Image's `TAG` may differ based on the `RELEASE` setting. If unspecified, `latest` is used.

> **Note:** For `ARMv*` platforms, the image names will be appended with an `-arm64` suffix, so that they can coexist with `x86` platform images on the same host.

## Naming Convention:

As a convention, the image name uses the following pattern: `[<platform>-]<workload>-<other names>`, and it must be unique. The platform prefix is a must have if the image is platform specific, and optional if the image can run on any platform.  

## List Ingredients 

Any significant ingredients used in the workload must be marked with the `ARG` statement, so that we can easily list ingredients of a workload, for example:

```Dockerfile
ARG IPP_CRYPTO_VER="ippcp_2020u3"
ARG IPP_CRYPTO_REPO=https://github.com/intel/ipp-crypto.git
#...
```

The following `ARG` suffixes are supported:
- **`_REPO`** or **`_REPOSITORY`**: Specify the ingredient source repository location.
- **`_VER`** or **`_VERSION`**: Specify the ingredient version.
- **`_IMG`** or **`_IMAGE`**: Specify an ingredient docker image.
- **`_PKG`** or **`_PACKAGE`**: Specify an ingredient OS package, such as deb or rpm.

> `_VER` and the corresponding `_REPO`/`_PACKAGE`/`_IMAGE` must be in a pair to properly show up in the Wiki ingredient table. For example, if you define `OS_VER`, then there should be an `OS_IMAGE` definition.

## Export Status & Logs

It is the workload developer's responsibility to design how to start the workload and how to stop the workload. However, it is a common requirement for the validation runtime to reliably collect execution logs and any telemetry data for analysing the results.

### Export to FIFO 

The workload image must create a FIFO under `/export-logs` path, and then archive:

- The workload exit code (in `status`)
    > **Note:** Any exit code different than `0` returned in `status` defines a failed execution.
- **and** any workload-specific logs, which can be used to generate performance indicators

> **Note:** Path to FIFO can be overwrote from `/export-logs`, by setting the `EXPORT_LOGS=/my/custom/path` variable in `validate.sh` to point an absolute path to the FIFO inside the container.

For example:

```Dockerfile
RUN mkfifo /export-logs
CMD (./run-workload.sh; echo $? > status) 2>&1 | tee output.logs && \
    tar cf /export-logs status output.logs && \
    sleep infinity
```

1. `RUN mkfifo /export-logs` creates a FIFO for logs export;
2. `CMD` executes and collects logs:
    1. `(./run-workload.sh;` executes workload;
    2. `echo $? > status)` sends exit code to status;
    3. `2>&1` points standard error output to standard output;
    4. `| tee output.logs` sends the output to both terminal and `output.logs` file;
    5. `tar cf /export-logs status output.logs` creates a tarball archive with `status` and `output.logs` inside the `/export-logs` queue;
    6. `sleep infinity` is mandatory to hold the container for logs retrieval.

Alternatively, a list of files can be `echo`ed to `/export-logs`, for example:

```Dockerfile
RUN mkfifo /export-logs
CMD (./run-workload.sh; echo $? > status) 2>&1 | tee output.logs && \
    echo "status output.logs" > /export-logs && \
    sleep infinity
```

The difference is only within point 5 of `CMD`: `echo "status output.logs" > /export-logs` sends the list of files to the queue.

### Import from FIFO

The validation backend (`script/validate.sh`) imports the logs data through the FIFO, as follows for any docker execution:

```shell
# docker
docker exec <container-id> sh -c 'cat /export-logs > /tmp/tmp.tar; tar tf /tmp/tmp.tar > /dev/null && cat /tmp/tmp.tar || tar cf - $(cat /tmp/tmp.tar)' | tar xf -
```

```shell
# kubernetes
kubectl exec <pod-id> sh -c 'cat /export-logs > /tmp/tmp.tar; tar tf /tmp/tmp.tar > /dev/null && cat /tmp/tmp.tar || tar cf - $(cat /tmp/tmp.tar)' | tar xf -
```

The above command blocks, when the workload execution is in progress, and exits, after the workload is completed (thus it is time for cleanup). 

<!-- TODO: Describe the mechanism in a more step-by-step approach -->

## `ENTRYPOINT` reserved feature

Do not use `ENTRYPOINT` in the Dockerfile. This is a reserved feature for future extension.

## Workaround the `software.intel.com` proxy issue

The Intel proxy setting includes `intel.com` in the `no_proxy` setting. This is generally an ok solution but `software.intel.com` is an exception, which must go through the proxy. Use the following workaround on the specific command that you need to bypass the `intel.com` restriction:  

```Dockerfile
RUN no_proxy=$(echo $no_proxy | tr ',' '\n' | grep -v -E '^.?intel.com$' | tr '\n' ',') yum install -y intel-hpckit
```

## See Also

- [How to Create a Workload][How to Create a Workload]
- [Provisioning Specification][Provisioning Specification]
- [Workload with Dataset][Workload with Dataset]

[How to Create a Workload]: workload.md
[Provisioning Specification]: cluster-config.md
[Dockerfile-mount]: https://docs.docker.com/engine/reference/builder/#run---mounttypesecret
