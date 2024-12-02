
# Workload types

The Workload Service Framework (WSF) supports the following types of workloads:

- **[Native workloads][Native workloads]**: The workload runs directly on the SUT (System Under Test) hosts. The workload logic is implemented by Ansible scripts.  
- **[Containerized workloads][Containerized workloads]**: The workload runs under either docker or Kubernetes. The workload logic is implemented by a set of Dockerfiles and docker/Kubernetes configuration files.   

## Native Workloads

A native workload consists of the following elements:  

- **[CMakeLists.txt][CMakeLists.txt]**: A manifest to configure how to build and test the workload.    
- **[build.sh][build.sh]**: A script for building the workload. Strictly speaking, native workloads do not need a separate build process. They build on the SUTs if required. This is just a place holder script for scanning and listing workload ingredients.    
- **[validate.sh][validate.sh]**: A script to define how to execute the workload.  
- **[kpi.sh][kpi.sh]**: A script for extracting KPI data out of the workload execution logs. 
- **[cluster-config.yaml.m4][cluster-config]**: A manifest to describe how to provision the SUTs.  
- **[Native Scripts][Native Scripts]**: The native scripts that implement the workload logic, including Ansible scripts (workload execution logic) and optional Terraform scripts (SUT provisioning logic).  
- **[README][README]**: A README to introduce the workload, configure parameters, and provide other related information.   

## Containerized Workloads

A containerized workload can run under docker (single-container) or Kubernetes (single- or multiple-containers). The workload consists of the following elements:  

- **[CMakeLists.txt][CMakeLists.txt]**: A manifest to configure how to build and test the workload.  
- **[build.sh][build.sh]**: A script for building the workload docker image(s).  
- **[validate.sh][validate.sh]**: A script for executing the workload.  
- **[kpi.sh][kpi.sh]**: A script for extracting KPI data out of the workload execution logs. 
- **[compose-config.yaml.m4/j2][compose-config]**: An optional manifest to describe how to schedule the containers with docker-compose.  
- **[cluster-config.yaml.m4/j2][cluster-config]**: A manifest to describe how to provision a machine or a set of machines for running the workload.  
- **[Dockerfiles][Dockerfiles]**: A workload may contain one or multiple Dockerfiles.   
- **[kubernetes-config.yaml.m4/j2 or helm charts][kubernetes-config]**: An optional manifest to describe how to schedule the containers to a Kubernetes cluster. 
- **[Native Scripts][Native Scripts]**: Optionally, the workload may provide native scripts for customizing the workload execution logic (Ansible scripts) or the SUT provisioning logic (Terraform scripts).  
- **[README][README]**: A README to introduce the workload, configure parameters, and provide other related information.  


[CMakeLists.txt]: cmakelists.md
[Containerized workloads]: #containerized-workloads
[Dockerfiles]: dockerfile.md
[Native Scripts]: native-script.md
[Native workloads]: #native-workloads
[README]: readme.md
[build.sh]: build.md
[compose-config]: compose-config.md
[cluster-config]: cluster-config.md
[kpi.sh]: kpi.md
[kubernetes-config]: kubernetes-config.md
[validate.sh]: validate.md