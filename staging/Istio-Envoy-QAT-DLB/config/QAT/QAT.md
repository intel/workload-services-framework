# Istio QAT installation, Intel device plugin


Install  [Intel® QAT Device Plugin for Kubernetes](https://github.com/intel/intel-device-plugins-for-kubernetes) - detailed information and the newest releases.
```
$ kubectl apply -f intel-qat-plugin.yaml
```

To enable IOMMU for Linux kernel:
```
$ cat /etc/default/grub:
GRUB_CMDLINE_LINUX="intel_iommu=on vfio-pci.ids=8086:4941"
$ update-grub
$ reboot
```

Check if the IOMMU has been enabled via the following command:
```
$ dmesg| grep IOMMU
DMAR: IOMMU enabled
```
```
$ tar xzf qat20-fw-stepping-e.tgz
$ sudo cp QAT20/quickassist/qat/fw/e/qat_4xxx.bin /usr/lib/firmware/
$ sudo cp QAT20/quickassist/qat/fw/qat_4xxx_mmp.bin /usr/lib/firmware/
$ sudo rmmod qat_4xxx
$ sudo modprobe qat_4xxx
```

In case of out of memory,check dmesg:
```
$ dmesg | grep -ie memlock
```
(vfio_pin_pages_remote: RLIMIT_MEMLOCK exceeded). 

Qat intel device plugin pod will not be running, istio-ingress gateway pod will be also in state pending. Entering into istio ingress gateway logs may help in investigate errors. 

Add:
```
sudo mkdir /etc/systemd/system/containerd.service.d

sudo bash -c 'cat <<EOF >>/etc/systemd/system/containerd.service.d/memlock.conf
[Service]
LimitMEMLOCK=16777216
EOF'

$ sudo systemctl daemon-reload
$ sudo systemctl restart containerd
```


**Istio install with QAT**

Use the following command for the Istio installation:

```
istioctl install -y -f istio/istio-intel-qat-hw.yaml
```

**Check**

Make sure QAT_4XXX driver is enabled in your kernel as a module. The driver has been in kernel since 5.11 but tested only on 5.17 onwards.

Load the driver and check dmesg:
```
$ modprobe qat_4xxx.
$ dmesg | grep -i qat 
 ```

Create SRIOV instances out of the physical endpoint. Echo 16 to the physical endpoints sriov_numfs file:

```
echo 16 > /sys/devices/pci0000\:6b/0000\:6b\:00.0/sriov_numvfs
```


Check if new /dev/vfio resources are created and change its permission:
```
chmod a+rw /dev/vfio/*
```

Intel qat device plugin will be deployed as a daemonset and will find QAT resources and setup VFIO resources automatically, there is no need to bind them manually.

For enabling intel qat device plugin apply:
```
$ kubectl apply -f  intel-qat-plugin.yaml 
```

After any change of QAT resources restart daemonset of plugin:

```
$ kubectl rollout restart daemonset.apps/intel-qat-plugin 
```

Check if crypto resources are available:
 ```
$ kubectl describe nodes | grep qat
```

Enable qat after every reboot:
```
$ modprobe qat
$ dmesg | grep qat
```


