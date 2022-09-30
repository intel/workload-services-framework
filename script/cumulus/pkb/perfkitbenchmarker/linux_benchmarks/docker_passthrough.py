from absl import flags
from perfkitbenchmarker import configs, events, stages, vm_util, sample
from perfkitbenchmarker.linux_packages import k8s
from perfkitbenchmarker.linux_packages import skopeo
try:
  from perfkitbenchmarker.linux_packages import archived_images
except:
  archived_images = None
from perfkitbenchmarker.linux_packages import habana
from perfkitbenchmarker.linux_packages import runwith
from perfkitbenchmarker.linux_packages import docker_ce
from perfkitbenchmarker.linux_packages import INSTALL_DIR
from perfkitbenchmarker.linux_packages import docker_auth
from posixpath import join
from uuid import uuid4
from yaml import safe_load_all, dump_all
import logging
import time
import os

BENCHMARK_NAME = "docker_pt"
BENCHMARK_CONFIG = """
docker_pt:
  description: Docker Passthrough Benchmark
  vm_groups: {}
  flags:
    dpt_docker_image: ""
    dpt_docker_dataset: []
    dpt_docker_options: ""
    dpt_kubernetes_yaml: ""
    dpt_kubernetes_job: ""
    dpt_namespace: ""
    dpt_logs_dir: ""
    dpt_timeout: "300"
    dpt_name: ""
    dpt_script_args: ""
    dpt_cluster_yaml: ""
    dpt_registry_map: []
    dpt_trace_mode: []
    dpt_params: ""
    dpt_tunables: ""
    dpt_debug: []
    dpt_vm_groups: "worker"
    dpt_reuse_sut: false
"""

run_seq = 0
SUT_VM_CTR = "controller"
KUBERNETES_CONFIG = "kubernetes_config.yaml"
HUGEPAGE_NR = "/sys/kernel/mm/hugepages/hugepages-{}/nr_hugepages"
LOGS_TARFILE = "{}.tar"
ITERATION_DIR = "itr-{}"
KPISH = "kpi.sh"
SF_NS_LABEL = "cn-benchmarking.intel.com/sf_namespace=true"
EXPORT_LOGS_TARFILE = "~/export-logs.tar"
KUBELET_CONFIG = "kubelet-config.yaml"

FLAGS = flags.FLAGS
flags.DEFINE_string("dpt_name", "", "Benchmark name")
flags.DEFINE_list("dpt_script_args", [], "The KPI and setup script args")
flags.DEFINE_string("dpt_docker_image", "", "Docker image name")
flags.DEFINE_list("dpt_docker_dataset", [], "Docker dataset images")
flags.DEFINE_string("dpt_docker_options", "", "Docker run options")
flags.DEFINE_string("dpt_kubernetes_yaml", "", "Kubernetes run yaml file")
flags.DEFINE_string("dpt_kubernetes_job", "benchmark", "Benchmark job name")
flags.DEFINE_string("dpt_namespace", str(uuid4()), "namespace")
flags.DEFINE_string("dpt_logs_dir", "", "The logs directory")
flags.DEFINE_string("dpt_timeout", "300", "Execution timeout")
flags.DEFINE_string("dpt_cluster_yaml", "", "The cluster configuration file")
flags.DEFINE_string("dpt_params", "", "The workload configuration parameters")
flags.DEFINE_string("dpt_tunables", "", "The workload tunable configuration parameters")
flags.DEFINE_list("dpt_registry_map", [], "Replace the registries")
flags.DEFINE_list("dpt_vm_groups", ["worker"], "Define the mapping of cluster-config groups to vm_groups")
flags.DEFINE_list("dpt_debug", [], "Set debug breakpoints")
flags.DEFINE_list("dpt_trace_mode", [], "Specify the trace mode triple")
flags.DEFINE_boolean("dpt_reuse_sut", False, "Enable when IWOS running in cloud")


def _GetTempDir():
  return join(INSTALL_DIR, FLAGS.dpt_namespace)


def _MakeTempDir(vm):
  tmp_dir = _GetTempDir()
  vm.RemoteCommand("sudo mkdir -p {0} && bash -c 'sudo chown $(id -u):$(id -g) {0}'".format(tmp_dir))
  return tmp_dir


def _SetBreakPoint(breakpoint):
  if breakpoint in FLAGS.dpt_debug:
    try:
      logging.info("Pause for debugging at %s", breakpoint)
      while not os.path.exists(join(vm_util.GetTempDir(), "Resume" + breakpoint)):
        time.sleep(5)
    except:
      pass
    logging.info("Resume after debugging %s", breakpoint)


def _FormatKPI(line):
  key, _, value = line.rpartition(":")
  key = key.strip()
  value = float(value.strip())
  if key.endswith(")"):
    key, _, unit = key.rpartition("(")
    unit = unit[0:-1].strip()
    key = key.strip()
  else:
    unit = "-"
  return key, value, unit


