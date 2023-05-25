## RocksDB
[RocksDB](https://rocksdb.org/) library provides a persistent key value store. Keys and values are arbitrary byte arrays. The keys are ordered within the key value store according to a user-specified comparator function. The library is maintained by the Facebook Database Engineering Team, and is based on LevelDB, by Sanjay Ghemawat and Jeff Dean at Google.

#RocksDB, #kv database, #database, #database management system

## Software Components
Table 1 lists the necessary software components. 
The descending row order represents the install sequence. 
The recommended component version and download location are also provided.

Table 1: Software Components

| Component| Version |
| :---        |    :----:   |
| ROCKYLINUX | [v8.5](https://rockylinux.org/) |
| IDXD-CONFIG | [vaccel-config-v3.4.6.4](https://github.com/intel/idxd-config.git) |
| QPL | [v1.1.0](https://github.com/intel/qpl.git) |
| ONETBB | [v2021.8.0](https://www.intel.com/content/www/us/en/developer/articles/tool/oneapi-standalone-components.html#onetbb) |
| GFLAGS | [v2.2.2](https://github.com/gflags/gflags.git) |
| ROCKSDB | [PR6717](https://github.com/facebook/rocksdb/pull/6717) |
| ROCKSDB_PLUGIN | [d4b1c7bb45341b2560970bd921002d624daf94dc](https://github.com/intel/iaa-plugin-rocksdb.git) |

## Configuration Snippets
This section contains code snippets on build instructions for software components and IAA device configuration.

Note: Common Linux utilities, such as docker, git, wget, will not be listed here. Please install on demand if it is not provided in base OS installation.

### Rockylinux
```
docker pull rockylinux:8.5
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

### QPL
```
QPL_VER=v1.1.0
QPL_REPO=https://github.com/intel/qpl.git

git clone --recursive -b ${QPL_VER} ${QPL_REPO} qpl_library && \
    cd qpl_library && \
    mkdir build && cd build && \
    cmake -DCMAKE_INSTALL_PREFIX=../../qpl -DCMAKE_BUILD_TYPE=Release -DLIB_ACCEL_3_2=ON .. && \
    cmake --build . --target install
```

### ONETBB
```
download onetbb from https://www.intel.com/content/www/us/en/developer/articles/tool/oneapi-standalone-components.html#onetbb

chmod +x l_tbb_oneapi_p_2021.8.0.25334_offline.sh && \
    ./l_tbb_oneapi_p_2021.8.0.25334_offline.sh -a -s --eula accept --install-dir /oneapi
```

### GFLAGS
```
GFLAGS_VER=v2.2.2
GFLAGS_REPO=https://github.com/gflags/gflags.git

git clone -b ${GFLAGS_VER} ${GFLAGS_REPO} && \
    cd gflags && \
    mkdir build && cd build && \
    cmake -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SHARED_LIBS=ON .. && \
    make && make install && \
    ldconfig
```

### ROCKSDB
```
ROCKSDB_VER=aa8ec63a4eec1c1b02da3879d0e044b948b7d1a4
ROCKSDB_PLUGIN_VER=d4b1c7bb45341b2560970bd921002d624daf94dc
ROCKSDB_REPO=https://github.com/facebook/rocksdb.git
ROCKSDB_IAA_PLUGIN_REPO=https://github.com/intel/iaa-plugin-rocksdb.git

git clone ${ROCKSDB_REPO} && \
    cd rocksdb && \
    git fetch origin pull/6717/head && \
    git checkout -b pullrequest FETCH_HEAD && \
    git clone ${ROCKSDB_IAA_PLUGIN_REPO} plugin/iaa_compressor && \
    EXTRA_CXXFLAGS="-I/qpl/include -I/qpl/include/qpl -I/usr/local/include" EXTRA_LDFLAGS="-L/qpl/lib64 -L/oneapi/tbb/latest/lib/intel64/gcc4.8 -L/usr/local/lib -Lgflags" ROCKSDB_CXX_STANDARD="c++17" DISABLE_WARNING_AS_ERROR=1 ROCKSDB_PLUGINS="iaa_compressor" make release

```
### IAA Device configuration
```
Here is the sh commandlines to enable IAA device on the same Socket. By the way, we only enable 1 IAA device in the example
accel-config disable-wq iax1/wq1.0
accel-config disable-device iax1

accel-config config-engine iax1/engine1.0
accel-config config-engine iax1/engine1.1
accel-config config-engine iax1/engine1.2
accel-config config-engine iax1/engine1.3
accel-config config-engine iax1/engine1.4
accel-config config-engine iax1/engine1.5
accel-config config-engine iax1/engine1.6
accel-config config-engine iax1/engine1.7

accel-config config-wq iax1/wq1.0 -g 0 -s 128 -p 10 -m shared -y user -n user1 -t 128 -b 1 -d user

accel-config enable-device iax1
accel-config enable-wq iax1/wq1.0
```

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

Notes: If you use `docker` to run your program, set `-v /dev:/dev` as the argument to docker run



Workload Services Framework

-end of document-