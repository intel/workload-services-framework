
### Introduction

The terraform backend can be used to validate workloads on a remote cluster, On-Premises or on Cloud.

### Setup Terraform for Cloud Validation

- Follow the instructions in the [WSF Cloud Setup][WSF Cloud Setup] to setup the development host.
- The terraform backend supports Cloud vendors such as `aws`, `gcp`, `azure`, `tencent`, `alicloud`, and `oracle`. Each vendor has a corresponding configuration file: `script/terraform/terraform-config.<SUT>.tf`, where `<SUT>` is the Cloud vendor name. You can customize as needed.  

#### Configure Cloud Account

If this is your first time, run the terraform build command:   

> Note: mentioned below commands should be executed from a build folder such as ~/applications.benchmarking.benchmark.platform-hero-features/build# make build_terraform

```
make build_terraform
```

Then proceed with the Cloud account setup as follows:

```
make aws           # or make -C ../.. aws, if under build/workload/<workload>
$ aws configure    # please specify a region and output format as json
$ exit
```

```
make azure         # or make -C ../.. azure, if under build/workload/<workload>
$ az login
# if you have multiple subscriptions in your account, please set
# az account set --subscription="<subscription-id>"
$ exit
```

```
make gcp           # or make -C ../.. gcp, if under build/workload/<workload>
$ gcloud init --no-launch-browser
$ gcloud auth application-default login --no-launch-browser # Please make sure quota-project-id is set
$ gcloud auth activate-service-account --key-file <keyfile> # required only for running workloads in Google Kubernetes Engine
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

```
make oracle        # make -C ../.. oracle, if under build/workload/<workload>
$ oci setup config # please specify a compartment id and upload public key to the oracle cloud console 
$ exit
```

#### Run Workload(s) Through Terraform

```
cd workload/<workload>
make
./ctest.sh -N
```

#### Cleanup Cloud Resources

If your terraform validation is interrupted for any reason, the Cloud resource may remain active. You can explicitly cleanup any Cloud resources as follows:

> Note: mentioned below commands should be executed from the required workload folder such as ~/applications.benchmarking.benchmark.platform-hero-features/build/workload/OpenSSL3-RSAMB# make -C ../.. azure

```
make -C ../.. [aws|gcp|azure|tencent|alicloud]
$ cleanup
$ exit
```

### Setup Terraform for On-Premises Validation

- Follow the instructions in the [WSF On-Premises Setup][WSF On-Premises Setup] to setup the On-Premises hosts.
- Customize [`terraform-config.static.tf`][terraform-config.static.tf] to specify your cluster information.

Now you can run any workload as follows:    

```
cd workload/<workload>
make
./ctest.sh -N
```

### Setup Terraform for KVM Validation

- Follow the instructions in the [WSF KVM Setup][WSF KVM Setup] to setup the KVM environment.
- Customize [`terraform-config.kvm.tf`][terraform-config.kvm.tf] to specify your KVM host information.

Now you can run any workload as follows:    

```
cd workload/<workload>
make
./ctest.sh -N
```

### Telemetry Trace and Publishing Options

See [Trace Module][Trace Module] for available trace options. You can enable telemetry trace modules during the workload validation as follows:

```
cmake -DTERRAFORM_OPTIONS=--collectd ..
cd workload/<workload>
./ctest.sh -N
```

Additionally, you can use `--svrinfo` to the `TERRAFORM_OPTIONS` to
automatically detect the platform information as follows:

```
cmake -DTERRAFORM_OPTIONS=--svrinfo ..
cd workload/<workload>
./ctest.sh -N
```

See also: [Publishing Module Options][Publishing Module Options].

### Debugging

While the workload evaluation is in progress, you can logon to the remote instances to debug any encountered issues. As terraform engine runs inside a container, you need to first login to the container as follows:

```
./debug.sh
```

The script will bring you to the container shell where you can perform, from the current directory or `/opt/workspace`, additional operations such as examining the workload execution logs and logging onto the workload instances.

Files of interest:
- `cluster-config.yaml`: The workload cluster configuration definition.
- `terraform-config.yaml`: The workload terraform entry point.
- `workload-config.yaml`: The workload configuration parameters.
- `kubernetes-config.yaml[.mod.yaml]`: The kubernetes deployment script (for containerized workloads.)
- `cluster.yaml`: The ansible playbook to initialize the VM instances.
- `deployment.yaml`: The ansible playbook to run the workload.
- `inventory.yaml`: The provisioned VM information.
- `tfplan.logs`: The process logs.
- `ssh_access.key[.pub]`: The SSH keys for accessing to the VM instances.
- `template/*`: Source code used to provision VMs and evaluate workloads.

```
$ cat inventory.yaml
...
        worker-0:
          ansible_host: 35.92.225.114
          ansible_user: ubuntu
...
$ ssh -i ssh_access.key ubuntu@35.92.225.114
```

**HINT:** while working within the terraform container, if you need to ssh or scp data to public VMs, use the ssh identity ssh_access.key. If you are not under the default directory /opt/workspace, please use the absolute path.

For Example:
```
$ scp -r -i ssh_access.key /tmp/test.log <username>@<public_ip>:/tmp/
Warning: Permanently added '<public_ip>' (ED25519) to the list of known hosts.
test.log                                                                                                                                                                                                                                                    100%    5     0.1KB/s   00:00
```

#### Setting Breakpoint(s)

You can set one or many breakpoints by specifying the `wl_debug` option in `TERRAFORM_OPTIONS` or `terraform-config.<sut>.tf`:  

```
cmake -DTERRAFORM_OPTIONS=--wl_debug=<BreakPoint>[,<BreakPoint>] ..
```

The following `<BreakPoint>`s are supported:  
- `PrepareStage`: Pause when the workload is about to setup the host environment.  
- `RunStage`: Pause when the workload is about to start the workload execution. 
- `CleanupStage`: Pause when the workload is about to cleanup.  

When a breakpoint is reached, the execution is paused for an hour (as specified by the `wl_debug_timeout` value.) You can explicitly resume the execution by creating a signaling file under `/opt/workspace`, as follows:    

```
./debug.sh
$ touch ResumeRunStage
$ exit
```


[WSF Cloud Setup]: setup-wsf.md#cloud-development-setup
[WSF On-Premises Setup]: setup-wsf.md#on-premises-development-setup
[terraform-config.static.tf]: ../../../script/terraform/terraform-config.static.tf
[WSF KVM Setup]: setup-wsf.md#kvm-development-setup
[terraform-config.kvm.tf]: ../../../script/terraform/terraform-config.kvm.tf
[Trace Module]: ../executing-workload/terraform-options.md#trace-module-parameters
[Publishing Module Options]: ../executing-workload/terraform-options.md#publishing-module-parameters