def _ParseKPI(metadata):
  cmd = "cd {} && ./{} {}".format(join(FLAGS.dpt_logs_dir, ITERATION_DIR.format(run_seq)), KPISH, " ".join(FLAGS.dpt_script_args))
  stdout, _, retcode = vm_util.IssueCommand(["sh", "-c", cmd])

  samples = []
  for line in stdout.split("\n"):
    if line.startswith("##"):
        k, _, v = line[2:].rpartition(":")
        k = k.strip()
        v = v.strip()
        if k and v:
          metadata[k]=v
    else:
      try:
        k, v, u = _FormatKPI(line)
        if k.startswith("*"):
          samples.append(sample.Sample(k[1:], v, u, {"primary_sample": True}))
        elif not k.startswith("#"):
          samples.append(sample.Sample(k, v, u))
      except Exception:
        pass
  if len(samples) == 1:
    samples[0].metadata["primary_sample"] = True
  return samples


def GetConfig(user_config):
  return configs.LoadConfig(BENCHMARK_CONFIG, user_config, BENCHMARK_NAME)


def CheckPrerequisites(benchmark_config):
  pass


def _ReplaceImage(image):
  if FLAGS.dpt_registry_map:
    if FLAGS.dpt_registry_map[0]:
      return image.replace(FLAGS.dpt_registry_map[0], FLAGS.dpt_registry_map[1])
    return FLAGS.dpt_registry_map[1] + image
  return image


def _WalkTo(node, name):
  try:
    if name in node:
      return node
    for item1 in node:
      node1 = _WalkTo(node[item1], name)
      if node1:
        return node1
  except Exception:
    pass
  return None


def _GetNodes(controller0):
  nodes = {}
  stdout, _ = controller0.RemoteCommand(
      "kubectl get nodes -o='custom-columns=name:.metadata.name,ip:.status.addresses[?(@.type==\"InternalIP\")].address' --no-headers")
  for line in stdout.split("\n"):
    fields = line.strip().split(" ")
    if fields[-1]:
      nodes[fields[-1]] = fields[0]
  return nodes


def _WriteKubeletConfigFile(options):
  kc = [{
    "apiVersion": "kubelet.config.k8s.io/v1beta1",
    "kind": "KubeletConfiguration",
  }]
  kc[0].update(options)

  kcf = f"{FLAGS.dpt_logs_dir}/{KUBELET_CONFIG}"
  with open(kcf, "w") as fd:
    dump_all(kc, fd)
  return kcf


def _ParseClusterConfigs(vm_groups, nodes={}):
  vimages = []
  workers = []
  nidx = {}
  options = []

  with open(FLAGS.dpt_cluster_yaml, "rt") as fd:
    for doc in safe_load_all(fd):
      if "cluster" in doc:
        for i, cluster1 in enumerate(doc["cluster"]):
          name = FLAGS.dpt_vm_groups[i % len(FLAGS.dpt_vm_groups)]
          if name not in nidx:
            nidx[name] = 0
          worker1 = {
              "vm": vm_groups[name][nidx[name] % len(vm_groups[name])],
              "labels": cluster1["labels"],
          }
          worker1["labels"]["VM_GROUP_" + name.upper()] = "required"
          internal_ip = worker1["vm"].internal_ip
          try:
            worker1["name"] = nodes[internal_ip]
          except Exception:
            worker1["name"] = internal_ip
          nidx[name] = nidx[name] + 1
          workers.append(worker1)
      if "vm" in doc:
        for vim1 in doc["vm"]:
          for vm10 in vm_groups[vim1["name"]]:
            vimages.append({
                "name": vim1["name"],
                "vm": vm10,
                "env": vim1["env"],
            })
            if "setup" in vim1:
              vimages[-1]["setup"] = vim1["setup"]
            options.extend(["-e", "{}={}".format(vim1["env"], vm10.internal_ip)])
      if "kubernetes" in doc:
        dock8s = doc["kubernetes"]
        if "cni" in dock8s:
          FLAGS.k8s_cni = dock8s["cni"]
        if "cni-options" in dock8s:
          FLAGS.k8s_cni_options = dock8s["cni-options"]
        if "kubevirt" in dock8s:
          FLAGS.k8s_kubevirt = dock8s["kubevirt"]
        if "kubelet-options" in dock8s:
          option = "--config=" + _WriteKubeletConfigFile(dock8s["kubelet-options"])
          if option not in FLAGS.k8s_kubeadm_options:
            FLAGS.k8s_kubeadm_options.append(option)

  return workers, vimages, options


