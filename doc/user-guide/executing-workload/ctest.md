
### Run Test

Use `./ctest.sh` to run a single test or batch of tests. You can do this at the top-level `build` directory or under each workload directory. In the latter case, only the tests of the workload will be executed. 

```
cd build
cd workload/dummy
./ctest.sh -N
```

### CTest Options

There is extensive list of options in `./ctest.sh` to control how tests can be executed. See the `./ctest.sh` manpage. The followings are most common options.  

- *`-R`*: Select tests based on a regular expression string.   
- *`-E`*: Exclude tests based on a regular expression string.  
- *`-V`*: Show test execution with details.  
- *`-N`*: Dry-run the tests only.  

Example: list tests with `boringssl` in name excluding those with `_gated`

```
./ctest.sh -R boringssl -E _gated -N

```
Example: run only `test_static_boringssl` (exact match)

```
./ctest.sh -R '^test_static_boringssl$'
```

### Customize Configurations

It is possible to specify a test configuration file to overwrite any configuration parameter of a test case:   

```
./ctest.sh --config=test_config.yaml -V
```

The configuration file uses the following format:

```
*_dummy_pi:
    SCALE: 3000
```

where `*_dummy_pi` specifies the test case name. You can use `*` to specify a wildcard match. The subsection underneath specifies the configuration variables and values. Any parameters specified in each test case [`validate.sh`][validate.sh] can be overwritten.

Use with caution as overwriting configuration parameters may lead to invalid parameter combinations.  

### Benchmark Scripts

A set of utility scripts are linked under your workload build directory to make it easy for workload benchmark activities.  

#### `ctest.sh`

- **`ctest.sh`**: This is an extended ctest script extending the following features, besides what ctest supports:

```
Usage: [options]
--nohup          Run the test case(s) in the daemon mode for long benchmark
--daemon         Run the test case(s) with daemonize for long benchmark with cleaning of environments before workload execution.
--noenv          Clean any external environment variables before proceeding with the tests.
--loop           Run the benchmark multiple times sequentially.
--run            Run the benchmark multiple times on the same SUT(s).  
--burst          Run the benchmark multiple times simultaneously.
--config         Specify the test-config file.  
--options        Specify additional validation backend options.  
--set            Set the workload parameter values during loop and burst iterations.  
--stop [prefix]  Kill all ctest sessions.
--continue       Ignore any errors and continue the loop and burst iterations.  
--prepare-sut    Prepare cloud SUT instances for reuse.
--reuse-sut      Reuse previously prepared cloud SUT instances. 
--cleanup-sut    Cleanup cloud SUT instances. 
--dry-run        Generate the testcase configurations and then exit.  
--testcase       Specify the exact testcase name to be executed.  
```

The followings are some examples:

```
# run aws test cases 5 times sequentially
./ctest.sh -R aws --loop=5 --nohup    

# run aws test cases 5 times simultaneously
./ctest.sh -R aws --burst=5 --nohup   

# run aws test cases 4 times simultaneously with the SCALE value
# incremented linearly as 1000, 1300, 1600, 1900 in each iteration.  
# "..." uses three previous values to deduce the increment. 
./ctest.sh -R aws --set "SCALE=1000 1300 1600 ...2000" --burst=4 --nohup

# run aws test cases 4 times simultaneously with the SCALE value
# incremented linearly as 1000, 1600, 1000, 1600 in each iteration.  
# "..." uses three previous values to deduce the increment. 
# "|200" means the values must be divisible by 200.  
./ctest.sh -R aws --set "SCALE=1000 1300 1600 ...2000 |200" --burst=4 --nohup

# run aws test cases 4 times simultaneously with the SCALE value
# incremented linearly as 1000, 1600, 2000, 1000 in each iteration.  
# "..." uses three previous values to deduce the increment. 
# "8000|" means the values must be a factor of 8000. 
./ctest.sh -R aws --set "SCALE=1000 1200 1400 ...2000 8000|" --burst=4 --nohup

# run aws test cases 4 times simultaneously with the SCALE value
# incremented exponentially as 1000, 2000, 4000, 8000 in each iteration.  
# "..." uses three previous values to deduce the multiplication factor. 
./ctest.sh -R aws --set "SCALE=1000 2000 4000 ...10000" --burst=4 --nohup  

# run aws test cases 6 times simultaneously with the SCALE value
# enumerated repeatedly as 1000, 1500, 1700, 1000, 1500, 1700 in each iteration.  
./ctest.sh -R aws --set "SCALE=1000 1500 1700" --burst=6 --nohup

# run aws test cases 6 times simultaneously with the SCALE and BATCH_SIZE values
# enumerated separately as (1000,1), (1500,2), (1700,4), (1000,8) in each 
# iteration. Values are repeated as needed.   
./ctest.sh -R aws --set "SCALE=1000 1500 1700" --set BATCH_SIZE="1 2 4 8" --burst=6 --nohup

# run aws test cases 8 times simultaneously with the SCALE and BATCH_SIZE values
# permutated as (1000,1), (1000,2), (1000,4), (1000,8), (1500,1), (1500, 2), 
# (1500, 4), (1500, 8) in each iteration.   
./ctest.sh -R aws --set "SCALE=1000 1500 1700/BATCH_SIZE=1 2 4 8" --burst=8 --nohup

# for cloud instances, it is possible to test different machine types by 
# enumerating the AWS_MACHINE_TYPE values (or similar GCP_MACHINE_TYPE):
./ctest.sh -R aws --set "AWS_MACHINE_TYPE=m6i.xlarge m6i.2xlarge m6i.4xlarge" --loop 3 --nohup

# for aws disk type/disk size/iops/num_striped_disks
./ctest.sh -R aws --set "AWS_DISK_TYPE=io1 io2" --loop 2 --nohup
./ctest.sh -R aws --set "AWS_DISK_SIZE=500 1000" --loop 2 --nohup
./ctest.sh -R aws --set "AWS_IOPS=16000 32000" --loop 2 --nohup
./ctest.sh -R aws --set "AWS_NUM_STRIPED_DISKS=1 2" --loop 2 --nohup
```

