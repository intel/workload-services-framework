# Terraform options

The Terraform validation backend runs any testcases in stages.

## Stages

```mermaid
flowchart LR;
  provision{{Provision VMs}};;
  setup{{Setup VMs}};;
  exec{{Workload Execution}};;
  cleanup{{Restore/Cleanup}};;
  provision --> setup --> exec --> cleanup;;
```

- `CSP Provisioning`: Terraform scripts are used to provision any CSP VMs. For on-premises clusters, this step is skipped.
  > See [Terraform Configuration Parameters][Terraform Configuration Parameters].
- `VM Setup` and `Workload Execution`: Ansible scripts are used to install software and execute the workloads.
  > See [Ansible Configuration Parameters][Ansible Configuration Parameters].
- `Cleanup`: Terraform and ansible scripts are used to restore the VM settings and to destroy the VMs. There is no configuration in this stage.

## Terraform Configuration Parameters

You can configure the CSP resources during the terraform VM provisioning stage:
  
```shell
./ctest.sh --set AWS_ZONE=us-east-2 --set AWS_CUSTOM_TAGS=team=my,batch=test -R throughput -V
```

### CSP Common Parameters
  
- `<CSP>_COMPARTMENT`: Specify the compartment id of the Oracle Cloud resources.
- `<CSP>_CUSTOM_TAGS`: Specify custom resource tags to be attached to any newly created CSP resources. The value should be a set of comma delimited key=value pairs, i.e., `a=b,c=d,e=f`.
- `<CSP>_REGION`: Specify the CSP region value. If not specified, the region value will be parsed from the zone value.
- `<CSP>_RESOURCE_GROUP_ID`: Specify the resource group id of the Alibaba* Cloud resources.
- `<CSP>_SPOT_INSTANCE`: Specify whether to use the CSP spot instance for cost saving. The default value is `true`.
- `<CSP>_ZONE`: Specify the CSP availability zone. The zone value must be prefixed with the region string.

### VM Work Group Parameters

- `<CSP>_<workgroup>_CPU_CORE_COUNT`: Specify the visible CPU core number.
- `<CSP>_<workgroup>_CPU_MODEL_REGEX`: Specify a regular expression pattern that the SUT cpu model must match. The SUT instance will be replaced if there is a mismatch.
- `<CSP>_<workgroup>_INSTANCE_TYPE`: Specify workgroup instance type. The instance type is CSP specific.
- `<CSP>_<workgroup>_MEMORY_SIZE`: Specify the memory size in GB.
- `<CSP>_<workgroup>_MIN_CPU_PLATFORM`: Specify the minimum CPU platform value for Google* Cloud compute instances. Replace any whitespace with `%20`. For example, use `Intel%20Ice%20Lake` to specify a minimum platform of `Intel Ice Lake`.
  > See [GCP][GCP specify-min-cpu-platform] for possible values.
- `<CSP>_<workgroup>_NIC_TYPE`: Specify the Google Cloud NIC type. Possible values: `GVNIC` or `VIRTIO_NET`. The default is `GVNIC`.
- `<CSP>_<workgroup>_OS_DISK_IOPS`: Specify the OS disk I/O performance numbers in I/O per second.
- `<CSP>_<workgroup>_OS_DISK_SIZE`: Specify the OS disk size in GB.
- `<CSP>_<workgroup>_OS_DISK_THROUGHPUT`: Specify the I/O throughput in MB/s.
- `<CSP>_<workgroup>_OS_DISK_TYPE`: Specify the OS disk type.
  > See [`AWS`][AWS ebs_volume-type], [`GCP`][GCP compute_disk-type], [`Azure`][Azure managed_disk-storage_account_type], [`Tencent`][Tencent instance-data_disk_type], and [`AliCloud`][AliCloud disk-category].
- `<CSP>_<workgroup>_OS_IMAGE`: Specify the OS virtual machine custom image. If specified, the value will void `OS_TYPE` and `OS_DISK` values.
- `<CSP>_<workgroup>_OS_TYPE`: Specify the OS type. Possible values: `ubuntu2004`, `ubuntu2204`, or `debian11`. Note that `debian11` may not work on all CSPs.  
where `<workgroup` can be any of `worker`, `client`, and `controller`.
- `<CSP>_<workgroup>_THERADS_PER_CORE`: Specify the thread number per CPU core.

### Data Disks Parameters

