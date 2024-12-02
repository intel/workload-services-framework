# Templating systems

There are templating systems, based on M4 macros (`*.m4` files) and Jinja2 (`*.j2` files), built into the workload build process. You can use them to simplify the workload recipe development by encapsulating any duplicated steps.

> Note: This document lacks information about Jinja templating. We are working on improvements.

## Usage

To use the template system, create a (or more) `.m4`/`.j2` files under your workload folder, and put any shared templates `.m4`/`.j2` under the `template` folder under the workload, feature, platform or the top directory. During the build process, those `.m4`/`.j2` files will be expanded to either `.tmpm4.xyzt` or `.tmpj2.xyzt`, where `xyzt` is a random string. The temporary files will be removed after the build.  

### Example

The following sample uses `ippmb.m4` to encapsulate the IPP library installation steps:

```m4
# SPR/Crypto/WordPress/Docker.1.nginx.m4
...
include(ippmb.m4)
...
```

where `ippmb.m4` will be expanded to:   

```shell
# SPR/Crypto/template/ippmb.m4
ARG IPP_CRYPTO_VERSION="ippcp_2020u3"
ARG IPP_CRYPTO_REPO=https://github.com/intel/ipp-crypto.git
RUN git clone -b ${IPP_CRYPTO_VERSION} --depth 1 ${IPP_CRYPTO_REPO} && \
    cd /ipp-crypto/sources/ippcp/crypto_mb && \
    cmake . -B"../build" \
      -DOPENSSL_INCLUDE_DIR=/usr/local/include/openssl \
      -DOPENSSL_LIBRARIES=/usr/local/lib64 \
      -DOPENSSL_ROOT_DIR=/usr/local/bin/openssl && \
    cd ../build && \
    make crypto_mb && \
    make install
```

### Pre-defined Variables:

- **PLATFORM**: The platform name that the workload is defined for.
- **FEATURE**: The hero feature name that the workload is defined under.
- **WORKLOAD**: The workload name.
- **REGISTRY**: The private registry.
- **RELEASE**: The release version.

