# MySQL

MySQL is world most popular database. This image is based on [official DockerHub image](https://hub.docker.com/_/mysql) (ver [8.0.31](https://hub.docker.com/layers/library/mysql/8.0.31/images/sha256-cfddf275c8b1ae1583c0f6afb4899d4dbe14111a6462699559a1f4dc8f4d5f6e?context=explore)) and adds Intel optimizations of top of it. This readme focuses on Intel added scripts and configurations.
Please refer to original readme regarding usage of this image.

## Usage
This image can be used almost exactly like the official DockerHub MySQL image, with following differences:

1. Run with `--privileged` flag. \
   Some of optimizations are implemented as low-level kernel configuration, \
   To use it the Container have to be executed with escalated privileges
2. Proposed optimizations are executed during runtime and are added using `entrypoint.sh` \
   This script apply Intel optimizations and then pass to DockerHub's original `docker-entrypoint.sh`.
   When replacing entrypoint remember to execute this script in order to use all optimizations.
3. Some optimizations are passed using `/etc/mysql/conf.d/mysql.conf` file. When adding extra configuration remember to include those already present in `mysql.conf` file.

### Example usage of this image:

``` sh
# build image
docker build . -t mysql8031-base:your-tag --build-arg http_proxy --build-arg https_proxy --build-arg no_proxy --network=host
# run container using built image
docker run --name some-mysql -e MYSQL_ROOT_PASSWORD=my-secret-pw --privileged -d mysql8031-base:your-tag
```

### Contact

- Stage1 Contact: `Longtan Li`; `Junlai Wang`; `Amit Kumar Sah`
- Validation: `Yanping Wu`
- Stage2 Contact: `Khun Ban`

The stack version was created by `Buczak, Jakub` and was based on [HammerDB-TPCC workload](workload/HammerDB-TPCC). Please contact original workload creators (listed above) regarding any questions about this workload.
