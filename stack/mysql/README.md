>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
# MySQL

MySQL is world most popular database. This image is based on [official DockerHub image](https://hub.docker.com/_/mysql) (ver [8.0.36](https://hub.docker.com/layers/library/mysql/8.0.36/images/sha256-4d1049b49769005fa7f83f30534bcd6b77877ec22c0737a170d5aa0ea77fb27f?context=explore)). This readme focuses on Intel added scripts and configurations.
Please refer to original readme regarding usage of this image.

## Usage
This image can be used almost exactly like the official DockerHub MySQL image, with following differences:

1. Run with `--privileged` flag. \
   Some of optimizations are implemented as low-level kernel configuration, \
   To use it the Container have to be executed with escalated privileges
2. MySQL configurations are passed using `/etc/mysql/conf.d/mysql.conf` file. When adding extra configuration remember to include those already present in `mysql.conf` file.

### Example usage of this image:

``` sh
# build image
docker build . -t mysql8036-oh:your-tag --build-arg http_proxy --build-arg https_proxy --build-arg no_proxy --network=host
# run container using built image
docker run --name some-mysql -e MYSQL_ROOT_PASSWORD=my-secret-pw --privileged -d mysql8036-oh:your-tag
```
