## Apache CASSANDRA
[Apache Cassandra](https://cassandra.apache.org/_/index.html) is an open source distributed NoSQL database management system designed to handle large amounts of data across many commodity servers, providing high availability with no single point of failure. It is a type of NoSQL database that provides a mechanism for storage and retrieval of data that is modeled in means other than the tabular relations used in relational databases. Cassandra offers robust support for clusters spanning multiple datacenters, with asynchronous masterless replication allowing low latency operations for all clients. It is scalable, fault-tolerant, and consistent. 


#cassandra, #nosql, #distributed, #decentralized, #storage, #database, #dbms, #database management system

## Software Components
Table 1 lists the necessary software components.
The descending row order represents the install sequence. 
The recommended component version and download location are also provided.

JDK11 means use openjdk11 and Cassandra 4.1.0.

JDK14 means use openjdk14 and Cassandra 4.0.6.

Table 1: Software Components
| Component| Version |
| :---        |    :----:   |
| UBUNTU | [v22.04](https://ubuntu.com/) |
| JDK 11 | [jdk11](https://download.java.net/java/ga/jdk11/openjdk-11_linux-x64_bin.tar.gz) |
| CASSANDRA | [v4.1.0](https://archive.apache.org/dist/cassandra/4.1.0/apache-cassandra-4.1.0-bin.tar.gz) |
| JDK 14 | [jdk14](https://download.java.net/java/GA/jdk14/076bab302c7b4508975440c56f6cc26a/36/GPL/openjdk-14_linux-x64_bin.tar.gz) |
| CASSANDRA | [v4.0.6](https://archive.apache.org/dist/cassandra/4.0.6/apache-cassandra-4.0.6-bin.tar.gz) |

## Configuration Snippets
This section contains code snippets on build instructions for software components.

Note: Common Linux utilities, such as docker, git, wget, will not be listed here. Please install on demand if it is not provided in base OS installation.

### UBUNTU
```
docker pull ubuntu:22.04
```

### JDK 11
```
wget https://download.java.net/java/GA/jdk11/9/GPL/openjdk-11.0.2_linux-x64_bin.tar.gz && \
  mkdir -p /opt/openjdk-11 && \
  tar -zxvf openjdk-11.0.2_linux-x64_bin.tar.gz -C ./opt/openjdk-11 --strip-components 1 

export JAVA_HOME=/opt/openjdk-11
export JRE_HOME=/opt/openjdk-11/jre
```

### CASSANDRA v4.1.0
```
wget https://archive.apache.org/dist/cassandra/4.1.0/apache-cassandra-4.1.0-bin.tar.gz && \
  mkdir -p /cassandra && \
  tar -zxvf apache-cassandra-4.1.0-bin.tar.gz -C /cassandra --strip-components 1
```

### JDK 14
```
wget https://download.java.net/java/GA/jdk14/076bab302c7b4508975440c56f6cc26a/36/GPL/openjdk-14_linux-x64_bin.tar.gz && \
  mkdir -p /opt/openjdk-14 && \
  tar -zxvf openjdk-14_linux-x64_bin.tar.gz -C /opt/openjdk-14 --strip-components 1

export JAVA_HOME=/opt/openjdk-14
export JRE_HOME=/opt/openjdk-14/jre
```

### CASSANDRA v4.0.6
```
wget https://archive.apache.org/dist/cassandra/4.0.6/apache-cassandra-4.0.6-bin.tar.gz && \
  mkdir -p /cassandra && \
  tar -zxvf apache-cassandra-4.0.6-bin.tar.gz -C /cassandra --strip-components 1
```

Workload Services Framework

-end of document-