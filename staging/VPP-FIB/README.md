## VPP-FIB: Vector Packet Processor - Forwarding Information Base ((VPP-FIB)
[Vector Packet Processor (VPP)](https://s3-docs.fd.io/vpp/23.02/) is a fast, scalable layer 2-4 multi-platform network stack. Vector packet processing is a technique used in networking and communication systems to process multiple packets simultaneously. It is used to increase the speed of packet processing, as well as reduce latency in the network. 

A forwarding information base (FIB), also known as a forwarding table or MAC table, is most commonly used in network bridging, routing, and similar functions to find the proper output network interface to which the input interface should forward a packet. 

[DPDK](https://www.dpdk.org/) is the Data Plane Development Kit that consists of libraries to accelerate packet processing workloads running on a wide variety of CPU architectures. By enabling very fast packet processing, DPDK is making it possible for the telecommunications industry to move performance-sensitive applications like the backbone for mobile networks and voice to the cloud.

#packet processing, #VPP, #FIB, #forwarding information base, #DPDK, Data Plane Development Kit, #Vector Packet Processor

## Software Components
Table 1 lists the necessary software components. 
The descending row order represents the install sequence. 
The recommended component version and download location are also provided.

Table 1: Software Components
| Component| Version |
| :---        |    :----:   |
| UBUNTU | [v20.04](https://ubuntu.com/) |
| VPP | [v22.02](https://github.com/FDio/vpp.git) |
| DPDK | [v22.03](https://fast.dpdk.org/rel/dpdk-22.03.tar.xz) |
| PYTHON | [v3.8.0](https://www.python.org/ftp/python/3.8.0/Python-3.8.0.tar.xz) ||

## Configuration Snippets
This section contains code snippets on build instructions for software components.

Note: Common Linux utilities, such as docker, git, wget, will not be listed here. Please install on demand if it is not provided in base OS installation.

### UBUNTU
```
docker pull ubuntu:20.04
```

### VPP
```
VPP_VER="v22.02"
VPP_REPO=https://github.com/FDio/vpp.git
git clone ${VPP_REPO} && cd vpp && git checkout ${VPP_VER} && \
    sh -c '/bin/echo -e "y\ny" | ./extras/vagrant/build.sh' && \
    sh -c '/bin/echo -e "y\n" | make install-dep' && \
    make install-ext-deps && \
    make build-release
```

### DPDK
```
DPDK_VER=22.03
DPDK_PACKAGE=https://fast.dpdk.org/rel/dpdk-${DPDK_VER}.tar.xz
wget --no-check-certificate -O - ${DPDK_PACKAGE} | tar xfJ - && \
    cd dpdk* && \
    meson build && \
    cd build && \
    ninja && \
    ninja install
```
### PYTHON
```
PYTHON_VER="3.8.0"
PYTHON_PACKAGE=https://www.python.org/ftp/python/${PYTHON_VER}/Python-${PYTHON_VER}.tar.xz
cd / && \
    wget --no-check-certificate -O - ${PYTHON_PACKAGE} | tar xfJ - && \
    cd Python-*  && \
    sed -i 's/#SSL=\/usr\/local\/ssl/SSL=\/usr\/local/g' ./Modules/Setup && \
    sed -i '211,213s/#//g' ./Modules/Setup && \
    ./configure && \
    make && \
    make install && \
    python3 -m pip install -U pip setuptools && \
    python3 -m pip install --upgrade cryptography && \
    ln -s /usr/local/bin/python3 /usr/bin/python3
```

Workload Services Framework

-end of document-
