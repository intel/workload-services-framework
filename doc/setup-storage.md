
### Storage Setup

#### SSD Disks

Certain workloads require to use scratch disk(s) as cache storage. The workers must be equipped with the right SSD disks.  

Label the worker nodes with the following node labels:
- `HAS-SETUP-DISK-MOUNT-1`: The worker node must have a SSD disk with the size of at least 500GB. The SSD disk must be mounted under `/mnt/disk1`.  

