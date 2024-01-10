## NGINX-QAT-SOFTWARE
[NGINX](https://nginx.org/) is a free, open-source, high-performance web server that can also be used as a reverse proxy, load balancer, mail proxy and HTTP cache. NGINX is known for its high performance, stability, rich feature set, simple configuration, and low resource consumption.

Nginx uses SSL/TLS to enhance web access security. Intel has introduced the Crypto-NI software solution which is based on Intel® Xeon® Scalable Processors (Codename Ice Lake /Whitley). It can effectively improve the security of
web access. [Intel_Asynch_Nginx](https://github.com/intel/asynch_mode_nginx.git) is an Intel optimized version Nginx, used
by Intel to support Async hardware and software acceleration for https.

The main software used in this solution are IPP Cryptography Library, Intel Multi-Buffer Crypto for IPsec Library ([intel-ipsec-mb](https://github.com/intel/intel-ipsec-mb.git)) and  Intel® QuickAssist Technology ([Intel® QAT](https://github.com/intel/QAT_Engine.git)), which  provide batch submission of multiple SSL requests and parallel asynchronous processing mechanism on the new instruction set, greatly improving the performance. Intel® QuickAssist Accelerator is a
PCIe card that needs to be inserted into the PCIe slot in the server at the start.

#nginx, #web server, #reverse proxy, #load balancer, #mail proxy, #HTTP cache

## Software Components
Table 1 lists the necessary software components. 
The descending row order represents the install sequence. 
The recommended component version and download location are also provided.

Table 1: Software Components

| Component| Version |
| :---        |    :----:   |
| UBUNTU | [v22.04](https://ubuntu.com/) |
| OpenSSL | [openssl-3.1.4](https://github.com/openssl/openssl) |
| IPP Cyrpto | [ippcp_2021.9.0](https://github.com/intel/ipp-crypto) |
| IPsec MB | [v1.4](https://github.com/intel/intel-ipsec-mb) |
| Software QAT Engine | [v1.4.0]( https://github.com/intel/QAT_Engine) |
| ASYNC NGINX | [v0.5.1](https://github.com/intel/asynch_mode_nginx) |

## Configuration Snippets
This section contains code snippets on build instructions for software components.

Note: Common Linux utilities, such as docker, git, wget, will not be listed here. Please install on demand if it is not provided in base OS installation.

### Install OpenSSL
```sh
mkdir ${HOME}/Downloads

export OPENSSL_ROOT_DIR=/usr/local/openssl
echo "export OPENSSL_ROOT_DIR=/usr/local/openssl" >> ~/.bashrc
export OPENSSL_INCLUDE_DIR=/usr/local/openssl/include
echo "export OPENSSL_INCLUDE_DIR=/usr/local/openssl/include" >> ~/.bashrc
export OPENSSL_LIBRARIES_DIR=/usr/local/openssl/lib
echo "export OPENSSL_LIBRARIES_DIR=/usr/local/openssl/lib" >> ~/.bashrc
export OPENSSL_ENGINES=${OPENSSL_ROOT_DIR}/lib64/engines-3/
echo "export OPENSSL_ENGINES=${OPENSSL_ROOT_DIR}/lib64/engines-3/" >> ~/.bashrc
export RECIPE_OPENSSL_VERSION=openssl-3.1.4
echo "export RECIPE_OPENSSL_VERSION=openssl-3.1.4" >> ~/.bashrc

sudo apt-get -y install wget gcc perl make 
cd ${HOME}/Downloads
mkdir openssl
cd openssl
wget https://github.com/openssl/openssl/releases/download/${RECIPE_OPENSSL_VERSION}/${RECIPE_OPENSSL_VERSION}.tar.gz
tar xf ${RECIPE_OPENSSL_VERSION}.tar.gz
cd ${RECIPE_OPENSSL_VERSION}
./config
make depend
make -j16
sudo make install
```

### Install Intel Ipp Crypto
```sh
export RECIPE_IPP_CRYPTO_VERSION="ippcp_2021.9.0"
echo "export RECIPE_IPP_CRYPTO_VERSION=ippcp_2021.9.0" >> ~/.bashrc
sudo apt-get -y install cmake g++
cd ${HOME}/Downloads
mkdir ipp-crypto
cd ipp-crypto
wget https://github.com/intel/ipp-crypto/archive/refs/tags/${RECIPE_IPP_CRYPTO_VERSION}.tar.gz
tar xf ${RECIPE_IPP_CRYPTO_VERSION}.tar.gz
cd ipp-crypto-${RECIPE_IPP_CRYPTO_VERSION}/sources/ippcp/crypto_mb/
cmake . -Bbuild
cd build
make -j16
sudo make install
```

### Install Intel IPsec MultiBuffer
```sh 
export RECIPE_IPSECMB_VERSION=v1.4
echo "export RECIPE_IPSECMB_VERSION=v1.4" >> ~/.bashrc
export RECIPE_IPSECMB_VERSION_SHORT="1.4"
echo "export RECIPE_IPSECMB_VERSION_SHORT=1.4" >> ~/bashrc
sudo apt-get -y install autoconf nasm
cd ${HOME}/Downloads
mkdir ipsecmb
cd ipsecmb
wget https://github.com/intel/intel-ipsec-mb/archive/refs/tags/${RECIPE_IPSECMB_VERSION}.tar.gz
tar xf ${RECIPE_IPSECMB_VERSION}.tar.gz
ls && cd intel-ipsec-mb-${RECIPE_IPSECMB_VERSION_SHORT}
make -j16
sudo make install LIB_INSTALL_DIR=/usr/local/lib NOLDCONFIG=y
```

### Install Software QAT Engine
```sh
export RECIPE_QATENGINE_VERSION=v1.4.0
echo "export RECIPE_QATENGINE_VERSION=v1.4.0" >> ~/.bashrc
export RECIPE_QATENGINE_VERSION_SHORT="1.4.0"
echo "export RECIPE_QATENGINE_VERSION_SHORT=1.4.0" >> ~/.bashrc
sudo apt-get -y install pkg-config libtool
cd ${HOME}/Downloads
mkdir qatengine
cd qatengine
wget https://github.com/intel/QAT_Engine/archive/refs/tags/${RECIPE_QATENGINE_VERSION}.tar.gz
tar xf ${RECIPE_QATENGINE_VERSION}.tar.gz
cd QAT_Engine-${RECIPE_QATENGINE_VERSION_SHORT}
./autogen.sh
./configure --prefix=${OPENSSL_ROOT_DIR} --with-openssl_install_dir=${OPENSSL_ROOT_DIR} --enable-qat_sw
make -j16
sudo make install
```

### Install Async NGINX
```sh
export RECIPE_ASYNC_NGINX_VERSION=v0.5.1
echo "export RECIPE_ASYNC_NGINX_VERSION=v0.5.1" >> ~/.bashrc
export RECIPE_ASYNC_NGINX_VERSION_SHORT=0.5.1
echo "export RECIPE_ASYNC_NGINX_VERSION_SHORT=0.5.1" >> ~/.bashrc
sudo apt-get -y install libpcre3-dev zlib1g-dev
cd ${HOME}/Downloads
mkdir async_nginx
cd async_nginx
wget https://github.com/intel/asynch_mode_nginx/archive/refs/tags/${RECIPE_ASYNC_NGINX_VERSION}.tar.gz
tar xf ${RECIPE_ASYNC_NGINX_VERSION}.tar.gz
cd asynch_mode_nginx-${RECIPE_ASYNC_NGINX_VERSION_SHORT}/
./configure --prefix=/var/www --conf-path=/usr/local/share/nginx/conf/nginx.conf --sbin-path=/usr/local/bin/nginx  --pid-path=/run/nginx.pid --lock-path=/run/lock/nginx.lock --modules-path=/var/www/modules/ --without-http_rewrite_module --with-http_ssl_module --with-pcre --add-dynamic-module=modules/nginx_qat_module/ --with-cc-opt="-DNGX_SECURE_MEM -I/usr/local/include/openssl -Wno-error=deprecated-declarations -Wimplicit-fallthrough=0" --with-ld-opt="-Wl,-rpath=/usr/local/lib64 -L/usr/local/lib64"
make
sudo make install
```


-end of document-