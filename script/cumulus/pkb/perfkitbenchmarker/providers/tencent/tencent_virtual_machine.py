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

"""Class to represent a Tencent Virtual Machine object.

All VM specifics are self-contained and the class provides methods to
operate on the VM: boot, shutdown, etc.
"""

import json
import threading
import logging
import base64

from absl import flags
from perfkitbenchmarker import virtual_machine
from perfkitbenchmarker import linux_virtual_machine
from perfkitbenchmarker import vm_util
from perfkitbenchmarker import disk
from perfkitbenchmarker import errors
from perfkitbenchmarker import providers
from perfkitbenchmarker.providers.tencent import tencent_disk
from perfkitbenchmarker.providers.tencent import tencent_network
from perfkitbenchmarker.providers.tencent import util
FLAGS = flags.FLAGS

# Tencent CLI returns 0 even when an exception is encountered.
# In some cases, stdout must be scanned for this message.
TENCENT_CLOUD_EXCEPTION_STDOUT = '[TencentCloudSDKException]'
TENCENT_CLOUD_SOLD_OUT_MSG = 'ResourcesSoldOut'
TENCENT_CLOUD_INSUFFICIENT_BALANCE = 'InsufficientBalance'

INSTANCE_TRANSITIONAL_STATUSES = frozenset(['TERMINATING', 'PENDING'])
DEFAULT_SYSTEM_DISK_SIZE = 50
DEFAULT_SYSTEM_DISK_TYPE = 'CLOUD_PREMIUM'
DEFAULT_INTERNET_BANDWIDTH = 100
DEFAULT_USER_NAME = 'perfkit'


class TencentTransitionalVmRetryableError(Exception):
  """Error for retrying _Exists when an Tencent VM is in a transitional state."""


class TencentCloudSDKExceptionRetryableError(Exception):
  """Error for retrying commands when STDOUT returns TencentCLoudSDKException (and still exit 0)"""


class TencentCloudUnknownCLIRetryableError(Exception):
  """Error for retrying commands when STDOUT returns an unexpected CLI error (and still exit 0)"""


class TencentCloudResourceSoldOut(Exception):
  """Error for resouce sold out"""


class TencentCloudInsufficientBalance(Exception):
  """Error for insufficient account balance"""


