# Setup Hugepage

Workloads that require to use hugepages must specify a `HAS-SETUP-HUGEPAGE` label in the format of `HAS-SETUP-HUGEPAGE-<size>-<pages>`, where `<size>` is the hugepage size and `<pages>` is the #pages required. The `<size>` value must exactly match the string, case sensitive, of the hugepage sizes supported under `/sys/kernel/mm/hugepages`. For example, to request 1024 pages of 2MB hugepages, use `HAS-SETUP-HUGEPAGE-2048kB-1024`.

If setting the default hugepage size is required, append `-DEFAULTSZ` to the label name. For example, `HAS-SETUP-HUGEPAGE-2048kB-1024-DEFAULTSZ`.  

## Node Labels

To avoid creating a lot of node labels, it is recommended to specify #pages only in the power 2 values. Label the worker node(s) with the following node labels:  
- `HAS-SETUP-HUGEPAGE-2048kB-512=yes` Optional  
- `HAS-SETUP-HUGEPAGE-2048kB-1024=yes` Optional  
- `HAS-SETUP-HUGEPAGE-2048kB-2048=yes` Optional  
- `HAS-SETUP-HUGEPAGE-2048kB-4096=yes` Optional  

## System Setup

Hugepage is setup automatically once the labels are in place. If for any reason you need to setup hugepages manually, setup hugepages through the kernel boot parameters, as follows:  

```
sudo grubby --update-kernel=DEFAULT --args="hugepages=1024"
```

Then reboot the machine for the hugepages to take effect. 

For Ubuntu, you need to edit `sudo vi /etc/default/grub` by adding the number of huge pages to `GRUB_CMDLINE_LINUX`, like this:

```
GRUB_CMDLINE_LINUX="hugepages=1024"
```

Then you need to do `sudo update-grub` and reboot.

To verify changes you can use this `cat /proc/meminfo | grep Huge`.

---

Kubernetes only recognizes hugepages if they are preallocated through boot parameters.    

---

## See Also

- [Manage HugePages][Manage HugePages]

[Manage HugePages]: https://kubernetes.io/docs/tasks/manage-hugepages/scheduling-hugepages

