>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
--- 
Please note that MongoDB depend on software subject to non-open sourcelicenses. If you use or redistribute this software, it is your sole responsibility to ensure compliance with such licenses https://www.mongodb.com/licensing/server-side-public-license.
---

### MongoDB

MongoDB is a source-available cross-platform document-oriented database program. Classified as a NoSQL database program, MongoDB uses JSON-like documents with optional schemas.

### Images

These images can be used almost exactly like the official DockerHub MongoDB image. The MongoDB stack contains 2 docker images; images suffix with amd64 is based on amd64 platform.

- amd64-mongodb604-base : MongoDB Version 6.0.4 on amd64 Platforms.

### Example of Usage

```shell
cd <root dir of wsf>
mkdir -p build && cd build
cmake -DPLATFORM=SPR -DRELEASE=:latest -DREGISTRY=<your registry> -DBENCHMARK=stack/MongoDB -DBACKEND=terraform -DTERRAFORM_SUT=static" -DTERRAFORM_OPTIONS="kubernetes" ..

# build the image
cd stack/MongoDB
make

# list test cases
./ctest.sh -N

# run the unit test
./ctest.sh -R mongodb_sanity$ -VV
```

### See also

The stack version was based on [Mongo-ycsb workload](../../workload/Mongo-ycsb). Please contact original workload creators (listed above) regarding any questions about this workload.