- `<CSP>_DISK_SPEC_<n>_DISK_COUNT`: Specify the number of data disks to be mounted.
- `<CSP>_DISK_SPEC_<n>_DISK_FORMAT`: Specify the data disk format as part of the `disk_spec_<n>` definition. The value depends on the OS image. `ext4` is a common format.
- `<CSP>_DISK_SPEC_<n>_DISK_SIZE`: Specify the data disk size in GB as part of the `disk_spec_<n>` definition.
- `<CSP>_DISK_SPEC_<n>_DISK_TYPE`: Specify the data disk type as per CSP definition. Use the value `local` to use the instance local storage.
  > See [`AWS`][AWS ebs_volume-type], [`GCP`][GCP compute_disk-type], [`Azure`][Azure managed_disk-storage_account_type], [`Tencent`][Tencent instance-data_disk_type], and [`AliCloud`][AliCloud disk-category].
- `<CSP>_DISK_SPEC_<n>_DISK_IOPS`: Specify the IOPS value of the data disks.
- `<CSP>_DISK_SPEC_<n>_DISK_PERFORMANCE`: Specify the AliCloud performance level of the data disks.
  > See [`AliCloud`][AliCloud disk-performance_level].
- `<CSP>_DISK_SPEC_<n>_DISK_THROUGHPUT`: Specify the I/O throughput value of the data disks.
  > See [`Azure`][Azure managed-disks-overview].

## Ansible Configuration Parameters

You can further configure the test parameters during the test execution as follows:

- Use `cmake -DTERRAFORM_OPTIONS=` to define the TERRAFORM_OPTIONS options.

  ```shell
  cmake -DTERRAFORM_OPTIONS="--docker --svrinfo --intel_publish" ..
  ```
  
- Use `./ctest.sh --options=` to add extra configurations to `TERRAFORM_OPTIONS`.

  ```shell
  ./ctest.sh --options="--docker --svrinfo --intel_publish" -R throughput -V
  ```
  
### Common Parameters

- `docker_auth_reuse`: Copy the docker authentication information to SUTs.
- `nosvrinfo`/`svrinfo`: Disable/enable svrinfo SUT information detection.
  - `svrinfo_options`: Specify svrinfo options. Replace any whitespace in options with `%20`. The default is `''` (no options).
- `nomsrinfo`/`msrinfo`: Disable/enable msrinfo SUT information detection.   
- `run_stage_iterations`: Specify the number of iterations to repeat the workload exuections. The default is `1`.
- `skopeo_insecure_registries`: Specify a list of insecure docker registries (comma delimited). Any access to the registries will use `http`.
- `skopeo_sut_accessible_registries`: Specify a list of docker registries (comma delimited) that SUT can directly access to. The workload images are not copied to the SUT assuming the SUT can directly pull the images.
- `terraform_delay`: Specify the CSP provisioning retry delay in seconds, if any provision step failed. Default 10 seconds if `terraform apply` failed, or 0s if cpu model mismatched.
- `terraform_retries`: Specify the retry times if cpu model mismatched. Default: `10`.
- `wl_debug_timeout`: Specify the debug breakpoint timeout value in seconds. The default is 3600.

### SUT Parameters

- `sut_default_hugepagesz`: When any hugepage is set, configure if the default hugepage size should be set. The default is `false`.  
- `sut_kernel_args`: Specify the list of additional kernel args to be applied on the SUT. The format is `<group>:key=value[ key=value][,<group>:key=value...]`, where `group` is the SUT work group and `key=value` is the kernel arguments.  
- `sut_kernel_modules`: Specify additional kernel modules to be installed on the SUT. The format is `<group>:module1 [module2...][,<group>:module...]`, where `group` is the SUT work group.  
- `sut_reboot`: Specify whether the SUT is allowed to be rebooted. The default is `true`. 
- `sut_sudo`: Specify whether the SUT is allowed to use sudo. The default is `true`.  
- `sut_sysctl_options`: Specify additional sysctl options to be set on the SUT. The format is `<group>:key=value[ key=value][,<group>:key=value...]`, where `group` is the SUT work group and `key=value` is the sysctl setting.  
- `sut_sysfs_options`: Specify additional sysfs options to be set on the SUT. The format is `<group>:key=value[ key=value][,<group>:key=value...]`, where `group` is the SUT work group and `key=value` is the sysfs seting. 

### Containerd Parameters

