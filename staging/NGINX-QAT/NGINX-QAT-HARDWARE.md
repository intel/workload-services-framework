## NGINX-QAT-HARDWARE
[NGINX](https://nginx.org/) is a free, open-source, high-performance web server that can also be used as a reverse proxy, load balancer, mail proxy and HTTP cache. NGINX is known for its high performance, stability, rich feature set, simple configuration, and low resource consumption.

Nginx uses SSL/TLS to enhance web access security. Intel has introduced the Crypto-NI software solution which is based on
Intel® Xeon® Scalable Processors (Codename Ice Lake/Whitley). It can effectively improve the security of web access. [Intel_Asynch_Nginx](https://github.com/intel/asynch_mode_nginx.git) is an Intel optimized version Nginx,  used by Intel to support Async hardware and software acceleration for https.

The main software used in this solution are IPP Cryptography Library, Intel Multi-Buffer Crypto for IPsec Library ([intel-ipsec-mb](https://github.com/intel/intel-ipsec-mb.git)) and Intel®  QuickAssist Technology ([Intel® QAT](https://github.com/intel/QAT_Engine.git)), which provide batch submission of multiple SSL requests and parallel asynchronous processing mechanism based on the new instruction set, greatly improving the performance. Intel® QuickAssist Accelerator
is a PCIe card that needs to be inserted into the PCIe slot in the server at the start.

#nginx, #web server, #reverse proxy, #load balancer, #mail proxy, #HTTP cache

## Software Components
Table 1 lists the necessary software components. 
The descending row order represents the install sequence. 
The recommended component version and download location are also provided.

Table 1: Software Components

| Component| Version |
| :---        |    :----:   |
| UBUNTU | [v22.04](https://ubuntu.com/) |
| qat-crypto-base| [qathw-ubuntu](https://hub.docker.com/r/intel/qat-crypto-base) |
| ASYNC NGINX | [v0.4.7](https://github.com/intel/asynch_mode_nginx.git) |

## Configuration Snippets
This section contains code snippets on build instructions for software components.

Note: Common Linux utilities, such as docker, git, wget, will not be listed here. Please install on demand if it is not provided in base OS installation.

### UBUNTU
```sh
docker pull ubuntu:22.04
```

### qat-crypto-base-ubuntu
```sh
docker pull intel/qat-crypto-base:qathw-ubuntu
```
The installation guide for this container can be found at https://optimizations.intel.com/catalog?uuid=opt-97bdd198-7f3f-4083-b6c9-30d36197b865 

### ASYNC NGINX
```sh
ARG ASYNC_NGINX_VER="v0.4.7"
ARG ASYNC_NGINX_REPO=https://github.com/intel/asynch_mode_nginx.git
RUN git clone -b $ASYNC_NGINX_VER --depth 1 ${ASYNC_NGINX_REPO} && \
    cd /asynch_mode_nginx && \
    ./configure \
      --prefix=/var/www \
      --conf-path=/usr/local/share/nginx/conf/nginx.conf \
      --sbin-path=/usr/local/bin/nginx \
      --pid-path=/run/nginx.pid \
      --lock-path=/run/lock/nginx.lock \
      --modules-path=/var/www/modules/ \
      --without-http_rewrite_module \
      --with-http_ssl_module \
      --with-pcre \
      --add-dynamic-module=modules/nginx_qat_module/ \
      --with-cc-opt="-DNGX_SECURE_MEM -O3 -I/usr/local/include/openssl -Wno-error=deprecated-declarations -Wimplicit-fallthrough=0" \
      --with-ld-opt="-ltcmalloc_minimal -Wl,-rpath=/usr/local/lib -L/usr/local/lib" && \
    make -j && \
    make install
```

Workload Services Framework

-end of document-