See Also: [Cloud SUT Reuse][Cloud SUT Reuse]

#### `list-kpi.sh`

- **`list-kpi.sh`**: Scan the ctest logs files and export the KPI data.  

```
Usage: [options] [logs-directory]
--primary             List only the primary KPI.  
--all                 List all KPIs.  
--outlier <n>         Remove outliers beyond N-stdev.  
--params              List workload configurations.  
--svrinfo             List svrinfo information.   
--format list|xls-ai|xls-inst|xls-table  
                      Specify the output format.
--var[1-9] <value>    Specify the spread sheet variables.   
--filter _(real|throughput)
                      Specify a trim filter to shorten spreadsheet name.  
--file <filename>     Specify the spread sheet filename. 
--uri                 Show the WSF portal URI if present.   
--intel_publish       Publish to the WSF dashboard.
--owner <name>        Set the publisher owner.
--tags <tags>         Set the publisher tags.
```

> The `xls-ai` option writes the KPI data in the `kpi-report.xls` spread sheet as follows:

![image-ss-ai][image-ss-ai]
    
> where `--var1=batch_size` `--var2=cores_per_instance` `--var3='*Throughput'` `--var4=Throughput_`.  

> The `xls-inst` option writes the KPI data in the `kpi-report.xls` spread sheet as follows:

![image-ss-inst][image-ss-inst]
    
> The `xls-table` option writes the KPI data in the `kpi-report.xls` spread sheet as follows:

![image-ss-table][image-ss-table]
    
> where `--var1=scale`, `--var2=sleep_time`. Optionally, you can specify `--var3` and `--var4` variables for multiple tables in the same spreadsheet.  

### Cloud SUT Reuse

It is possible to reuse the Cloud SUT instances during the benchmark process. This is especially useful in tuning parameters for any workload.   

To reuse any SUT instances, you need to first prepare (provision) the Cloud instances, using the `ctest.sh` `--prepare-sut` command as follows:  

```
./ctest.sh -R aws_kafka_3n_pkm -V --prepare-sut
```

The `--prepare-sut` command provisions and prepares the Cloud instances suitable for running the `aws_kafka_3n_pkm` test case. The preparation includes installing docker/Kubernetes and labeling the worker nodes. The SUT details are stored under the `sut-logs-aws_kafka_3n_pkm` directory.  

Next, you can run any iterations of the test cases, reusing the prepared SUT instances with the `--reuse-sut` command, as follows:

```
./ctest.sh -R aws_kafka_3n_pkm -V --reuse-sut
```

> If `--reuse-sut` is set, `--burst` is disabled.  

Finally, to cleanup the SUT instances, use the `--cleanup-sut` command:

```
./ctest.sh -R aws_kafka_3n_pkm -V --cleanup-sut
```

SUT reuse is subject to the following limitations:
- The SUT instances are provisioned and prepared for a specific test case. Different test cases cannot share SUT instances.  
- It is possible to change workload parameters, provided that such changes do not:
  - The changes do not affect the worker node numbers.  
  - The changes do not affect the worker node machine types, disk storage, or network topologies.   
  - The changes do not affect worker node labeling.  
  - The changes do not introduce any new container images.  

---

After using the Cloud instances, please clean them up.

--- 


[validate.sh]: ../../developer-guide/component-design/validate.md
[Cloud SUT Reuse]: #cloud-sut-reuse

[image-ss-ai]: ../../image/ss-ai.png
[image-ss-inst]: ../../image/ss-inst.png
[image-ss-table]: ../../image/ss-table.png