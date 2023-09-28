# Cmake Configuration
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

This will help to generate native build tool that uses platform independent configuration
files to generate native build tool files. You can execute inside `build` directory.

## Build examples

```shell
cd build
cmake -DREGISTRY=xxyyzz.com:1234 ..
```

## Customize the Build Process

You can use the following build options to customize the build process:

- **PLATFORM**: Specify the platform names. See [`platforms`][platforms] for the list of platforms.
- **REGISTRY**: Must end with forward slash (`/`). Specify the privacy docker registry URL. If specified, all built images will be pushed to given docker registry.
- **REGISTRY_AUTH**: Specify the registry authentication method. The only supported value is `docker`, which uses the docker configuration file.
- **RELEASE**: Must begin with colon (`:`). Specify the release version. All built images will be tagged with it. Defaults to `:latest`
- **BACKEND**: Specify the validation backend: [`docker`][docker], [`kubernetes`][kubernetes], or [`terraform`][terraform].
  - **TERRAFORM_OPTIONS**: Specify the `terraform` options.
  - **TERRAFORM_SUT**: Specify the target System Under Test (SUT) list.
- **TIMEOUT**: Specify the validation timeout, which contains the execution timeout and docker pull timeout. Default to 28800,300 seconds.
- **BENCHMARK**: Specify a workload pattern. Workloads not matching the pattern will be disabled.
- **SPOT_INSTANCE**: If specified, overwrite the `spot_instance` variable in the Cloud configuration files.

```shell
cmake -DPLATFORM=xyz -DREGISTRY=xxyyzz.com:1234 -DBACKEND=xxyzz ..
```

## Command Make Targets

- **bom**: Print out the BOM list of each workload.
- **clean**: Purge the `logs`.

```shell
cd build
cmake ..
make bom
```

## See Also

- [Docker Engine][Docker Engine]
- [Kubernetes Cluster][Kubernetes Cluster]
- [Terraform Setup][Terraform Setup]

[platforms]: ../../../workload/platforms
[docker]: ../preparing-infrastructure/setup-docker.md
[kubernetes]: ../preparing-infrastructure/setup-kubernetes.md
[terraform]: ../preparing-infrastructure/setup-terraform.md
[Docker Engine]: ../preparing-infrastructure/setup-docker.md
[Kubernetes Cluster]: ../preparing-infrastructure/setup-kubernetes.md
[Terraform Setup]: ../preparing-infrastructure/setup-terraform.md