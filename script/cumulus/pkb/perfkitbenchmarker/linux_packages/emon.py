# Copyright 2015 PerfKitBenchmarker Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Builds and install emon from source.
"""

import posixpath
import os
import logging

from absl import flags
from perfkitbenchmarker import errors
from perfkitbenchmarker import data
from perfkitbenchmarker import os_types
from perfkitbenchmarker import vm_util
try:
  from perfkitbenchmarker.linux_packages import intel_s3_transfer
except:
  intel_s3_transfer = None
from perfkitbenchmarker.linux_packages import INSTALL_DIR

flags.DEFINE_string('emon_tarball', None,
                    'Optional, path to emon package. eg --emon_tarball=/tmp/sep_private_5_19_linux_07062101c5153a9.tar.bz2')
flags.DEFINE_string('edp_events_file', None,
                    'Optional, path to edp event list. present in config/edp')
flags.DEFINE_boolean('emon_post_process_skip', False,
                     'Optional, no post processing will be done if supplied')
flags.DEFINE_enum('edp_script_type', 'python3',
                  ['ruby', 'python3'], 'Optional, default is python3. eg --edp_script_type=ruby if need to use ruby script')
flags.DEFINE_string('edp_config_file', None,
                    'Optional, path to EDP config. eg --edp_config_file=/tmp/edp_config.txt')
flags.DEFINE_boolean('edp_publish', False,
                     'Optional, EDP csv files will be published to zip file if provided and --intel-publish is applied')
flags.DEFINE_boolean('emon_debug', False,
                     'Optional, for debugging EMON driver, build, collection, and post processing. eg --emon_debug')
flags.DEFINE_enum('emon_package_version', '5_34_linux_050122015feb2b5',
                  ['5_29_linux_09162200a7108a4', '5_33_linux_0316081130eb678', '5_34_linux_050122015feb2b5'],
                  'Specify the internal emon version')
FLAGS = flags.FLAGS


UBUNTU_PKGS = ["linux-headers-`uname -r`", "build-essential"]
RHEL_PKGS = ["kernel-devel"]
EMON_SOURCE_TARBALL_DEFAULT = 'sep_private_linux_pkb.tar.bz2'
EMON_SOURCE_TARBALL_DEFAULT_LOCATION_S3_BUCKET = 'emon'
EMON_MAIN_DIR = '/opt/emon'
EMON_INSTALL_DIR = '/opt/emon/emon_files'
EMON_RESULT_TARBALL = 'emon_result.tar.gz'
EMON_EDP_TARBALL = 'emon_edp.tar.gz'
PKB_RUBY_FILE = '{0}/pkb_ruby_file'.format(EMON_MAIN_DIR)
PKB_POSTPROCESS_FILE = '{0}/pkb_postprocess_packages_file'.format(EMON_MAIN_DIR)


def _GetEmonTarball():
  if FLAGS.emon_package_version:
    return "sep_private_" + FLAGS.emon_package_version + ".tar.bz2"
  else:
    return EMON_SOURCE_TARBALL_DEFAULT


def _GetAbsPath(path):
  absPath = os.path.abspath(os.path.expanduser(path))
  if not os.path.isfile(absPath):
    raise RuntimeError('File (%s) does not exist.' % path)

  return absPath


def _TransferEMONTarball(vm):
  # get emon_tarball file name
  emon_tarball = _GetEmonTarball()

  if FLAGS.emon_tarball:
    logging.info("Copying local emon tarball ({}) to remote SUT location ({})"
                 .format(FLAGS.emon_tarball, INSTALL_DIR))
    tarFile_path = _GetAbsPath(FLAGS.emon_tarball)
    _, emon_tarball = os.path.split(FLAGS.emon_tarball)
    vm.RemoteCopy(tarFile_path, INSTALL_DIR, True)
  else:
    download_success = False
    s3_image_path = posixpath.join(EMON_SOURCE_TARBALL_DEFAULT_LOCATION_S3_BUCKET, emon_tarball)
    target = posixpath.join(INSTALL_DIR, emon_tarball)
    download_success = intel_s3_transfer.GetFileFromS3(vm, s3_image_path, target) if intel_s3_transfer else None

    if not download_success:
      raise RuntimeError(f'Failed to download EMON tarball ({emon_tarball}). Quit!')

  return emon_tarball


def _DoSanityCheck(vm):
  """do a sanity check first"""
  logging.info("Doing EMON sanity check")
  sub_dir = CheckIfExternalVersion(vm)
  cmds = ['source {0}/{1}/sep_vars.sh'.format(EMON_INSTALL_DIR, sub_dir),
          'emon -v > {0}/emon-v.dat'.format(INSTALL_DIR),
          'emon -M > {0}/emon-M.dat'.format(INSTALL_DIR)]
  cmd = ' ; '.join(cmds)
  vm.RemoteCommand("bash -c '{}'".format(cmd))
  emon_v_dat = posixpath.join(INSTALL_DIR, 'emon-v.dat')
  emon_M_dat = posixpath.join(INSTALL_DIR, 'emon-M.dat')
  logging.info("checking the contents in sanity checking output files ({}) and ({})".format(emon_M_dat, emon_v_dat))
  wc_M, stderr_M, ret_M = vm.RemoteCommandWithReturnCode('wc -c {}'.format(emon_M_dat), ignore_failure=False)
  wc_v, stderr_v, ret_v = vm.RemoteCommandWithReturnCode('wc -c {}'.format(emon_v_dat), ignore_failure=False)
  if ret_M != 0 or ret_v != 0:
    logging.info("Failed to collect emon sanity checking data ({}) and data ({}) with stderr ({}) and ({})"
                 .format(emon_M_dat, emon_v_dat, stderr_M, stderr_v))
    raise RuntimeError('EMON sanity check failed, quit!')
  else:
    # check the str return with num > 0 from wc_M and wc_v
    # "wc -c /opt/pkb/emon-M.dat" ==> "4255 /opt/pkb/emon-M.dat"
    # sample output: wc_M = '4255 /opt/pkb/emon-M.dat'
    # split into an array with multiple strings separated by space,
    # and get the first string, which is 4255 before converting it to int
    # if that int is zero, we didn't get any output
    if int(wc_M.split()[0]) <= 0 or int(wc_v.split()[0]) <= 0:
      err_str = ('EMON sanity check failed with invalid output '
                 ' in ({}) and/or ({}), quit!').format(emon_M_dat, emon_v_dat)
      raise RuntimeError(err_str)


def GetEmonVersion(vm):
  sub_dir = 'sep'
  if FLAGS.emon_tarball:
     _, emon_version = os.path.split(FLAGS.emon_tarball)
  else:
    tar_file = vm.RemoteCommand("cd {0} && ls -ld {1}_* | head -n 1 | awk -F' ' '{{print $9}}'"
                                .format(EMON_MAIN_DIR, sub_dir))[0].rstrip("\n")
    emon_version = tar_file.split('.tar')[0]
  return emon_version


def GetEDPVersion(vm):
  sub_dir = CheckIfExternalVersion(vm)
  edp_version = vm.RemoteCommand("grep 'EDP_VERSION' {0}/{1}/config/edp/edp.rb | head -n 1"
                                 " | awk -F' ' '{{print $3}}'"
                                 .format(EMON_INSTALL_DIR, sub_dir))[0].rstrip("\n")
  return edp_version.strip('"')


def CheckIfExternalVersion(vm):
  use_dir = 'sep'
  if FLAGS.emon_tarball and 'emon_nda' in FLAGS.emon_tarball:
    use_dir = 'emon'
  return use_dir


def _GetGroup(vm):
  group = 'sudo'
  if "centos" in vm.OS_TYPE:
    group = 'wheel'
  return group


def _AddUserToGroup(vm, group):
  vm.RemoteCommand('sudo usermod -g {0} $USER'.format(group))
  # When we add pkb to the wheel group in CentOS, we need to exit and log in for new shells
  # to load this new environment.
  if "centos" in vm.OS_TYPE:
    if FLAGS.ssh_reuse_connections:
      vm.RemoteCommand('', ssh_args=['-O', 'stop'])


def _InstallCentosKernelDev(vm):
  mirror_base = 'https://mirrors.portworx.com/mirrors/http/mirror.centos.org/centos/'
  if os_types.CENTOS7 == vm.OS_TYPE:
    os_repo = '7'
  elif os_types.CENTOS8 == vm.OS_TYPE:
    os_repo = '8'
  elif os_types.CENTOS_STREAM8 == vm.OS_TYPE:
    os_repo = '8-stream'
  else:
    return False
  base_arq_pkg = '/BaseOS/x86_64/os/Packages/'
  kernel_devel = 'kernel-devel-$(uname -r).rpm'
  vm.InstallPackages('wget')
  pkg_url = mirror_base + os_repo + base_arq_pkg + kernel_devel
  _, _, wget_rc = vm.RemoteCommandWithReturnCode('wget {} -O /tmp/{}'.format(pkg_url, kernel_devel),
                                                 ignore_failure=True)
  if wget_rc:
    return False

  _, _, yum_rc = vm.RemoteCommandWithReturnCode('sudo yum -y install /tmp/{}'.format(kernel_devel),
                                                ignore_failure=True)

  vm.RemoteCommand('rm /tmp/{}'.format(kernel_devel))
  if yum_rc:
    return False

  return True


def _Install(vm):
  # check input file exists asap, if supplied from command line as an optional flag
  # error out if file does not exist
  if FLAGS.emon_tarball:
    _GetAbsPath(FLAGS.emon_tarball)

  if FLAGS.edp_events_file is not None:
    _GetAbsPath(FLAGS.edp_events_file)

  if FLAGS.edp_config_file is not None:
    _GetAbsPath(FLAGS.edp_config_file)

  """Installs emon on vm."""
  logging.info("Installing emon")

  # transfer tarball to the SUT
  emon_tarball = _TransferEMONTarball(vm)
  # install emon
  vm.RemoteCommand('sudo rm -rf {0} && sudo mkdir -p {0}'.format(EMON_MAIN_DIR))
  vm.RemoteCommand('sudo mkdir -p {0}'.format(EMON_INSTALL_DIR))

  vm.RemoteCommand('sudo tar -xf {}/{} -C {} --strip-components=1'
                   .format(INSTALL_DIR, emon_tarball, EMON_MAIN_DIR))

  sub_dir = CheckIfExternalVersion(vm)
  group = _GetGroup(vm)
  _AddUserToGroup(vm, group)

  cmds = ['cd {0}'.format(EMON_MAIN_DIR),
          './{0}-installer.sh -i -u -C {1} --accept-license -ni -g {2}'
          .format(sub_dir, EMON_INSTALL_DIR, group)]
  vm.RemoteCommand(' && '.join(cmds))

  # quick sanity check
  _DoSanityCheck(vm)


def Start(vm):
  sub_dir = CheckIfExternalVersion(vm)
  logging.info("Starting emon collection")
  cmd = ('source {0}/{1}/sep_vars.sh; emon -collect-edp > {2}/emon.dat 2>&1 &'
         .format(EMON_INSTALL_DIR, sub_dir, INSTALL_DIR))
  if FLAGS.edp_events_file:
    edp_event_file_path = _GetAbsPath(FLAGS.edp_events_file)
    _, edp_event_file_name = os.path.split(FLAGS.edp_events_file)
    vm.RemoteCopy(edp_event_file_path, INSTALL_DIR, True)
    cmd = ('source {0}/{1}/sep_vars.sh; cd {2};'
           'emon -collect-edp edp_file={3} > {2}/emon.dat 2>&1 &'
           .format(EMON_INSTALL_DIR, sub_dir, INSTALL_DIR, edp_event_file_name))

  stdout, stderr, retcode = vm.RemoteCommandWithReturnCode("bash -c '{}'".format(cmd))


def Stop(vm):
  """Stops emon collection on vm"""
  logging.info("Stopping emon collection")
  sub_dir = CheckIfExternalVersion(vm)
  logging.info("Stopping emon")
  cmds = ['source {0}/{1}/sep_vars.sh'.format(EMON_INSTALL_DIR, sub_dir),
          'emon -stop',
          'sleep 5',
          'pkill -9 -x emon']
  stdout, stderr, retcode = vm.RemoteCommandWithReturnCode("bash -c '{}'".format(' ; '.join(cmds)), ignore_failure=True)
  if not FLAGS.emon_post_process_skip:
    _PostProcess(vm)


def _CheckRubyFile(vm):
  _, _, retcode = vm.RemoteCommandWithReturnCode('sudo file -f {0}'.format(PKB_RUBY_FILE),
                                                 ignore_failure=True, suppress_warning=True)
  if retcode == 0:
    return True
  return False


def _PostProcessingPackagesExist(vm):
  _, _, retcode = vm.RemoteCommandWithReturnCode('sudo file -f {0}'.format(PKB_POSTPROCESS_FILE),
                                                 ignore_failure=True, suppress_warning=True)
  if retcode == 0:
    return True
  return False


def _PostProcess(vm):
  logging.info("Starting emon post processing")
  if FLAGS.trace_skip_install and _PostProcessingPackagesExist(vm):
    logging.info("Post processing packages present. Skipping installation")
  else:
    if FLAGS.edp_script_type == 'ruby':
      logging.info("Installing ruby ...")
      vm.Install('ruby')
    elif FLAGS.edp_script_type == 'python3':
      vm.InstallPackages('python3-pip')
      if 'centos' in vm.OS_TYPE:
        vm.InstallPackages('python3-devel')
      vm.RemoteCommand('sudo pip3 install xlsxwriter pandas numpy pytz defusedxml tdigest dataclasses')
    vm.RemoteCommand('sudo touch {0}'.format(PKB_POSTPROCESS_FILE))

  sub_dir = CheckIfExternalVersion(vm)
  cmd = 'source {0}/{1}/sep_vars.sh; cd {2};'.format(EMON_INSTALL_DIR, sub_dir, INSTALL_DIR)
  default_edp_config_file = " {0}/{1}/config/edp/edp_config.txt".format(EMON_INSTALL_DIR, sub_dir)

  if FLAGS.edp_script_type == 'ruby':
    if _CheckRubyFile(vm):
      cmd = cmd + 'rvm use ruby-{0}; '.format(FLAGS.ruby_version)
    cmd = cmd + "emon -process-edp"
  elif FLAGS.edp_script_type == 'python3':
    cmd = cmd + "emon -process-pyedp"
    default_edp_config_file = " {0}/{1}/config/edp/pyedp_config.txt".format(EMON_INSTALL_DIR, sub_dir)

  if FLAGS.edp_config_file:
    edp_config_file_full_path = _GetAbsPath(FLAGS.edp_config_file)
    _, edp_config_file_name = os.path.split(FLAGS.edp_config_file)
    vm.RemoteCopy(edp_config_file_full_path, INSTALL_DIR, True)
    cmd = cmd + ' {0}'.format(edp_config_file_name)
  else:
    cmd = cmd + default_edp_config_file
  stdout, stderr, retcode = vm.RemoteCommandWithReturnCode("bash -c '{}'".format(cmd))

  if FLAGS.emon_debug:
    if stdout != '' or stderr != '':
      logging.info("Emon post process generated stdout ({}) and stderr ({})"
                   .format(stdout, stderr))


def FetchResults(vm):
  """Copies emon data to PKB host."""
  logging.info('Fetching emon results')

  # TODO: tag vm with machine category, such as server, client, single_machine
  # if vm.tag is not None and vm.tag is not '':
  #  local_dir = os.path.join(vm_util.GetTempDir(), vm.name + '-' + vm.tag + '-emon')
  #  e.g.: pkb-5c37bc7a-0-client-emon
  #  e.g.: pkb-5c37bc7a-1-server-emon
  # else:
  local_dir = os.path.join(vm_util.GetTempDir(), vm.name + '-emon')
  # e.g.: pkb-5c37bc7a-0-emon
  cmd = ['mkdir', '-p', local_dir]
  vm_util.IssueCommand(cmd)
  tar_pkgs = [('*emon*', EMON_RESULT_TARBALL)]
  if not FLAGS.emon_post_process_skip:
    edp_files = '*edp*.csv'
    if FLAGS.edp_script_type == 'python3':
        edp_files += ' summary.xlsx'
    tar_pkgs.append((edp_files, EMON_EDP_TARBALL))
    # tar command below will cause an exception if edp fails to generate the output files as expected,
    # and PKB process will be shutdown by the framework
    # this is desired if edp post process fails, which could be due to multiple reasons,
    # such as EMON data corruption, and we should quit

  for remote_output_files, remote_output_tarfile in tar_pkgs:
    remote_output_tarfile = os.path.join("/tmp", remote_output_tarfile)
    vm.RemoteCommand('cd {} && sudo -E tar cvzf {} {}'
                     .format(INSTALL_DIR, remote_output_tarfile, remote_output_files))
    vm.PullFile(local_dir, remote_output_tarfile)


def EmonCleanup(vm):
  sub_dir = CheckIfExternalVersion(vm)
  group = _GetGroup(vm)
  cmds = ['cd {0}'.format(EMON_MAIN_DIR),
          './{1}-installer.sh  -u -C {0} --accept-license -ni -g {2} > /dev/null 2>&1 &'
          .format(EMON_INSTALL_DIR, sub_dir, group)]
  vm.RemoteCommand(' && '.join(cmds))
  if not FLAGS.emon_post_process_skip:
    emon_edp_data = posixpath.join(INSTALL_DIR, '*edp*.csv')
    if FLAGS.edp_script_type == 'python3':
      emon_edp_data += ' summary.xlsx'
    vm.RemoteCommand('sudo rm -f {}'.format(emon_edp_data), ignore_failure=False)
  # rm emon shell scripts and output emon*.dat files
  emon_all_files = posixpath.join(INSTALL_DIR, '*emon*')
  vm.RemoteCommand('sudo rm -f {}'.format(emon_all_files), ignore_failure=False)

  # rm entire emon install folder
  vm.RemoteCommand('sudo rm -fr {}'.format(EMON_MAIN_DIR))


def EmonDirsExist(vm):
  _, _, retVal = vm.RemoteCommandWithReturnCode('test -d {0}'.format(EMON_INSTALL_DIR),
                                                ignore_failure=True)
  # They do not exist
  if retVal != 0:
    return False
  return True


def YumInstall(vm):
  vm.InstallPackageGroup('Development Tools')
  _, _, rc = vm.RemoteCommandWithReturnCode('test -d /usr/src/kernels/$(uname -r)', ignore_failure=True)
  if rc != 0:
    pkg_name = "kernel-devel-$(uname -r)"
    if vm.HasPackage(pkg_name):
      vm.InstallPackages(pkg_name)
    elif _InstallCentosKernelDev(vm):
      pass
    else:
      raise Exception("\n Could not find the kernel headers to match your kernel ! Please install it manually \n "
                      "There are two approaches to solve this :- \n"
                      "1) Get the kernel details with 'uname-r' and search for kernel headers on "
                      "CentOS repo and download them.\n"
                      "2)'sudo yum -y update' and then 'sudo reboot' - Please note that this may \n"
                      "update other packages on your system which may not be desirable to you\n")
  vm.RemoteCommand('sudo yum -y install bzip2')
  _Install(vm)


def AptInstall(vm):
  vm.InstallPackages(' '.join(UBUNTU_PKGS))
  # since we always install the exact matching kernel headers by UBUNTU_PKGS
  # there is no need to search for it like in YUM based kernel
  _Install(vm)
