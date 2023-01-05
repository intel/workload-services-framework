
### Storage Setup

Certain workloads require to use data disk(s) as cache storage. The SUT workers must be equipped with the SSD or NVME disks specified by the disk specification. 
A workload can request data disk storage as follows:
- `HAS-SETUP-DISK-SPEC-1`: The worker node must have a set of SSD or NVME disks, whose specification, `disk_spec_1`, is specified in the `cumulus`/`terraform` configuration files. The data disk is mounted under `/mnt/disk1.../mnt/diskN`, where `N` is the data disk count.    

### Node Labels:

Label the worker nodes with the following node labels: 
- `HAS-SETUP-DISK-SPEC-1=yes`: The worker node is equipped with the data storage disks described in `disk_spec_1`.  
