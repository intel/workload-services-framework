## In-tree Driver
QAT device intree enabling BKM for **4xxx** device

**Reference**

- https://github.com/intel/qatlib/blob/main/INSTALL

- [intel-device-plugins-for-kubernetes/Dockerfile at main · intel/intel-device-plugins-for-kubernetes · GitHub](https://github.com/intel/intel-device-plugins-for-kubernetes/blob/main/demo/openssl-qat-engine/Dockerfile)

### Check System Prerequisites

* platform must have one of the following Intel® Communications devices:
   4xxx  : Use `lspci -d 8086:4940` to check Physical Function (PF) devices are present.
  
  > Note: Later, after "systemctl start qat" or "make install" steps, the
  >  corresponding Virtual Function devices will also be visible and bound
  >  to the vfio-pci driver.
  >  4xxx  : Use `lspci -d 8086:4941` to check VF devices have been created.

* firmware must be available
  Check  whether `/lib/firmware/qat_4xxx.bin` and `/lib/firmware/qat_4xxx_mmp.bin` files exist, if not contact qat-linux@intel.com
  
  then copy these files into `/lib/firmware/`

* kernel driver must be running, after installing the firmware, reinstall the kernel mod
  
  ```shell
  sudo rmmod qat_4xxx
  sudo modprobe qat_4xxx
  sudo dracut --force
  ```
  
  They should load by default if using any of the following:
  
  * Linux kernel v5.11+ (This is for crypto, for compression use v5.17+)
  * Fedora 34+ (for compression use 36+)
  * RHEL 8.4+ (for compression use 9.0+)

* each PF device must be bound to the 4xxx driver
   Use `ls /sys/bus/pci/drivers/4xxx/` to show the BDFs of each bound PF

* BIOS settings
   `Intel VT-d` and `SR-IOV` must be enabled in the platform BIOS.
   Consult your platform guide on how to do this.
   If using an Intel BKC these usually default to on, you can verify by
   rebooting, entering F2 on the console to get to the BIOS menus and
   checking these are enabled:
   EDKII Menu
  
      -> Socket Configuration
       -> IIO Configuration
        -> Intel VT for Directed I/O (VT-d)
         -> Intel VT for Directed I/O
  
   EDKII Menu
  
      -> Platform Configuration
       -> Miscellaneous Configuration
        -> SR-IOV Support

* Grub settings

   set `intel_iommu` on in grub file, 
   
   **e.g.** in Fedora:
  
  * ` sudo grubby --update-kernel=DEFAULT --args="intel_iommu=on iommu=pt default_hugepagesz=2M hugepagesz=2M hugepages=4096"`
  * reboot system

  Ubuntu:  
  * `sudo vim /etc/default/grub`
  * move to `GRUB_CMDLINE_LINUX` add `intel_iommu=on iommu=pt default_hugepagesz=2M hugepagesz=2M hugepages=4096`
  *  `sudo update-grub` in ubuntu
  * reboot system

### Install QATLib

#### Fedora 34+, using software package manager

```shell
# Install qatlib
sudo dnf install -y qatlib-devel

# Add your user to qat group and re-login to make the change effective
sudo usermod -a -G qat `whoami`
sudo su -l $USER

# Enable qat service and make persistent after reboot
sudo systemctl enable qat
sudo systemctl start qat

# The library is now ready to use with your application
systemctl status qat
```

#### Other distributions: Building from source

- Install dependencies

  - Fedora
    
    ```shell
    sudo dnf install -y gcc systemd-devel automake autoconf libtool
    sudo dnf install -y openssl-devel zlib-devel yasm
    ```

  - Ubuntu
    
    ```shell
      sudo apt update && \
        sudo env DEBIAN_FRONTEND=noninteractive apt install -y \
        libudev-dev \
        make \
        gcc \
        g++ \
        nasm \
        pkg-config \
        libssl-dev \
        zlib1g-dev \
        wget \
        git \
        yasm \
        autoconf \
        cmake \
        libtool
    ```

-  Build & install

    ```shell
    git clone https://github.com/intel/qatlib
    cd qatlib
    ./autogen.sh
    ./configure --prefix=/usr --enable-service
    make -j
    sudo make install
    
    # Add your user to the "qat" group which was automatically
    # created by --enable-service. Then re-login to make the change
    # effective, this will also move you back into your home directory
    sudo usermod -a -G qat `whoami`
    sudo su -l $USER

    # The library is now ready to use with your application
    systemctl status qat
    ```

### (Optional) Install QAT engine

To enable OpenSSL with QAT on host.

- Fedora 34+

  `sudo dnf install qatengine`

- Other distributions

  ```shell
    git clone https://github.com/intel/QAT_Engine
    cd /QAT_Engine && \
        ./autogen.sh && \
        ./configure --enable-qat_sw && \
        make && make install
    ```

## Out-of-tree driver
### System Setup

Perform the following system setup for QAT to function properly:  
- Setup only PF:
    - Disable `VT-d` in BIOS:  

    ```
    EDKII Menu → Socket Configuration → IIO Configuration → Intel VT for directed IO (VT-d) → Intel VT for directed IO → Disable
    ```

    - Disable IOMMU and setup hugepages from your kernel command line:

    ```
    sudo grubby --update-kernel=DEFAULT --args="intel_iommu=off default_hugepagesz=2M hugepagesz=2M hugepages=4096"
    ```

    - Reboot your system for the kernel settings to take effect.

- Setup both PF and VF:
    - Enable `VT-d` in BIOS:  

    ```
    EDKII Menu → Socket Configuration → IIO Configuration → Intel VT for directed IO (VT-d) → Intel VT for directed IO → Enable
    ```

    -  Enable IOMMU and setup hugepages from your kernel command line:

    ```
    sudo grubby --update-kernel=DEFAULT --args="intel_iommu=on iommu=pt default_hugepagesz=2M hugepagesz=2M hugepages=4096"
    ```

    - Reboot your system for the kernel settings to take effect.

### QAT Driver Setup

- Download, build and install the [QAT HW 2.0](https://af01p-ir.devtools.intel.com/artifactory/scb-local/QAT_packages/QAT20) driver as follows:  

```
sudo dnf config-manager --set-enabled powertools
sudo yum -y groupinstall "Development Tools" 
sudo yum -y install yasm pciutils libudev-devel openssl-devel boost-devel libnl3-devel 
sudo yum -y install kernel-next-server-devel

sudo rmmod qat_4xxx usdm_drv intel_qat

wget https://af01p-ir.devtools.intel.com/artifactory/scb-local/QAT_packages/QAT20/QAT20_0.9.4/QAT20.L.0.9.4-00004/QAT20.L.0.9.4-00004.tar.gz

sudo mkdir -p /opt/intel/QAT
sudo tar xvfz QAT20.L.0.9.4-00004.tar.gz -C /opt/intel/QAT

cd /opt/intel/QAT
sudo ./configure
sudo make
sudo make install
```

To setup QAT VF, need probe vfio-pci and change configuration:

```
cd /opt/intel/QAT
sudo modprobe vfio-pci disable_denylist=1
sudo ./configure --enable-icp-sriov=host
sudo make
sudo make install
```
- Optionally check the QAT driver features with sample code: 

```
cd /opt/intel/QAT
sudo make samples-install
cd /usr/local/bin/
./cpa_sample_code 
```

- Intel QATLibs Installation (Optional Requirement If Needed)
  
  **Note:** This package provides user space libraries that allow access to Intel QuickAssist devices and expose the Intel(R) QuickAssist APIs and sample codes.
```
git clone https://github.com/intel/qatlib.git
cd qatlib
./autogen.sh
./configure --enable-service
make install
sudo systemctl enable qat.service
sudo systemctl restart qat.service
sudo systemctl status qat.service
```

- Setup hugepages and install the modules and services:

```
echo 4096 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
sudo rmmod usdm_drv
sudo insmod /opt/intel/QAT/build/usdm_drv.ko max_huge_pages=4096 max_huge_pages_per_process=224
sudo systemctl stop qat.service
sudo systemctl enable qat.service
sudo systemctl restart qat.service
sudo systemctl status qat.service
```

### QAT HW Build Package

The QAT HW images must be built against a specific OS kernel version. The default is against the `next` kernel, version `5.12`. The corresponding Dockerfiles must be updated if the OS kernel version is different. Use the following command to generate the qat-driver package used in the Dockerfiles:    

```
sudo tar cvfz ~/qat-driver-20-$(uname -r).tar.gz -C / /opt/intel/QAT/build $(find /opt/intel/QAT -name '*.h') /etc/udev/rules.d/00-qat.rules
```

### QAT Driver Configuration

The default QAT default configuration may not work for all use cases. Please see how to [replace the QAT driver config file](https://gitlab.devtools.intel.com/qat_apps/qat_engine#copy-the-intel-quickassist-technology-driver-config-files-for-qat_hw).  

The [`qat-invoke.sh`](../dist/@pve/qat-invoke.sh) script can be used to generate the QAT device configurations. Examples as follows:

```
SERVICES_ENABLED=asym SECTION_NAME=SHIM CY_INSTANCES=8 PROCESSES=8 qat-invoke.sh
```
```
SERVICES_ENABLED=sym SECTION_NAME=SHIM CY_INSTANCES=1 PROCESSES=64 qat-invoke.sh
```
```
SERVICES_ENABLED=asym SECTION_NAME=SSL CY_INSTANCES=8 PROCESSES=8 qat-invoke.sh
```
```
SERVICES_ENABLED=sym SECTION_NAME=SSL CY_INSTANCES=8 PROCESSES=8 qat-invoke.sh
```
```
SERVICES_ENABLED=dc SECTION_NAME=SSL DC_INSTANCES=1 PROCESSES=64 qat-invoke.sh
```

### Node Labels

Label the QAT worker node(s) with the following node labels:  
- `HAS-SETUP-KERNEL-V0512=yes`: Must have.  
- `HAS-SETUP-CENTOS8=yes`: Must have.  
- `HAS-SETUP-QAT=yes`: Must have. 
- `HAS-SETUP-QAT-V200=yes`: Must have.  
- `HAS-SETUP-HUGEPAGE-2048kB-4096=yes`: Must have.  
An additional label is needed if QAT VF is required:
- `HAS-SETUP-MODULE-VFIO-PCI=yes`: Must have.

### QAT Driver Uninstall

Remove the QAT driver and cleanup. Especially helpful if QAT setup needs to be re-configured
```
sudo systemctl stop qat.service
make uninstall
make clean
make distclean
```
### See Also

- [Quick Assist Technology](https://01.org/intel-quickassist-technology)  
- [QAT Resources](https://wiki.ith.intel.com/display/PRCCIDSW/Useful+Resources)   

