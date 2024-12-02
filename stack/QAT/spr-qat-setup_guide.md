### Introduction

The `spr-qat-setup` image generates the QAT device configurations (`/etc/qat4xxx.conf`). 

### Configuration

The following environment variables can be used to configure the device configurations:  
- **`DEVICES`**: The number of QAT devices.  
- **`SERVICES_ENABLED`**: The QAT services to be enabled: `dc`, `sym`, or `asym`. At most two services can be enabled, for example, `dc;sym`.  
- **`CY_INSTANCES`**: The number of crypto instances.  
- **`DC_INSTANCES`**: The number of compression/decompression instances.  
- **`PROCESSES`**: The number of kernel processes. 
- **`THREADS`**: The maximum number of application processes.  
- **`ASYNC_JOBS`**: The maximum number of asynchronous job submissions.  

### Usage

Invoke the `spr-qat-setup` image as follows:

```
docker run --rm -v /opt/intel/QAT/build:/opt/intel/QAT/build -v /etc:/opt/intel/etc \
       -v /dev:/dev -e DEVICES=8 -e SERVICES_ENABLED=dc spr-qat-setup /qat-invoke.sh
```

This image can also be used as a base image. See [`QATzip`](../../workload/QATzip) for an example.  