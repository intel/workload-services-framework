# Setup QAT in-tree

Intel® QuickAssist Technology allows data encryption and compression. In-tree setup is described in this document.

## QAT In-tree Driver Setup For **4xxx** Device

### Check System Prerequisites

* Platform must have Intel® QuickAssist Technology QAT device such as "4xxx"
* QAT Physical Functions (PF's) can be determined as under:

  ```shell
  lspci -d 8086:4942
  76:00.0 Co-processor: Intel Corporation Device 4942 (rev 40)
  ...
  ```
  or
  ``` shell
  lspci -d 8086:4940
  6b:00.0 Co-processor: Intel Corporation Device 4940 (rev 40)
  ...
  ```
* Firmware must be available.

  check that these files exist: 
  
  `/lib/firmware/qat_4xxx.bin` or `/lib/firmware/qat_4xxx.bin.xz` 
  
  `/lib/firmware/qat_4xxx_mmp.bin` or `/lib/firmware/qat_4xxx_mmp.bin.xz`

  if not, download form:
  ```
  https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/qat_4xxx.bin
  https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/qat_4xxx_mmp.bin
  ```
  
  On updating these files run 
    ``` shell
    sudo rmmod qat_4xxx
    sudo modprobe qat_4xxx
    sudo dracut --force
    ```
  to update kernel modules and initramfs.

### Required Kernel Information

* Linux kernel v5.11+ (This is for crypto, for compression use v5.17+)
* Fedora 34+ (for compression use 36+)
* RHEL 8.4+ (for compression use 9.0+)

### BIOS Settings

* Intel `VT-d` and `SR-IOV` must be enabled in the platform (BIOS).

### Grub Settings

Fedora:

* `sudo grubby --update-kernel=DEFAULT --args="intel_iommu=on vfio-pci.disable_denylist=1 iommu=pt default_hugepagesz=2M hugepagesz=2M hugepages=4096"`
* Reboot system

Ubuntu:

* `sudo vim /etc/default/grub`
* move to `GRUB_CMDLINE_LINUX` add `intel_iommu=on vfio-pci.disable_denylist=1 iommu=pt default_hugepagesz=2M hugepagesz=2M hugepages=4096`
* `sudo update-grub`
* Reboot system

### Install QATLib

Fedora 34+, using software package manager

```shell
# Install QATLib
sudo dnf install -y qatlib-devel

# Add your user to qat group and re-login to make the change effective
sudo usermod -a -G qat `whoami`
sudo su -l $USER

# Make sure qat service is started properly and ready for use.
sudo systemctl stop qat.service
sudo systemctl enable qat.service
sudo systemctl restart qat.service
sudo systemctl status qat.service
```

### Other Distributions: Building From Source

Fedora

```shell
# Install dependencies
sudo dnf update -y
sudo dnf install -y gcc systemd-devel automake autoconf libtool
sudo dnf install -y openssl-devel zlib-devel yasm
```

Ubuntu

```shell
# Install dependencies
sudo apt update -y
sudo apt install -y build-essential cmake g++ pkg-config wget make yasm nasm libboost-all-dev libnl-genl-3-dev zlib1g zlib1g-dev
apt install -y systemd m4 pkg-config libudev-dev libssl-dev autoconf libtool tar git libssl-dev
```

### Build & install

```shell
git clone https://github.com/intel/qatlib
cd qatlib
./autogen.sh
./configure --prefix=/usr --enable-service
make -j
sudo make -j install
sudo make samples-install

# Make sure qat service is started properly and ready to use
sudo systemctl stop qat.service
sudo systemctl enable qat.service
sudo systemctl restart qat.service
sudo systemctl status qat.service
```

## QAT Drivers Uninstall

Remove / clean-up of drivers / configurations. Especially helpful if QAT setup needs to be re-configured

```shell
sudo systemctl stop qat.service
# Move to dir location in which drivers / configuration are saved such as "/opt/intel/QAT" and execute mentioned below commands:
make uninstall
make clean
make distclean
```

## References

Please refer to the following links for detailed information on QAT In-tree Driver Setup For 4xxx Device

* https://github.com/intel/qatlib/blob/main/INSTALL

* [intel-device-plugins-for-kubernetes/Dockerfile at main · intel/intel-device-plugins-for-kubernetes · GitHub][intel-device-plugins-for-kubernetes]

For more information on setting up PFs / VFs for specific QAT devices, please visit

* https://doc.dpdk.org/guides/cryptodevs/qat.html


[intel-device-plugins-for-kubernetes]: https://github.com/intel/intel-device-plugins-for-kubernetes/blob/main/demo/openssl-qat-engine/Dockerfile