def _AddNodeAffinity(spec, workers):
  if "affinity" not in spec:
    spec["affinity"] = {}

  if "nodeAffinity" not in spec["affinity"]:
    spec["affinity"]["nodeAffinity"] = {}

  if "requiredDuringSchedulingIgnoredDuringExecution" not in spec["affinity"]["nodeAffinity"]:
    spec["affinity"]["nodeAffinity"]["requiredDuringSchedulingIgnoredDuringExecution"] = {}

  if "nodeSelectorTerms" not in spec["affinity"]["nodeAffinity"]["requiredDuringSchedulingIgnoredDuringExecution"]:
    spec["affinity"]["nodeAffinity"]["requiredDuringSchedulingIgnoredDuringExecution"]["nodeSelectorTerms"] = []

  spec["affinity"]["nodeAffinity"]["requiredDuringSchedulingIgnoredDuringExecution"]["nodeSelectorTerms"].append({
      "matchExpressions": [{
          "key": "kubernetes.io/hostname",
          "operator": "In",
          "values": [x["name"] for x in workers],
      }],
  })


def _ModifyImageRef(spec, images, ifcloud):
  for c1 in spec:
    if c1["image"] in images:
      c1["image"] = FLAGS.dpt_registry_map[1] + images[c1["image"]][0]
      if ifcloud:
        c1["imagePullPolicy"] = "IfNotPresent"


def _ScanImages(docs):
  images = {}
  for doc in docs:
    for c1 in ["containers", "initContainers"]:
      spec = _WalkTo(doc, c1)
      if spec and spec[c1]:
        for c2 in spec[c1]:
          if "image" in c2:
            images[c2["image"]] = 1

  registry_url = FLAGS.dpt_registry_map[0] if FLAGS.dpt_registry_map else ""
  priv_images = {}
  for image in images:
    attr = skopeo.InspectImage(image, registry_url)
    if attr:
      priv_images[image] = attr
  return priv_images


def _ModifyEnvs(spec, vimages, workers):
  if vimages:
    for c1 in spec:
      if "env" not in c1:
        c1["env"] = []
      elif not c1["env"]:
        c1["env"] = []
      for vm1 in vimages:
        c1["env"].append({
            "name": vm1["env"],
            "value": vm1["vm"].internal_ip,
        })
  for c1 in spec:
    if "env" in c1:
      if isinstance(c1["env"], list):
        for e1 in c1["env"]:
          if "name" in e1 and "value" in e1:
            if e1["name"] == "CLUSTER_WORKERS" and e1["value"] == "":
              e1["value"] = ",".join([w["name"] for w in workers])


def _PullImages(vm, images):
  registry_url = FLAGS.dpt_registry_map[0] if FLAGS.dpt_registry_map else ""
  priv_images = {}
  for image in images:
    attr = skopeo.InspectImage(image, registry_url)
    if attr:
      priv_images[image] = attr
  if priv_images:
    priv_images_remaining = archived_images.CopyImagesToDocker(vm, priv_images) if archived_images else priv_images
    if priv_images_remaining:
      skopeo.CopyImagesToDocker(vm, priv_images_remaining)


def _UpdateK8sConfig(controller0, workers, vimages):
  with open(FLAGS.dpt_kubernetes_yaml, "rt") as fd:
    docs = [d for d in safe_load_all(fd) if d]

  images = _ScanImages(docs)
  if controller0.CLOUD != "Static" or FLAGS.install_packages:
    nworkers = len(_UniqueVms(workers))
    worker1 = workers[0]["vm"]
    if nworkers == 1 and docker_ce.IsDocker(worker1):
      images_remaining = archived_images.CopyImagesToDocker(worker1, images) if archived_images else images
      if images_remaining:
        skopeo.CopyImagesToDocker(worker1, images_remaining)
    elif not skopeo.IsSUTAccessible(FLAGS.dpt_registry_map[0]):
      vms = _UniqueVms(workers, controller0)
      registry_url = k8s.CreateRegistry(controller0, vms)
      images_remaining = archived_images.CopyImagesToRegistry(controller0 if nworkers > 1 else worker1, images, registry_url, nworkers > 1) if archived_images else images
      if images_remaining:
        skopeo.CopyImagesToRegistry(controller0, images_remaining, registry_url)
      FLAGS.dpt_registry_map[1] = f"{registry_url}/"
      logging.info(f"SUT/Info: registry {FLAGS.dpt_registry_map[1]}")

  modified_docs = []
  for doc in docs:
    modified_docs.append(doc)

    spec = _WalkTo(doc, "containers")
    if spec and spec["containers"]:
      _AddNodeAffinity(spec, workers)
      _ModifyImageRef(spec["containers"], images, controller0.CLOUD != "Static" or FLAGS.dpt_reuse_sut or FLAGS.install_packages)
      _ModifyEnvs(spec["containers"], vimages, workers)

    spec = _WalkTo(doc, "initContainers")
    if spec and spec["initContainers"]:
      _ModifyImageRef(spec["initContainers"], images, controller0.CLOUD != "Static" or FLAGS.dpt_reuse_sut or FLAGS.install_packages)
      _ModifyEnvs(spec["initContainers"], vimages, workers)

  modified_filename = FLAGS.dpt_kubernetes_yaml + ".mod.yaml"
  with open(modified_filename, "wt") as fd:
    dump_all(modified_docs, fd)

  return modified_filename, images


