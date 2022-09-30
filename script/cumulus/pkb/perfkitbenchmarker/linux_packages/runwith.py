
from perfkitbenchmarker import vm_util
from perfkitbenchmarker.linux_packages import INSTALL_DIR
from absl import flags
import posixpath
import json

FLAGS = flags.FLAGS
flags.DEFINE_boolean("run_with_vm", False,
                     "Whether to run with VM or docker")


def DockerRun(vm, options, image):
  if FLAGS.run_with_vm:
    stdout, _ = vm.RemoteCommand("sudo -E docker create {options} {image}".format(options=" ".join(options), image=image))
    container = stdout.strip()

    stdout, _ = vm.RemoteCommand(f"sudo -E docker container inspect {container}" + " -f '{{json .}}'")
    inspect = json.loads(stdout)

    root_dir = posixpath.join(INSTALL_DIR, container)
    vm.RemoteCommand(f"mkdir -p {root_dir}")
    vm.RemoteCommand(f"sudo -E docker container export {container} | sudo tar xf - -C {root_dir}")
    for mount1 in inspect["Mounts"]:
      mount_path = posixpath.join(root_dir, mount1["Destination"][1:])
      vm.RemoteCommand(f"sudo mkdir -p {mount_path}")
      vm.RemoteCommand("sudo mount --bind {src} {dst}".format(src=mount1["Source"], dst=mount_path))
 
    mount_path = posixpath.join(root_dir, "proc")
    vm.RemoteCommand(f"sudo mount -t proc /proc {mount_path}")
    for mount1 in ["sys", "dev"]:
      mount_path = posixpath.join(root_dir, mount1)
      vm.RemoteCommand(f"sudo mount --rbind /{mount1} {mount_path}")
      vm.RemoteCommand(f"sudo mount --make-rslave {mount_path}")
  
    cmds = []
    for cmd1 in inspect["Config"]["Cmd"]:
      if " " in cmd1:
        cmds.append("'{}'".format(cmd1.replace("'", "'\\''")))
      else:
        cmds.append(cmd1)

    working_dir = inspect["Config"]["WorkingDir"] if inspect["Config"]["WorkingDir"] else "/"
    logfile = posixpath.join(root_dir, ".logs")
    user = inspect["Config"]["User"] if inspect["Config"]["User"] else "root"
    stdout, _ = vm.RemoteCommand("sudo chroot --userspec={userspec} {root_dir} bash -c 'cd {dir};{envs} {cmd}' > {logfile} 2>&1 & echo $!".format(envs=" ".join(inspect["Config"]["Env"]), root_dir=root_dir, cmd=" ".join(cmds).replace("'", "'\\''"), dir=working_dir, logfile=logfile, userspec=user))
    pid = stdout.strip()
    return (container, pid)

  stdout, _ = vm.RemoteCommand("sudo -E docker run --rm -d {options} {image}".format(options=" ".join(options), image=image))
  container = stdout.strip()

  # set perf cgroup
  FLAGS.perf_options = FLAGS.perf_options.replace("%container%", f"docker/{container}")

  return (container, None)


def DockerWaitForCompletion(vm, container, timeout, logs_file):
  if FLAGS.run_with_vm:
    root_dir = posixpath.join(INSTALL_DIR, container)
    export_logs = posixpath.join(root_dir, "export-logs")
    vm.RemoteCommand(f"timeout {timeout}s cat {export_logs} > {logs_file}")
  else:
    vm.RemoteCommand(f"timeout {timeout}s sudo -E docker exec {container} cat /export-logs > {logs_file}")


def DockerLogsCmd(container, flags=""):
  if FLAGS.run_with_vm:
    root_dir = posixpath.join(INSTALL_DIR, container)
    log_file = posixpath.join(root_dir, ".logs")
    return f"sudo tail {flags} {log_file}"

  return f"sudo -E docker logs {flags} {container}"
  

def DockerRemove(vm, containers, container_id, pid):
  if FLAGS.run_with_vm:
    vm.RemoteCommand(f"sudo kill -9 {pid}", ignore_failure=True)

    stdout, _ = vm.RemoteCommand(f"sudo -E docker container inspect {container_id}" + " -f '{{json .}}'")
    inspect = json.loads(stdout)

    root_dir = posixpath.join(INSTALL_DIR, container_id)
    stdout, _ = vm.RemoteCommand(f"sudo mount | cut -f3 -d' ' | sort")
    last_umounted = "na"
    for mount_path in stdout.split("\n"):
      if mount_path.startswith(root_dir + '/') and not mount_path.startswith(last_umounted):
        vm.RemoteCommand(f"sudo umount -R {mount_path}", ignore_failure=True)
        last_umounted = mount_path
      
    vm.RemoteCommand(f"sudo rm -rf {root_dir}")
    
  vm.RemoteCommand("sudo -E docker rm -v -f {}".format(" ".join(containers + [container_id])), ignore_failure = True)

