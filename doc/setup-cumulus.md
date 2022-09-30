
### Introduction

The cumulus backend can be used to validation workloads on a remote cluster, on Premesis or on Cloud. 

### Prerequisite

- Set the `REGISTRY` cmake variable to an empty string or a [private](https://docs.docker.com/registry/deploying) docker registry where you have write permission. 

```
cd build
cmake -DBACKEND=cumulus -DREGISTRY= ..
make build_cumulus
```

- Check the proxy setting in [`ssh_config`](../script/cumulus/ssh_config), if you are behind a firewall.  

### Setup Cumulus for Cloud Validation

The cumulus backend supports Cloud vendors such as `AWS`, `GCP`, `AZURE`, `Tencent`, and `AliCloud`. 
- Each vendor has a corresonding configuration file: [`script/cumulus/cumulus-config.<SUT>.yaml`](../script/cumulus), where `<SUT>` is the Cloud vendor name. You can customize as needed.  
- If you are behind a corporate firewall, please update the proxy settings in [`ssh_config`](../script/cumulus/ssh_config) accordingly.  

#### Configure Cloud Account

```
make aws           # or make -C ../.. aws, if under build/workload/<workload>
$ aws configure    # please specify a region
$ exit
```

```
make azure         # or make -C ../.. azure, if under build/workload/<workload>
$ az login
$ exit
```

```
make gcp           # or make -C ../.. gcp, if under build/workload/<workload>
$ gcloud init --no-browser
$ exit
```

```
make tencent       # or make -C ../.. tencent, if under build/workload/<workload>
$ tccli configure  # please specify a region
$ exit
```

```
make alicloud      # make -C ../.. alicloud, if under build/workload/<workload>
$ aliyun configure # please specify a region
$ exit
```

#### Run Workload(s) Through Cumulus

```
cd workload/<workload>
make
ctest -N
```

#### Cleanup Cloud Resources

If your cumulus validation is interrupted for any reason, the Cloud resource may remain active. You can explicitly cleanup any Cloud resources as follows:

```
make -C ../.. aws
$ cleanup
$ exit
```

```
make -C ../.. gcp
$ cleanup
$ exit
```

```
make -C ../.. azure
$ cleanup
$ exit
```

```
make -C ../.. tencent
$ cleanup
$ exit
```

```
make -C ../.. alicloud
$ cleanup
$ exit
```

#### Use A Cloud Private Registry

A Cloud private registry is a convenient option to store workload images. During the Cloud validation, the SUTs (System Under Test) can directly pull images from the docker registry without transfering any images. Here we assume the Cloud registry and the SUTs are in the same region.

Add the following flag in the `flags` section of `script/cumulus/cumulus-config.<cloud>.yaml` to indicate that the SUTs can directly access to the registry. The cumulus backend will then skip transfering workload images during validation:

```
  flags:
    skopeo_sut_accessible_registries: "<registry-url>"
```

See Also: [Private Registry Authentication](setup-auth.md)


### Setup Cumulus for On-Premesis Validation

- Setup a [Kubernetes](setup-kubernetes.md#Setup-Kubernetes) cluster. Customize [`cumulus-config.static.yaml`](../script/cumulus/cumulus-config.static.yaml) to specify your cluster information.  
- Run the [`setup-sut.sh`](../script/cumulus/script/setup-sut.sh) script to setup the SUT (System Under Test) hosts as follows:

```
./setup-sut.sh user@host1 [user@host2...]
```

> The script requires sudo permission on the SUT hosts.

### Cumulus Options

Use the following options to customize the cumulus validation:  

- Set the default to use `docker` in validation wherever possible:  

```
cmake -DCUMULUS_OPTIONS=--docker-run ..
```

- Set the dry-run mode. Configure the workload but skip the execution stage: 

```
cmake -DCUMULUS_OPTIONS=--dry-run ..
```

### Telemetry Tracing

You can enable telemetry tracing via `sar`, `emon`, and/or `collectd` as follows:  
- **`sar`**: Add `--sar` to `CUMULUS_OPTIONS`.  
- **`emon`**: Add `--emon --edp_publish --emon_post_process_skip` to `CUMULUS_OPTIONS`.  
- **`collectd`**: Add `--collectd` to `CUMULUS_OPTIONS`.  

```
cmake -DCUMULUS_OPTIONS=--collectd ..
cd workload/<workload>
ctest -N
```

For On-Cloud validation, there is no additional setup. For On-Premesis validation, you need to perform additional setup for each telemetry tracing mechniasm: 

#### Setup `sar` On-Prem

- Install the `sar` utility on your worker nodes. 

#### Setup `EMON` On-Prem

On your worker nodes,
- Create a `/opt/pkb` folder with the right ownership:  

```
sudo mkdir -p /opt/pkb
sudo chown $(id -u):$(id -g) /opt/pkb
```

- Download and install [EMON](https://www.intel.com/content/dam/develop/public/us/en/documents/emon-user-guide-nov-2019.pdf) to `/opt/emon/emon_files`.  
> Note it is critical that the installation location is `/opt/emon/emon_files`.  
 
- Add your worker username to the `vtune` group.   

```
sudo usermod -aG vtune $(id -gn)
```

##### For `EDP` post process capabilities

On your worker nodes install `python3` and add the following pip packages:

```
sudo python3 -m pip install xlsxwriter pandas numpy pytz defusedxml tdigest dataclasses
```

#### Setup Collectd On-Prem

On your worker nodes, 
- Install `flex`, `bison`, `autoconf`, `automake` and `libtool`.  
- Download [collectd](https://github.com/collectd/collectd) and compile it as follows:

```
sudo mkdir -p /opt/pkb
sudo chown -R $(id -u).$(id -g) /opt/pkb
sudo mkdir -p /opt/collectd
sudo chown -R $(id -u).$(id -g) /opt/collectd

git clone https://github.com/collectd/collectd.git
cd collectd
./build.sh
./configure --prefix=/opt/collectd/collectd
make
make install
```

- Copy [collectd.conf](../script/cumulus/collectd.conf) to `/opt/collectd/collectd/etc`.  

### Setup SVRINFO

The `svrinfo` utility is used to retrieve system-level information at the beginning of any validation run. Since `svrinfo` is under NDA only, the use of `svrinfo` is optional and by default disabled.  

To setup `svrinfo`, copy the `svrinfo` tarball under `script/cumulus/pkb/perfkitbenchmarker/data/svrinfo`. Remake. Then turn on the `svrinfo` option as follows:

```
cmake -DCUMULUS_OPTIONS=--svrinfo ..
```

### Cumulus Debugging

Enable the cumulus debugging mode as follows:  

- Specify break points in `CUMULUS_OPTIONS`:  

```
cmake -DCUMULUS_OPTIONS=--dpt_debug=<BreakPoint>[,<BreakPoint>] ..
```

where `<BreakPoint>` can be one of more of the following strings:  
- `PrepareStage`: Pause when the workload is about to setup the host environment. 
- `SetupVM`: Pause when the workload is about to setup external VMs. 
- `RunStage`: Pause when the workload is about to start the workload execution. 
- `CleanupStage`: Pause when the workload is about to cleanup.  
- `ScheduleExec`: Pause when the workload is about to schedule execution.  
- `ExtractLogs`: Pause when the workload is about to extract logs.  
- `ExtractKPI`: Pause when the workload is about to extract KPIs.  
- `ScheduleExecFailed`: Pause when scheduling execution is failed.  
- `ExtractLogsFailed`: Pause when extracting logs is failed.  
- `ExtractKPIFailed`: Pause when extracting KPI is failed. 

Start the workload validation as usual (ctest), cumulus will pause at the specified breakpoints. You can start a new shell and login to the cumulus container as follows:  

```
./debug.sh
$
```

Now you can `ssh` to the remote worker and start debugging. To resume validation, simply create an empty signalling file `Resume<BreakPoint>` under `/tmp/pkb/runs/<runid>/` as follows:  

```
> touch /tmp/pkb/runs/784d84f59e3d/ResumeRunStage
```


### See Also

- [TCP TIME_WAIT Reuse](https://github.com/intel/Updates-for-OSS-Performance/blob/main/time_wait.md)  
- [Unsuitable CPU Speed Policy](https://github.com/intel/Updates-for-OSS-Performance/blob/main/cpufreq.md)  
