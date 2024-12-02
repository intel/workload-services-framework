
# DLB Setup

DLB is supported in certain SPR SKUs. Please make sure your CPU sku (QDF) supports DLB.

And DLB is broken with latest BKC kernel `5.15.0-spr.bkc.pc.2.10.0.x86_64`.
Before running the workload, please make sure your SPR has DLB device by running the following command:

```shell
lspci | grep 2710
```

If there are devices listed, then please download the DLB driver from this link: https://www.intel.com/content/www/us/en/download/686372/intel-dynamic-load-balancer.html

Execute the following commands:

```shell
tar -xf dlb_linux_src_release_<dlb_driver_version>.txz
cd dlb/driver/dlb2/
make
sudo insmod dlb2.ko
```

Then you can run the workload on this machine.

