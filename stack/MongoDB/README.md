### MongoDB

MongoDB is a source-available cross-platform document-oriented database program. Classified as a NoSQL database program, MongoDB uses JSON-like documents with optional schemas.

### Images

This image can be used almost exactly like the official DockerHub MongoDB image. The naming of MongoDB images follow the rules: `<PLATFORM>-mongodb<VERSION>-<USAGE>`. `PLATFORM` can be `amd64`; `VERSION` can be `441`, ... ; `USAGE` can be `base`.

Example to build and run the intel optimized docker image of MongoDB:

```shell
# build image
docker build . -f Dockerfile.1.amd64mongodb441 -t amd64-mongodb441:<tag> --build-arg http_proxy --build-arg https_proxy --build-arg no_proxy --network=host
# run container using built image
docker run --name mongodb441 --privileged --network host -v /dev:/dev amd64-mongodb441:<tag>
```

IAX is required to provide compression/decompression support. Thus, the host `/dev` directory should be mounted to the container's `/dev` directory with `-v /dev:/dev` parameters,

### Intel Optimized MongoDB

#### Environment

CPU: SPR E3.

OS: CentOS stream 8 /Ubuntu.

Kernel: Linux kernel 5.18.
Install from RPM: [https://www.elrepo.org](https://www.elrepo.org/).

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

```

### Stacks

- `mongodb441_base`: the stack of MongoDB 4.4.1;

Here is an example to set the stack (default: mongodb441_base).

```shell
cmake .. -DBECHMARK=stack/MongoDB -DSTACK=mongodb441_base
```

### Test Case

- `mongodb_sanity`
  This testcase is the unit test of MongoDB.


### See also

The stack version was based on [Mongo-ycsb workload](workload/Mongo-ycsb). Please contact original workload creators (listed above) regarding any questions about this workload.