def _ParseParams(params, metadata):
  for kv in params.split(";"):
    k, p, v = kv.partition(":")
    try:
      v = float(v.strip())
    except Exception:
      pass
    metadata[k.strip()] = v


@vm_util.Retry()
def _AddNodeLabels(controller0, workers, vm):
  node = None
  labels = {}
  for worker in workers:
    if worker["vm"] == vm:
      for k in worker["labels"]:
        if worker["labels"][k] == "required":
          labels[k] = "yes"
          node = worker["name"]
  if labels and node:
    cmd = ["kubectl", "label", "--overwrite", "node", node] + [k + "=" + labels[k] for k in labels]
    controller0.RemoteCommand(" ".join(cmd))


def _GetController(vm_groups):
  if SUT_VM_CTR in vm_groups:
    return vm_groups[SUT_VM_CTR][0]
  return vm_groups[FLAGS.dpt_vm_groups[0]][-1]


def _GetWorkers(vm_groups):
  workers = []
  for g1 in vm_groups:
    if (g1 != SUT_VM_CTR) and (g1 in FLAGS.dpt_vm_groups):
      for vm1 in vm_groups[g1]:
        if vm1 not in workers:
          workers.append(vm1)
  return workers


def _SetupHugePages(workers, vm):
  reqs = {}
  for worker in workers:
    if worker["vm"] == vm:
      for k in worker["labels"]:
        if k.startswith("HAS-SETUP-HUGEPAGE-") and worker["labels"][k] == "required":
          req = k.split("-")[-2:]
          if req[0] not in reqs:
            reqs[req[0]] = 0
          if int(req[1]) > reqs[req[0]]:
            reqs[req[0]] = int(req[1])

  cmds = ["hugepagesz={} hugepages={}".format(sz.replace("B",""), reqs[sz]) for sz in reqs]
  if cmds:
    vm.AppendKernelCommandLine(" ".join(cmds), reboot=False)
    vm._needs_reboot = True


def _ProbeModules(workers, vm):
  modules = []
  for worker in workers:
    if worker["vm"] == vm:
      for k in worker["labels"]:
        if k.startswith("HAS-SETUP-MODULE-") and worker["labels"][k] == "required":
          modules.append(k.replace("HAS-SETUP-MODULE-", "").lower())
  if modules:
    cmd = ["sudo", "modprobe"] + modules
    vm.RemoteCommand(" ".join(cmd), ignore_failure=True, suppress_warning=True)


# We use Habana Gaudi AMI. Assume the driver is already installed. 
# Just need to refresh docker or containerd configurations after 
# a new installation (k8s).
def _SetupHabanaWorker(controller0, workers, vm):
  for worker in workers:
    if worker["vm"] == vm:
      for k in worker["labels"]:
        if k.startswith("HAS-SETUP-HABANA-") and worker["labels"][k] == "required":
          vm.Install("habana")
          if controller0:
            habana.RegisterWithContainerD(vm)
          else:
            habana.RegisterWithDocker(vm)
          return


# Use aws inferentia for ai workload, need to install neuron runtime driver in vm firstly.
def _SetupInferentiaWorker(controller0, workers, vm):
  for worker in workers:
    if worker["vm"] == vm:
      for k in worker["labels"]:
        if k.startswith("HAS-SETUP-INFERENTIA-") and worker["labels"][k] == "required":
          vm.Install("inferentia")
          return


# Use aws nvidia for ai workload, need to install cuda driver in vm firstly.
def _SetupGPUWorker(controller0, workers, vm):
  for worker in workers:
    if worker["vm"] == vm:
      for k in worker["labels"]:
        if k.startswith("HAS-SETUP-NVIDIA-") and worker["labels"][k] == "required":
          vm.Install("nvidia_gpu")
          return


def _SetupHabanaController(controller0, workers):
  for worker in workers:
    for k in worker["labels"]:
      if k.startswith("HAS-SETUP-HABANA-") and worker["labels"][k] == "required":
        habana.RegisterKubernetesPlugins(controller0)
        return


def _SetupWorker(controller0, workers, vm):
  for worker in workers:
    if worker["vm"] == vm:
      for k in worker["labels"]:
        if k.startswith("HAS-SETUP-") and worker["labels"][k] == "required":
          pass


def _UniqueVms(workers, controller0=None):
  vms = []
  for worker in workers:
    if worker["vm"] != controller0 and worker["vm"] not in vms:
      vms.append(worker["vm"])
  return vms


