>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

Apache Cassandra is an open source NoSQL distributed database trusted by thousands of companies for scalability and high availability without compromising performance. Linear scalability and proven fault-tolerance on commodity hardware or cloud infrastructure make it the perfect platform for mission-critical data.

### Docker Build Images

* `JDK14` stands for **openjdk14** and **Cassandra 4.0.6**.

```
docker build --build-arg http_proxy --build-arg https_proxy --build-arg no_proxy -f Dockerfile.2.cassandra.jdk14.ubuntu -t jdk14-cassandra .
```

* `JDK11` stands for **openjdk11** and **Cassandra 4.0.1**.

```
docker build --build-arg http_proxy --build-arg https_proxy --build-arg no_proxy  -f Dockerfile.1.cassandra.jdk11.ubuntu -t jdk11-cassandra .
```

### Docker Run Images

* `JDK14` stands for **openjdk14** and **Cassandra 4.0.6**.

```
docker run -d --rm  -e cassandra_server_addr=*** -e deploy_mode=*** -e cassandra_seeds=*** cassandra-server-jdk14:cassandra
```

* `JDK11` stands for **openjdk11** and **Cassandra 4.0.1**.

```
docker run -d --rm -e cassandra_server_addr=*** -e deploy_mode=*** -e cassandra_seeds=*** cassandra-server-jdk11:cassandra
```

### Environment Variables

Parameters for workload configuration:
* `deploy_mode` - Cassandra deployment can be done in two modes(standalone|cluster). "Standalone" refers to running Cassandra as a single node. "cluster" means running Cassandra with at least one node. Default value is 'standalone'
* `cassandra_server_addr` - Cassandra node address. This address is used for connecting by client.
* `cassandra_seeds` - Cassandra seeds address. It is the value of 'seed_provider' in cassandra.yaml
* `JVM_HEAP_SIZE` - JVM configuration for '-Xms' and '-Xmx'. '-Xms' is min heap and '-Xmx' is max heap sizes, values set to same to avoid stop-the-world GC pauses during resize. If the value are larger than free memory size, it will be adjust to '80% * free memory size'.
* `JVM_GC_TYPE` - JVM garbage collection type. Suggestion is to use '+UseG1GC'. Default value is **'+UseG1GC'**