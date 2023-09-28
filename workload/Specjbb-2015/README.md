>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

The SPECjbb 2015 (<https://www.spec.org/jbb2015/>) benchmark has been developed to measure performance based on the latest Java application features.
It is relevant to all audiences who are interested in Java server performance, including JVM vendors, hardware developers, Java application developers, researchers and members of the academic community.

### Configure Options

@see [./scripts/specjbb.env.sh](./scripts/specjbb.env.sh) for full list arguments that can be configured/passed in
Please pay special attention to: **large pages**

- *large pages* and *huge pages* terms are used interchangably and mean the same thing
- they are currently **disabled** by default using the `SPECJBB_USE_HUGE_PAGES` parameter, for all tests
- Please note, to get optimal performance for a test, they should be enabled by setting the variable to true, i.e., `SPECJBB_USE_HUGE_PAGES=true`
- if you are running the workload on a lower spec machine, i.e., any machine `<= 16Gb` then it is recommended you disable them by running `SPECJBB_USE_HUGE_PAGES=false` as you'll invariably have a problem with memory allocation, without heavily configuring the workload parameters
- When `SPECJBB_USE_HUGE_PAGES=true` @see [System Requirements](#system-requirements) for configuration guide
  - Note: `HUGEPAGE_MEMORY_NUM` needs to be tuned to get the best possible jOPS value, when set to true
  - @see `HUGEPAGE_MEMORY_NUM` in [./scripts/specjbb.env.sh](./scripts/specjbb.env.sh) for details
  - @example of how to manually invoke "your_test_case_name" with 2Mb huge pages configured by default, that will consume 32Gi of huge pages
  
```bash
./ctest.sh -R <your_test_case_name> -V --set SPECJBB_USE_HUGE_PAGES=true --set SPECJBB_HUGE_PAGE_SIZE=2m --set HUGEPAGE_MEMORY_NUM=2Mb*32Gi
```

#### SpecJBB binaries

SPECjbb 2015 is a commercial benchmark a requires a licensed version. Before you run `make` to build the workload you need to do the following ( to specify the location of where your licensed version of SPECjbb 2015 is ).

```bash
# Note: SPECjbb2015 has 2 versions 1.02 or 1.03
export SPEC_JBB_VER="1.03"

# Note: must be a .tar.gz file of the following format "SPECjbb2015-${SPEC_JBB_VER}.tar.gz"
export SPEC_JBB_PKG=<location.of.your.licensed.version/SPECjbb2015-${SPEC_JBB_VER}.tar.gz>

# Now run make to build your workload
make
```

**Note:** The contents of `SPECjbb2015-${SPEC_JBB_VER}.tar.gz` must be

- `./SPECjbb2015-${SPEC_JBB_VER}.tar.gz/${SPEC_JBB_VER}`
  *@example* if the `SPEC_JBB_VER` your using is `1.03` then when you extract the tar archive, the specjbb2015.jar and all its configuration should be located in `./SPECjbb2015-1.03/1.03/`.

Simple snapshot should look like

- `/SPECjbb2015-1.03/1.03/specjbb2015.jar`
- `/SPECjbb2015-1.03/1.03/docs/`
- ....

### Docker Images

The workload provides the following docker images, JDK vendor and version as postfix:

- specjbb-2015-openjdk-11.0.11
- specjbb-2015-openjdk-16.0.2
- specjbb-2015-openjdk-17.0.1
- specjbb-2015-openjdk-18.0.2.1
- specjbb-2015-zulu-16.32.15
- specjbb-2015-zulu-17.36.17
- specjbb-2015-zulu-18.32.12
- specjbb-2015-zulu-19.30.11

The workload currently runs specjbb in 2 modes:

- *composite*    all services run in a single jvm
- *multi mode*   all services run in separate individual jvm's but on 1 host.

```bash
mkdir -p logs
id=$(docker run --rm --detach -e SPECJBB_DURATION=600 --cap-add SYS_NICE --user 70001:70001 \
-e SPECJBB_WORKLOAD_CONFIG=multijvm_max_general -e PLATFORM=SPR -e WORKLOAD=specjbb_2015 \
--rm specjbb-2015-openjdk-17.0.1:latest)
docker exec $id cat /export-logs | tar xf - -C logs
docker rm -f $id
```

### Test Case

`Multijvm Mode`
There are currently 3 test cases available for each `jdk` vendor

- `test_specjbb_2015_${jdk}_multijvm_crit_ops_pkm`
    *Specjbb run type is [HBIR_RT_LOADLEVELS] in multi-mode. critical-jOPS is primary kpi*
- `test_specjbb_2015_${jdk}_multijvm_max_jops_pkm`
    *Specjbb run type is [HBIR_RT_LOADLEVELS] in multi-mode. max-jOPS is primary kpi*
- `test_specjbb_2015_${jdk}_multijvm_gated`
    *Specjbb run type is [PRESET] in multi-mode. critical-jOPS is primary kpi*

`composite Mode`
There are currently 2 test cases available only for openjdk vendor

- `test_specjbb_2015_${jdk}_composite_base`
    *Specjbb run type is [HBIR_RT_LOADLEVELS] in composite-mode. max-jOPS is primary kpi*
- `test_specjbb_2015_${jdk}_composite_gated`
    *Specjbb run type is [PRESET] in composite-mode. critical-jOPS is primary kpi*

The currently supported versions for each `jdk` vendor are in the table below.
To change jdk version for a specific vendor, as an @example, run the following

 ```bash
  ./ctest.sh -V -R test_specjbb_2015_zulu_multijvm_gated --set JDK_PACKAGE=16.32.15
 ```

#### Notes

- Highlighted in bold is the default version used

|                 | `zulu JDK`   | `openjdk`      |
|:---------------:|:------------:|:--------------:|
| `JDK_PACKAGE =` | N/A          | 16.0.2         |
| `JDK_PACKAGE =` | N/A          | **17.0.1**     |
| `JDK_PACKAGE =` | N/A          | 18.0.2.1       |
| `JDK_PACKAGE =` | **19.30.11** | N/A            |

#### Errors

The workload makes sensible calculations based on user input and machine details, but working with huge/large pages and ensuring the workload runs (with all its services) in its entirety, within the bounds of huge pages, can sometimes lead to breaching the underlying machine's resources. To help diagnose where a problem has occurred (if any) a `workload_finished.log` is produced for each test, that details the machine and containers resources (when complete)

### Customize Configurations

It is possible to specify a global test configuration file to overwrite any configuration parameter of a test case: [`Customize Configurations`](../../doc/ctest.md#customize-configurations). For typical AWS instances, here are some recommended configurations defined in this [path](test_config_file).
To reproduce the performance data of on-premises platform, which is shown in wsf performance report, the configurations are also defined [`icx`](test_config_file/test-config-icx8358.yaml) & [`spr`](test_config_file/test-config-spr.yaml).
To run test cases with customize configurations, you can set the value of exposed parameters in [`test-config-customize.yaml`](test_config_file/test-config-customize.yaml) and run with below command line:

```bash
TEST_CONFIG=<wsf-path>/workload/Specjbb-2015/test_config_file/test-config-customize.yaml ./ctest.sh -V
```

### KPI

Run the [`kpi.sh`](kpi.sh) script to parse the KPIs from the validation logs.
For primary KPI [@see](#test-case)

The following KPIs are generated:

- **`max-jOPS`**: A sustainable full system capacity throughput metric. This is the primary KPI.
- **`critical-jOPS`**: A throughput under response time constraint metric.

### System Requirements

- To run the `gated` test, a min. of `8Gb` memory is required
- To run the `main` or `pkb` tests, the min. memory needed is dependant on if `SPECJBB_USE_HUGE_PAGES` is enabled or not.
  - If `SPECJBB_USE_HUGE_PAGES=false` its recommended a min. of 16gb for those tests (with default configuration)
  - If `SPECJBB_USE_HUGE_PAGES=true` then you need to configure the number of huge pages you want by setting the `HUGEPAGE_MEMORY_NUM` variable.
    - Rule of thumb memory calculations for huge pages:
        1) The min. memory requirements for a machine should be the memory value of `HUGEPAGE_MEMORY_NUM` by 2 (to run other core services that don't leverage huge page's).
        For example if the memory allocation for `HUGEPAGE_MEMORY_NUM` is 16Gb, then the min. memory requirements for the underlying machine would be 32Gb
        2) To calculate the number of huge pages you need the following formulae can be used as a rough guide `(SPECJBB_XMX x SPECJBB_GROUPS + 2 x SPECJBB_GROUPS + 2 + 2)` and update the `HUGEPAGE_MEMORY_NUM` with the value, accordingly
            - For formula, the first `2` means the heap size of transaction injector and the second `2` stands for the heap size used by controller. We also need `2GB` more for JVM to store some other runtime data, otherwise there might be a core dump error during the test.
    - `HUGEPAGE_MEMORY_NUM` is currently defaulted to "2Mb\*16Gi" which states
      a huge page size of 2Mb that will have a total memory allocation of 16Gi. *Note:* this will require (16*512)=8192 pages ( which is calculated automatically )
    - *Note:* this value can and should be overridden depending on your machine configuration and test i.e `HUGEPAGE_MEMORY_NUM=2Mb*<new_value>Gi`

  - To run the `main` or `pkb` test cases, using an on-prem machine, it's necessary to configure hugepage(s), manually. You can use command(s) below on your *worker* node:

    ```bash
    # 2Mb huge pages
    echo <-hugepage_2m_num> | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
    # or (if using 1Gi huge pages)
    echo <-hugepage_2m_num> | sudo tee /sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages

    sudo systemctl daemon-reload
    sudo systemctl restart docker
    sudo systemctl restart kubelet
    ```

    And also ensure transparent huge pages are set to always on, by running the following on your *worker* node:

    ```bash
    echo always | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
    echo always | sudo tee /sys/kernel/mm/transparent_hugepage/defrag

    sudo systemctl daemon-reload
    sudo systemctl restart docker
    sudo systemctl restart kubelet
    ```

  - Kubernetes
    - if running with kubernetes, use the following command to find out how many hugepage(s) are recognized by kubernetes and also the amount of cpu capacity left in each node
      - `kubectl describe node $(kubectl get nodes --no-headers | grep -v controller | awk '{print $1}') | grep -iAP6 "capacity|allocatable"`
    - depending on the capacity in the cluster, and if you decide to use huge pages, you can configure the huge page amount and cpu core using the following 2 variables
    @see [./scripts/specjbb.env.sh](./scripts/specjbb.env.sh) for definitions
      - `HUGEPAGE_MEMORY_NUM`
      - `HUGEPAGE_KB8_CPU_UNITS`

  - The method to calculate total amount of hugepage is described in the "Performance BKM" section below.

### SPR Machines

Sapphire Rapids machines require different formula to calculate parameters, but can be overridden as per users requirement.

- If SNC is enabled, T = (Core(s) per socket) *(sockets)* (core  per thread) / (no of groups)
- If SNC is disabled, T = (Core(s) per socket) / (no of groups)

```plaintext
  where T is used for calculating other parameters.
  SPECJBB_TIER_1_THREADS = 8.50*T
  SPECJBB_TIER_2_THREADS = 0.23*T
  SPECJBB_TIER_3_THREADS = 1.00*T
  SPECJBB_GC_THREADS = T
```

### Performance BKM

- HW Config
  - ICX:
    - CPU: Intel(R) Xeon(R) Platinum 8358 CPU @ 2.60GHz
    - Core Number: 32 Cores Per Socket
    - Memory: DDR4 DRAM with 3200MT/s
  - SPR:
    - CPU: D0 QY08; Frequency 1.90GHz
    - Core Number: 56 Cores Per Socket
    - Memory: DDR5 DRAM with 4800MT/s
  - Cloud:
    - ICX: AWS m6i.32xlarge

- FW/SW Version For OnPrem Test Only
  - ICX:
    - BIOS: SE5C620.86B.01.01.0003.2104260124
    - OS: CentOS Stream release 8
    - Kernel: 4.18.0-348.el8.x86_64
  - SPR:
    - BIOS: EGSDCRB1.86B.0071.D03.2112251345
    - OS: CentOS Stream release 8
    - Kernel: 5.15.0-spr.bkc.pc.2.10.0.x86_64
- BIOS Setting For OnPrem Test Only
  - ICX:
    - HT: Enable (Advanced->Processor Configuration->Intel Hyper-Threading Tech)
    - SNC-2: Enable (Advanced->Memory Configuration->Memory RAS and Performance Configuration->SNC(Sub NUMA))
    - Turbo Mode: Enable (Advanced->Power & Performance->CPU P State Control->Intel Turbo Boost Technology)
  - SPR:
    - HT: Enable
    - SNC-4: Enable
    - Turbo Mode: Enable
- Workload Parameter Tuning Tips
  See [./scripts/specjbb.env.sh](./scripts/specjbb.env.sh)

Notice(s):
For `pkm`, `main`, `loadlevel` and `hbir_rt` tests

1. The normally take just under 120 mins to complete
2. If `SPECJBB_USE_HUGE_PAGES=true` The total hugepage amount should not be larger than free memory of the system under test. Otherwise the system may crash after set the hugepage or when running this workload.
3. `SPECJBB_TUNE_OPTION` is defaulted to:

    - `regular` for tuning the BE service if `SPECJBB_XMS,SPECJBB_XMN,SPECJBB_XMS` are not explicitly set by the user.
    - To set the tuning level to `max`. if `SPECJBB_XMS,SPECJBB_XMN,SPECJBB_XMS` are not explicitly set by the user, set `SPECJBB_TUNE_OPTION` to: `max`
    - When set to `max`, the calculation used for `SPECJBB_XMX` is `(1 * (cores / SPECJBB_GROUPS)) GB` see [scripts/specjbb.env.sh](scripts/specjbb.env.sh) for full description(s)

Since every system has its own suitable configurations, the recommended parameters may not lead to the best performance. And when meeting the known issue listed below(kpi is 0 and test case passed), reducing T1 may help.

### See Also

- [Specjbb UserGuide](https://www.spec.org/jbb2015/docs/userguide.pdf)
