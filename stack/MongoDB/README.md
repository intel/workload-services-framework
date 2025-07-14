>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### MongoDB

MongoDB is a source-available cross-platform document-oriented database program. Classified as a NoSQL database program, MongoDB uses JSON-like documents with optional schemas.

### Images

This image can be used almost exactly like the official DockerHub MongoDB image. The naming of MongoDB images follow the rules: `<PLATFORM>-mongodb<VERSION>-<USAGE>`. `PLATFORM` can be `amd64` and `arm64`; `VERSION` can be `441/4419/604/710`, ... ; `USAGE` can be `base` `redhat` `ubuntu2404` and `iaa`.

For example:

- `amd64-mongodb710-iaa`: Intel Optimized with IAA MongoDB 7.1.0 on amd64 platform;

Example to build and run the intel optimized docker image of MongoDB:

```shell
# build image
docker build . -f Dockerfile.1.amd64mongodb710.iaa -t amd64-mongodb710-iaa:<tag> --build-arg http_proxy --build-arg https_proxy --build-arg no_proxy --network=host
# run container using built image
docker run --name mongodb710-iaa --privileged --network host -v /dev:/dev -v /var/tmp:/var/tmp -v /sys:/sys -v /lib/modules:/lib/modules amd64-mongodb710-iaa:<tag> --iaa=true --iaa_mode=0 --iax_devices=0 --iaa_wq_size=128

# --iaa: true - enable iaa.
# --iaa_mode: 0 - shared, 1 - dedicated
# --iaa_devices: 0 - all devices or start and end device number. 
#  For example, 1, 7 will configure all the Socket0 devices in host or 0, 3  will configure all the Socket0 devices in guest
#               9, 15  will configure all the Socket1 devices and son on
#               1  will conigure only device 1
# iaa_wq_size: 1-128
```

IAX is required to provide compression/decompression support. Thus, the host `/dev` directory should be mounted to the container's `/dev` directory with `-v /dev:/dev` parameters,

### Intel Optimized MongoDB

#### Environment

CPU: SPR E3.

OS: CentOS stream 9 /Ubuntu.

Kernel: Linux kernel 6.8.
Install from RPM: [https://www.elrepo.org](https://www.elrepo.org/).

Check IAA device:

```shell
$ lspci | grep 0cfe
Expected output:
6a:02.0 System peripheral: Intel Corporation Device 0cfe
6f:02.0 System peripheral: Intel Corporation Device 0cfe
```

#### BIOS setting

Enable VT-d:

```
Socker Configuration -> IIO Configuration -> Intel VT For Directed I/O (VT-d) -> Intel VT For Directed I/O --> Enable
Socket Configuration -> IIO Configuration -> Intel VT for Directed I/O (VT-d) Option: No -> Yes
Socket Configuration -> IIO Configuration -> Interrupt Remapping Option: No -> Yes
Socket Configuration -> IIO Configuration -> PCIe ENQCMD /ENQCMDS -> Enable
Socket Configuration -> Processor Configuration -> VMX -> Enable
```

Enable Illegal MSI Mitigation for SKUs other than SPR E5:

```
Socket Configuration/IIO Configuration/Intel VT for Directed I/O (VT-d)/Opt-Out Illegal MSI Mitigation = enabled
```

#### Kernel setting

Add kernel parameters: "intel_iommu=on,sm_on no5lvl".

```
sudo grubby --update-kernel=DEFAULT --args="intel_iommu=on,sm_on iommu=pt"
sudo update-grub && sudo reboot
```

On the next reboot, the kernel should be started with the boot parameter. To permanently remove it, simply remove the parameter from GRUB_CMDLINE_LINUX_DEFAULT and run sudo update-grub again. To verify your changes, you can see exactly what parameters your kernel booted with by executing `cat /proc/cmdline`.

#### Dependency

Install accel-config:

- Install from yum: yum install accel-config

- Install from source(https://github.com/intel/idxd-config) on ubuntu: please refer to [https://github.com/intel/idxd-config#build](https://github.com/intel/idxd-config%23build).

#### IAA configuration

Enable 1 IAA devices as example:

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

### Stacks

- `mongodb441_base`: the stack of MongoDB 4.4.1 on Ubuntu 22.04;
- `mongodb604_base`: the stack of MongoDB 6.0.4 on Ubuntu 22.04;
- `mongodb604_ubuntu2404`: the stack of MongoDB 6.0.4 on Ubuntu 24.04;
- `mongodb604_redhat`: the stack of MongoDB 6.0.4 on Redhat;
- `mongodb710_iaa`: the stack of Intel optimized MongoDB 7.1.0 with IAA;
- `mongodb700_base`: the stack of MongoDB 7.0.0 on Ubuntu 22.04;
- `mongodb800_base`: the stack of MongoDB 8.0.0 on Ubuntu 22.04;

Here is an example to set the stack (default: mongodb441_base).

```shell
cmake .. -DBECHMARK=stack/MongoDB -DSTACK=mongodb710_base
```

### Test Case

- `mongodb_sanity`
  This testcase is the unit test of MongoDB.

Here is an example to run the unittest with Intel optimized MongoDB.

```shell
ctest -R mongodb_sanity$ -VV --set MONGODB_VERSION="7.1.0" --set INTEL_FEATURE="iaa"
```


### See also

The stack version was based on [Mongo-ycsb workload](../../workload/Mongo-ycsb). 