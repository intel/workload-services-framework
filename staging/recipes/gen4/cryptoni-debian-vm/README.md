## Base Debian VM
[Base Debian VM](https://www.debian.org/) is an open source distribution of Linux. The following is a tutorial to assist users with installing software needed to utilize Intel® CryptoNI instructions so they see better performance with encryption/decryption and compression/decompression workloads. [Intel® Quick Assist Technology](https://www.intel.com/content/www/us/en/developer/articles/guide/building-software-acceleration-features-in-the-intel-qat-engine-for-openssl.html) (Intel® QAT) has been expanded to provide software-based acceleration of cryptographic operations through instructions in the Intel® Advanced Vector Extensions 512 (Intel® AVX-512) family. This software-based acceleration has been incorporated into the Intel QAT Engine for OpenSSL*, a dynamically loadable module that uses the OpenSSL ENGINE framework, allowing administrators to add this capability to OpenSSL without having to rebuild or replace their existing OpenSSL libraries.


#debian #vm #qat #encryption

## Software Components
Table 1 lists the necessary software components.

Table 1: Software Components
| Component| Version |
| :---        |    :----:   |
| Debian | [bookworm](https://debian.org/) |
| OpenSSL | [1.1.1w](https://www.openssl.org/source/openssl-1.1.1w.tar.gz) |
| IPP-crypto | [2021.8](https://github.com/intel/ipp-crypto/archive/refs/tags/ippcp_2021.8.tar.gz) |
| Intel IPSEC MB | [v1.4](https://github.com/intel/intel-ipsec-mb/archive/refs/tags/v1.4.tar.gz) |
| QAT Engine | [v1.4.0](https://github.com/intel/QAT_Engine/archive/refs/tags/v1.4.0.tar.gz) |


## Installation Instructions

### Software Prerequisites

The following packages are required for compliation of required components

**autoconf**, **build-essential**, **libtool**, **cmake**, **cpuid**, **nasm**, **wget**

The instructions also make the assumption that there is a **Downloads** folder in the user's home folder.
```
mkdir -p ${HOME}/Downloads
```

### Install openSSL (1.1.1w)

Install openSSL and and modify both the PATH and LD_LIBRRY_PATH environment variables. Notice the variables are set for the current execution, but also added to bashrc to be run if an vm is restarted. The **ENV** primitive may be appropriate when creating a container. the --prefix primitive sets the destination of openSSL binaries created.

```
cd ${HOME}/Downloads
wget https://www.openssl.org/source/openssl-1.1.1w.tar.gz
tar xf openssl-1.1.1w.tar.gz
cd openssl-1.1.1w
./config --prefix=/opt/openssl/1.1.1w --openssldir=/opt/openssl/1.1.1w
make -j
sudo make install
echo "export PATH=/opt/openssl/1.1.1w/bin:$PATH" >> ~/.bashrc
export PATH=/opt/openssl/1.1.1w/bin:$PATH
echo "export LD_LIBRARY_PATH=/opt/openssl/1.1.1w/lib:$LD_LIBRARY_PATH" >> ~/.bashrc
export LD_LIBRARY_PATH=/opt/openssl/1.1.1w/lib:$LD_LIBRARY_PATH
echo "export OPENSSL_ROOT_DIR=/opt/openssl/1.1.1w/" >> ~/.bashrc
export OPENSSL_ROOT_DIR=/opt/openssl/1.1.1w/
```

### Install IPP-crypto - (2021.8)
Install IPP Crypto. The **LD_LBRARY_PATH** is also modified to provide access to created libraries. The destination of binaries is set using **-DCMAKE_INSTALL_PREFIX=/opt/crypto_mb/VERSION**

```
cd  ${HOME}/Downloads
wget https://github.com/intel/ipp-crypto/archive/refs/tags/ippcp_2021.8.tar.gz
tar xvf ippcp_2021.8.tar.gz
cd ipp-crypto-ippcp_2021.8/sources/ippcp/crypto_mb/
cmake . -Bbuild -DCMAKE_INSTALL_PREFIX=/opt/crypto_mb/2021.8
cd build
make -j
sudo make install
echo "export LD_LIBRARY_PATH=/opt/crypto_mb/2021.8/lib:$LD_LIBRARY_PATH" >> ~/.bashrc
export LD_LIBRARY_PATH=/opt/crypto_mb/2021.8/lib:$LD_LIBRARY_PATH
```

### Intel IPSEC MB - (1.4)
Install Intel® Multi-Buffer Crypto for IPsec Library. Notice the compilation sets **SAFE_DATA=y**, **SAFE_PARAM=y**, and **SAFE_LOOKUP=y**. 
```
cd ${HOME}/Downloads
wget https://github.com/intel/intel-ipsec-mb/archive/refs/tags/v1.4.tar.gz
tar xvf v1.4.tar.gz
cd intel-ipsec-mb-1.4/
make -j SAFE_DATA=y SAFE_PARAM=y SAFE_LOOKUP=y
sudo make install NOLDCONFIG=y PREFIX=/opt/ipsec-mb/1.4
echo "export LD_LIBRARY_PATH=/opt/ipsec-mb/1.4/lib:$LD_LIBRARY_PATH" >> ~/.bashrc
export LD_LIBRARY_PATH=/opt/ipsec-mb/1.4/lib:$LD_LIBRARY_PATH
```

### QAT Engine - latest release (1.4.0)

First set the **OPENSSL_ENGINES** and **PERL5LIB** which is used when compiling QAT Engine. Because the OpenSSL version installed is 1.1.x. If using OpenSSL 3.x, this value will need to reflect the change.

```
echo "export OPENSSL_ENGINES=/opt/openssl/1.1.1w/lib/engines-1.1/" >> ~/.bashrc
export OPENSSL_ENGINES=/opt/openssl/1.1.1w/lib/engines-1.1/

echo "export PERL5LIB=${HOME}/Downloads/openssl-1.1.1w" >> ~/.bashrc
export PERL5LIB=${HOME}/Downloads/openssl-1.1.1w
```

Now compile QAT Engine. This requires setting  **LDFLAGS** and **CPPFLAGS** to reflect the installed prerequisite libraries. 

```
cd  ${HOME}/Downloads
wget https://github.com/intel/QAT_Engine/archive/refs/tags/v1.4.0.tar.gz
tar xvf v1.4.0.tar.gz
cd QAT_Engine-1.4.0/
./autogen.sh
LDFLAGS="-L/opt/ipsec-mb/1.4/lib -L/opt/crypto_mb/2021.8/lib" CPPFLAGS="-I/opt/ipsec-mb/1.4/include -I/opt/crypto_mb/2021.8/include" ./configure --prefix=/opt/openssl/1.1.1w --with-openssl_install_dir=/opt/openssl/1.1.1w --enable-qat_sw
make -j
sudo make install
```

-end of document-