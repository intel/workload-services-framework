>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

This is a native implementation of a dummy workload. It is used as a reference for native workload development. 

### Testcases

The dummy-native workload organizes the following common test cases:  

- `pi_fail`: This test case calculates `PI` to the 2000 digits, delay 10 seconds, and then intentionally return a failure.  
- `pi_pass`: This test case calculates `PI` to the 2000 digits, delay 10 seconds, and then return a success.  
- `pi_pkm`: This test case calculate `PI` to the 2000 digits.  
- `gated`: This test case validates the workload feature.  

### Configurations

The dummy-native workload can be configured with the following parameters:  

- **`SCALE`**: Specify the number of PI digits that should be calcualted.
- **`SLEEP_TIME`**: Specify the workload duration.
- **`RETURN_VALUE`**: Specify the return status code.

### Evaluation

Run workload testcase as follows:

```
# Run the _pkm test case with SCALE=3000
wsf-test --set SCALE=3000 -R pi_pkm -V
```

### KPI

The following KPI is defined:

- `throughput`: The workload throughput value in the unit of digits/second.  

```
wsf-kpi logs*
```

### Performance BKM

The dummy-native workload can run on any system with a `native` setup.  


### See Also

- [Workload Elements](../../doc/developer-guide/component-design/workload.md)
- [Native Implementation](../../doc/developer-guide/component-design/native.md)

