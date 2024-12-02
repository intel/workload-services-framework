
### Introduction

This code provides experimental support to change BIOS settings on SUT machines. The support is based on `syscfg` for most production systems.

---

**As BIOS update can potential cause irreversible damage, you must explicitly enable the `--sut_update_bios` option and the `--sut_reboot` option for any BIOS related operations.**

---

### Probe BIOS Versions and Knobs

The BIOS knobs differ by different BIOS versions, which makes it difficult to provide universal BIOS setup. To probe the BIOS version on your SUT systems, do the following:

```
./ctest.sh -R <testcase> -V --options='--sut_update_bios --sut_reboot --sut_bios_probe'
```

After running the testcase, the current BIOS setup is saved under the test case logs directory under `worker-0-bios/syscfg.ini`, where you can obtain the BIOS version and the BIOS knobs.

### `cluster.bios`

As a workload developer, you can configure your workload to mandate certain BIOS settings, such as setting `HyperThreading` to be `Disabled`.

Write such configurations in `cluster-config.yaml.m4`:

```
- labels: {}
  bios:
    SE5C620.86B:
      "Intel(R) Hyper-Threading Tech": Enabled          # Disabled
      "CPU Power and Performance Policy": Performance   # "Balanced Performance", "Balanced Power", or "Power"
    EGSDCRB1.86B:
      ProcessorHyperThreadingDisable: "ALL LPs"         # "Single LP"
      ProcessorEppProfile: Performance                  # "Balanced Performance", "Balanced Power", or "Power"
```
where `SE5C620.86B` and `EGSDCRB1.86B` are BIOS version substrings. If there are multiple matches, the longest match takes precedent (according to descendent string sort.)

The BIOS knobs such as `Intel(R) Hyper-Threading Tech` and their values `Enabled` must exactly match the BIOS definitions.

### Global Options

You can overwrite any BIOS settings globally as follows:

```
./ctest.sh -R <testcase> -V --options="--sut_reboot --sut_update_bios --sut_bios_tool=syscfg --sut_bios_options=worker:ProcessorEppProfile=Performance"
```
where `--sut_bios_options` is a list of BIOS group:key=value string. Use `,` to separate the list items and `%20` to escape any whitespaces. 

### See Also

- `syscfg`: https://www.intel.com/content/www/us/en/download/765094/server-configuration-utility-syscfg-for-intel-server-boards-and-intel-server-systems.html