- `containerd_data_root`: Specify the `containerd` data root directory. The default is `/var/lib/containerd`.
- `containerd_pause_registry`: Specify the `containerd` pause image registry prefix. The default is `registry.k8s.io`.
- `containerd_version`: Specify the containerd version. The default is `Ubuntu:1.6.15`, `CentOS:1.6.10`, or `Debian:1.6.15`.
- `containerd_reset`: Reset and reinstall containerd. The default is `false`.
- `containerd_insecure_registry`: Specify the list of insecure registries, separated with comma. 

### Docker Parameters

- `compose`: Enable workload docker-compose execution.
- `docker`: Enable workload docker execution.
- `docker_compose_plugin_version`: Specify the docker compose plugin version. The default is `2.18.1`.
- `docker_data_root`: Specify the docker daemon data root directory. The default is `/var/lib/docker`.
- `docker_dist_repo`: Specify the docker repository URL. The default is `https://download.docker.com`.
- `docker_version`: Specify the docker version. The default is `20.10.23`.
- `native`: Enable workload native execution over docker image.

### Kubernetes Parameters

- `k8s_cni`: Specify the Kubernetes CNI. The default is `flannel`.
- `k8s_apiserver_ip`: Specify the kubernetes api server ip. The default is controller's `private_ip` of terraform applied outputs.
- `k8s_apiserver_port`: Specify the kubernetes api server port. The default is `6443`.
- `k8s_calico_encapsulation`: Specify the Calico CNI overlay networking. The default is `VXLAN`.
- `k8s_calico_version`: Specify the Calico CNI version. The default is `v3.25`.
- `k8s_calico_mtu`: Specify the Specify MTU, value can be `1500` or `9000`. Default is `1500`.
- `k8s_calicoctl_version`: Specify the Calico CNI operator version. The default is `v3.25`.
- `k8s_calicovpp_version`: Specify the Calicovpp operator version. THe default is `v3.25`.
- `k8s_calicovpp_buffer_data_size`: Specify Calico-vpp data-size buffer in Calicovpp configuration. The default is `2048`.
- `k8s_calicovpp_cores`: Specify how many CPU cores will be used for the l3fwd  and calicovpp pod, respectively. Default is `1`.
- `k8s_calicovpp_dsa_enable`: Specify testing mode, value can be `true`, `false` for DSA memif, SW memif testing. Default is `true`.
- `k8s_delete_namespace_timeout`: Specify the timeout value when deleting the Kubernetes namespace. The default is `10m` (10 minutes).
- `k8s_enable_registry`: Install a docker registry within the Kubernetes cluster to serve the workers. The workload images are copied to the docker registry. The default value is `true`.
- `k8s_flannel_version`: Specify the flannel CNI version. The default is `v0.21.5`.
- `k8s_istio_install_dist_repo`: Specify the istio distribution repository. The default is `https://istio.io/downloadIstio`.
- `k8s_istio_version`: Specify the istio version. The default is `1.15.3`.
- `k8s_nfd_registry`: Specify the NFD image repository. The default is `k8s.gcr.io/nfd`.
- `k8s_nfd_version`: Specify the NFD version. The default is `v0.13.2`.
- `k8s_pod_cidr`: Specify the kubernetes pod subnet. The default is `10.244.0.0/16`.
- `k8s_registry_port`: Specify the in-cluster registry port. The default is `20668`.
- `k8s_install`: If True, force Kubernetes installation playbook to be run. Default False. Images for upload should be defined using `wl_docker_images` in `validate.sh` and passed as a string with `,` separator using `TERRAFORM_OPTIONS`.

  > Example: `TERRAFORM_OPTIONS="${TERRAFORM_OPTIONS} --wl_docker_images=${REGISTRY}image-name-1${RELEASE},${REGISTRY}image-name-2${RELEASE}"`

- `k8s_reset`: Reset Kubernetes, if detected, and reinstall Kubernetes. The default is `false`.
- `k8s_service_cidr`: Specify the kubernetes service subnet. The default is `10.96.0.0/12`.
- `k8s_version`: Specify the Kubernetes version. The default is `1.26.6`.
- `k8s_plugins`: Specify a list of additonal Kubernetes devices plugins, supported options are nfd. The default is None.


### Trace Module Parameters

- `collectd`: Enable the collectd tracer.
  - `collectd_interval`: Specify the collectd sample time interval. The default is 10 seconds.
- `emon`: Enable the emon tracer.
  - `emon_post_processing`: Specify whether to enable/disable Emon post-processing. The default is `true`.
  - `emon_view`: There are 3 optional views to be selected `--socket-view` `--core-view` `--thread-view` you can select one or more of them or use `--no-detail-views` to just generate the summary by default system/core/thread views are generated. Replace any white space in options with `%20`. The default is `--socket-view%20--core-view%20--thread-view`; also can use `emon_view=""` to just generate the summary by system.
