##HAPROXY

## HAPROXY-QAT-SOFTWARE
[HAProxy](https://www.haproxy.org/) HAProxy is a free, very fast and reliable reverse-proxy offering high availability, load balancing, and proxying for TCP and HTTP-based applications. It is particularly suited for very high traffic web sites and powers a significant portion of the world's most visited ones.

HAProxy uses SSL/TLS SSL/TLS may be used on the connection coming from the client, on the connection going to the server, or even on both connections. 
    
Intel has introduced the Crypto-NI software solution which is based on Intel® Xeon® Scalable Processors (Codename Ice Lake /Whitley). It can effectively improve the security of web access. 

The main software used in this solution are IPP Cryptography Library, Intel Multi-Buffer Crypto for IPsec Library ([intel-ipsec-mb](https://github.com/intel/intel-ipsec-mb.git)) and  Intel® QuickAssist Technology ([Intel® QAT](https://github.com/intel/QAT_Engine.git)), which  provide batch submission of multiple SSL requests and parallel asynchronous processing mechanism on the new instruction set, greatly improving the performance. Intel® QuickAssist Accelerator is a
PCIe card that needs to be inserted into the PCIe slot in the server at the start.

#haproxy, #web server, #reverse proxy, #load balancer, #mail proxy, #HTTP cache

## Software Components
Table 1 lists the necessary software components. 
The descending row order represents the install sequence. 
The recommended component version and download location are also provided.

Table 1: Software Components

| Component| Version |
| :---        |    :----:   |
| UBUNTU | [v22.04](https://ubuntu.com/) |
| OpenSSL | [v1.1.1](https://github.com/openssl/openssl.git) |
| IPP Crypto | [ipp-crypto_2021_5](https://github.com/intel/ipp-crypto ) |
| Intel IP Sec MB | [v1.1](https://github.com/intel/intel-ipsec-mb.git ) |
| QAT Engine | [v0.6.11](https://github.com/intel/QAT_Engine.git) |
| HAProxy | [v2.5.6](https://www.haproxy.org/download/) |

## Configuration Snippets
This section contains code snippets on build instructions for software components.

Note: Common Linux utilities, such as docker, git, wget, will not be listed here. Please install on demand if it is not provided in base OS installation.

### UBUNTU
```sh
docker pull ubuntu:22.04
```

```
BASE_PATH=/intelHaproxy
```

### OpenSSL
```
openssl_version="OpenSSL_1_1_1d"
ssl_location=$BASE_PATH"/openssl/"
ssl_install_location=$BASE_PATH"/openssl_install/"
cd $BASE_PATH && \ 
    git clone https://github.com/openssl/openssl.git && \
    cd $BASE_PATH && mkdir openssl_install && cd openssl && git checkout $openssl_version && ./config --prefix="$ssl_install_location" -Wl,-rpath,$ssl_location && make -j 10 && make install -j 10 
```

### IPP Crypto
```
ipp_crypto_version="ipp-crypto_2021_5"
GIT_SSL_NO_VERIFY=1 \
    PATH=$PATH:/sbin
cd $BASE_PATH  && mkdir mb_build && apt-get install autoconf build-essential libtool cmake cpuid nasm -y
git clone https://github.com/intel/ipp-crypto  && \
    cd ipp-crypto && git checkout $ipp_crypto_version  && \ cd sources/ippcp/crypto_mb && \ 
    cmake . -B"../build" -DOPENSSL_ROOT_DIR=$ssl_location -DCMAKE_INSTALL_PREFIX=$mb_location -DOPENSSL_LIBRARIES=$ssl_install_location  && \
    cd ../build &&  make -j 10 &&  \
    make install -j 10
```

### Intel IP Sec MB
```
intel_ipsec_mb_version="v1.1"
mb_location=$BASE_PATH"/mb_build/"
cd $BASE_PATH && \
    git clone https://github.com/intel/intel-ipsec-mb.git && \
    cd intel-ipsec-mb/ && \
    git checkout $intel_ipsec_mb_version && \ 
    make -j 10 && make install PREFIX=$mb_location
```

### Intel QAT SW
```
QAT_Engine_version="v0.6.11"
GIT_SSL_NO_VERIFY=1
cd $BASE_PATH && \
    git clone https://github.com/intel/QAT_Engine.git && \ 
    cd QAT_Engine && git checkout $QAT_Engine_version && \ 
    ./autogen.sh && \ 
    ./configure --enable-qat_sw --disable-qat_hw --disable-qat_sw_sm2 --with-qat_sw_install_dir=$mb_location --with-openssl_install_dir="$ssl_install_location" && \
    make -j 10 && make install
```

### HAProxy
```
haproxy_version="haproxy-2.5.6"
version_haproxy="2.5"
haproxy_source_location=$BASE_PATH"/"$haproxy_version"/"
haproxy_install_location=$BASE_PATH"/haproxy_install/"

wget https://www.haproxy.org/download/$version_haproxy/src/$haproxy_version.tar.gz --no-check-certificate
tar -xzvf $haproxy_version.tar.gz && \
 $haproxy_version && \ 
    CPPFLAGS="-fno-omit-frame-pointer -g -O2 -g -Wall -Wextra -Wundef -Wdeclaration-after-statement -fwrapv -Wno-unused-label -Wno-sign-compare -Wno-unused-parameter -Wno-clobbered -Wno-missing-field-initializers -Wno-cast-function-type -Wtype-limits -Wshift-negative-value -Wshift-overflow=2 -Wduplicated-cond -Wnull-dereference" && \ 
    make -j 10 TARGET=linux-glibc USE_SYSTEMD=1 USE_THREAD=1 USE_CPU_AFFINITY=1 USE_OPENSSL=1 SSL_INC="$ssl_install_location"include SSL_LIB="$ssl_install_location"lib && \ 
    make install PREFIX=$haproxy_install_location
```

### ENVIRONMENT VARIABLES
```
PATH=$PATH:/sbin
PATH="$ssl_install_location"bin:$PATH
OPENSSL_ENGINES="$ssl_install_location"lib/engines-1.1
PATH="$haproxy_install_location"sbin:$PATH
LD_LIBRARY_PATH="$ssl_install_location"lib:"$mb_location"lib:$LD_LIBRARY_PATH
```

Workload Services Framework

-end of document-




