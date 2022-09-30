
### Workload Elements

A workload consists of the following elements, some described in this document and others in the linked document:  

- **[Dockerfiles](dockerfile.md)**: A workload may contain one or many Dockerfiles.   
- **[CMakeLists.txt](cmakelists.md)**: A manifest to configure `cmake`.  
- **[build.sh](build.md)**: A script for building the workload docker image(s).  
- **[validate.sh](validate.md)**: A script for executing the workload.  
- **[kpi.sh](kpi.md)**: A script for extracting KPI data out of the workload execution logs. 
- **[cluster-config.yaml.m4](cluster-config.md)**: A manifest to describe how to provision a machine or a set of machines for running the workload.  
- **[kubernetes-config.yaml.m4](kubernetes-config.md)**: A manifest to describe how to schedule the containers to the cluster for Kubernetes.  
- **[README](readme.md)**: A README to describe the workload.  

### See Also

- [Dockerfile Requirements](dockerfile.md)   
- [Provisioning Specification](cluster-config.md)   