def _PrepareWorker(controller0, workers, vm):
  _SetupHugePages(workers, vm)
  _ProbeModules(workers, vm)
  _SetupHabanaWorker(controller0, workers, vm)
  _SetupInferentiaWorker(controller0, workers, vm)
  _SetupGPUWorker(controller0, workers, vm)
  if controller0:
    _AddNodeLabels(controller0, workers, vm)
  vm._RebootIfNecessary()


def _PrepareVM(vimage):
  if "setup" in vimage:
    setup = vimage["setup"]
    vm1 = vimage["vm"]

    while True:
      try:
        vm1.RemoteCommand("sudo mkdir -p /opt/pkb/vmsetup && sudo chown -R {} /opt/pkb".format(vm1.user_name))
        vm1.PushFile("{}/{}.tgz".format(FLAGS.dpt_logs_dir, setup), "/opt/pkb")
        vm1.RemoteCommand("cd /opt/pkb/vmsetup && sudo tar xfz ../{}.tgz && sudo ./setup.sh {}".format(setup, " ".join(FLAGS.dpt_script_args)))
        break
      except Exception as e:
        logging.warning("VM Setup Exception: %s", str(e))
      vm1.RemoteCommand("sleep 10s", ignore_failure=True)
      vm1.WaitForBootCompletion()


def _SaveConfigFiles(spec):
  spec.s3_reports.append((FLAGS.dpt_cluster_yaml, 'text/yaml'))
  cumulus_config_file = join(FLAGS.dpt_logs_dir, "cumulus-config.yaml")
  spec.s3_reports.append((cumulus_config_file, 'text/yaml'))

  if FLAGS.dpt_kubernetes_yaml:
    spec.s3_reports.append((FLAGS.dpt_kubernetes_yaml, 'text/yaml'))

  test_config_file = join(FLAGS.dpt_logs_dir, "test-config.yaml")
  if os.path.exists(test_config_file):
    spec.s3_reports.append((test_config_file, 'text/yaml'))


def Prepare(benchmark_spec):
  _SetBreakPoint("PrepareStage")

  benchmark_spec.name = FLAGS.dpt_name.replace(" ", "_").lower()
  benchmark_spec.workload_name = FLAGS.dpt_name
  benchmark_spec.sut_vm_group = FLAGS.dpt_vm_groups[0]
  benchmark_spec.always_call_cleanup = True

  benchmark_spec.control_traces = True
  FLAGS.dpt_trace_mode = [x.strip() for x in FLAGS.dpt_trace_mode]

  _SaveConfigFiles(benchmark_spec)
  _ParseParams(FLAGS.dpt_params, benchmark_spec.software_config_metadata)
  _ParseParams(FLAGS.dpt_tunables, benchmark_spec.tunable_parameters_metadata)

  # export SUT Instrumentation
  for group1 in benchmark_spec.vm_groups:
    for worker1 in benchmark_spec.vm_groups[group1]:
      logging.info(f"SUT/Info: {group1} {worker1.ip_address} {worker1.internal_ip} {worker1.OS_TYPE}")

  if FLAGS.dpt_docker_image:
    controller0 = _GetWorkers(benchmark_spec.vm_groups)[0]
    tmp_dir = _MakeTempDir(controller0)
    if controller0.CLOUD != "Static" or FLAGS.install_packages:
      controller0.Install('docker_ce')
      docker_auth.CopyDockerConfig(controller0)
      _PullImages(controller0, [FLAGS.dpt_docker_image] + FLAGS.dpt_docker_dataset)

    workers, vimages, options = _ParseClusterConfigs(benchmark_spec.vm_groups)
    FLAGS.dpt_docker_options = " ".join(FLAGS.dpt_docker_options.split(" ") + options)
    _PrepareWorker(None, workers, controller0)
    if controller0.CLOUD != "Static" or FLAGS.install_packages:
      _SetBreakPoint("SetupVM")
      vm_util.RunThreaded(lambda vim1: _PrepareVM(vim1), vimages)

  if FLAGS.dpt_kubernetes_yaml:
    controller0 = _GetController(benchmark_spec.vm_groups)
    tmp_dir = _MakeTempDir(controller0)

    if controller0.CLOUD != "Static" or FLAGS.install_packages:
      _ParseClusterConfigs(benchmark_spec.vm_groups)
      workers = [vm1 for vm1 in _GetWorkers(benchmark_spec.vm_groups) if vm1 != controller0]
      taint = SUT_VM_CTR in benchmark_spec.vm_groups
      k8s.CreateCluster(controller0, workers, taint)
      docker_auth.CopyDockerConfig(controller0)

    nodes = _GetNodes(controller0)
    workers, vimages, _ = _ParseClusterConfigs(benchmark_spec.vm_groups, nodes)
    k8s_config_yaml, images = _UpdateK8sConfig(controller0, workers, vimages)

    if controller0.CLOUD != "Static" or FLAGS.install_packages:
      vm_util.RunThreaded(lambda vm1: _PrepareWorker(controller0, workers, vm1), _UniqueVms(workers))
      _SetupHabanaController(controller0, workers)
      _SetBreakPoint("SetupVM")
      vm_util.RunThreaded(lambda vim1: _PrepareVM(vim1), vimages)

    remote_yaml_file = join(tmp_dir, KUBERNETES_CONFIG)
    controller0.PushFile(k8s_config_yaml, remote_yaml_file)

  kpish = f"{FLAGS.dpt_logs_dir}/{KPISH}"
  for i in range(1, FLAGS.run_stage_iterations + 1):
    local_logs_dir = join(FLAGS.dpt_logs_dir, ITERATION_DIR.format(i))
    vm_util.IssueCommand(["mkdir", "-p", local_logs_dir])
    vm_util.IssueCommand(["cp", "-f", kpish, local_logs_dir])

  with open(kpish) as fd:
    test_string = f"cd {ITERATION_DIR.format(1)}"
    if test_string not in fd.read():
      vm_util.IssueCommand(["sh", "-c", "sed -i '1a[ -d {} ] && cd {}' {}".
                           format(ITERATION_DIR.format(1), ITERATION_DIR.format(1), kpish)])