class TencentVirtualMachine(virtual_machine.BaseVirtualMachine):
  """Object representing an Tencent Virtual Machine."""

  IMAGE_NAME_FILTER = None
  CLOUD = providers.TENCENT

  def __init__(self, vm_spec):
    """Initialize a Tencent virtual machine.

    Args:
      vm_spec: virtual_machine.BaseVirtualMachineSpec object of the VM.
    """
    super(TencentVirtualMachine, self).__init__(vm_spec)
    self.region = util.GetRegionFromZone(self.zone)
    self.user_name = FLAGS.tencent_user_name
    self.network = tencent_network.TencentNetwork.GetNetwork(self)
    self.host = None
    self.id = None
    self.project_id = FLAGS.tencent_project_id
    self.key_id = None
    self.boot_disk_size = FLAGS.tencent_boot_disk_size or DEFAULT_SYSTEM_DISK_SIZE
    self.boot_disk_type = FLAGS.tencent_boot_disk_type or DEFAULT_SYSTEM_DISK_TYPE
    self.internet_bandwidth = FLAGS.tencent_internet_bandwidth or DEFAULT_INTERNET_BANDWIDTH
    self.image_id = FLAGS.tencent_image_id or None

  @vm_util.Retry()
  def _PostCreate(self):
    """Get the instance's data."""
    describe_cmd = util.TENCENT_PREFIX + [
        'cvm', 'DescribeInstances',
        '--region', self.region,
        '--InstanceIds', json.dumps([self.id])] + util.TENCENT_SUFFIX
    logging.info('Getting instance %s public IP. This will fail until '
                 'a public IP is available, but will be retried.', self.id)
    stdout, _ = util.IssueRetryableCommand(describe_cmd)
    try:
      response = json.loads(stdout)
    except ValueError as e:
      logging.warn("Encountered unexpected return from command '{}', retrying.".format(e))
      raise TencentCloudUnknownCLIRetryableError
    instance = response['InstanceSet'][0]
    if not instance['PublicIpAddresses']:
      raise TencentTransitionalVmRetryableError
    self.ip_address = instance['PublicIpAddresses'][0]
    self.internal_ip = instance['PrivateIpAddresses'][0]

  def _CreateDependencies(self):
    """Create VM dependencies."""
    self.image_id = self.image_id or self.GetDefaultImage(self.machine_type,
                                                          self.region)
    self.key_id = TencentKeyFileManager.ImportKeyfile(self.region)


  def _DeleteDependencies(self):
    """Delete VM dependencies."""
    if self.key_id:
      TencentKeyFileManager.DeleteKeyfile(self.region, self.key_id)

  @vm_util.Retry(poll_interval=5, log_errors=False, max_retries=5,
                 retryable_exceptions=(TencentCloudUnknownCLIRetryableError,))
  def _Create(self):
    """Create a VM instance."""
    placement = {
        'Zone': self.zone,
        'ProjectId': self.project_id

    }
    login_settings = {
        'KeyIds': [self.key_id]
    }
    vpc = {
        'VpcId': self.network.vpc.id,
        'SubnetId': self.network.subnet.id
    }
    system_disk = {
        'DiskType': self.boot_disk_type,
        'DiskSize': self.boot_disk_size
    }
    internet_accessible = {
        'PublicIpAssigned': True,
        'InternetMaxBandwidthOut': self.internet_bandwidth
    }

    create_cmd = util.TENCENT_PREFIX + [
        'cvm', 'RunInstances',
        '--region', self.region,
        '--Placement', json.dumps(placement),
        '--InstanceType', self.machine_type,
        '--ImageId', self.image_id,
        '--VirtualPrivateCloud', json.dumps(vpc),
        '--InternetAccessible', json.dumps(internet_accessible),
        '--SystemDisk', json.dumps(system_disk),
        '--LoginSettings', json.dumps(login_settings),
        '--InstanceName', self.name
    ] + util.TENCENT_SUFFIX

    # Create user and add SSH key if image doesn't have a default non-root user
    if self.CREATE_NON_ROOT_USER:
      public_key = TencentKeyFileManager.GetPublicKey()
      user_data = util.ADD_USER_TEMPLATE.format(self.user_name, public_key)
      logging.debug('encoding startup script: %s' % user_data)
      create_cmd.extend(['--UserData', base64.b64encode(user_data.encode("utf-8"))])

    # Tccli will exit 0 and provide a non-json formatted error msg to stdout in case of failure
    stdout, _, _ = vm_util.IssueCommand(create_cmd)
    try:
      response = json.loads(stdout)
    except ValueError:
      if TENCENT_CLOUD_EXCEPTION_STDOUT in stdout:
        if TENCENT_CLOUD_SOLD_OUT_MSG in stdout:
          raise TencentCloudResourceSoldOut
        elif TENCENT_CLOUD_INSUFFICIENT_BALANCE in stdout:
          raise TencentCloudInsufficientBalance
        else:
          raise TencentCloudSDKExceptionRetryableError
      else:
        raise TencentCloudUnknownCLIRetryableError

    self.id = response['InstanceIdSet'][0]
    util.AddDefaultTags(self.id, self.region)

  @vm_util.Retry(poll_interval=5, log_errors=False, max_retries=5,
                 retryable_exceptions=(TencentCloudUnknownCLIRetryableError,))
  def _Delete(self):
    """Delete a VM instance."""
    delete_cmd = util.TENCENT_PREFIX + [
        'cvm',
        'TerminateInstances',
        '--region', self.region,
        '--InstanceIds', json.dumps([self.id])] + util.TENCENT_SUFFIX
    stdout, stderr, _ = vm_util.IssueCommand(delete_cmd)
    try:
      json.loads(stdout)
    except ValueError as e:
      if TENCENT_CLOUD_EXCEPTION_STDOUT not in stderr:
        logging.warn("Encountered unexpected return from command '{}', retrying.".format(e))
        raise TencentCloudUnknownCLIRetryableError

  @vm_util.Retry(poll_interval=5, log_errors=False,
                 retryable_exceptions=(TencentTransitionalVmRetryableError, TencentCloudUnknownCLIRetryableError))
  def _Exists(self):
    """Returns whether the VM exists."""
    describe_cmd = util.TENCENT_PREFIX + [
        'cvm', 'DescribeInstances',
        '--region', self.region,
        '--InstanceIds', json.dumps([self.id])] + util.TENCENT_SUFFIX
    stdout, _ = util.IssueRetryableCommand(describe_cmd)
    try:
      response = json.loads(stdout)
    except ValueError as e:
      logging.warn("Encountered unexpected return from command '{}', retrying.".format(e))
      raise TencentCloudUnknownCLIRetryableError
    instance_set = response['InstanceSet']
    if not instance_set:
      return False
      # TODO There is potential issue here with tccli, possibly during high traffic periods where the instance query will return empty when an instnace is transitioning from PENDING -> RUNNING
    if instance_set[0]['InstanceState'] in INSTANCE_TRANSITIONAL_STATUSES:
      raise TencentTransitionalVmRetryableError
    assert len(instance_set) < 2, 'Too many instances.'
    return len(instance_set) > 0

  @classmethod
  @vm_util.Retry(poll_interval=5, log_errors=False,
                 retryable_exceptions=(TencentTransitionalVmRetryableError, TencentCloudUnknownCLIRetryableError))
  def GetDefaultImage(cls, machine_type, region):
    """Returns Image ID of first match with IMAGE_NAME_MATCH.
    Results from DescribeImages are evaluated in the order they are returned from the command (assumed arbitrary).
    """
    if cls.IMAGE_NAME_MATCH is None:
      return None
    describe_cmd = util.TENCENT_PREFIX + [
        'cvm', 'DescribeImages',
        '--region', region,
        '--Limit', '100',
        '--InstanceType', machine_type
    ] + util.TENCENT_SUFFIX
    stdout, _ = util.IssueRetryableCommand(describe_cmd)
    try:
      response = json.loads(stdout)
    except ValueError as e:
      logging.warn("Encountered unexpected return from command '{}', retrying.".format(e))
      raise TencentCloudUnknownCLIRetryableError
    for i in response['ImageSet']:
      if i['ImageName'] in cls.IMAGE_NAME_MATCH and i['ImageSource'] == 'OFFICIAL':
        logging.debug('Found image %s, %s' % (i['ImageName'], i['ImageId']))
        return i['ImageId']
    return None

  def CreateScratchDisk(self, disk_spec):
    """Create a VM's scratch disk.

    Args:
      disk_spec: virtual_machine.BaseDiskSpec object of the disk.
    """
    disk_ids = []
    if disk_spec.disk_type in tencent_disk.LOCAL_DISK_TYPES:
      disk_spec.disk_type = disk.LOCAL
      logging.debug("Querying instance for local disk ids")
      disk_ids = self._GetDataDiskIds()
      if len(disk_ids) != disk_spec.num_striped_disks:
        raise errors.Error('Expected %s local disks but found %s local disks' %
                           (disk_spec.num_striped_disks, len(disk_ids)))
    disks = []
    for i in range(disk_spec.num_striped_disks):
      data_disk = tencent_disk.TencentDisk(disk_spec, self)
      if disk_spec.disk_type == disk.LOCAL:
        data_disk.SetDiskId(disk_ids[i])
      disks.append(data_disk)
    self._CreateScratchDiskFromDisks(disk_spec, disks)

  @vm_util.Retry(poll_interval=2, log_errors=False,
                 retryable_exceptions=(TencentCloudUnknownCLIRetryableError,))
  def _GetDataDiskIds(self):
    """Returns Ids of attached data disks"""
    disk_ids = []
    describe_cmd = util.TENCENT_PREFIX + [
        'cvm', 'DescribeInstances',
        '--region', self.region,
        '--InstanceIds', json.dumps([self.id])] + util.TENCENT_SUFFIX
    stdout, _ = util.IssueRetryableCommand(describe_cmd)
    try:
      response = json.loads(stdout)
    except ValueError as e:
      logging.warn("Encountered unexpected return from command '{}', retrying.".format(e))
      raise TencentCloudUnknownCLIRetryableError
    instance = response['InstanceSet'][0]
    for data_disk in instance['DataDisks']:
      disk_ids.append(data_disk['DiskId'])
    return disk_ids


