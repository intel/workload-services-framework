# MongoDB-IAA-Recipe

Note: Intel IAA: Intel® In-Memory Analytics Accelerator

Keywords {#keywords .mume-header}
--------

DBMS, database management system, document database, nosql, online analytical processing, data compression, hardware-assisted codec, Intel IAA

Software Components {#software-components .mume-header}
-------------------

Table 1 lists the necessary software components.\
The descending row order represents the install sequence.\
The recommended component version and download location are also
provided.

Table 1: Software Components

|  Component | Version |
| ----- | ----- |
|  CentOS | CentOS Linux release 8.4.2105|
|  MongoDB | [v7.1.0](https://github.com/mongodb/mongo)|
|  IDXD-CONFIG | [accel-config-v3.4.6.4](https://github.com/intel/idxd-config.git)|
|  Kernel | [5.18.6-1.el8.elrepo.x86\_64](https://www.kernel.org/)|
|  QPL | [1.1](https://github.com/intel/qpl)|

### Download MongoDB {#download-mongodb .mume-header}

To enable IAA, basically we have two Pull Requests, one is to add IAA
compressor in
[WiredTIger](https://github.com/mongodb/mongo/commit/6aa17cc64ac9e651f3934de7b9d9ef1dff8be30d),
this Pull Request has already been merged in to Wiredtiger and will be
included in MongoDB 7.1RC0. The other [Pull
Request](https://github.com/mongodb/mongo/pull/1543) has been submited
and work in progress to be merged.

So we need to fetch the 2nd Pull Request in order to build a complete
IAA support in MongoDB, as below.

``` {.language-shell data-role="codeBlock" info="shell"}
cd [SOURCE DIR]
$ git clone https://github.com/mongodb/mongo.git
$ cd mongo 
$ git fetch origin pull/1543/head
$ git checkout -b pullrequest FETCH_HEAD
$ git log
```

If it succeed, git log will show the commit information of QPL/IAA.

### Install dependency {#install-dependency .mume-header}

Install libcurl\
yum install libcurl-devel.x86\_64\
GCC 11.3 or newer\
Python 3.7\
Install MongoDB requirements:

``` {.language-shell data-role="codeBlock" info="shell"}
cd [SOURCE DIR]
python3 -m pip install -r etc/pip/compile-requirements.txt
```

### Build MongoDB {#build-mongodb .mume-header}

#### Build MongoDB with IAA {#build-mongodb-with-iaa .mume-header}

``` {.language-shell data-role="codeBlock" info="shell"}
cd [SOURCE_DIR]/mongo    
python3 buildscripts/scons.py install-mongod --release=RELEASE --separate-debug=on -j 28 --disable-warnings-as-errors --opt=on 
```

Once complete, you\'re expected to get mongod executable program in the
dir \"\[SOURCE\_DIR\]/build/install/bin/\"

#### Known issue {#known-issue .mume-header}

1.  Error, Checking if linker supports -fuse-ld=lld\... no\
    Solution: The recommended linker \'lld\' is not supported with the
    current compiler configuration, you can try the \'gold\' linker with
    \'\--linker=gold\'

    ``` {.language-shell data-role="codeBlock" info="shell"}
    python3 buildscripts/scons.py install-mongod --release=RELEASE --separate-debug=on -j 28 --disable-warnings-as-errors --opt=on --linker=gold
    ```

2.  Invalid MONGO\_VERSION\
    Need to add an option during build: MONGO\_VERSION=7.1.0, details as
    below.

    ``` {.language-shell data-role="codeBlock" info="shell"}
    python3 buildscripts/scons.py install-mongod --release=RELEASE --separate-debug=on -j 28 --disable-warnings-as-errors --opt=on --linker=gold MONGO_VERSION=7.1.0
    ```

3.  Cannot find system library \'lzma\' required for use with libunwind

    ``` {.language-shell data-role="codeBlock" info="shell"}
     $/bin/ld.gold -llzma -verbose
     /bin/ld.gold -llzma -verbose
     /bin/ld.gold: Attempt to open //lib/liblzma.so failed
     ls /usr/lib64/liblzma.so*
     /usr/lib64/liblzma.so.5  /usr/lib64/liblzma.so.5.2.4
     ln -s /usr/lib64/liblzma.so.5.2.4 /usr/lib64/liblzma.so
    ```

#### Tips {#tips .mume-header}

We developed this IAA deflate feature based on mongodb v7.1.0 baseline
with the commit id of 7f6eac6452a6e6e5739009117cd3b31417a95cac

### Build YCSB {#build-ycsb .mume-header}

#### Download YCSB source code {#download-ycsb-source-code .mume-header}

If you need to build whole YCSB from source, refer to this
[LINK](https://github.com/brianfrankcooper/YCSB/#building-from-source)

Suggested Steps:

1.  Download

    ``` {.language-shell data-role="codeBlock" info="shell"}
    git clone -b 0.17.0 https://github.com/brianfrankcooper/YCSB.git
    ```

2.  We need to apply one patch to reduce the randomess of YCSB generated
    data, otherwise the default data generated is too random and as a
    result for Snappy the size will expand that makes the perf.
    evaluation not representitive.

    ``` {.language-shell data-role="codeBlock" info="shell"}
     --- a/core/src/main/java/site/ycsb/RandomByteIterator.java
     +++ b/core/src/main/java/site/ycsb/RandomByteIterator.java
     @@ -37,15 +37,15 @@ public class RandomByteIterator extends ByteIterator {

         switch (buffer.length - base) {
         default:
     -      buffer[base + 5] = (byte) (((bytes >> 25) & 95) + ' ');
     +      buffer[base + 5] = (byte) (((bytes >> 20) & 31) + ' ');
         case 5:
     -      buffer[base + 4] = (byte) (((bytes >> 20) & 63) + ' ');
     +      buffer[base + 4] = (byte) (((bytes >> 20) & 23) + ' ');
         case 4:
     -      buffer[base + 3] = (byte) (((bytes >> 15) & 31) + ' ');
     +      buffer[base + 3] = (byte) (((bytes >> 10) & 31) + ' ');
         case 3:
     -      buffer[base + 2] = (byte) (((bytes >> 10) & 95) + ' ');
     +      buffer[base + 2] = (byte) (((bytes >> 10) & 31) + ' ');
         case 2:
     -      buffer[base + 1] = (byte) (((bytes >> 5) & 63) + ' ');
     +      buffer[base + 1] = (byte) (((bytes) & 31) + ' ');
         case 1:
         buffer[base + 0] = (byte) (((bytes) & 31) + ' ');
         case 0:
    ```

    You need to save the patch above to file:
    ycsb\_increase\_compr\_ratio.patch, then execute through command
    line to apply the patch.

    ``` {.language-shell data-role="codeBlock" info="shell"}
    patch -p1 < ycsb_increase_compr_ratio.patch
    ```

    Notice: this patch is optional, but we suggest to apply for a
    reasonable compression.

3.  Build with mvn for the full distribution.

    ``` {.language-shell data-role="codeBlock" info="shell"}
     mvn clean package
    ```

IAA configuration {#iaa-configuration .mume-header}
-----------------

Below steps are to enable IAA.

### Config IAA Device on host {#config-iaa-device-on-host .mume-header}

The BIOS must be configured with `VT-d` and `PCI ENQCMD` enabled, as follows:

``` {.language-shell data-role="codeBlock" info="shell"}
EDKII Menu → Socket Configuration → IIO Configuration → Intel VT for directed IO (VT-d) → Intel VT for directed IO → Enable
EDKII Menu → Socket Configuration → IIO Configuration → PCI ENQCMD/ENQCMDS → Yes
```

The `VT-d` must be enabled from the kernel command line.

``` {.language-shell data-role="codeBlock" info="shell"}
sudo grubby --update-kernel=DEFAULT --args="intel_iommu=on,sm_on iommu=pt"
sudo reboot
```

### Install IDXD-CONFIG {#install-idxd-config .mume-header}

An IAA device can be configured with the libaccel-config library, which can be found at <https://github.com/intel/idxd-config>

``` {.language-shell data-role="codeBlock" info="shell"}
IDXD_VER=accel-config-v3.4.6.4
IDXD_REPO=https://github.com/intel/idxd-config.git

git clone -b ${IDXD_VER} ${IDXD_REPO} && \
cd idxd-config && \
    ./autogen.sh && \
    ./configure CFLAGS='-g -O2' --prefix=/usr --sysconfdir=/etc --libdir=/usr/lib64 --enable-test=yes && \
    make && \
    make install
```

Note: Check if system\'s 64 bit library is in /usr/lib64. Otherwise, please use /usr/lib. as below.

``` {.language-shell data-role="codeBlock" info="shell"}
./configure CFLAGS='-O3' --prefix=/usr --sysconfdir=/etc --libdir=/usr/lib64 
```

### Enable IAA devices {#enable-iaa-devices .mume-header}

As an example to enable two IAAs on socket0, for more details on how to
config IAAs, check this
[guideline](https://intel.github.io/qpl/documentation/get_started_docs/installation.html#accelerator-configuration)

``` {.language-shell data-role="codeBlock" info="shell"}
Here are the sh command lines to enable 4 IAA device on the same Socket.
accel-config load-config -c ./accel-iaa-2d1g8e.conf
accel-config enable-device iax1
accel-config enable-wq iax1/wq1.0
accel-config enable-device iax3
accel-config enable-wq iax3/wq3.0
```

Check appendix for file accel-iaa-2d1g8e.conf, for different IAAs need to be enabled, check with the guideline and also need to customize the configure file accordingly.

Notes: If the user tries to config IAA device inside the docker, the BIOS and kernel options of the host machine should be pre-set properly. The user also needs to set `-v /dev:/dev` as the argument to docker run

Benchmark
---------

### Prerequsitions

1.  Disable CStates

    ``` {.language-shell data-role="codeBlock" info="shell"}
    cpupower idle-set -d 3
    cpupower idle-set -d 2
    ```

2.  set performance mode of frequency governor

``` {.language-shell data-role="codeBlock" info="shell"}
cpupower frequency-set -g performance
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
```

### Benchmark with 1 MongoDB instance

1.  Table insert with IAA to MongoDB\
    Start server on 14 cores with totally 28 threads, we limit the wiredtiger cache to 10GB, use other size on demand.

    ``` {.language-shell data-role="codeBlock" info="shell"}
    numactl -C 0-13,112-125 -m 0 ./mongod --dbpath ./mongodb1/ --logpath ./mongolog1/mongod.log --port 27017 --wiredTigerCollectionBlockCompressor=iaa --wiredTigerCacheSizeGB=10
    ```

    On client, launch YCSB to load data to MongoDB

    ``` {.language-shell data-role="codeBlock" info="shell"}
    numactl -m 1 -N 1 python2 ./bin/ycsb load mongodb -P workloads/workloada_query -p mongodb.url=mongodb://localhost:27017/ycsb -threads 28
    ```

    Here you should see prompt on terminal:\
    \[INSERT\], Return=OK, 16000000 \" from Client console, which means
    client successfully insert data into database.

    For file of workloada\_query, pls check below:

    ``` {.language-shell data-role="codeBlock" info="shell"}
    recordcount=16000000
    operationcount=4000000
    workload=site.ycsb.workloads.CoreWorkload
    fieldlength=100
    fieldcount=10
    readallfields=true
    #dataintegrity=true 
    readproportion=0.9
    updateproportion=0
    scanproportion=0.1
    insertproportion=0
    maxscanlength=100
    scanlengthdistribution=uniform
    requestdistribution=zipfian
    ```

    Notice:

    1.  This is what we tested, this can be customized with any other settings.
    2.  If you need to check result integrity, set the option: dataintegrity=true

2.  Table query

    ``` {.language-shell data-role="codeBlock" info="shell"}
    numactl -m 1 -N 1 python2 ./bin/ycsb run mongodb -P workloads/workloada_query -p mongodb.url=mongodb://localhost:27017/ycsb -threads 28
    ```

    Here you should see the message \"\[READ\], Return=OK, 3600440\" and  "\[SCAN\], Return=OK, 399560" from Client console which means client successfully insert data into database.

### Tips

1.  Similarly, you could do same with other compressor like Snappy, Zlib, etc. Just specify wiredTigerCollectionBlockCompressor with differnet compressor. Accepted ones are any of "zlib", "iaa", "zstd", "Snappy" that supported by MongoDB
2.  We don\'t recommend run 1 mongodb instnacne on more than 14 cores due to overhead on kenrel spinlock observed. Instead, launch multiple MongoDB instances and pinned to different cores (with SMT) instead. When you do benchmark, lauch multiple clients accordingly to those MongoDB servers. And pls specify differnet port with option \"\--port\" for different MongoDB server.
3.  For some Sapphire Rapids SKUs, there is only 1 IAA per socket, we observed bottleneck if launch multiple MongoDB instances on such server. Pay attention to the core scaling and check if 1 IAA becomes bottleneck

Appendix
--------

#### File content: accel-iaa-2d1g8e.conf

``` {.language-shell data-role="codeBlock" info="shell"}
accel-iaa-2d1g8e.conf:
[
  {
    "dev":"iax1",
    "max_groups":4,
    "max_work_queues":8,
    "max_engines":8,
    "work_queue_size":128,
    "numa_node":0,
    "op_cap":"0xd",
    "gen_cap":"0x71f10901f0104",
    "version":"0x100",
    "state":"disabled",
    "max_batch_size":1,
    "ims_size":2048,
    "max_transfer_size":2147483648,
    "configurable":1,
    "pasid_enabled":1,
    "cdev_major":234,
    "clients":0,
    "groups":[
    {
        "dev":"group1.0",
        "grouped_workqueues":[
          {
            "dev":"wq1.0",
            "mode":"shared",
            "size":128,
            "group_id":0,
            "priority":10,
            "block_on_fault":1,
            "type":"user",
            "name":"app1",
            "max_transfer_size":2147483648,
            "threshold":128
          }
        ],


        "grouped_engines":[
          {
            "dev":"engine1.0",
            "group_id":0
          },
          {
            "dev":"engine1.1",
            "group_id":0
          },
          {
            "dev":"engine1.2",
            "group_id":0
          },
          {
            "dev":"engine1.3",
            "group_id":0
          },
          {
            "dev":"engine1.4",
            "group_id":0
          },
          {
            "dev":"engine1.5",
            "group_id":0
          },
          {
            "dev":"engine1.6",
            "group_id":0
          },
          {
            "dev":"engine1.7",
            "group_id":0
          }
        ]
     }
    ]
  },
  {
    "dev":"iax3",
    "max_groups":4,
    "max_work_queues":8,
    "max_engines":8,
    "work_queue_size":128,
    "numa_node":0,
    "op_cap":"0xd",
    "gen_cap":"0x71f10901f0104",
    "version":"0x100",
    "state":"disabled",
    "max_batch_size":1,
    "ims_size":2048,
    "max_transfer_size":2147483648,
    "configurable":1,
    "pasid_enabled":1,
    "cdev_major":234,
    "clients":0,
    "groups":[
    {
        "dev":"group3.0",
        "grouped_workqueues":[
          {
            "dev":"wq3.0",
            "mode":"shared",
            "size":128,
            "group_id":0,
            "priority":10,
            "block_on_fault":1,
            "type":"user",
            "name":"app3",
            "max_transfer_size":2147483648,
            "threshold":128
          }
        ],


        "grouped_engines":[
          {
            "dev":"engine3.0",
            "group_id":0
          },
          {
            "dev":"engine3.1",
            "group_id":0
          },
          {
            "dev":"engine3.2",
            "group_id":0
          },
          {
            "dev":"engine3.3",
            "group_id":0
          },
          {
            "dev":"engine3.4",
            "group_id":0
          },
          {
            "dev":"engine3.5",
            "group_id":0
          },
          {
            "dev":"engine3.6",
            "group_id":0
          },
          {
            "dev":"engine3.7",
            "group_id":0
          }
        ]
     }
    ]
  }      
] 
```


-end of document-
:::
