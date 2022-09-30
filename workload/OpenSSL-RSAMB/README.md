
### Introduction

This is the speed test in the OpenSSL software, integrated with the QAT software stack. 

### Test Case

- **rsa**: This test case meausres the RSA cipher performance.  
- **dsa**: This test case meausres the DSA cipher performance.  
- **ecdsa**: This test case meausres the ECDSA cipher performance.  
- **ecdh**: This test case measures the ECDH (x25519) cipher performance.  
- **aes-sha**: This test case measures AES-CBC cipher performance.
- **aes-gcm**: This test case measures AES-GCM cipher performance.  

For each test case, there are a few variations: `sw`, `qatsw`. The `sw` test case is the default performance from the OpenSSL software. The `qatsw` test case is the performance optimized with QAT (`IPPMB` and `IPSECMB`).

### Docker Image

The workload provides the following docker images: `openssl-rsamb-qat-sw`. The `-qat-sw` image must be used to run the `qatsw-*` test cases.

The workload supports the following environment variables:  
- **`CONFIG`**: Specify the workload configuration: `(sw|qatsw)-(rsa|dsa|ecdsa|ecdh|aes-sha)`.  
- **`ASYNC_JOBS`**: Specify the number of asynchronous submissions. Default 64.  
- **`PROCESSES`**: Specify the number of processes. Default 8.  

```
mkdir -p logs-sw-rsa
id=$(docker run --rm --detach -e CONFIG=sw-rsa openssl-rsamb-qat-sw)
docker exec $id cat /export-logs | tar xf - -C logs-sw-rsa
docker rm -f $id
```

```
mkdir -p logs-qatsw-rsa
id=$(docker run --rm --detach -e CONFIG=qatsw-rsa openssl-rsamb-qat-sw)
docker exec $id cat /export-logs | tar xf - -C logs-qatsw-rsa
```

### KPI

Run the [`kpi.sh`](kpi.sh) script to parse the KPIs from the validation logs. The script takes the following command line argument:  

```
Usage: (sw|qatsw)-(rsa|dsa|ecdsa|ecdh|aes-sha)
```

#### RSA/DSA/ECDSA KPI

- **`sign (s)`**: The signing time measured in seconds.   
- **`sign/s`**: The signing throughput in terms of # of signing operations per second.  
- **`verify (s)`**: The verification time measured in seconds.  
- **`verify/s`**: The verification throughput in terms of # of verification operations per second.  

#### ECDH KPI

- **`op (s)`**: The cipher time measured in seconds. 
- **`op/s`**: The cipher throughput in terms of # of operations per second.  

#### AES KPI

- **`(k)`**: The cipher throughput.  

### Index Info
- Name: `OpenSSL RSAMB`  
- Category: `Synthetic`  
- Platform: `ICX`
- Keywords: `QAT`  
- Permission:

### See Also

- [OpenSSL](https://www.openssl.org)