class TencentKeyFileManager(object):
  """Object for managing Tencent Keyfiles."""
  _lock = threading.Lock()
  imported_keyfile_set = set()
  deleted_keyfile_set = set()
  run_uri_key_ids = {}

  @classmethod
  @vm_util.Retry(poll_interval=2, log_errors=False,
                 retryable_exceptions=(TencentCloudSDKExceptionRetryableError, TencentCloudUnknownCLIRetryableError))
  def ImportKeyfile(cls, region):
    """Imports the public keyfile to Tencent."""
    with cls._lock:
      if FLAGS.run_uri in cls.run_uri_key_ids:
        return cls.run_uri_key_ids[FLAGS.run_uri]
      public_key = cls.GetPublicKey()
      import_cmd = util.TENCENT_PREFIX + [
          'cvm',
          'ImportKeyPair',
          '--ProjectId', '0',
          '--region', region,
          '--KeyName', cls.GetKeyNameForRun(),
          '--PublicKey', public_key] + util.TENCENT_SUFFIX
      stdout, _ = util.IssueRetryableCommand(import_cmd)
      try:
        response = json.loads(stdout)
      except ValueError as e:
        if TENCENT_CLOUD_EXCEPTION_STDOUT in stdout:
          raise TencentCloudSDKExceptionRetryableError
        else:
          logging.warn("Encountered unexpected return from command '{}', retrying.".format(e))
          raise TencentCloudUnknownCLIRetryableError

      key_id = response['KeyId']
      cls.run_uri_key_ids[FLAGS.run_uri] = key_id
      return key_id


  @classmethod
  @vm_util.Retry(poll_interval=2, log_errors=False,
                 retryable_exceptions=(TencentCloudSDKExceptionRetryableError, TencentCloudUnknownCLIRetryableError))
  def DeleteKeyfile(cls, region, key_id):
    """Deletes the imported KeyPair for a run_uri."""
    with cls._lock:
      if FLAGS.run_uri not in cls.run_uri_key_ids:
        return
      delete_cmd = util.TENCENT_PREFIX + [
          'cvm',
          'DeleteKeyPairs',
          '--region', region,
          '--KeyIds', json.dumps([key_id])] + util.TENCENT_SUFFIX
      stdout, _ = util.IssueRetryableCommand(delete_cmd)
      try:
        json.loads(stdout)
      except ValueError as e:
        if TENCENT_CLOUD_EXCEPTION_STDOUT in stdout:
          raise TencentCloudSDKExceptionRetryableError
        else:
          logging.warn("Encountered unexpected return from command '{}', retrying.".format(e))
          raise TencentCloudUnknownCLIRetryableError
      del cls.run_uri_key_ids[FLAGS.run_uri]

  @classmethod
  def GetKeyNameForRun(cls):
    return 'perfkit_key_{0}'.format(FLAGS.run_uri)

  @classmethod
  def GetPublicKey(cls):
    cat_cmd = ['cat',
               vm_util.GetPublicKeyPath()]
    keyfile, _ = vm_util.IssueRetryableCommand(cat_cmd)
    return keyfile


