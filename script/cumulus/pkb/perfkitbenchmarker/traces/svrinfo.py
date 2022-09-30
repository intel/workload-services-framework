"""Records system information using svrinfo.
"""

import os
import logging
import posixpath

from six.moves.urllib.parse import urlparse

from perfkitbenchmarker import events, stages
from perfkitbenchmarker import trace_util
from absl import flags
from perfkitbenchmarker import vm_util

SVRINFO_BINARY_NAME = "svr-info"
SVRINFO_DIRECTORY_NAME = "svr-info"
SVRINFO_ARCHIVE_URL_S3_BUCKET = "https://cumulus.s3.us-east-2.amazonaws.com/svr_info/"

flags.DEFINE_boolean('svrinfo', True,
                     'Run svrinfo on VMs.')
flags.DEFINE_string('svrinfo_flags', '-format all',
                    'Command line flags that get passed to svr_info.')
flags.DEFINE_string('svrinfo_local_path', None,
                    'Local path where svr_info is/ will be installed.')
flags.DEFINE_string('svrinfo_tarball', None,
                    'Local path to svr_info tarball.')
flags.DEFINE_string('svrinfo_url', None,
                    'URL for downloading svr_info tarball.')
flags.DEFINE_enum('svrinfo_package_version', 'svr-info-internal-2.0.1.tgz',
                  ['svr-info-internal-2.0.1.tgz'],
                  'Specify the internal svrinfo version')
FLAGS = flags.FLAGS


class _SvrinfoCollector(object):
  """Manages running svrinfo"""
  def __init__(self):
    pass

  def InstallAndRun(self, unused_sender, benchmark_spec):
    """Install, Run, Retrieve/Publish on all VMs."""
    install_dir = _GetLocalInstallPath()
    vms = trace_util.GetVMsToTrace(benchmark_spec, FLAGS.trace_vm_groups)
    if vms:
      # installations of svr_info if it is not installed before or need re-install
      if not FLAGS.trace_skip_install or not os.path.isdir(install_dir):
        vm_util.IssueCommand(["rm", "-rf", install_dir])
        vm_util.IssueCommand(["mkdir", "-p", install_dir])
        svr_info_archive = _GetLocalArchive()
        vm_util.IssueCommand(["tar", "-C", install_dir, "-xf", svr_info_archive])

      try:
        # run svr_info
        vm_util.RunThreaded(lambda vm: _Run(vm, benchmark_spec), vms)
      except Exception:
        raise
      finally:
        # always do the cleanups no matter run fail or not if skip_cleanup is not set
        if not FLAGS.trace_skip_cleanup:
          vm_util.IssueCommand(["rm", "-rf", install_dir])


def _GetLocalInstallPath():
  """Get svr_info local installation directory"""
  if FLAGS.svrinfo_local_path is None and FLAGS.trace_skip_install:
    """Local path is not specified and we are skipping trace install, default to generic dir"""
    svrinfo_local_path = posixpath.join(FLAGS.temp_dir, SVRINFO_DIRECTORY_NAME)
  elif FLAGS.svrinfo_local_path is None and not FLAGS.trace_skip_install:
    """Use unique path ID based on run_uri for cases where we're installing cleaning up (for common tmp dir)"""
    svrinfo_local_path = posixpath.join(FLAGS.temp_dir, '-'.join([SVRINFO_DIRECTORY_NAME, FLAGS.run_uri]))
  else:
    svrinfo_local_path = FLAGS.svrinfo_local_path
  return svrinfo_local_path


def _GetLocalArchive():
  """ get or make sure we already have the svr_info archive """
  if FLAGS.svrinfo_tarball:
    logging.info("svrinfo_tarball specified: {}".format(FLAGS.svrinfo_tarball))
    local_archive_path = FLAGS.svrinfo_tarball
  else:
    svrinfo_archive_url = SVRINFO_ARCHIVE_URL_S3_BUCKET + FLAGS.svrinfo_package_version
    url = FLAGS.svrinfo_url or svrinfo_archive_url
    logging.info("downloading svrinfo from: {}".format(url))
    filename = os.path.basename(urlparse(url).path)
    local_archive_path = posixpath.join(_GetLocalInstallPath(), filename)
    vm_util.IssueCommand(["curl", "-o", local_archive_path, url], timeout=None)
  return local_archive_path


def _Run(vm, benchmark_spec):
  output_dir = posixpath.join(vm_util.GetTempDir(), vm.name + '-svrinfo')
  vm_util.IssueCommand(["mkdir", "-p", output_dir])
  command = [
      posixpath.join(".", SVRINFO_BINARY_NAME)
  ]
  command.extend(FLAGS.svrinfo_flags.split())
  command.extend([
      "-output",
      output_dir,
      "-ip",
      vm.ip_address,
      "-port",
      str(vm.ssh_port),
      "-user",
      vm.user_name])
  key = vm.ssh_private_key if vm.is_static else vm_util.GetPrivateKeyPath()
  if key is not None:
      command.extend(["-key", key])
  vm_util.IssueCommand(command, cwd=posixpath.join(_GetLocalInstallPath(), SVRINFO_DIRECTORY_NAME), timeout=None)


def Register(parsed_flags):
  """Register the collector if FLAGS.svrinfo is set."""
  if not parsed_flags.svrinfo:
    return
  logging.info('Registering svr_info collector to run after PREPARE phase.')
  collector = _SvrinfoCollector()
  events.after_phase.connect(collector.InstallAndRun, stages.PREPARE, weak=False)


def IsEnabled():
  return FLAGS.svrinfo
