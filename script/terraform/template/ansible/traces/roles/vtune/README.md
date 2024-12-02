
### Introduction

VTune POC to collect hotspots with HW sampling
- Integrated public release vtune
- Tested using Llama2 (OOB), Stream and HPCG
- Tested using TERRAFORM_OPTIONS=--docker 
- Workload needs to be run with DOCKER_OPTIONS="--privileged"
- Can be triggered with TERRAFORM_OPTIONS=--vtune
- Trace log will be archived in vtune.tar.gz and can be opened by vtune GUI

### POC Logs
[Stream](https://wsf-dashboards.intel.com/services-framework/perfkitruns/run_uri/33d45328-78dd-4769-b1df-9003421c03da) : It is too short to get enough detail.

[HPCG](https://wsf-dashboards.intel.com/services-framework/perfkitruns/run_uri/38c548a9-b85a-47d5-955b-fac76b489160) : Run with gated. Still a large log file .

### Parameters

Pls refer to defaults/main.yaml with definitions in comments

### System Requirements

- Only supports baremetal system

### Trace Log

- vtune.tar.gz inside WSF logs sub-folder. For example: worker-0-1-vtune\vtune.tar.gz

### Contact
- Stage1 Contact: `Alex H Zhang`

### Validation Notes

- TODOs:  
  - Doesn't support pre-PRQ systems. Need to enable internal vtune
  - Still in experiement to attach to a specific process in a docker image

- Known Issues:
  - There might be unknow modules while resolving symbols in report

### Trouble Shooting
- If any issue while vtune collection, please check vtune log under worker-*-*-vtune first
- Try to set config `vtune_force_install` to `yes` to see if it help solve issues
- If there is issue while using HW sampling, please check if driver is installed and do force install also
```
lsmod | grep sep
lsmod | grep vtsspp
```
- If ctest is pending on trace stop for long time, please try to kill the vtune / amplxe related process manually, then retest

### See Also
- [Profiling a docker image](https://www.intel.com/content/www/us/en/docs/vtune-profiler/cookbook/2023-0/profiling-in-docker-container.html)   
- [Install Internal vtune for Pre-PRQ Systems](https://intel.sharepoint.com/sites/vtune)  
