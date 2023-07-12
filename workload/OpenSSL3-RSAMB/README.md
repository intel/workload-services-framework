>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>

### Introduction

This is the speed test in the OpenSSL software, integrated with the QAT software stack.

### Test Case

- **rsa**: This test case meausres the RSA cipher performance. `|QAT_HW & QAT_SW|`
- **dsa**: This test case meausres the DSA cipher performance. `|QAT_HW & QAT_SW|`
- **ecdsa**: This test case meausres the ECDSA cipher performance. `|QAT_HW & QAT_SW|`
- **ecdh**: This test case measures the ECDH (x25519) cipher performance. `|QAT_HW & QAT_SW|`
- **aes-sha**: This test case measures AES-GCM cipher performance. `|QAT_HW & QAT_SW|`
- **aes-gcm**: This test case measures AES-GCM cipher performance. `|QAT_HW & QAT_SW|`
- **prf**: This test case measures PRF cipher performance. `|QAT_HW|`
- **hkdf**: This test case measures HKDF cipher performance. `|QAT_HW|`
- **ecx**: This test case measures ECX cipher performance. `|QAT_HW|`
- **dh**: This test case measures DH cipher performance. `|QAT_HW|`
- **chachapoly**: This test case measures CHACHA-POLY cipher performance. `|QAT_HW|`

For each test case, there are a few variations: `sw`, `qatsw` and `qathw`. The `sw` test case is the default performance from the OpenSSL software. The `qatsw` test case is the performance optimized with QAT (`IPPMB` and `IPSECMB`). The `qathw` test case is optimized with QAT HW v2.0.

### Docker Image

The workload provides the following docker images: `openssl3-rsamb-qat-sw` and `spr-openssl3-rsamb-qat-hw`. The `-qat-sw` image must be used to run the software or hardware `qat-` test cases and in edition can also run `sw-*` test cases as well. There is an additional `qathw-setup` image that is used to setup the QAT device.

The workload supports the following environment variables:
- **`CONFIG`**: Specify the workload configuration: `(sw|qatsw|qathw)-(rsa|dsa|ecdsa|ecdh|aes-sha)`.
- **`ASYNC_JOBS`**: Specify the number of asynchronous submissions. Default 64.
- **`PROCESSES`**: Specify the number of processes. Default 8.

```
mkdir -p logs-sw-rsa
id=$(docker run --rm --detach -e CONFIG=sw-rsa openssl3-rsamb-qat-sw)
docker exec $id cat /export-logs | tar xf - -C logs-sw-rsa
docker rm -f $id
```

```
mkdir -p logs-qatsw-rsa
id=$(docker run --rm --detach -e CONFIG=qatsw-rsa openssl3-rsamb-qat-sw)
docker exec $id cat /export-logs | tar xf - -C logs-qatsw-rsa
```
### KPI

Run the [`kpi.sh`](kpi.sh) script to parse the KPIs from the validation logs. The script takes the following command line argument:

```
Usage: (sw|qatsw)-(rsa|dsa|ecdsa|ecdh|aes-sha|aes-gcm)
Usage: (sw|qatsw|qathw)-(rsa|dsa|ecdsa|ecdh|aes-sha|aes-gcm|dh|hkdf|prf|ecx|chachapoly)
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
- Name: `OpenSSL3 RSAMB`
- Category: `Synthetic`
- Platform: `ICX`, `SPR`
- Keywords: `QAT`
- Permission:

### See Also

- [OpenSSL](https://www.openssl.org)
