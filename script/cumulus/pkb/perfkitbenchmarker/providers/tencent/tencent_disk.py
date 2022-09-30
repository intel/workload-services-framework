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

"""Module containing classes related to Tencent disks.
"""

import json
import threading
import logging

from perfkitbenchmarker import disk
from perfkitbenchmarker import vm_util
from perfkitbenchmarker import providers
from perfkitbenchmarker.providers.tencent import util

TENCENT_CLOUD_EXCEPTION_STDOUT = '[TencentCloudSDKException]'
DISK_CHARGE_TYPE = 'POSTPAID_BY_HOUR'
LOCAL_DISK_TYPES = ['LOCAL_BASIC', 'LOCAL_SSD']


class TencentWaitOnDiskRetryableError(Exception):
  """Error for retrying _Exists when an Tencent Disk has an ID but is not yet created."""


class TencentCloudDiskUnknownCLIRetryableError(Exception):
  """Error for retrying commands when STDOUT returns an unexpected CLI error (and still exit 0)"""


class TencentDisk(disk.BaseDisk):
  """Object representing a Tencent Disk."""
  _lock = threading.Lock()
  vm_devices = {}

  def __init__(self, disk_spec, vm):
    super(TencentDisk, self).__init__(disk_spec)

    self.id = None
    self.vm = vm
    self.zone = vm.zone
    self.project_id = vm.project_id
    self.region = util.GetRegionFromZone(self.zone)
    self.device_letter = None
    self.attached_vm_id = None
    self.device_path = None
    self.disk_recently_created = False

  @vm_util.Retry(poll_interval=5, log_errors=False, max_retries=5,
                 retryable_exceptions=(TencentCloudDiskUnknownCLIRetryableError,))
  def _Create(self):
    """Creates the disk."""
    placement = {
        "Zone": self.zone
    }
    create_cmd = util.TENCENT_PREFIX + [
        'cbs',
        'CreateDisks',
        '--region', self.region,
        '--DiskType', self.disk_type,
        '--DiskChargeType', DISK_CHARGE_TYPE,
        '--Placement', json.dumps(placement),
        '--DiskSize', str(self.disk_size)] + util.TENCENT_SUFFIX

    stdout, _, _ = vm_util.IssueCommand(create_cmd)
    try:
      response = json.loads(stdout)
    except ValueError as e:
      logging.warn("Encountered unexpected return from command '{}', retrying.".format(e))
      raise TencentCloudDiskUnknownCLIRetryableError
    self.id = response['DiskIdSet'][0]
    self.disk_recently_created = True
    util.AddDefaultTags(self.id, self.region)

  @vm_util.Retry(poll_interval=5, log_errors=False, max_retries=10,
                 retryable_exceptions=(TencentCloudDiskUnknownCLIRetryableError))
  def _Delete(self):
    """Deletes the disk."""
    delete_cmd = util.TENCENT_PREFIX + [
        'cbs',
        'TerminateDisks',
        '--region', self.region,
        '--DiskIds', json.dumps([self.id])] + util.TENCENT_SUFFIX
    logging.info('Deleting Tencent volume %s. This may fail if the disk is not '
                 'yet detached, but will be retried.', self.id)
    stdout, _, _ = vm_util.IssueCommand(delete_cmd)
    try:
      json.loads(stdout)
    except ValueError as e:
      if TENCENT_CLOUD_EXCEPTION_STDOUT not in stdout:
        logging.warn("Encountered unexpected return from command '{}', retrying.".format(e))
        raise TencentCloudDiskUnknownCLIRetryableError
    self.disk_recently_created = False

  @vm_util.Retry(poll_interval=3, log_errors=False, max_retries=5,
                 retryable_exceptions=(TencentWaitOnDiskRetryableError, TencentCloudDiskUnknownCLIRetryableError))
  def _Exists(self):
    """Returns true if the disk exists."""
    describe_cmd = util.TENCENT_PREFIX + [
        'cbs',
        'DescribeDisks',
        '--region', self.region,
        '--DiskIds', json.dumps([self.id])] + util.TENCENT_SUFFIX
    stdout, _ = util.IssueRetryableCommand(describe_cmd)
    try:
      response = json.loads(stdout)
    except ValueError as e:
      logging.warn("Encountered unexpected return from command '{}', retrying.".format(e))
      raise TencentCloudDiskUnknownCLIRetryableError
    disks = response['DiskSet']
    assert len(disks) < 2, 'Too many volumes.'
    if not disks:
      if self.disk_recently_created:
        raise TencentWaitOnDiskRetryableError
      else:
        return False
    return len(disks) > 0

  @vm_util.Retry(poll_interval=5, log_errors=False, max_retries=10,
                 retryable_exceptions=(TencentCloudDiskUnknownCLIRetryableError))
  def Attach(self, vm):
    """Attaches the disk to a VM.

    Args:
      vm: The Tencent instance to which the disk will be attached.
    """
    self.attached_vm_id = vm.id
    attach_cmd = util.TENCENT_PREFIX + [
        'cbs',
        'AttachDisks',
        '--region', self.region,
        '--InstanceId', vm.id,
        '--DiskIds', json.dumps([self.id])] + util.TENCENT_SUFFIX
    logging.info('Attaching Tencent disk %s. This may fail if the disk is not '
                 'ready, but will be retried.', self.id)
    stdout, _ = util.IssueRetryableCommand(attach_cmd)
    try:
      json.loads(stdout)
    except ValueError as e:
      logging.warn("Encountered unexpected return from command '{}', retrying.".format(e))
      raise TencentCloudDiskUnknownCLIRetryableError

  @vm_util.Retry(poll_interval=5, log_errors=False, max_retries=10,
                 retryable_exceptions=(TencentCloudDiskUnknownCLIRetryableError))
  def Detach(self):
    """Detaches the disk from a VM."""
    detach_cmd = util.TENCENT_PREFIX + [
        'cbs',
        'DetachDisks',
        '--region', self.region,
        '--DiskIds', json.dumps([self.id])] + util.TENCENT_SUFFIX
    stdout, _ = util.IssueRetryableCommand(detach_cmd)
    try:
      json.loads(stdout)
    except ValueError as e:
      logging.warn("Encountered unexpected return from command '{}', retrying.".format(e))
      raise TencentCloudDiskUnknownCLIRetryableError
    util.IssueRetryableCommand(detach_cmd)

  def GetDevicePath(self):
    """Returns the path to the device inside the VM."""
    if not self.device_path:
      self._GetPathFromRemoteHost()
    return self.device_path

  def SetDiskId(self, id):
    """Sets Disk ID for the local disk case since Create() will not be called"""
    self.id = id

  @vm_util.Retry(log_errors=False, poll_interval=5, max_retries=10)
  def _GetPathFromRemoteHost(self):
    """Waits until VM is has booted."""
    readlink_cmd = 'readlink -e /dev/disk/by-id/virtio-%s' % self.id
    resp, _ = self.vm.RemoteHostCommand(readlink_cmd, suppress_warning=True)
    self.device_path = resp[:-1]
