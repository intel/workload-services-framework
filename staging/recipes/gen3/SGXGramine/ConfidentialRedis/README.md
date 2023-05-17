## Redis with Confidential Compute
[Intel® QuickAssist Technology (Intel® QAT)](https://www.intel.com/content/www/us/en/developer/topic-technology/open/quick-assist-technology/overview.html) enables acceleration for data encryption and compression for applications from networking to enterprise, cloud to storage, and content delivery to database. Below recipe contains instructions for a version without hardware acceleration.

#SGX #Secure Guard Extension #Gramine #Redis

## Software Components
Table 1 lists the necessary software components for this workload. 
The descending row order represents the install sequence. 
The recommended component version and download location are also provided.


Table 1: Software Components
| Component    | Version |
| :---         | :----: |
| Ubuntu OS    | [22.04](https://ubuntu.com/) |
| curl          | [7.81.0-1ubuntu1.10](http://curl.haxx.se/) |
| gcc          | [4:11.2.0-1ubuntu1](https://gcc.gnu.org/) |
| git          | [1:2.34.1-1ubuntu1.8](https://github.com/git-guides/install-git#install-git-on-linux) |
| libjemalloc-dev | [ 5.2.1-4ubuntu1 ](http://jemalloc.net/) |
| make         | [4.3-4.1build1](https://www.gnu.org/software/make/) |
| pkg-config   | [0.29.2-1ubuntu3](https://www.freedesktop.org/wiki/Software/pkg-config/) |
| tzdata   | [ 2023c-0ubuntu0.22.04.1 ](https://www.iana.org/time-zones) |
| wget   | [ 1.21.2-2ubuntu1 ](https://www.gnu.org/software/wget/) |

### Ubuntu
```
docker pull ubuntu:22.04
```

## Configuration Snippets
This section contains code snippets on build instructions for components.

Note: Common Linux utilities, such as docker, git, wget, will not be listed here. Please install on demand if it is not provided in base OS installation.

### Helper packages
```
DEBIAN_FRONTEND=noninteractive apt-get -y install libjemalloc-dev pkg-config tzdata
```

### Gramine
```
curl -fsSLo /usr/share/keyrings/gramine-keyring.gpg https://packages.gramineproject.io/gramine-keyring.gpg 
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/gramine-keyring.gpg] https://packages.gramineproject.io/ jammy main" | tee /etc/apt/sources.list.d/gramine.list
curl -fsSLo /usr/share/keyrings/intel-sgx-deb.asc https://download.01.org/intel-sgx/sgx_repo/ubuntu/intel-sgx-deb.key
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/intel-sgx-deb.asc] https://download.01.org/intel-sgx/sgx_repo/ubuntu jammy main" | tee /etc/apt/sources.list.d/intel-sgx.list
apt-get -y update && apt-get -y install gramine
```

### Redis Server
Build the Redis Server CI Example from the gramine project. To avoid shipping the container with a sgx key, the make command is embedded within an echo command. This allows for a container build to complete and most of the application to be built before the container is launched.

```
cd /
git clone https://github.com/gramineproject/gramine.git
cd /gramine/CI-Examples/redis
echo $(make SGX=1) 
```

To build sign Redis at container launch time, add the make command into a script that executes at launch.

```
echo "gramine-sgx-gen-private-key &&\
cd /gramine/CI-Examples/redis/ && \
make SGX=1 && \ 
gramine-sgx /gramine/CI-Examples/redis/redis-server" \ 
>> /entrypoint.sh
```