- `gprofiler`: Enable the gprofiler tracer.  
  - `gprofiler_image`: Specify the gprofiler docker image. The default is `docker.io/granulate/gprofiler`.
  - `gprofiler_options`: Specify the gprofiler options. Replace any white space in options with `%20`. The default is `--profiling-frequency=11%20--profiling-duration=2`.
  - `gprofiler_version`: Specify the gprofiler version. The default is `latest`.
- `perf`: Enable the perf tracer.
  - `perf_action`: Specify the perf action. The default is `record`.
  - `perf_collection_time`: Specify the perf record time. The default is `infinity`.
  - `perf_fetch_data`: Specify whether to retrieve the raw perf record data back to the logs directory. The default is `false`.
  - `perf_flamegraph`: Specify whether to generate flamegraph during post-processing. The default is `false`.
  - `perf_flamegraph_collapse_options`: Specify the flamegraph collapse command [options][FlameGraph readme]. Replace any whitespace in options with `%20`. The default is `--all`.
  - `perf_flamegraph_svg_options`: Specify the flamegraph generation [options][FlameGraph options]. Replace any whitespace in options with `%20`. The default is `--color=java%20--hash`.
  - `perf_record_options`: Specify the perf record command options. Replace any whitespace in options with `%20`. The default is `-a%20-g`.
  - `perf_stat_options`: Specify the perf record command options. Replace any whitespace in options with `%20`. The default is `-a%20-I%20500%20-e%20cycles%20-e%20instructions`.
  - `perf_script_options`: Specify the perf script command options. Replace any whitespace in options with `%20`. The default is `` (no options).
- `sar`: Enable the sar tracer.
  - `sar_options`: Specify the sar command line options. Replace any whitespace in options with `%20`. The default is `-B%20-b%20-d%20-p%20-H%20-I%20ALL%20-m%20ALL%20-n%20ALL%20-q%20-r%20-u%20ALL%20-P%20ALL%20-v%20-W%20-w%205`.

### Instance Watch Parameters

The instance watch feature monitors a SUT instance uptime and CPU utilization. Best for managing Cloud VM instances. If the uptime of the SUT instance exceeds a threshold and then the CPU load is consequtively measured to be low, the instance will be automatically shutdown (powered off).

- `instance_watch`: Enable/disable instance watch. The default is `false`.
- `instance_watch_cpu_load`: Specify the CPU load in percentage. The instance is considered low utilization if the load is below the threashold. The default is `10`.
- `instance_watch_cpu_load_count`: Specify the number of times that the CPU load must be consequtively below the threshold before considering the CPU as low utilized. The default is `3`.
- `instance_watch_cpu_load_span`: Specify the time between two CPU load measures. The default is `15s`.
- `instance_watch_interval`: Specify the instance uptime watch interval. The default is `30m`.
- `instance_watch_shutdown_postpone`: Specify the shutdown postpone time in minutes. The default is `30`.
- `instance_watch_uptime`: Specify the maximum instance uptime in minutes. The default is `360`, i.e., 6 hours.


[AWS ebs_volume-type]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_volume#type
[AliCloud disk-category]: https://registry.terraform.io/providers/aliyun/alicloud/latest/docs/resources/disk#category
[AliCloud disk-performance_level]: https://registry.terraform.io/providers/aliyun/alicloud/latest/docs/resources/disk#performance_level
[Ansible Configuration Parameters]: #ansible-configuration-parameters
[Azure managed-disks-overview]: https://learn.microsoft.com/en-us/azure/virtual-machines/managed-disks-overview
[Azure managed_disk-storage_account_type]: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/managed_disk#storage_account_type
[Azure managed-disks-overview]: https://learn.microsoft.com/en-us/azure/virtual-machines/managed-disks-overview
[FlameGraph options]: https://github.com/brendangregg/FlameGraph#options
[FlameGraph readme]: https://github.com/brendangregg/FlameGraph#readme
[GCP compute_disk-type]: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_disk#type
[GCP specify-min-cpu-platform]: https://cloud.google.com/compute/docs/instances/specify-min-cpu-platform
[Tencent instance-data_disk_type]: https://registry.terraform.io/providers/tencentcloudstack/tencentcloud/latest/docs/resources/instance#data_disk_type
[Terraform Configuration Parameters]: #terraform-configuration-parameters
