
`Kubernetes` is the default validation backend to run single-or-multiple-container workloads on your local cluster of machines.  

### Prerequisite

Starting Kubernetes v1.20, Kubernetes deprecated `docker` as a runtime and used `containerd` instead. Follow the [instructions][instructions] to install and configure `containerd` on your system.

### Setup Kubernetes

Follow the [Ubuntu][Ubuntu]/[CentOS][CentOS] instructions to setup a Kubernetes cluster. For full features, please install Kubernetes v1.21 or later.

---

You can build the workloads and run the workloads on the same machine by setting up a single-node Kubernetes cluster:  

```
kubectl taint node --all node-role.kubernetes.io/master-
kubectl taint node --all node-role.kubernetes.io/control-plane-  # >= v1.20
```

---

### Setup Node Feature Discovery With Intel Device Plugins (Ansible Automation)

To achieve NFD + Intel Device Plugins in SF, please refer to the execution role in the location below:
```
applications.benchmarking.benchmark.platform-hero-features/script/terraform/template/ansible/kubernetes/roles/nfd_with_intel_device_plugins/
```

For deployment and verification of NFD + Intel Device Plugins, please refer to mentioned below location:
```
applications.benchmarking.benchmark.platform-hero-features/doc/nfd-with-intel-device-plugins.md
```

### Setup Node Feature Discovery (Manually)

Install node feature discovery as follows:

```
kubectl apply -k https://github.com/kubernetes-sigs/node-feature-discovery/deployment/overlays/default
```

### Setup arm64 Emulation

You can setup any worker node as an arm64 emulator. To do so, run the [`setup.sh`][setup.sh] script on each worker node to setup the arm64 emulation.

```
script/march/setup.sh
```

### See Also

- [Docker Setup][Docker Setup]
- [Kubernetes Setup][Kubernetes Setup]
- [Private Registry Authentication][Private Registry Authentication]
- [Cumulus Setup][Cumulus Setup]
- [`cluster-config.yaml`][cluster-config.yaml]
- [Secured Registry Setup][Secured Registry Setup]
- [NFD With Intel Device Plugins][NFD With Intel Device Plugins]


[instructions]: setup-containerd.md
[Ubuntu]: https://phoenixnap.com/kb/install-kubernetes-on-ubuntu
[CentOS]: https://phoenixnap.com/kb/how-to-install-kubernetes-on-centos
[setup.sh]: ../../../script/march/setup.sh
[Docker Setup]: setup-docker.md)
[Kubernetes Setup]: setup-kubernetes.md
[Private Registry Authentication]: setup-auth.md
[Cumulus Setup]: setup-cumulus.md
[`cluster-config.yaml`]: ../../developer-guide/component-design/cluster-config.md
[Secured Registry Setup]: setup-secured-registry.md
[NFD With Intel Device Plugins]: setup-nfd.md