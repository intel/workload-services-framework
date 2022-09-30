
The `build.sh` script performs the workload build. Since the docker build process is [standardized](dockerfile.md), there is usually no need to customize it. You can use the following template as is:  

```
#!/bin/bash -e

DIR="$(dirname "$(readlink -f "$0")")"
. "$DIR"/../../script/build.sh
```

In some cases, the `script/buid.sh` can be customized as follows:
- **`FIND_OPTIONS`**: Specify any custom arguments to the `find` program to locate the set of Dockerfiles for building the docker images and for listing the BOMs.  
- **`DOCKER_CONTEXT`**: Optionally specify a or an array of relative directory names where the Dockerfiles are located. By default, the Dockerfiles are assumed to be located directly under the workload directory.   

### Build Dependencies

If your workload depends on some common software stacks, simply invoke the corresponding software stack's `build.sh`. For example, if your image depends on `QAT-Setup`, your `build.sh` can be something like below:

```
#!/bin/bash -e

DIR="$(dirname "$(readlink -f "$0")")"

# build QAT-Setup
STACK="qat_setup" "$DIR"/../../stack/QAT-Setup/build.sh $@

# build our image(s)
. "$DIR"/../../script/build.sh
```