def _PullExtractLogs(controller0, pods, remote_logs_dir):
  estr = None
  for pod1 in pods:
    remote_logs_tarfile = join(remote_logs_dir, LOGS_TARFILE.format(pod1))
    local_logs_dir = join(FLAGS.dpt_logs_dir, join(ITERATION_DIR.format(run_seq), f"{pod1}"))
    local_logs_tarfile = join(local_logs_dir, LOGS_TARFILE.format(pod1))
    try:
      vm_util.IssueCommand(["mkdir", "-p", local_logs_dir])
      controller0.PullFile(local_logs_tarfile, remote_logs_tarfile)
      vm_util.IssueCommand(["tar", "xf", local_logs_tarfile, "-C", local_logs_dir])
      vm_util.IssueCommand(["rm", "-f", local_logs_tarfile])
    except Exception as e:
      estr = str(e)
  if estr:
    raise Exception("ExtractLogs Exception: " + estr)


def _TraceByTime(benchmark_spec, controller0):
  controller0.RemoteCommand(f"sleep {FLAGS.dpt_trace_mode[1]}s", ignore_failure=True)
  events.start_trace.send(stages.RUN, benchmark_spec=benchmark_spec)
  controller0.RemoteCommand(f"sleep {FLAGS.dpt_trace_mode[2]}s", ignore_failure=True)
  events.stop_trace.send(stages.RUN, benchmark_spec=benchmark_spec)


def _TraceByROI(benchmark_spec, controller0, timeout, cmds):
  _, _, status = controller0.RemoteCommandWithReturnCode("timeout {}s bash -c 'while true; do ({}) | grep -q -F \"{}\" && exit 0 || sleep 1s; done'".format(timeout, cmds, FLAGS.dpt_trace_mode[1]), ignore_failure=True)
  if status == 0:
    events.start_trace.send(stages.RUN, benchmark_spec=benchmark_spec)
    controller0.RemoteCommand("timeout {}s bash -c 'while true; do ({}) | grep -q -F \"{}\" && exit 0 || sleep 1s; done'".format(timeout, cmds, FLAGS.dpt_trace_mode[2]), ignore_failure=True)
    events.stop_trace.send(stages.RUN, benchmark_spec=benchmark_spec)


@vm_util.Retry()
def _RobustGetLogs(vm, pod1, container, remote_logs_tarfile):
   # copy with tarball validity check
   vm.RemoteCommand(f"kubectl exec --namespace={FLAGS.dpt_namespace} -c {container} {pod1} -- sh -c \"cat {EXPORT_LOGS_TARFILE}\" > {remote_logs_tarfile} && tar xf {remote_logs_tarfile} -O > /dev/null")


