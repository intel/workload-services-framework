# Workload Testcase 

Each workload defines a set of testcases, i.e., typical usage scenarios. Internally, each testcase encapsulates default values of workload configuration parameters. For example, the dummy workload's testcase `dummy_pi_pkm` calculates pi (π) to the 2000 digits.

## Naming patterns

You can list the testcases of a workload as follows:

```shell
cd build/workload/<WORKLOAD>
./ctest.sh -N
```

Testcases typically follow the pattern of `test_[<sut>_]<workload>_<testcase>`, where `<sut>` is optional and specific to the validation backend setting. The testcase name should be descriptive for the workload usage conditions.

For example, use `_1n` to indicate that the workload runs on a single worker node, and `_3n` to indicate that the workload runs on 3 worker nodes.

## Special Test Cases

The following testcase suffixes are reserved:
- `_gated`: A testcase suffixed with `_gated` is designed for CI commit validation. The testcase is expected to be a quick test 
of the workload software stack. To improve CI efficiency, design the testcase such that the workload completes within 5 minutes.
- `_preswa`: A testcase suffixed with `_preswa` is designed for Pre-Si performance analysis. The testcase is expected to run 
with reduced complexity such that the workload can complete in a reasonable time in Simics and still represent the main 
characteristics of the full workload execution. The workload must define [`EVENT_TRACE_PARAMS`][validate.md] and [`PRESWA_POI_PARAMS`][validate.md] 
to enable windowed emon trace collection.
- `_pkm`: A testcase suffixed with `_pkm` is designed for Post-Si performance analysis. The testcase is expected to represent 
the common use case of the workload. If the `_pkm` testcase runs relatively long (say, more than 10 minutes), the workload must 
define [`EVENT_TRACE_PARAMS`][validate.md] to enable windowed emon trace collection. Compared with `_preswa`, there is no 
complexity restriction in `_pkm`. Each workload should have at least 1 `_pkm` testcase and no more than 2 `_pkm` testcases.
- `_pdt`, `_pnp`: A testcase suffixed with `_pnp` or `_pdt` indicates that the test case contains recipes and configurations that have been approved by either the Performance PDT or the PNPJet forum. The software recipe versions 
and the workload configurations are frozen. This is designed for the users to repeat any previously approved performance data. 

## Testcase Configurations

To improve usability, define the configuration parameters of a testcase such that the workload can run on any typical platforms. 
Here the typical platform is defined as being the `AWS` `xlarge` instance equivalent, which includes 4 virtual cores and 16GB of memory. 
If a workload must use more cores or memory, the workload must declare the minimum platform requirement in [cluster-config.yaml.m4][cluster-config.yaml.m4] 
and [README.md][README.md].

In addition to the testcases defined in [`CMakeLists.txt`][cmake], a workload may define additional testcase [configuration][ctest customize-configuration] 
files to customize the testcase parameters for reproducing performance data in the workload performance report.

The testcase configuration files use the following convention: `test-config-<sut|arch>[-<identifier>].yaml`, where:
- `<sut|arch>` defines the target platform. For Cloud instances, `<sut>` is usually the Cloud provider name, matching one of the validation backend configurations, 
for example, `aws` will be matched against `terraform-config.aws.tf`. For On-Premises platforms, `<sut>` specifies 
the platform architecture, for example, `icx` or `spr`. 
- `<identifier>` is an optional string to describe the purpose of the testcase overwrite, if there are multiple testcase configurations.

The testcase configuration for below mentioned file overwrites the dummy workload testcases:

```yaml
# test-config-aws.yaml
# Overwrite the test cases for performance tunning on AWS instances.

*_pi_pass:
    SCALE: 5000
    AWS_MACHINE_TYPE: m6i.x4large
    
*_pi_fail:
    SCALE: 5000
    AWS_MACHINE_TYPE: m6i.x4large    
```

> Please note that it is important to include the Cloud instance type as part of the overwrite to completely describe the running environment.  
> Things become complicated when it comes to define an On-Premises platform setup. Please describe the complete setup as comments at the top of the configuration file. 


[validate.md]: ../../developer-guide/component-design/validate.md
[cluster-config.yaml.m4]: ../../developer-guide/component-design/cluster-config.md
[README.md]: ../../developer-guide/component-design/readme.md
[cmake]: cmake.md
[ctest customize-configuration]: ctest.md#customize-configurations
