
The disk-avail labels are used to probe if the workload minimum disk availability threshold is met. 

There are three label formats:

- `HAS-SETUP-DISK-AVAIL-192`: This requires that a minimum of 192GB disk availability under either `/tmp` (native workloads), `/var/lib/docker` (docker/compose workloads), `/var/lib/kubelet` (Kubernetes workloads), or `C` (windows workloads).   
- `HAS-SETUP-DISK-AVAIL-192-MNT-DISK1`: This requires that a minimum of 192GB disk availability under `/mnt/disk1`. You can specify any disk path with `/` replaced with `-`.  
- `HAS-SETUP-DISK-AVAIL-192-D`: This requires that a minimum of 192GB disk availability under the drive letter `D`. This is specific to Windows.  

