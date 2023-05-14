### Introduction

This is a base stack for Kafka workload with version 3.2.0. It supports both amd64 and arm64 platforms with JDK8, JDK11 and JDK17 options. It is used by workload [Kafka](../../workload/Kafka/), please refer to it for more comprehesive test scenarios.
### Images
The Kafka stack contains 6 docker images; images with suffix `arm64` are based on arm64 platform, otherwise are based on amd64 platform.
- `kafka-jdk8-base`
- `kafka-jdk11-base`
- `kafka-jdk17-base`
- `kafka-jdk8-base-arm64`
- `kafka-jdk11-base-arm64`
- `kafka-jdk17-base-arm64`


### Example of Usage:
``` 
cd <root dir of wsf>
mkdir build && cd build
cmake -DPLATFORM=SPR -DRELEASE=:latest -DREGISTRY=<your registry> -DBENCHMARK=stack/Kafka -DBACKEND=terraform -DTERRAFORM_SUT=static" -DTERRAFORM_OPTIONS="kubernetes" ..

cd stack/Kafka
make

# list test cases
./ctest.sh -N
# run tests
./ctest.sh -R test_static_kafka-jdk8_version_check -VV
```

