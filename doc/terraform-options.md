### Introduction


The terraform validation backend runs any workload testcases in the following stages:
<IMG src="image/terraform-pipeline.svg" height=200px>
- `CSP Provisioning`: Terraform scripts are used to provision any CSP VMs. For on-premesis clusters, this step is skipped. See [Terraform Configuration Parameters](#terraform-configuration-parameters).   
- `VM Setup` and `Workload Execution`: Ansible scripts are used to install software and execute the workloads. See [Ansible Configuration Parameters](#ansible-configuration-parameters).   
- `Cleanup`: Terraform and ansible scripts are used to restore the VM settings and to destroy the VMs. There is no configuration in this stage. 

### Terraform Configuration Parameters

You can configure the CSP resources during the terraform VM provisioning stage: 
  
```
./ctest.sh --set AWS_ZONE=us-east-2 --set AWS_CUSTOM_TAGS=team=my,batch=test -R throughput -V
```

#### CSP Common Parameters:
  
- `<CSP>_CUSTOM_TAGS`: Specify custom resource tags to be attached to any newly created CSP resources. The value should be a set of comma delimited key=value pairs, i.e., `a=b,c=d,e=f`.   
- `<CSP>_MIN_CPU_PLATFORM`: Specify the minimum CPU platform value for Google* Cloud compute instances. See [GCP](https://cloud.google.com/compute/docs/instances/specify-min-cpu-platform) for possible values. Replace any whitespace with `%20`. For example, use `Intel%20Ice%20Lake` to specify a minimum platform of `Intel Ice Lake`.  
- `<CSP>_THERADS_PER_CORE`: Specify the thread number per CPU core.  
- `<CSP>_CPU_CORE_COUNT`: Specify the visible CPU core number.  
- `<CSP>_MEMORY_SIZE`: Specify the memory size in GB.  
- `<CSP>_NIC_TYPE`: Specify the Google Cloud nic type. Possible values: `GVNIC` or `VIRTIO_NET`. The default is `GVNIC`.  
- `<CSP>_REGION`: Specify the CSP region value. If not specified, the region value will be parsed from the zone value.  
- `<CSP>_RESOURCE_GROUP_ID`: Specify the resource group id of the Alibaba* Cloud resources.    
- `<CSP>_COMPARTMENT`: Specify the compartment id of the Oracle Cloud resources.    
- `<CSP>_SPOT_INSTANCE`: Specify whether to use the CSP spot instance for cost saving. The default value is `true`. 
- `<CSP>_ZONE`: Specify the CSP availability zone. The zone value must be prefixed with the region string.  

#### VM Work Group Parameters:

- `<CSP>_<workgroup>_INSTANCE_TYPE`: Specify workgroup instance type. The instance type is CSP specific.  
- `<CSP>_<workgroup>_OS_DISK_IOPS`: Specify the OS disk I/O performance numbers in I/O per second.  
- `<CSP>_<workgroup>_OS_DISK_SIZE`: Specify the OS disk size in GB.  
- `<CSP>_<workgroup>_OS_DISK_THROUGHPUT`: Specify the I/O throughput in MB/s.  
- `<CSP>_<workgroup>_OS_DISK_TYPE`: Specify the OS disk type. See [`AWS`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_volume#type), [`GCP`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_disk#type), [`Azure`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/managed_disk#storage_account_type), [`Tencent`](https://registry.terraform.io/providers/tencentcloudstack/tencentcloud/latest/docs/resources/instance#data_disk_type), and [`AliCloud`](https://registry.terraform.io/providers/aliyun/alicloud/latest/docs/resources/disk#category).
- `<CSP>_<workgroup>_OS_IMAGE`: Specify the OS virtual machine custom image. If specified, the value will void `OS_TYPE` and `OS_DISK` values.   
- `<CSP>_<workgroup>_OS_TYPE`: Specify the OS type. Possible values: `ubuntu2004`, `ubuntu2204`, or `debian11`. Note that `debian11` may not work on all CSPs.   
where `<workgroup` can be any of `worker`, `client`, and `controller`.  

#### Data Disks Parameters

- `<CSP>_DISK_SPEC_<n>_DISK_COUNT`: Specify the number of data disks to be mounted.    
- `<CSP>_DISK_SPEC_<n>_DISK_FORMAT`: Specify the data disk format as part of the `disk_spec_<n>` definition. The value depends on the OS image. `ext4` is a common format.  
- `<CSP>_DISK_SPEC_<n>_DISK_SIZE`: Specify the data disk size in GB as part of the `disk_spec_<n>` definition.  
- `<CSP>_DISK_SPEC_<n>_DISK_TYPE`: Specify the data disk type as per CSP definition. Use the value `local` to use the instance local storage. See [`AWS`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_volume#type), [`GCP`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_disk#type), [`Azure`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/managed_disk#storage_account_type), [`Tencent`](https://registry.terraform.io/providers/tencentcloudstack/tencentcloud/latest/docs/resources/instance#data_disk_type), and [`AliCloud`](https://registry.terraform.io/providers/aliyun/alicloud/latest/docs/resources/disk#category). 
- `<CSP>_DISK_SPEC_<n>_IOPS`: Specify the IOPS value of the data disks.  
- `<CSP>_DISK_SPEC_<n>_PERFORAMANCE`: Specify the AliCloud performance level of the data disks. See [`AliCloud`](https://registry.terraform.io/providers/aliyun/alicloud/latest/docs/resources/disk#performance_level).  
- `<CSP>_DISK_SPEC_<n>_THROUGHPUT`: Specify the I/O throughput value of the data disks. See [`Azure`](https://learn.microsoft.com/en-us/azure/virtual-machines/managed-disks-overview).       

### Ansible Configuration Parameters

You can further configure the test parameters during the test execution as follows:
- Use `cmake -DTERRAFORM_OPTIONS=` to define the TERRAFORM_OPTIONS options. 

```
cmake -DTERRAFORM_OPTIONS="--docker --svrinfo --intel_publish" ..
```
  
- Use `./ctest.sh --options=` to add extra configurations to `TERRAFORM_OPTIONS`.  

```
./ctest.sh --options="--docker --svrinfo --intel_publish" -R throughput -V
```
  
#### Common Parameters

- `docker_auth_reuse`: Copy the docker authentication information to SUTs.  
- `nosvrinfo`/`svrinfo`: Disable/enable svrinfo SUT information detection. 
  - `svrinfo_options`: Specify svrinfo options. Replace any whitespace in options with `%20`. The default is `''` (no options).  
- `provision_delay`: delay between provision retries, in seconds. Default: 10 seconds.  
- `provision_retries`: the number of times to retry the provisioning stage.  
- `run_stage_iterations`: Specify the number of iterations to repeat the workload exuections. The default is `1`.   
- `skopeo_insecure_registries`: Specify a list of insecure docker registries (comma delimited). Any access to the registries will use `http`.  
- `skopeo_sut_accessible_registries`: Specify a list of docker registries (comma delimited) that SUT can directly access to. The workload images are not copied to the SUT assuming the SUT can directly pull the images. 
- `wl_debug_timeout`: Specify the debug breakpoint timeout value in seconds. The default is 3600.   
- `wl_default_sysctls`: Specify the default sysctl paramters, as a comma delimited key/value pairs: `net.bridge.bridge-nf-call-iptables=1`.  
- `wl_default_sysfs`: Specify the default sysfs parameters, as a comma delimited key/value pairs: `/sys/devices/system/cpu/cpu*/cpufreq/scaling_governor=performance`. 
- `wl_set_default_hugepagesz`: When any hugepage is set, configure if the default hugepage size should be set. The default is `false`. 
- `nomsrinfo`/`msrinfo`: Disable/enable msrinfo SUT information detection. 


#### Containerd Parameters

- `containerd_data_root`: Specify the `containerd` data root directory. The default is `/var/lib/containerd`.  
- `containerd_pause_registry`: Specify the `containerd` pause image registry prefix. The default is `k8s.gcr.io`.    
- `containerd_version`: Specify the containerd version. The default is `Ubuntu:1.5.9`, `CentOS:1.6.8`, or `Debian:1.4.13`.  

#### Docker Parameters

- `docker`: Enable docker execution (instead of Kubernetes.)  
- `docker_data_root`: Specify the docker daemon data root directory. The default is `/var/lib/docker`.  
- `docker_dist_repo`: Specify the docker repository URL. The default is `https://download.docker.com`.  
- `docker_version`: Specify the docker version. The default is `20.10.17`.  
- `native`: Enable workload native execution over docker image.  

#### Kubernetes Parameters

- `k8s_cni`: Specify the Kubernetes CNI. The default is `flannel`.
- `k8s_apiserver_ip`: Specify the kubernetes api server ip. The default is controller's `private_ip` of terraform applied outputs.
- `k8s_apiserver_port`: Specify the kubernetes api server port. The default is `6443`.
- `k8s_calico_encapsulation`: Specify the Calico CNI overlay networking. The default is `VXLAN`.
- `k8s_calico_version`: Specify the Calico CNI version. The default is `v3.24`.
- `k8s_calico_mtu`: Specify the Specify MTU, value can be `1500` or `9000`. Default is `1500`.
- `k8s_calicoctl_version`: Specify the Calico CNI operator version. The default is `v3.24.0`.
- `k8s_calicovpp_version`: Specify the Calicovpp operator version. THe default is `v3.23.0`.
- `k8s_calicovpp_buffer_data_size`: Specify Calico-vpp data-size buffer in Calicovpp configuration. The default is `2048`.
- `k8s_calicovpp_cores`: Specify how many CPU cores will be used for the l3fwd  and calicovpp pod, respectively. Default is 1
- `k8s_calicovpp_dsa_enable`: Specify testing mode, value can be `true`, `false` for DSA memif, SW memif testing. Default is `true`.
- `k8s_delete_namespace_timeout`: Specify the timeout value when deleting the Kubernetes namespace. The default is `10m` (10 minutes).
- `k8s_enable_registry`: Install a docker registry within the Kubernetes cluster to serve the workers. The workload images are copied to the docker registry. The default value is `true`.
- `k8s_flannel_version`: Specify the flannel CNI version. The default is `v0.18.1`.
- `k8s_istio_install_dist_repo`: Specify the istio distribution repository. The default is `https://istio.io/downloadIstio`.
- `k8s_istio_version`: Specify the istio version. The default is `1.15.3`.
- `k8s_nfd_registry`: Specify the NFD image repository. The default is `k8s.gcr.io/nfd`.
- `k8s_nfd_version`: Specify the NFD version. The default is `v0.11.1`.
- `k8s_pod_cidr`: Specify the kubernetes pod subnet. The default is `10.244.0.0/16`.
- `k8s_registry_port`: Specify the in-cluster registry port. The default is `20668`.
- `k8s_install`: If True, force Kubernetes installation playbook to be run. Default False.
- `k8s_reset`: Reset Kubernetes, if detected, and reinstall Kubernetes. The default is `false`.
- `k8s_service_cidr`: Specify the kubernetes service subnet. The default is `10.96.0.0/12`.
- `k8s_version`: Specify the Kubernetes version. The default is `1.24.4`.


#### Trace Module Parameters

- `collectd`: Enable the collectd tracer.  
  - `collectd_interval`: Specify the collectd sample time interval. The default is 10 seconds.  
- `emon`: Enable the emon tracer.  
  - `emon_post_processing`: Specify whether to enable/disable Emon post-processing. The default is `true`.  
- `gprofiler`: Enable the gprofiler tracer.  
  - `gprofiler_image`: Specify the gprofiler docker image. The default is `docker.io/granulate/gprofiler`.  
  - `gprofiler_options`: Specify the gprofiler options. Replace any white space in options with `%20`. The default is `--profiling-frequency=11%20--profiling-duration=2`.  
  - `gprofiler_version`: Specify the gprofiler version. The default is `latest`.  
- `perf`: Enable the perf tracer.
  - `perf_action`: Specify the perf action. The default is `record`.
  - `perf_collection_time`: Specify the perf record time. The default is `10s`.   
  - `perf_fetch_data`: Specify whether to retrieve the raw perf record data back to the logs directory. The default is `false`.  
  - `perf_flamegraph`: Specify whether to generate flamegraph during post-processing. The default is `false`.  
  - `perf_flamegraph_collapse_options`: Specify the flamegraph collapse command [options](https://github.com/brendangregg/FlameGraph#readme). Replace any whitespace in options with `%20`. The default is `--all`.  
  - `perf_flamegraph_svg_options`: Specify the flamegraph generation [options](https://github.com/brendangregg/FlameGraph#options). Replace any whitespace in options with `%20`. The default is `--color=java%20--hash`.  
  - `perf_record_options`: Specify the perf record command options. Replace any whitespace in options with `%20`. The default is `-a%20-g`.
  - `perf_stat_options`: Specify the perf record command options. Replace any whitespace in options with `%20`. The default is `-a%20-I%20500%20-e%20cycles%20-e%20instructions`.
  - `perf_script_options`: Specify the perf script command options. Replace any whitespace in options with `%20`. The default is `` (no options).

- `processwatch`: Enable the processwatch tracer.  
  - `processwatch_options`: Specify the processwatch command options. Replace any whitespace in options with `%20`. The default is `--interval=1`.  
  - `processwatch_repository`: Specify the processwatch git repository URL.  
  - `processwatch_version`: Specify the processwatch version. The default is a glone hash code of `466ed06027`.   
- `sar`: Enable the sar tracer.  
  - `sar_options`: Specify the sar command line options. Replace any whitespace in options with `%20`. The default is `-B%20-b%20-d%20-p%20-H%20-I%20ALL%20-m%20ALL%20-n%20ALL%20-q%20-r%20-u%20ALL%20-P%20ALL%20-v%20-W%20-w%205`.  
- `PerfSpect`: Enable the PerfSpect tracer.  
  - `perfspect_repository`: Specify the PerfSpect released binary git repository URL.

#### Publishing Module Parameters
  
- `intel_publish`: Publish the execution results to the WSF portal.  
- `intel_publisher_sut_platform`: Specify the primary SUT worker group name. The default is `worker`.  
- `intel_publisher_sut_machine_type`: Specify the primary SUT platform machine type.    
- `intel_publisher_sut_metadata`: Specify additional SUT metadata in a comma delimited key/value pairs: `CPU:IceLake,QDF:QY02`.  
- `owner`: Specify the tester name.  
- `tags`: Specify any tags to be attached the results on the WSF portal. Use a comma delimited list. The tags must be capitalized. 

