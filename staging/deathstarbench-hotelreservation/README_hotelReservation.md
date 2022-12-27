# DSB HotelReservation Benchmarking Guide

This guide is for reproducing benchmarking result of [DSB HotelReservation](https://github.com/delimitrou/DeathStarBench/tree/master/hotelReservation) workload with our BKC(Best Known Configurations). Users of this document may outside of org/company, so be careful not to include any intel-restricted sources. 

Following are steps to deploy the DSB HotelReservation workload and run the benchmark.

## 1. Cluster Setup

You should have a running Kubernete cluster, preferably with 1 master and 3 worker nodes. Here is a summary of our recommended cluster setup. If you already have such a cluster or know how to create one, you may directly go to the end of this section and verify your cluster. 

 - Kernel and OS: Ubuntu 22.04 with kernel 5.15.0-43-generic (older kernel is ok but may get lower performance, e.g. Ubuntu 20.04)
 - Kubernetes: v1.23.6 (different version is ok)
 - Container Runtime Interface: containerd v1.6.6 with CRI-RM v0.7.0
 - Container Network Interface: Calico v3.22.2 (for baseline) or Cilium 1.11.7 (for BKC)

 If you do not have an existing cluster or your existing cluster does not meet requirement above, below are some useful links and tips.

### Prepare Hosts

 You need to have 4 hosts, either baremetal machines or vms, to setup a k8s cluster with 1 master and 3 workers. 

 - k8s master node will act as both `controller` to manage the workload and `client` to run load generator. 
 - k8s worker nodes will act as `worker` to run all the workload containers. They should have same setting and must be baremetal machines if you want to collect emon data.

### Installing kubeadm
On all the hosts, please follow Kubernetes guide to [install kubeadm](https://v1-23.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm).

When installing the container runtime, please follow [this Kubernetes's guide](https://v1-23.docs.kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd) to install containerd v1.6.6 as the Kubernetes container runtime.

After successfully installed the containerd v1.6.6 as the Kubernetes container runtime, we need to install [CRI-RM](https://github.com/intel/cri-resource-manager) v0.7.0, a CRI proxy that sits between clients and the actual CRI to apply hardware-aware resource allocation policies to the containers running in the system. To install [CRI-RM v0.7.0](https://intel.github.io/cri-resource-manager/v0.7/docs/quick-start.html#setup-cri-resmgr), please run the following commands on all the hosts:
```
# Install CRI-RM 0.7.0
CRIRM_VERSION="0.7.0"
source /etc/os-release
pkg=cri-resource-manager_${CRIRM_VERSION}_${ID}-${VERSION_ID}_amd64.deb; curl -LO https://github.com/intel/cri-resource-manager/releases/download/v${CRIRM_VERSION}/${pkg}; sudo dpkg -i ${pkg}; rm ${pkg}
sudo cp /etc/cri-resmgr/fallback.cfg.sample /etc/cri-resmgr/fallback.cfg
sudo systemctl enable cri-resource-manager && sudo systemctl start cri-resource-manager
```

Use of CRI-RM is optional but as it suggests, hardware-aware resource allocation can benefits the performance as well as resource usage. Follow this [link](https://intel.github.io/cri-resource-manager/v0.7/docs/setup.html) to config CRI-RM with your cluster.

### Creating a cluster with kubeadm
Please follow Kubernetes guide to [create a cluster with kubeadm](https://v1-23.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/). 

When initializing the Kubernetes control plane, please append `--cri-socket /var/run/cri-resmgr/cri-resmgr.sock` parameter to the original `kubeadm init` command.

When joining the Kubernetes worker nodes, please append `--cri-socket /var/run/cri-resmgr/cri-resmgr.sock` parameter to the original `kubeadm join` command.

### Install CNI
Although Calico is as the baseline choice, [Cillium](https://github.com/cilium/cilium) is recommended for its eBPF-based dataplane to provide better performance, observability and security. It's recommend to use Cilium as the Kubernetes CNI. 

If you plan to use Cilium v1.11.7, please append `--skip-phases=addon/kube-proxy` parameter to the original `kubeadm init` command. Please see [Cilium documentation](https://docs.cilium.io/en/v1.11/gettingstarted/k8s-install-kubeadm/) for details.

When install the Cilium, please use the following helm command on the Kubernetes master node:
```
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium --version 1.11.7 -n kube-system --set kubeProxyReplacement=strict,k8sServiceHost=<Kubernetes master node ip address>,k8sServicePort=6443,hubble.enabled=false,bpf.masquerade=true,devices='{east_west_bound_nic_name,north_south_bound_nic_name}',nodePort.directRoutingDevice=<east_west_bound_nic_nameE>,ipam.operator.clusterPoolIPv4PodCIDRList="10.244.0.0/16" --wait
```

## 2. Deploy DSB hotelReservation Workload
To deploy the DSB HotelReservation, please do the following steps on the k8s master node:

### 2.0 Setup the container image build environment
NOTE: If you don't have a account on [DockerHub](https://hub.docker.com), you need to create an account to store the container image built in the following steps.

To build the container image, you need to install [Buildkit](https://github.com/moby/buildkit) and [nerdctl](https://github.com/containerd/nerdctl) first on the Kubnernetes master node.

Once you have installed the Buildkit and nerdctl, please [set up nerdctl working with Buildkit](https://github.com/containerd/nerdctl/blob/main/docs/build.md) on the Kubernetes master node. Normally, it's suggested to set up Buildkit with rootful containerd worker to make building container image more easily.

Start the Buildkit daemon either through command line `sudo buildkitd` or through systemd `sudo systemctl enable --now buildkit` depending how you install the Buildkit.

### 2.1 Build and push the container image
1. On Kubernetes master node, get the DSB HotelReservation source code
```
git clone https://github.com/delimitrou/DeathStarBench
cd DeathStarBench/hotelReservation
git checkout 526c6e8fea517d06d165d824338041548f1af301
```
NOTE: the above git commit id needs to be changed if the pending github [PR](https://github.com/delimitrou/DeathStarBench/pull/255) is merged.

2. Build the container image and push it to DockerHub
```
sudo nerdctl login -u <your DockerHub account name>
sudo nerdctl build -t <dockerhub_account_name>/dsbpp_hotel_reserv:test .
sudo nerdctl push <dockerhub_account_name>/dsbpp_hotel_reserv:test
```

3. Open a web browser to DockerHub `https://hub.docker.com/repository/docker/<dockerhub_account_name>/dsbpp_hotel_reserv`, to make sure the container image have been successfully pushed there.

### 2.2 Install helm on Kubernetes master node if necessary
If there is no helm installed on the Kubernetes master node, you need to install [Helm3](https://helm.sh/docs/intro/install/#from-the-binary-releases). 

### 2.3 Deploy multiple workload instances
1. Copy the whole directory [`helm_hotelReservation`](helm_hotelReservation) to the Kubernetes master node.

2. On kubernetes master node, deploy 4 DSB hotelReservation workload instances into 4 different namespaces:
```
cd helm_hotelReservation
helm install test . --create-namespace --wait --set replicaCount=6 --set image.repository=<dockerhub_account_name>/dsbpp_hotel_reserv --set image.tag=test --set features.gcPercent=1000 --set features.memcTimeout=10 -n hotel-res1
helm install test . --create-namespace --wait --set replicaCount=6 --set image.repository=<dockerhub_account_name>/dsbpp_hotel_reserv --set image.tag=test --set features.gcPercent=1000 --set features.memcTimeout=10 -n hotel-res2
helm install test . --create-namespace --wait --set replicaCount=6 --set image.repository=<dockerhub_account_name>/dsbpp_hotel_reserv --set image.tag=test --set features.gcPercent=1000 --set features.memcTimeout=10 -n hotel-res3
helm install test . --create-namespace --wait --set replicaCount=6 --set image.repository=<dockerhub_account_name>/dsbpp_hotel_reserv --set image.tag=test --set features.gcPercent=1000 --set features.memcTimeout=10 -n hotel-res4
```

Some important helm chart configuration items are listed here:
- replicaCount: replica number of the DSB hotelReservation workload pods.
- image.repository and image.tag: container image name and tag built in step 2.2.
- features.gcPercent: Golang garbage collection target percentage ratio.
- features.memcTimeout: timeout in seconds of memcached client library.

### 2.4 Verify all the pods are running correctly:
Make sure all the DSB hotelReservation pods in all the 4 namespaces(hotel-res1, hotel-res2, hotel-res3, hotel-res4) are in Running status:
```
kubectl get pod -A | grep hotel-res.
```

If some DSB hotelReservation pods are not in Running status, wait for sometime and recheck, until all the DSB hotelReservation pods are in Running status.

## 3. Run Load Generator 
To run the benchmark against the 4 DSB hotelReservation instances which are deployed in Step 2, the wrk2 in DSB is used.

1. On the Kubernetes master node, get the wrk2 source code.
When this document is being created, there is still a pending github [PR](https://github.com/delimitrou/DeathStarBench/pull/255) of wrk2. Please check the github [PR](https://github.com/delimitrou/DeathStarBench/pull/255) status.

If this PR is in 'Open' status, run the following command to get the source code:
```
# Assuming have already git clone the DSB code in Step 2.
cd DeathStarBench
git fetch origin pull/255/head:wrk
git checkout wrk
ls
# Once the PR is feteched to local directory, a new directory named wrk2 should be in the current directory.
```
NOTE: the above steps is not needed any more after that PR is merged.

2. Build wrk2 on Kubenetes master node:
```
sudo apt-get install -y build-essential luarocks libssl-dev zlib1g-dev
sudo luarocks install luasocket
cd wrk2
make clean && make
```

3. Get DSB hotelReservation workload instances' frontend services' node port number:
```
export NODE_IP=$(kubectl get nodes --selector='!node-role.kubernetes.io/master' -o jsonpath="{.items[0].status.addresses[0].address}")
export NODE_PORT1=$(kubectl get --namespace hotel-res1 -o jsonpath="{.spec.ports[0].nodePort}" services frontend-test-hotelres)
export NODE_PORT2=$(kubectl get --namespace hotel-res2 -o jsonpath="{.spec.ports[0].nodePort}" services frontend-test-hotelres)
export NODE_PORT3=$(kubectl get --namespace hotel-res3 -o jsonpath="{.spec.ports[0].nodePort}" services frontend-test-hotelres)
export NODE_PORT4=$(kubectl get --namespace hotel-res4 -o jsonpath="{.spec.ports[0].nodePort}" services frontend-test-hotelres)

```

4. Run wrk2 load generator against the 4 workload instances
```
./wrk -D exp -L -s ../hotelReservation/wrk2/scripts/hotel-reservation/mixed-workload_type_1.lua -t 48 -c 1920 -d 120 -R 60000 http://${NODE_IP}:${NODE_PORT1} http://${NODE_IP}:${NODE_PORT2} http://${NODE_IP}:${NODE_PORT3} http://${NODE_IP}:${NODE_PORT4}
```

The new wrk2 can be run against multiple workload instance target. Here are some important wrk2 parameters:

- -t <thread num>: total thread number for each target instance. The product of `<thread num>` * `<instance num>` should be no more than the CPU core number on the host where wrk is running.
- -c <connection num>: total connection number for each target instance.
- -d <time in seconds>: duration of test
- -R <QPS>: request throughput in requests/sec for each target instance.

Snipped from the output of the wrk2 load generator:
```
$ ./wrk -D exp -L -s ../hotelReservation/wrk2/scripts/hotel-reservation/mixed-workload_type_1.lua -t 48 -c 1920 -d 60 -R 60000 http://${NODE_IP}:${NODE_PORT1} http://${NODE_IP}:${NODE_PORT2} http://${NODE_IP}:${NODE_PORT3} http://${NODE_IP}:${NODE_PORT4}

Running 1m test @ http://172.16.28.110:31150
  48 threads and 1920 connections

Running 1m test @ http://172.16.28.110:30685
  48 threads and 1920 connections

Running 1m test @ http://172.16.28.110:30464
  48 threads and 1920 connections

Running 1m test @ http://172.16.28.110:30814
  48 threads and 1920 connections

  Thread calibration: mean lat.: 18.489ms, rate sampling interval: 89ms
  Thread calibration: mean lat.: 18.876ms, rate sampling interval: 90ms
... ...
... ...
  Thread calibration: mean lat.: 30.374ms, rate sampling interval: 148ms

-----------------------------------------------------------------------
---------------------------Overall Statistics--------------------------
-----------------------------------------------------------------------
  Thread Stats   Avg      Stdev     99%   +/- Stdev
    Latency     3.87s     5.35s   17.81s    79.81%
    Req/Sec     1.25k   193.94     1.69k    69.83%
  Latency Distribution (HdrHistogram - Recorded Overall Latency)
 50.000%   90.75ms
 75.000%    7.59s
 90.000%   12.80s
 99.000%   17.81s
 99.900%   20.37s
 99.990%   22.00s
 99.999%   23.31s
100.000%   24.30s

  Detailed Percentile spectrum:
       Value   Percentile   TotalCount 1/(1-Percentile)

       0.295     0.000000            1         1.00
       3.255     0.100000      1030314         1.11
      10.591     0.200000      2060915         1.25
... ...
... ...
   24264.703     1.000000     10300583   8388608.00
   24264.703     1.000000     10300583   9320675.55
   24297.471     1.000000     10300584  10485760.00
   24297.471     1.000000     10300584          inf
#[Mean    =     3872.127, StdDeviation   =     5346.209]
#[Max     =    24281.088, Total count    =     10300584]
#[Buckets =           27, SubBuckets     =         2048]
-----------------------------------------------------------------------
  Overall 12388581 requests in 1.00m, 5.00GB read
Requests/sec: 205897.22
Transfer/sec:     85.12MB
```

From the above wrk2 output, we can see that we've run wrk2 against 4 different target workload instances, i.e. http://172.16.28.110:31150, http://172.16.28.110:30685, http://172.16.28.110:30464, http://172.16.28.110:30814, for each target workload instance, we launch 48 thread to make 1920 connections, send out the requests in a rate of 60000 Requests/sec for 60 seconds. The aggregated output total throughput of the 4 workload instance is 205897.22 Requests/sec.

5. Collect baseline data
Collecting the baseline for a range of RPS (requests per second) involves running consecutive wrk2 workloads starting from a specific RPS value and increasing it with a step of 1000 RPS.
```
./wrk -D exp -L -s ../hotelReservation/wrk2/scripts/hotel-reservation/mixed-workload_type_1.lua -t 48 -c 1920 -d 60 -R 55000 http://${NODE_IP}:${NODE_PORT1} http://${NODE_IP}:${NODE_PORT2} http://${NODE_IP}:${NODE_PORT3} http://${NODE_IP}:${NODE_PORT4}
./wrk -D exp -L -s ../hotelReservation/wrk2/scripts/hotel-reservation/mixed-workload_type_1.lua -t 48 -c 1920 -d 60 -R 56000 http://${NODE_IP}:${NODE_PORT1} http://${NODE_IP}:${NODE_PORT2} http://${NODE_IP}:${NODE_PORT3} http://${NODE_IP}:${NODE_PORT4}
./wrk -D exp -L -s ../hotelReservation/wrk2/scripts/hotel-reservation/mixed-workload_type_1.lua -t 48 -c 1920 -d 60 -R 57000 http://${NODE_IP}:${NODE_PORT1} http://${NODE_IP}:${NODE_PORT2} http://${NODE_IP}:${NODE_PORT3} http://${NODE_IP}:${NODE_PORT4}
... ...
... ...
./wrk -D exp -L -s ../hotelReservation/wrk2/scripts/hotel-reservation/mixed-workload_type_1.lua -t 48 -c 1920 -d 60 -R 70000 http://${NODE_IP}:${NODE_PORT1} http://${NODE_IP}:${NODE_PORT2} http://${NODE_IP}:${NODE_PORT3} http://${NODE_IP}:${NODE_PORT4}
./wrk -D exp -L -s ../hotelReservation/wrk2/scripts/hotel-reservation/mixed-workload_type_1.lua -t 48 -c 1920 -d 60 -R 71000 http://${NODE_IP}:${NODE_PORT1} http://${NODE_IP}:${NODE_PORT2} http://${NODE_IP}:${NODE_PORT3} http://${NODE_IP}:${NODE_PORT4}

```

We'll see that with increasing -R value, the aggregated output total throughput will decrease. If the latest 6 aggreated output total throughput is less than the maximum value in the history, we stop the above repetition and call that maximum value the maximum throughput(MAX throughput).

## 4. Cleanup DSB hotelReservation workload
To cleanup the DSB hotelReservation workload, run the following helm commands on the Kubernetes master node:
```
helm uninstall test -n hotel-res1
helm uninstall test -n hotel-res2
helm uninstall test -n hotel-res3
helm uninstall test -n hotel-res4
```
