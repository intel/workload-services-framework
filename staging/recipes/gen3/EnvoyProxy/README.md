## ENVOY

## Envoy CryptoMB private key provider and vAES BoringSSL

[Envoy](https://github.com/envoyproxy/envoy) Envoy is an L7 proxy and communication bus designed for large modern service-oriented architecture.  The biggest impact can be seen when transferring large files using vAES


## Software Components
Table 1 lists the necessary software components. 
The descending row order represents the install sequence. 
The recommended component version and download location are also provided.

Table 1: Software Components

| Component| Version |
| :---        |    :----:   |
| UBUNTU | [v22.04](https://ubuntu.com/) |
| Envoy | [v1.26.1](https://github.com/envoyproxy/envoy.git) |
| Bazel | [v4.2.1] (https://bazel.build/)|
| Clang | [v11] (https://clang.llvm.org/)|

### ​Intel Boring SSL vAES Patch
To enable the Intel optimizations for vAES, Boring SSL must be patched
[vAES patch](https://boringssl-review.googlesource.com/c/boringssl/+/48745).

#envoy, #web server, #reverse proxy, #load balancer, #mail proxy, #HTTP cache


## Configuration Snippets
This section contains code snippets on build instructions for software components.

Note: Common Linux utilities, such as docker, git, wget, will not be listed here. Please install on demand if it is not provided in base OS installation.

### UBUNTU
```sh
docker pull ubuntu:22.04
```

### Bazel
```
apt-get -y install apt-transport-https curl gnupg wget && \
    curl -fsSL https://bazel.build/bazel-release.pub.gpg | gpg --dearmor > bazel.gpg && \
    mv bazel.gpg /etc/apt/trusted.gpg.d/ && \
    echo "deb [arch=amd64] https://storage.googleapis.com/bazel-apt stable jdk1.8" | tee /etc/apt/sources.list.d/bazel.list && apt-get update && \
    apt-get -y install bazel-4.2.1 && \
    ln -s /usr/bin/bazel-4.2.1 /usr/bin/bazel

```

### Clang 11
```
apt-get -y install clang-11 llvm-11 lld && \
export CC=/usr/bin/clang && export CXX=/usr/bin/clang++ && \
ln -s /usr/bin/llvm-config-11 /usr/bin/llvm-config
```

### Envoy
```
GIT_SSL_NO_VERIFY=1
apt-get -y install git gettext yasm python3 python3-pip cmake ninja-build && \
 ln -s /usr/bin/python3 /usr/bin/python && \
 git clone https://github.com/envoyproxy/envoy.git envoy
```

### Apply patch
```
cd envoy && git checkout remotes/origin/release/v1.21 && \
git am 0001-Add-vAES-patches.patch && bazel/setup_clang.sh /usr/ && \
```

### Install Envoy 
```
CC=clang CXX=clang++ bazel build --config=clang -c opt //contrib/exe:envoy-static 
install -D /envoy/LICENSE /tmp/install_root/usr/local/share/package-licenses/envoy/LICENSE && \
install -D /envoy/bazel-bin/contrib/exe/envoy-static /tmp/install_root/usr/local/bin/envoy-static 
```

-end of document-




