## MYSQL
[MySQL](https://www.mysql.com/) is an open source relational database management system (RDBMS) that is based on Structured Query Language (SQL). A relational database organizes data into one or more data tables in which data may be related to each other; these relations help structure the data. SQL is a language programmers use to create, modify and extract data from the relational database, as well as control user access to the database.

#mysql, #relational database, #storage, #database, #dbms, #database management system

## Software Components
Table 1 lists the necessary software components. 
The descending row order represents the install sequence. 
The recommended component version and download location are also provided.

Table 1: Software Components

| Component| Version |
| :---        |    :----:   |
| UBUNTU | [v22.04](https://ubuntu.com/) |
| GOSU | [v1.14](https://github.com/tianon/gosu/releases/download/1.14/gosu-amd64) |
| MYSQL_VER | [v8.0.31](https://repo.mysql.com/apt/ubuntu/pool/mysql-8.0/m/mysql-community/mysql-community-server-core_8.0.31-1ubuntu22.04_amd64.deb) |

## Configuration Snippets
This section contains code snippets on build instructions for software components.

Note: Common Linux utilities, such as docker, git, wget, will not be listed here. Please install on demand if it is not provided in base OS installation.

### UBUNTU
```sh
docker pull ubuntu:22.04
```

### GOSU
```sh
dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"
wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/1.14/gosu-$dpkgArch"
wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/1.14/gosu-$dpkgArch.asc"
```


### MySQL Server
```sh
MYSQL_VER="8.0.31"
MYSQL_DEB_POOL="https://repo.mysql.com/apt/ubuntu/pool/mysql-8.0/m/mysql-community"
wget ${MYSQL_DEB_POOL}/mysql-community-server-core_${MYSQL_VER}-1ubuntu22.04_amd64.deb
dpkg -i mysql-community-server-core_${MYSQL_VER}-1ubuntu22.04_amd64.deb
wget ${MYSQL_DEB_POOL}/mysql-common_${MYSQL_VER}-1ubuntu22.04_amd64.deb
dpkg -i mysql-common_${MYSQL_VER}-1ubuntu22.04_amd64.deb
wget ${MYSQL_DEB_POOL}/mysql-community-client-plugins_${MYSQL_VER}-1ubuntu22.04_amd64.deb
dpkg -i mysql-community-client-plugins_${MYSQL_VER}-1ubuntu22.04_amd64.deb
wget ${MYSQL_DEB_POOL}/mysql-community-client-core_${MYSQL_VER}-1ubuntu22.04_amd64.deb
dpkg -i mysql-community-client-core_${MYSQL_VER}-1ubuntu22.04_amd64.deb
wget ${MYSQL_DEB_POOL}/mysql-community-client_${MYSQL_VER}-1ubuntu22.04_amd64.deb
dpkg -i mysql-community-client_${MYSQL_VER}-1ubuntu22.04_amd64.deb
```

Workload Services Framework

-end of document-