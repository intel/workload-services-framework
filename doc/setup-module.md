
### Module Setup

The set of `HAS-SETUP-MODULE` labels specify the request of installing kernel modules that are part of the OS distribution but not by default installed during boot. 

The label should be specified in the format of `HAS-SETUP-MODULE-<module-name>`, where `<module-name>` is the module name with `_` replaced with `-`. 

### System Setup

The kernel module can be installed as follows:

```
sudo modprobe <module-name>.ko
```

### Node Labels

Add a node label to the worker node(s):
- `HAS-SETUP-MODULE-MSA`: Optional

