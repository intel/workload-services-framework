## WORDPRESS
[WORDPRESS](https://wordpress.com) is a free and open-source content management system to create and manage content on the web. It is based on PHP and paired with MySQL or MariaDB database with supported HTTPS.  WordPress contains a large library of themes, plugins, and widgets to customize the look and functionality of any website to fit your business, blog, portfolio, or online store.

#content management, #cms, #application server, #wordpress, #web hosting

## Software Components
Table 1 lists the necessary software components. 
The descending row order represents the install sequence. 
The recommended component version and download location are also provided.

Table 1: Software Components
| Component| Version |
| :---        |    :----:   |
| UBUNTU | [v22.04](https://ubuntu.com/) |
| WORDPRESS | [v5.9.3](https://hub.docker.com/_/wordpress) |
| MARIADB | [v10.7.3-focal](https://hub.docker.com/_/mariadb) |
| OPENSSL | [v1_1_1n](https://github.com/openssl/openssl.git) |
| IPP CRYPTO | [ippcp_2021.5](https://github.com/intel/ipp-crypto.git) |
| IPSEC MB | [v1.2](https://github.com/intel/intel-ipsec-mb.git) |
| QAT ENGINE | [v0.6.11](https://github.com/intel/QAT_Engine.git) |
| ASYNC NGINX | [v0.4.7](https://github.com/intel/asynch_mode_nginx.git) |


## Configuration Snippets
This section contains code snippets on build instructions for software components.

Note: Common Linux utilities, such as docker, git, wget, will not be listed here. Please install on demand if it is not provided in base OS installation.

### UBUNTU
```
docker pull ubuntu:22.04
```

### WORDPRESS
```
docker pull wordpress:5.9.3-php7.4-fpm
```

### MARIADB
```
docker pull mariadb:10.7.3-focal
```

### OPENSSL
```
git clone -b OpenSSL_1_1_1n --depth 1 https://github.com/openssl/openssl.git && \
cd /openssl && \
    ./config && \
    make depend && \
    make -j && \
    make install_sw
```

### IPP CRYPTO
```
git clone -b ippcp_2021.5 --depth 1 https://github.com/intel/ipp-crypto.git && \
    cd /ipp-crypto/sources/ippcp/crypto_mb \
    && cmake . -B"../build" \
        -DOPENSSL_INCLUDE_DIR=/usr/local/include/openssl \
        -DOPENSSL_LIBRARIES=/usr/local/lib64 \
        -DOPENSSL_ROOT_DIR=/usr/local/bin/openssl \
    && cd ../build \
    && make crypto_mb \
    && make install \
    && cd /
```

### IPSEC MB
```
git clone -b v1.2 --depth 1 https://github.com/intel/intel-ipsec-mb.git \
    && cd /intel-ipsec-mb \
    && make -j SAFE_DATA=y SAFE_PARAM=y SAFE_LOOKUP=y \
    && make install NOLDCONFIG=y PREFIX=/usr/local/ \
    && cd /
```

### QAT ENGINE
```
QAT_ENGINE_VER="v0.6.11"
QAT_ENGINE_REPO=https://github.com/intel/QAT_Engine.git
git clone -b ${QAT_ENGINE_VER} --depth 1 ${QAT_ENGINE_REPO} && \
cd /QAT_Engine && \
./autogen.sh && \
./configure \
  --enable-ipsec_offload \
  --enable-multibuff_ecx \
  --enable-multibuff_offload \
  --with-openssl_install_dir=/usr/local/ \
  --with-multibuff_install_dir=/usr/local \
  --enable-qat_sw && \
make clean && \
make && \
make install
```

### ASYNC NGINX
```
git clone -b v0.4.7 --depth 1 https://github.com/intel/asynch_mode_nginx.git \
    && cd /asynch_mode_nginx \
    && ./configure \
      --prefix=/var/www \
      --conf-path=/usr/local/share/nginx/conf/nginx.conf \
      --sbin-path=/usr/local/bin/nginx \
      --pid-path=/run/nginx.pid \
      --lock-path=/run/lock/nginx.lock \
      --modules-path=/var/www/modules/ \
      --without-http_rewrite_module \
      --with-http_ssl_module \
      --with-pcre \
      --with-cc-opt="-DNGX_SECURE_MEM -I/usr/local/include/openssl -Wno-error=deprecated-declarations -Wimplicit-fallthrough=0" \
      --with-ld-opt="-Wl,-rpath=/usr/local/lib64 -L/usr/local/lib64" \
    && make \
    && make install \
    && cd /
```

Workload Services Framework

-end of document-