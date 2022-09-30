
### Customize the Build Process:

You can use the following build options to customize the build process:  

- **PLATFORM**: Specify the platform name. The only supported platform is `ICX`.  
- **REGISTRY**: Specify the privacy docker registry URL. All built images will be pushed to the specified docker registry.
  > `REGISTRY` must end with forward slash `/`
- **RELEASE**: Specify the release version. All built images will be tagged with it. Defaults to `:latest`
  > `RELEASE` must begin with colon `:`
- **REGISTRY_AUTH**: Specify the registry authentication method. The only supported value is `docker`, which uses the docker configuration file.
- **BACKEND**: Specify the validation backend: [`docker`](setup-docker.md), [`kubernetes`](setup-kubernetes.md), or [`cumulus`](setup-cumulus.md).    
- **CUMULUS_OPTIONS**: Specify the `cumulus` options.  
- **TIMEOUT**: Specify the validation timeout, which contains the execution timeout and docker pull timeout. Default to 28800,300 seconds.   
- **BENCHMARK**: Specify a workload pattern. Workloads not matching the pattern will be disabled. 

Build examples:   

```bash
cd build
cmake -DREGISTRY=xxyyzz.com:1234 ..
```

### Command Make Targets

- **bom**: Print out the BOM list of each workload.  
- **kpi**: Print out the KPI of each workload.  
- **clean**: Purge the `logs`.  

```bash
cd build
cmake ..
make bom
```

### See Also

- [Docker Engine](setup-docker.md)  
- [Kubernetes Cluster](setup-kubernetes.md)  
- [Cumulus Setup](setup-cumulus.md)  