class DebianBasedTencentVirtualMachine(TencentVirtualMachine,
                                       linux_virtual_machine.BaseDebianMixin):
  CREATE_NON_ROOT_USER = False
  IMAGE_NAME_MATCH = 'Ubuntu Server 16.04.1 LTS 64'


class Ubuntu1604BasedTencentVirtualMachine(TencentVirtualMachine,
                                           linux_virtual_machine.Ubuntu1604Mixin):
  CREATE_NON_ROOT_USER = False
  IMAGE_NAME_MATCH = 'Ubuntu Server 16.04.1 LTS 64'


class Ubuntu1804BasedTencentVirtualMachine(TencentVirtualMachine,
                                           linux_virtual_machine.Ubuntu1804Mixin):
  CREATE_NON_ROOT_USER = False
  IMAGE_NAME_MATCH = 'Ubuntu Server 18.04.1 LTS 64'


class Ubuntu2004BasedTencentVirtualMachine(TencentVirtualMachine,
                                           linux_virtual_machine.Ubuntu2004Mixin):
  CREATE_NON_ROOT_USER = False
  IMAGE_NAME_MATCH = ['Ubuntu Server 20.04 LTS 64', 'Ubuntu 20.04(arm64)']

  def UpdateEnvironmentPath(self):
    # Tencent's image for Ubuntu 20.04 seems to have root-owned files in user home
    self.RemoteCommand('sudo chown -R {0}:{0} /home/{0}'.format(self.user_name))


# TODO to be verified
class Ubuntu2204BasedTencentVirtualMachine(TencentVirtualMachine,
                                           linux_virtual_machine.Ubuntu2204Mixin):
  CREATE_NON_ROOT_USER = False
  IMAGE_NAME_MATCH = 'Ubuntu Server 22.04 LTS 64'


class CentOs7BasedTencentVirtualMachine(TencentVirtualMachine,
                                        linux_virtual_machine.CentOs7Mixin):
  CREATE_NON_ROOT_USER = True
  IMAGE_NAME_MATCH = 'CentOS 7.9 64'

  def __init__(self, vm_spec):
    super(CentOs7BasedTencentVirtualMachine, self).__init__(vm_spec)
    user_name_set = FLAGS['tencent_user_name'].present
    self.user_name = FLAGS.tencent_user_name if user_name_set else DEFAULT_USER_NAME
    self.python_package_config = 'python'
    self.python_dev_package_config = 'python2-devel'
    self.python_pip_package_config = 'python2-pip'
