from absl import flags
import posixpath
import tempfile
import logging
import json
import os

FLAGS = flags.FLAGS
flags.DEFINE_boolean('docker_auth_reuse', False, 'SUT reuses the same docker auth info.')
flags.DEFINE_string('docker_auth_local_path', '~/.docker/config.json', 'The docker config file local path')
flags.DEFINE_string('docker_auth_remote_path', '.docker/config.json', 'The docker config file remote path')

SECRET_NAME = "my-registry-secret"

def CopyDockerConfig(vm):
  if FLAGS.docker_auth_reuse:
    try:
      with open(os.path.expanduser(FLAGS.docker_auth_local_path),'r') as fdr:
        auths = json.load(fdr)["auths"]
    except Exception as e:
      logging.warning("Exception: %s", str(e))
      return

    if auths:
      handle, local_path = tempfile.mkstemp()
      with os.fdopen(handle, "w") as fdw:
        fdw.write(json.dumps({"auths": auths}) + "\n")
      remote_path = f"/home/{vm.user_name}/{FLAGS.docker_auth_remote_path}"
      vm.RemoteCommand("mkdir -p {}".format(posixpath.dirname(remote_path)))
      vm.PushFile(local_path, remote_path)
      os.unlink(local_path)


def InstallImagePullSecret(vm, namespace):
  if FLAGS.docker_auth_reuse:
    remote_path = f"/home/{vm.user_name}/{FLAGS.docker_auth_remote_path}"
    vm.RemoteCommand(f"kubectl create secret docker-registry {SECRET_NAME} --from-file=.dockerconfigjson={remote_path} -n {namespace}", ignore_failure=True)
    vm.RemoteCommand(f"kubectl patch serviceaccount default -p '{{\"imagePullSecrets\": [{{\"name\": \"{SECRET_NAME}\"}}]}}' -n {namespace}", ignore_failure=True)
