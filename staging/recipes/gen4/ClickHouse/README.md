## CLICKHOUSE-IAA
[CLICKHOUSE](https://clickhouse.com/) is an open-source column-oriented database management system (DBMS) for online analytical processing of queries (OLAP). It allows users to generate analytical reports using SQL queries in real-time, without reconfiguring and restarting the server. As a real column-oriented DBMS, Clickhouse stores no extra data with the values, which means it can effectively process analytical queries. Clickhouse parallelizes large queries naturally, and supports distributed query processing to take all the necessary resources available on the current system to improve the performance. Moreover, Clickhouse can provide different efficient compression codecs with different trade-offs between disk space and CPU consumption, to well support data compression thus better performance, just as the hardware-assisted codec which exercising Intel In-Memory Analytics Accelerator (IAA) here.

#clickhouse, #dbms, #database management system, #online analytical processing, #column-oriented, #data compression, #hardware-assisted codec 

## Software Components
Table 1 lists the necessary software components. 
The descending row order represents the install sequence. 
The recommended component version and download location are also provided.

Table 1: Software Components

| Component| Version |
| :---        |    :----:   |
| UBUNTU | [jammy-20220315](https://ubuntu.com/) |
| CLICKHOUSE | [23.2.4.12](https://packages.clickhouse.com/tgz/stable) |
| IAADEFLATE CLICKHOUSE RECIPE | [23.2.4.12]( https://github.com/ClickHouse/ClickHouse.git) |
| IDXD-CONFIG | [vaccel-config-v3.4.6.4](https://github.com/intel/idxd-config.git) |


## Configuration Snippets
This section contains code snippets on build instructions for software components.

Note: Common Linux utilities, such as docker, git, wget, will not be listed here. Please install on demand if it is not provided in base OS installation.

### UBUNTU
```sh
docker pull ubuntu:jammy-20220315
```

### ClickHouse
```shell
CLICKHOUSE_VER=23.2.4.12
CLICKHOUSE_PACKAGE=https://packages.clickhouse.com/tgz/stable
wget -O - ${CLICKHOUSE_PACKAGE}/clickhouse-common-static-${CLICKHOUSE_VER}-amd64.tgz | tar xzf -
wget -O - ${CLICKHOUSE_PACKAGE}/clickhouse-common-static-dbg-${CLICKHOUSE_VER}-amd64.tgz | tar xzf -
wget -O - ${CLICKHOUSE_PACKAGE}/clickhouse-server-${CLICKHOUSE_VER}-amd64.tgz | tar xzf –
clickhouse-common-static-${CLICKHOUSE_VER}/install/doinst.sh
clickhouse-common-static-dbg-${CLICKHOUSE_VER}/install/doinst.sh
WORKDIR /root/clickhouse-server-${CLICKHOUSE_VER}/install
DEBIAN_FRONTEND=noninteractive ./doinst.sh
sed -i 's/<!-- <listen_host>::<\/listen_host> -->/<listen_host>0.0.0.0<\/listen_host>/g' /etc/clickhouse-server/config.xml
```

### IAADEFLATE CLICKHOUSE RECIPE
Compiler requires build machine to have AVX512 to complete.
```shell
CLICKHOUSE_SRC_VER=v23.2.4.12-stable
CLICKHOUSE_SRC_REPO=https://github.com/ClickHouse/ClickHouse.git
CC=clang-15
CXX=clang++-15
git clone --recursive --shallow-submodules -b ${CLICKHOUSE_SRC_VER} ${CLICKHOUSE_SRC_REPO} && \
mkdir ClickHouse/build && \
cd ClickHouse/build && \
cmake -DENABLE_AVX512=1 -DCMAKE_BUILD_TYPE=Release .. && \
ninja && \
cp programs/clickhouse /usr/bin 
sed -i "/<mark_cache_size>/i\    <compression>" /etc/clickhouse-server/config.xml && \
sed -i "/<mark_cache_size>/i\      <case>" /etc/clickhouse-server/config.xml && \
sed -i "/<mark_cache_size>/i\        <method>deflate_qpl<\/method>" /etc/clickhouse-server/config.xml && \
sed -i "/<mark_cache_size>/i\      <\/case>" /etc/clickhouse-server/config.xml && \
sed -i "/<mark_cache_size>/i\    <\/compression>" /etc/clickhouse-server/config.xml 
```

### IDXD-CONFIG
```
IDXD_VER=accel-config-v3.4.6.4
IDXD_REPO=https://github.com/intel/idxd-config.git

git clone -b ${IDXD_VER} ${IDXD_REPO} && \
cd idxd-config && \
    ./autogen.sh && \
    ./configure CFLAGS='-g -O2' --prefix=/usr --sysconfdir=/etc --libdir=/usr/lib64 --enable-test=yes && \
    make && \
    make install
```

### IAA Device configuration
```
Here are the sh command lines to enable 4 IAA device on the same Socket.
 
accel-config load-config -c ./accel-iaa-4d1g8e.conf

accel-config enable-device iax1
accel-config enable-wq iax1/wq1.0
accel-config enable-device iax3
accel-config enable-wq iax3/wq3.0
accel-config enable-device iax5
accel-config enable-wq iax5/wq5.0
accel-config enable-device iax7
accel-config enable-wq iax7/wq7.0
```

Notes: If the user tries to config IAA device inside the docker, the BIOS and kernel options of the host machine should be pre-set properly. The user also needs to set `-v /dev:/dev` as the argument to docker run

### Config IAA Device on host
The BIOS must be configured with `VT-d` and `PCI ENQCMD` enabled, as follows:
```
EDKII Menu → Socket Configuration → IIO Configuration → Intel VT for directed IO (VT-d) → Intel VT for directed IO → Enable

EDKII Menu → Socket Configuration → IIO Configuration → PCI ENQCMD/ENQCMDS → Yes
```

The `VT-d` must be enabled from the kernel command line.
```
sudo grubby --update-kernel=DEFAULT --args="intel_iommu=on,sm_on iommu=pt"

sudo reboot
```


Workload Services Framework

-end of document-
