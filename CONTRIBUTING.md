## Welcome to the Service Framework Workload Repository Contributing Guide

### Evaluate Workloads

Follow the [README](README.md#prerequisite) instructions to setup [local](doc/user-guide/preparing-infrastructure/setup-docker.md), [remote](doc/user-guide/preparing-infrastructure/setup-cumulus.md), or [Cloud](doc/user-guide/preparing-infrastructure/setup-cumulus.md) systems to evaluate any [supported workloads](worklod/README.md#list-of-workloads). 

You can choose to build the workloads and evaluate the workload execution with `ctest`, which manage the workload test cases. You can run any subset of the test cases or all of them. 

### Submit Issues

If you spot a problem with the repository, submit an issue at the **github issues**.  

### Contribute to Workload Development

Here is a list of references you can follow for workload development:
- A workload consists of a few critical pieces of scripts or manifests, documented in [Workload Elements](doc/developer-guide/component-design/workload.md):
  - [`CMakeLists.txt`](doc/developer-guide/component-design/cmakelists.md)  
  - [`build.sh`](doc/developer-guide/component-design/build.md)  
  - [`Dockerfiles`](doc/developer-guide/component-design/dockerfile.md)  
  - [`cluster-config.yaml.m4`](doc/developer-guide/component-design/cluster-config.md)  
  - [`kubernetes-config.yaml.m4`](doc/developer-guide/component-design/kubernetes-config.md)  
  - [`validate.sh`](doc/developer-guide/component-design/validate.md)  
  - [`kpi.sh`](doc/developer-guide/component-design/kpi.md)  
- The best way to start a new workload development is by copying the [dummy](workload/dummy) workload and then modifying it to your needs. 

### Submit Contributions

Thanks for your contribution to the Service Framework workload repository. Whether you plan to modify an existing workload or to create a new workload, please fork the SF workload repository to your own private work place. Make modifications there. Then submit a merge request. The branches of the main repository are reserved for release-related activities.  

