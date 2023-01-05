
### Customize the Build Process:

You can use the following build options to customize the build process:  

- **PLATFORM**: Specify the platform names. See [`platforms`](../workload/platforms) for the list of platforms.  
- **REGISTRY**: Specify the privacy docker registry URL. If specified, all built images will be pushed to given docker registry.
  > `REGISTRY` must end with forward slash `/`
- **REGISTRY_AUTH**: Specify the registry authentication method. The only supported value is `docker`, which uses the docker configuration file.    
- **RELEASE**: Specify the release version. All built images will be tagged with it. Defaults to `:latest`
  > `RELEASE` must begin with colon `:`
- **BACKEND**: Specify the validation backend: [`docker`](setup-docker.md), [`kubernetes`](setup-kubernetes.md), or [`terraform`](setup-terraform.md).    
  - **TERRAFORM_OPTIONS**: Specify the `terraform` options.  
  - **TERRAFORM_SUT**: Specify the target SUT (Sytem Under Test) list.
- **TIMEOUT**: Specify the validation timeout, which contains the execution timeout and docker pull timeout. Default to 28800,300 seconds.   
- **BENCHMARK**: Specify a workload pattern. Workloads not matching the pattern will be disabled. 
- **SPOT_INSTANCE**: If specified, overwrite the `spot_instance` variable in the Cloud configuration files.   

Build examples:   

```bash
cd build
cmake -DREGISTRY=xxyyzz.com:1234 ..
```

### Command Make Targets

- **bom**: Print out the BOM list of each workload.  
- **clean**: Purge the `logs`.  

```bash
cd build
cmake ..
make bom
```

### See Also

- [Docker Engine](setup-docker.md)  
- [Kubernetes Cluster](setup-kubernetes.md)  
- [Terraform Setup](setup-terraform.md)  