def Run(benchmark_spec):
  global run_seq
  run_seq = run_seq + 1

  _SetBreakPoint("RunStage")

  for vm in benchmark_spec.vms:
    thread_count = vm.num_cpus
    logging.debug(f"VM thread count: {thread_count}")

  tmp_dir = _GetTempDir()
  timeout = list(map(int,FLAGS.dpt_timeout.split(",")))
  if len(timeout)<2:
    timeout.append(timeout[0])
  if len(timeout)<3:
    timeout.append(timeout[0]/2)

  pull_logs = False
  if FLAGS.dpt_docker_image:
    controller0 = _GetWorkers(benchmark_spec.vm_groups)[0]

    options = FLAGS.dpt_docker_options.split(' ')
    if controller0.CLOUD == "Static" and not FLAGS.dpt_reuse_sut and not FLAGS.install_packages and FLAGS.dpt_registry_map[0]:
      options.extend(["--pull", "always"])

    containers = []
    options1 = "--pull always" if controller0.CLOUD == "Static" and not FLAGS.install_packages and FLAGS.dpt_registry_map[0] else ""
    for image1 in FLAGS.dpt_docker_dataset:
      stdout, _ = controller0.RemoteCommand("sudo -E docker create {} {} -".format(options1, _ReplaceImage(image1)))
      container_id = stdout.strip()
      containers.append(container_id)
      options.extend(["--volumes-from", container_id])

    _SetBreakPoint("ScheduleExec")
    container_id, pid = runwith.DockerRun(controller0, options, _ReplaceImage(FLAGS.dpt_docker_image))

    if events.start_trace.receivers:
      try:
        if not FLAGS.dpt_trace_mode:
          events.start_trace.send(stages.RUN, benchmark_spec=benchmark_spec)

        elif FLAGS.dpt_trace_mode[0] == "roi":
          _TraceByROI(benchmark_spec, controller0, timeout[2],
                      runwith.DockerLogsCmd(container_id))

        elif FLAGS.dpt_trace_mode[0] == "time":
          _TraceByTime(benchmark_spec, controller0)
      except Exception as e:
        logging.warning("Trace Exception: %s", str(e))
        _SetBreakPoint("TraceFailed")

    pods = [container_id]
    try:
      _SetBreakPoint("ExtractLogs")
      runwith.DockerWaitForCompletion(controller0, container_id, timeout[0], join(tmp_dir, LOGS_TARFILE.format(container_id)))
      pull_logs = True
    except Exception as e:
      logging.fatal("ExtractLogs Exception: %s", str(e))
      _SetBreakPoint("ExtractLogsFailed")

    if events.start_trace.receivers and (not FLAGS.dpt_trace_mode):
      try:
        events.stop_trace.send(stages.RUN, benchmark_spec=benchmark_spec)
      except:
        pass

    controller0.RemoteCommand(runwith.DockerLogsCmd(container_id), 
                              ignore_failure=True, should_log=True)
    runwith.DockerRemove(controller0, containers, container_id, pid)

  if FLAGS.dpt_kubernetes_yaml:
    controller0 = _GetController(benchmark_spec.vm_groups)
    remote_yaml_file = join(tmp_dir, KUBERNETES_CONFIG)

    _SetBreakPoint("ScheduleExec")
    controller0.RemoteCommand(f"kubectl create namespace {FLAGS.dpt_namespace}")
    controller0.RemoteCommand(f"kubectl label namespace {FLAGS.dpt_namespace} {SF_NS_LABEL}")
    docker_auth.InstallImagePullSecret(controller0, FLAGS.dpt_namespace)
    try:
      controller0.RemoteCommand(f"kubectl create --namespace={FLAGS.dpt_namespace} -f {remote_yaml_file}")
  
      try:
        controller0.RemoteCommand("timeout {1}s bash -c 'q=0;until kubectl --namespace={0} wait pod --all --for=condition=Ready --timeout=1s 1>/dev/null 2>&1; do if kubectl --namespace={0} get pod -o json | grep -q Unschedulable; then q=1; break; fi; done; exit $q'".format(FLAGS.dpt_namespace, timeout[1]))
  
        pods, _ = controller0.RemoteCommand("kubectl get --namespace=" + FLAGS.dpt_namespace + " pod --selector=" + FLAGS.dpt_kubernetes_job + " '-o=jsonpath={.items[*].metadata.name}'")
        pods = pods.strip(" \t\n").split(" ")
        container = FLAGS.dpt_kubernetes_job.rpartition("=")[2]
  
        if events.start_trace.receivers:
          try:
            if not FLAGS.dpt_trace_mode:
              events.start_trace.send(stages.RUN, benchmark_spec=benchmark_spec)
  
            elif FLAGS.dpt_trace_mode[0] == "roi":
              cmds = []
              for pod1 in pods:
                cmds.append(f"kubectl logs --ignore-errors --prefix=false {pod1} -c {container} --namespace={FLAGS.dpt_namespace}")
              _TraceByROI(benchmark_spec, controller0, timeout[2], ";".join(cmds))
  
            elif FLAGS.dpt_trace_mode[0] == "time":
              _TraceByTime(benchmark_spec, controller0)
          except Exception as e:
            logging.warning("Trace Exception: %s", str(e))
            _SetBreakPoint("TraceFailed")
  
        cmds = []
        for pod1 in pods:
          cmds.append(f"kubectl exec --namespace={FLAGS.dpt_namespace} {pod1} -c {container} -- sh -c \"cat /export-logs > {EXPORT_LOGS_TARFILE}\";x=$?;test $x -ne 0 && r=$x")
  
        try:
          _SetBreakPoint("ExtractLogs")
          controller0.RemoteCommand("timeout {}s bash -c 'r=0;{};exit $r'".format(timeout[0], ";".join(cmds)))

          for pod1 in pods:
            remote_logs_tarfile = join(tmp_dir, LOGS_TARFILE.format(pod1))
            _RobustGetLogs(controller0, pod1, container, remote_logs_tarfile)

          pull_logs = True
        except Exception as e:
          logging.fatal("ExtractLogs Exception: %s", str(e))
          _SetBreakPoint("ExtractLogsFailed")
  
        if events.start_trace.receivers and (not FLAGS.dpt_trace_mode):
          try:
            events.stop_trace.send(stages.RUN, benchmark_spec=benchmark_spec)
          except:
            pass
  
      except Exception as e:
        logging.fatal("Schedule Exception: %s", str(e))
        _SetBreakPoint("ScheduleExecFailed")
  
      controller0.RemoteCommand(f"kubectl describe node --namespace={FLAGS.dpt_namespace}", ignore_failure=True, should_log=True)
      controller0.RemoteCommand(f"kubectl describe pod --namespace={FLAGS.dpt_namespace}", ignore_failure=True, should_log=True)
      controller0.RemoteCommand("bash -c 'for p in $(kubectl get pod -n {0} --no-headers -o custom-columns=:metadata.name);do echo \"pod $p:\";kubectl -n {0} logs --all-containers=true $p;done'".format(FLAGS.dpt_namespace), ignore_failure=True, should_log=True)

    except Exception as e:
      logging.fatal("Failed to deploy test: %s", str(e))
      _SetBreakPoint("ScheduleExecFailed")

    if (controller0.CLOUD == "Static" and not FLAGS.install_packages) or (run_seq < FLAGS.run_stage_iterations):
      controller0.RemoteCommand(f"kubectl delete --namespace={FLAGS.dpt_namespace} -f {remote_yaml_file} --ignore-not-found=true", ignore_failure=True)
      try:
        controller0.RemoteCommand(f"timeout 120s kubectl delete namespace {FLAGS.dpt_namespace} --timeout=0 --wait --ignore-not-found=true")
      except:
        # force namespace removal
        controller0.RemoteCommand("bash -c 'kubectl replace --raw \"/api/v1/namespaces/{0}/finalize\" -f <(kubectl get ns {0} -o json | grep -v \"\\\"kubernetes\\\"\")'".format(FLAGS.dpt_namespace), ignore_failure=True)

        nodes = _GetNodes(controller0)
        workers, _, _ = _ParseClusterConfigs(benchmark_spec.vm_groups, nodes)
        vm_util.RunThreaded(lambda vm1: vm1.Reboot(), _UniqueVms(workers))
        controller0.RemoteCommand("kubectl wait --for=condition=Ready nodes --all")

  _SetBreakPoint("ExtractKPI")

  # pull the logs tarfile back
  samples = []
  if pull_logs:
    _PullExtractLogs(controller0, pods, tmp_dir)
    samples = _ParseKPI(benchmark_spec.tunable_parameters_metadata)

  if not samples:
    _SetBreakPoint("ExtractKPIFailed")
    raise Exception("KPI Exception: No KPI data")

  return samples


