
from perfkitbenchmarker import vm_util
#from perfkitbenchmarker.linux_packages import k8s
from absl import flags

FLAGS = flags.FLAGS
flags.DEFINE_list("skopeo_insecure_registries", [], 
                  "Specify the skopeo command line options")
flags.DEFINE_list("skopeo_sut_accessible_registries", [], 
                  "Specify the list of registries that the SUT has access.")
flags.DEFINE_string("skopeo_src_cert_dir", None,
                  "Specify the source certs directory")


def IsSUTAccessible(registry_url):
  return registry_url in FLAGS.skopeo_sut_accessible_registries


def InspectImage(image, registry_url):
  if registry_url:
    if image.startswith(registry_url) and not IsSUTAccessible(registry_url):
      options = []
      if FLAGS.skopeo_src_cert_dir:
        options.append(f"--src-cert-dir={FLAGS.skopeo_src_cert_dir}")
      for r1 in FLAGS.skopeo_insecure_registries:
        r2 = r1 if r1.endswith("/") else r1 + "/"
        if image.startswith(r2):
          options.append("--src-tls-verify=false")
          break
      basename = image[len(registry_url):]
      return (basename, options + [f"docker://{image}"])
    return None

  try:
    vm_util.IssueCommand(["skopeo", "inspect", f"docker-daemon:{image}"])
    return (image, [f"docker-daemon:{image}"])
  except:
    pass
  return None


@vm_util.Retry()
def _RobustSkopeoCopy(cmd):
  vm_util.IssueCommand(["sudo", "-E", "skopeo", "copy"] + cmd, timeout=None)


def CopyImagesToDocker(vm, images, port=12222):
  daemon_url = f"localhost:{port}"
  vm.RemoteCommand("", ssh_args = ["-fNL", f"{daemon_url}:/var/run/docker.sock"])
  for image1 in images:
    _RobustSkopeoCopy([f"--dest-daemon-host=http://{daemon_url}"] + images[image1][1] + [f"docker-daemon:{image1}"])

  # cancel forwaring
  vm.RemoteCommand("", ssh_args = ["-O", "exit"])


def CopyImagesToRegistry(vm, images, registry_url, port=16666):
  local_registry_url = f"localhost:{port}"
  vm.RemoteCommand("", ssh_args = ["-fNL", f"{local_registry_url}:{registry_url}"])
  
  #certs_dir = vm_util.PrependTempDir(k8s.REGISTRY_CERTS_DIR)
  for image1 in images:
    local_image=f"{local_registry_url}/{images[image1][0]}"
    #_RobustSkopeoCopy([f"--dest-cert-dir={certs_dir}", "--dest-tls-verify=false"] + images[image1][1] + [f"docker://{local_image}"])
    _RobustSkopeoCopy(["--dest-tls-verify=false"] + images[image1][1] + [f"docker://{local_image}"])

  # cancel forwaring
  vm.RemoteCommand("", ssh_args = ["-O", "exit"])

