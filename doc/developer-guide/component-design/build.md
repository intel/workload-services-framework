# Building a workload

The `build.sh` script performs the build of a workload.

Since the process is standardized, there is usually no need to customize it. You can use the following template as is to call the ready-made `build.sh` from under the `script` folder:

```shell
#!/bin/bash -e

DIR="$(dirname "$(readlink -f "$0")")"
. "$DIR"/../../script/build.sh
```

## Customizing with switches

In some cases, the `script/build.sh` can be customized as follows:
- **`BUILD_FILES`**: Specify an array of base file names to be included in the build.
- **`BUILD_OPTIONS`**: Specify any custom arguments to the docker build command.
- **`BUILD_CONTEXT`**: Optionally specify a relative directory name or an array of relative directory names, where the Dockerfiles are located. By default, the Dockerfiles are assumed to be located directly under the workload directory.
- **`FIND_OPTIONS`**: Specify any custom arguments to the `find` program to locate the set of Dockerfiles for building the docker images and for listing the BOMs.

## Template Expansion

The `build.sh` script automatically performs template expansion if you have templates defined in either the `.m4` format or the `.j2` format, except those under the `template` directory.

For example, if you define `Dockerfile.m4` or `Dockerfile.j2`, the script will expand the template to `Dockerfile` before building the docker images.

> More about templating systems can be found under [Templating systems][Templating systems].

## Build Dependencies

If your workload depends on one of the [common software stacks][common software stacks], invoke the corresponding software stack's `build.sh`.

For example, if your image depends on `QAT-Setup`, your `build.sh` can be something like below:

```shell
#!/bin/bash -e

DIR="$(dirname "$(readlink -f "$0")")"

# build QAT-Setup (added section)
STACK="qat_setup" "$DIR"/../../stack/QAT-Setup/build.sh $@

# build our image(s)
. "$DIR"/../../script/build.sh
```

[Templating systems]: template.md
[common software stacks]: stack.md