def Cleanup(benchmark_spec):
  _SetBreakPoint("CleanupStage")
  tmp_dir = _GetTempDir()

  _, vimages, _ = _ParseClusterConfigs(benchmark_spec.vm_groups)
  for i, vim1 in enumerate(vimages):
    if "setup" in vim1:
      local_dir = "{}/{}/{}".format(FLAGS.dpt_logs_dir, vim1["name"], i)
      vm_util.IssueCommand(["mkdir", "-p", local_dir])
      try:
        vm1 = vim1["vm"]
        vm1.RemoteCommand("cd /opt/pkb/vmsetup && sudo ./cleanup.sh {}".format(" ".join(FLAGS.dpt_script_args)))
        vm1.PullFile("{}/vmlogs.tgz".format(local_dir), "/opt/pkb/vmsetup/vmlogs.tgz")
      except Exception as e:
        logging.warning("Cleanup Exception: %s", str(e))

  if FLAGS.dpt_docker_image:
    controller0 = _GetWorkers(benchmark_spec.vm_groups)[0]

  if FLAGS.dpt_kubernetes_yaml:
    controller0 = _GetController(benchmark_spec.vm_groups)

  # cleanup containers
  if controller0.CLOUD == "Static" and not FLAGS.install_packages:
    controller0.RemoteCommand(f"sudo rm -rf '{tmp_dir}'", ignore_failure=True)


def GetCmdLine():
  tcase = FLAGS.dpt_tunables[FLAGS.dpt_tunables.index(";testcase:")+10:]
  tconfig = "TEST_CONFIG=$(pwd)/test-config.yaml " if os.path.exists("test-config.yaml") else ""
  return f"{tconfig}ctest -R '^{tcase}$' -V"

