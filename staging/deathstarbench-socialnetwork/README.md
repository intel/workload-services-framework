<h1 style="text-align: center;">Microservices Benchmarking with DeathStarBench</h1>


## Experiment replication guide

In this document we present the `conditions` and `steps` required to replicate the experiment setup for 
`DeathStarBench Social Network` workload and run experiments on a 3-worker-node Kubernetes Cluster using Home-timeline-query.

## DeathStarBench Social Network workload

The workload is a social network with unidirectional follow
relationships, implemented with loosely coupled microservices,
communicating with each other via Thrift RPCs. It is open source and can
be referenced here:  
https://github.com/delimitrou/DeathStarBench/tree/master/socialNetwork

The Social Network application is part of the DeathStarBench benchmark
suite for cloud microservices, that includes five end-to-end services,
four for cloud systems, and one for cloud-edge systems running on drone
swarms.  
https://github.com/delimitrou/DeathStarBench

More details on the applications and a characterization of their
behavior can be found at ["An Open-Source Benchmark Suite for
Microservices and Their Hardware-Software Implications for Cloud and
Edge Systems"](https://www.csl.cornell.edu/~delimitrou/papers/2019.asplos.microservices.pdf), Y. Gan et al., ASPLOS 2019.

## Conditions

Layers of the cluster (bottom up): 

* Operating System: Linux Centos 8.4.2105 - kernel stable v6.0.6
* Container Runtime: Containerd v1.4.12
* Container Orchestrator: Kubernetes v1.21.14
* Container Network Interface: Cilium v1.11.4
* Benchmark Application: DeathStarBench Social Network v0.0.8

They come on top of hardware infrastructure specifications presented in detail in the README enclosed with the data sets.

## Experiment steps

Bellow we relate the steps took to:
  
* create the kubernetes cluster 
* deploy, initialize and scale the social network
* collect the baseline data


### Step_1: create the Kubernetes Cluster

Master node kubeadm init command with `--skip-phases` option:

```
kubeadm init --config=config.yaml --skip-phases=addon/kube-proxy
```

Master node init `config.yaml`:

```
apiVersion: kubeadm.k8s.io/v1beta2
kind: InitConfiguration
nodeRegistration:
    taints: []
    criSocket: /run/containerd/containerd.sock
    kubeletExtraArgs:
        node-ip: <MASTER_NODE_IP>
localAPIEndpoint:
    advertiseAddress: <MASTER_NODE_IP>
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
cpuManagerPolicy: static
systemReserved:
    cpu: 500m
    memory: 256M
kubeReserved:
    cpu: 500m
    memory: 256M
topologyManagerPolicy: best-effort
maxPods: 4000
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
networking:
    dnsDomain: cluster.local
    podSubnet: 10.244.0.0/16
    serviceSubnet: 10.96.0.0/16
controlPlaneEndpoint: "<MASTER_NODE_IP>:6443"
apiServer:
    extraArgs:
        advertise-address: <MASTER_NODE_IP>
```

Worker nodes kubeadm join command:

```
kubeadm join --config=config.yaml
```

Worker nodes join `config.yaml`:

```
apiVersion: kubeadm.k8s.io/v1beta2
kind: JoinConfiguration
nodeRegistration:
    taints: []
    kubeletExtraArgs:
        node-ip: <WORKER_NODE_IP>
discovery:
    bootstrapToken:
        apiServerEndpoint: <MASTER_NODE_IP>:6443
        # REPLACE WITH OUTPUT FROM MASTER NODE KUBEADM INIT 
        token: <TOKEN>
        caCertHashes:
        - sha256:<SHA KEY>
```

### Step_2: install Kubernetes Cluster Network Plugin

Cilium repo:
```
helm repo add cilium https://helm.cilium.io/
```

Cilium install options:
```
helm install cilium cilium/cilium --version 1.11.4 \
    --namespace kube-system \
    --set kubeProxyReplacement=strict \
    --set k8sServiceHost=<MASTER_NODE_IP> \
    --set k8sServicePort=6443 \
    --set nodePort.directRoutingDevice=<NIC_NAME> \
    --set enableEndpointRoutes=true \
    --set nativeRoutingCIDR=10.0.0.0/16 \
    --set tunnel=disabled \
    --set autoDirectNodeRoutes=true
```


### Step_3: deploy DeathStarBench Social Network

DeathStarBench github repo and commit id used:

```
git clone https://github.com/delimitrou/DeathStarBench
git checkout 25f60f07edc8031cec7d7fd582e6732ace34d6a3 
```

Install Social Network helm command: 

```
helm install dsb DeathStarBench/socialNetwork/helm-chart/socialnetwork -n deathstarbench-social-network 
        --create-namespace  
        --set global.dockerRegistry=<docker private registry if available>
        --set-string global.topologySpreadConstraints=
         "- maxSkew: 1
            topologyKey:
                kubernetes.io/hostname
            whenUnsatisfiable:
                DoNotSchedule
            labelSelector:
                matchLabels:
                   service: {{ .Values.name }}"

```

Checks, info and best practices:
* Jaeger pod should be scheduled on master node, please move pod on master node if deployed on one of the worker nodes.
The reason is that jaeger service registers high values of cpu utilization and will interfere with performance of services
scheduled on the respective node.   
* Topology spread constraints ensure that when scaled service replicas are evenly distributed among the 3 worker nodes.
* GitHub repo commit id used assures versions:
    * socialNetwork-0.0.8 
    * nginx-thrift docker image: yg397/openresty-thrift:xenial


### Step_4: deploy Bitnami Redis Cluster

Bitnami charts github repo:
``` 
git clone https://github.com/bitnami/charts
```

Install Bitnami Redis chart helm command:

```
helm install redis-ha charts/bitnami/redis 
    --set master.persistence.enabled=false 
    --set replica.persistence.enabled=false 
    --set auth.enabled=false 
    --set replica.replicaCount=6
    --set-string global.topologySpreadConstraints=
         "- maxSkew: 1
            topologyKey:
                kubernetes.io/hostname
            whenUnsatisfiable:
                DoNotSchedule
            labelSelector:
                matchLabels:
                   service: {{ .Values.name }}"
```

Checks, info and best practices:
* Redis pods should all be scheduled on the worker nodes, to ensure that please taint master node as unschedulable 
before installing redis chart
* Topology spread constraints ensure that redis replicas are evenly distributed among the 3 worker nodes.


### Step_5: delete default home-timeline-redis service and point home-timeline-service to `redis-ha-master`

Delete default home-timeline-redis service:

```
kubectl delete deployment home-timeline-redis  -n deathstarbench-social-network
```

Edit `home-timeline-service` config map and change home-timeline-redis addr to `redis-ha-master`:

```
kubectl edit cm home-timeline-service -n deathstarbench-social-network
        ..
        "home-timeline-redis": {
          "addr": "redis-ha-master",
          "port": 6379,
       ...
```

Redeploy the `home-timeline-service` pod:

```
kubectl delete pod -l service=home-timeline-service -n deathstarbench-social-network
```


### Step_6: initialize the Social Graph with sample users, followers and posts

Initialization script is located at `DeathStarBench/socialNetwork/scripts/init_social_graph.py`.


`DeathStarBench//socialNetwork/datasets/social-graph/socfb-Reed98` dataset contains 962 users with 15 followers each (14430 edges):

```
python3 init_social_graph.py --graph socfb-Reed98
```

For each user add 110 sample posts: 

```
python3 init_social_graph.py --compose 110
```


### Step_7: point home-timeline-service to `redis-ha-replicas` service 

Edit `home-timeline-service` config map and change home-timeline-redis addr to `redis-ha-replicas`:

```
kubectl edit cm home-timeline-service -n deathstarbench-social-network
        ..
        "home-timeline-redis": {
          "addr": "redis-ha-replicas",
          "port": 6379,
       ...
```

Redeploy the `home-timeline-service` pod:

```
kubectl delete pod -l service=home-timeline-service -n deathstarbench-social-network
```

### Step_8: set nginx-thrift worker_processes and scale services according to BKC

Set nginx-thrift worker_processes to 110/200 according to the BKC:

```
kubectl edit cm nginx-thrift -n deathstarbench-social-network
    ...
    # Checklist: Make sure that worker_processes == #cores you gave to
    # nginx process
    worker_processes  110;
    ...
```

Redeploy nginx-thrift pod:

```
kubectl delete pod -l service=nginx-thrift -n deathstarbench-social-network
```

Scale services according to Best Known Configuration (BKC) to provide response latency time withing 100ms SLA for 
a Maximum Number of Requests per Second:

```
kubectl scale deployment          home-timeline-service  -n deathstarbench-social-network --replicas     18
kubectl scale deployment          nginx-thrift   -n deathstarbench-social-network --replicas             3
kubectl scale deployment          post-storage-memcached  -n deathstarbench-social-network --replicas    3
kubectl scale deployment          post-storage-service   -n deathstarbench-social-network --replicas     18
```


### Step_9: run wrk2 workloads 

`wrk2` close-loop load generator opens `-c` number of connections to `nginx-thrift` service endpoint and makes `-R` number requests 
per second for the duration of `-d` seconds. Each request triggers the action of `reading the home-timeline` for a random chose 
social-netowrk user. On client side the requests are parallelized using `-t` number of threads. 

```
wrk -t100 -c9000 -d 60s -L -s "scripts/social-network/read-home-timeline.lua" http://nginx-thrift.deathstarbench-social-network.svc.cluster.local:8080 -R 90000
```

Snipped from the output of the wrk2 load generator:

```
Running 1m test @ http://nginx-thrift.deathstarbench-social-network.svc.cluster.local:8080
  100 threads and 9000 connections
...
  Thread Stats   Avg      Stdev     99%   +/- Stdev
    Latency    29.40ms  378.32ms  26.90ms   99.70%
    Req/Sec     0.91k   215.55     1.38k    68.73%
  Latency Distribution (HdrHistogram - Recorded Latency)
 50.000%    9.76ms
 75.000%   12.92ms
 90.000%   16.70ms
 99.000%   26.90ms
 99.900%    7.65s 
 99.990%   11.66s 
 99.999%   12.51s 
100.000%   13.02s 
----------------------------------------------------------
  5369637 requests in 1.00m, 59.82GB read
Requests/sec:  89918.38
Transfer/sec:      1.00GB
```

`wrk2` is built and installed from `DeathStarBench/socialNetwork/wrk2`:

```
make && make install
``` 

The lua scripts employed by `wrk2` to trigger different actions are located at `DeathStarBench/socialNetwork/wrk2/scripts/social-network`:

```
# ls | cat
compose-post.lua
mixed-workload.lua
read-home-timeline.lua
read-user-timeline.lua
```

This experiment only uses `read-home-timeline` requests. 

The `wrk2` was build and run inside a container deployed in the same namespace as the social network app, this allowed us to send
the `wrk2` requests directly to the nginx-thrift FQDN `nginx-thrift.deathstarbench-social-network.svc.cluster.local` and also to partially qualified one:
`nginx-thrift` on port 8080:

```
kubectl exec -it deathstarclient-wrk2-rebase -c server -n deathstarbench-social-network -- /bin/bash -c './wrk2/wrk -t100 -c9000 -d 6s -L -s "socialnet/wrk-scripts/read-home-timeline.lua" http://nginx-thrift:8080 -R 90000'
```

The Docker file used to build `wrk2` and execute workloads inside a container:

```
FROM ubuntu:xenial

WORKDIR /workspace

RUN apt-get update && apt-get install -y software-properties-common && add-apt-repository ppa:deadsnakes/ppa
RUN apt-get update
RUN apt-get install -y python3.6 python3.6-dev python3-pip
RUN ln -sfn /usr/bin/python3.6 /usr/bin/python3 && ln -sfn /usr/bin/python3 /usr/bin/python && ln -sfn /usr/bin/pip3 /usr/bin/pip

RUN apt-get install -y curl vim dnsutils
RUN apt-get install -y libssl-dev
RUN apt-get install -y libz-dev
RUN apt-get install -y luarocks
RUN luarocks install luasocket

COPY . /workspace
RUN pip3 install --upgrade pip
RUN pip3 install --no-cache-dir -r requirements.txt


# Compile and install wrk2 to /usr/local/bin
COPY wrk2/ /workspace/wrk2
WORKDIR /workspace/wrk2
RUN make -j8 && make install

# Copy scripts to container.
COPY scripts/ /workspace/scripts

WORKDIR /workspace

CMD [ "python3", "./sleep.py" ]
```

Folder `wrk2` would be folder `DeathStarBench/socialNetwork/wrk2/`.  
Folder `scripts` would be folder `DeathStarBench/socialNetwork/wrk2/scripts`.


### Step_10: collect baseline data 

Collecting the baseline for a range of RPS (requests per second) involves running consecutive 
`wrk2` workloads starting from a specific RPS value and increasing it with a step of 1000 RPS.  

```
wrk -t100 -c7100 -d 60s -L -s "<rht lua script>" http://<nginx-thrift-service:port> -R 71000
wrk -t100 -c7200 -d 60s -L -s "<rht lua script>" http://<nginx-thrift-service:port> -R 72000
wrk -t100 -c7300 -d 60s -L -s "<rht lua script>" http://<nginx-thrift-service:port> -R 73000
wrk -t100 -c7400 -d 60s -L -s "<rht lua script>" http://<nginx-thrift-service:port> -R 74000
...
wrk -t100 -c9500 -d 60s -L -s "<rht lua script>" http://<nginx-thrift-service:port> -R 95000
wrk -t100 -c9600 -d 60s -L -s "<rht lua script>" http://<nginx-thrift-service:port> -R 96000
wrk -t100 -c9700 -d 60s -L -s "<rht lua script>" http://<nginx-thrift-service:port> -R 97000
wrk -t100 -c9800 -d 60s -L -s "<rht lua script>" http://<nginx-thrift-service:port> -R 98000
wrk -t100 -c9900 -d 60s -L -s "<rht lua script>" http://<nginx-thrift-service:port> -R 99000
wrk -t100 -c1000 -d 60s -L -s "<rht lua script>" http://<nginx-thrift-service:port> -R 100000
```

The Connections / RPS ratio (c/R) is always kept at 1/10 and the -t is fixed at 100 threads.   
The "c/R" ratio translates in 1 connection executes a number of 10 requests per second.  

To plot the data we parse the out or the each `wrk2` command and extract the P99 value from `Latency Distribution (HdrHistogram - Recorded Latency)` section. 
The RPS number is `X axis` and the P99 response latency is the `Y axis`.   

We call the previous value of RPS before the SLA is broken `MAX RPS`. The SLA is P99 = 100ms.  
