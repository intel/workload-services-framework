## Chromium Zlib
[ Zlib Chromium](https://chromium.googlesource.com/chromium/src/third_party/zlib/) is a custom version of zlib that is integrated into the larger Chromium browser project. This version of Zlib provides compiler optimzations that allow a developer to leverage Intel AVX 512 instructions. Advanced Vector Extensions 512 (Intel® AVX-512). 


#debian #zlib #avx512

## Software Components
Table 1 lists the necessary software components.

Table 1: Software Components
| Component| Version |
| :---        |    :----:   |
| Debian | [bookworm](https://debian.org/) |
| Chromium Zlib | [dfc48fc](https://chromium.googlesource.com/chromium/src/third_party/zlib) |


## Installation Instructions

### Software Prerequisites

The following packages are required for compliation of required components

**git**, **cmake**, **g++**

The instructions also make the assumption that there is a **Downloads** folder in the user's home folder.
```
mkdir -p ${HOME}/Downloads
```

## Install Chromium Zlib
To enable leverage AVX 512 instructions, ensure that both **ENABLE_SIMD_OPTIMIZATIONS** and  **ENABLE_SIMD_AVX512** flags are set to 1
```
cd ${HOME}/Downloads
git clone https://chromium.googlesource.com/chromium/src/third_party/zlib
cd zlib
mkdir avx-build
cd avx-build
cmake -DENABLE_SIMD_OPTIMIZATIONS=1 -DENABLE_SIMD_AVX512=1 -DCMAKE_BUILD_TYPE=RELEASE ..
make -j
sudo make install
```

-end of document-