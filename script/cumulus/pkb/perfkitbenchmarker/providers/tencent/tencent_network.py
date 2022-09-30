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
"""Module containing classes related to Tencent VM networking.
"""
import json
import logging
import threading

from absl import flags
from perfkitbenchmarker import network
from perfkitbenchmarker import providers
from perfkitbenchmarker import resource
from perfkitbenchmarker import vm_util
from perfkitbenchmarker.providers.tencent import util

FLAGS = flags.FLAGS
TENCENT_CLOUD_EXCEPTION_STDOUT = '[TencentCloudSDKException]'


class TencentCloudVPCError(Exception):
  """Error for VPC-related failures."""


class TencentCloudNetworkUnknownCLIRetryableError(Exception):
  """Error for retrying commands when STDOUT returns an unexpected CLI error (and still exit 0)"""


class TencentNetwork(network.BaseNetwork):
  """Object representing a Tencent Network.

  Attributes:
    region: The Tencent region the Network is in.
    zone: The Zone within the region for this network.
    vpc: The Tencent VPC for this network.
    subnet: the Tencent for this zone.
  """

  CLOUD = providers.TENCENT

  def __repr__(self):
    return '%s(%r)' % (self.__class__, self.__dict__)

  def __init__(self, spec):
    """Initializes TencentNetwork instances.

    Args:
      spec: A BaseNetworkSpec object.
    """
    super(TencentNetwork, self).__init__(spec)
    self.region = util.GetRegionFromZone(spec.zone)
    self.zone = spec.zone
    self.vpc = TencentVpc(self.region)
    self.subnet = None
    self._create_lock = threading.Lock()

  def Create(self):
    """Creates the network."""
    self.route_table = None
    self.created = False
    self.vpc.Create()
    if self.subnet is None:
      cidr = self.vpc.NextSubnetCidrBlock()
      self.subnet = TencentSubnet(self.zone, self.vpc.id,
                                  cidr_block=cidr)
      self.subnet.Create()

  def Delete(self):
    """Deletes the network."""
    self.vpc.Delete()


class TencentVpc(resource.BaseResource):
  """An object representing an Tencent VPC."""

  def __init__(self, region):
    super(TencentVpc, self).__init__()
    self.region = region
    self.id = None
    self.name = 'perfkit-vpc-{0}'.format(FLAGS.run_uri)

    # _subnet_index tracks the next unused 10.0.x.0/24 block.
    self._subnet_index = 0
    # Lock protecting _subnet_index
    self._subnet_index_lock = threading.Lock()
    self.default_security_group_id = None

  @vm_util.Retry(poll_interval=5, log_errors=False, max_retries=5,
                 retryable_exceptions=(TencentCloudNetworkUnknownCLIRetryableError,))
  def _Create(self):
    """Creates the VPC."""
    create_cmd = util.TENCENT_PREFIX + [
        'vpc', 'CreateVpc',
        '--region', self.region,
        '--CidrBlock', '10.0.0.0/16',
        '--VpcName', self.name
    ] + util.TENCENT_SUFFIX
    stdout, _, _ = vm_util.IssueCommand(create_cmd)
    try:
      response = json.loads(stdout)
    except ValueError:
      logging.error(stdout)
      raise TencentCloudVPCError
    self.id = response['Vpc']['VpcId']

  def _PostCreate(self):
    """Looks up the VPC default security group."""
    util.AddDefaultTags(self.id, self.region)
    return

  @vm_util.Retry(poll_interval=5, log_errors=False, max_retries=5,
                 retryable_exceptions=(TencentCloudNetworkUnknownCLIRetryableError,))
  def _Exists(self):
    """Returns true if the VPC exists."""
    describe_cmd = util.TENCENT_PREFIX + [
        'vpc', 'DescribeVpcs',
        '--region', self.region,
        '--VpcIds', json.dumps([self.id])
    ] + util.TENCENT_SUFFIX
    stdout, _ = util.IssueRetryableCommand(describe_cmd)
    try:
      response = json.loads(stdout)
    except ValueError as e:
      logging.warn("Encountered unexpected return from command '{}', retrying.".format(e))
      raise TencentCloudNetworkUnknownCLIRetryableError
    assert response['TotalCount'] < 2, 'Too many VPCs.'
    return response['TotalCount'] > 0

  @vm_util.Retry(poll_interval=5, log_errors=False, max_retries=5,
                 retryable_exceptions=(TencentCloudNetworkUnknownCLIRetryableError,))
  def _Delete(self):
    """Deletes the VPC."""
    delete_cmd = util.TENCENT_PREFIX + [
        'vpc', 'DeleteVpc',
        '--region', self.region,
        '--VpcId', self.id
    ] + util.TENCENT_SUFFIX
    stdout, _, _ = vm_util.IssueCommand(delete_cmd)
    try:
      json.loads(stdout)
    except ValueError as e:
      if TENCENT_CLOUD_EXCEPTION_STDOUT not in stdout:
        logging.warn("Encountered unexpected return from command '{}', retrying.".format(e))
        raise TencentCloudNetworkUnknownCLIRetryableError

  def NextSubnetCidrBlock(self):
    """Returns the next available /24 CIDR block in this VPC.

    Each VPC has a 10.0.0.0/16 CIDR block.
    Each subnet is assigned a /24 within this allocation.
    Calls to this method return the next unused /24.

    Returns:
      A string representing the next available /24 block, in CIDR notation.
    Raises:
      ValueError: when no additional subnets can be created.
    """
    with self._subnet_index_lock:
      if self._subnet_index >= (1 << 8) - 1:
        raise ValueError('Exceeded subnet limit ({0}).'.format(
            self._subnet_index))
      cidr = '10.0.{0}.0/24'.format(self._subnet_index)
      self._subnet_index += 1
    return cidr


class TencentSubnet(resource.BaseResource):
  def __init__(self, zone, vpc_id, cidr_block='10.0.0.0/24'):
    super(TencentSubnet, self).__init__()
    self.zone = zone
    self.region = util.GetRegionFromZone(zone)
    self.vpc_id = vpc_id
    self.id = None
    self.cidr_block = cidr_block
    self.name = self._GetSubNetName()

  @vm_util.Retry(poll_interval=5, log_errors=False, max_retries=5,
                 retryable_exceptions=(TencentCloudNetworkUnknownCLIRetryableError,))
  def _Create(self):
    """Creates the subnet."""
    create_cmd = util.TENCENT_PREFIX + [
        'vpc', 'CreateSubnet',
        '--region', self.region,
        '--VpcId', self.vpc_id,
        '--SubnetName', self.name,
        '--CidrBlock', self.cidr_block,
        '--Zone', self.zone
    ] + util.TENCENT_SUFFIX
    stdout, _, _ = vm_util.IssueCommand(create_cmd)
    try:
      response = json.loads(stdout)
    except ValueError as e:
      logging.warn("Encountered unexpected return from command '{}', retrying.".format(e))
      raise TencentCloudNetworkUnknownCLIRetryableError
    self.id = response['Subnet']['SubnetId']
    util.AddDefaultTags(self.id, self.region)

  def _Delete(self):
    """Deletes the subnet."""
    delete_cmd = util.TENCENT_PREFIX + [
        'vpc', 'DeleteSubnet',
        '--region', self.region,
        '--SubnetId', self.id
    ] + util.TENCENT_SUFFIX
    stdout, _, _ = vm_util.IssueCommand(delete_cmd)
    try:
      json.loads(stdout)
    except ValueError as e:
      if TENCENT_CLOUD_EXCEPTION_STDOUT not in stdout:
        logging.warn("Encountered unexpected return from command '{}', retrying.".format(e))
        raise TencentCloudNetworkUnknownCLIRetryableError


  @vm_util.Retry(poll_interval=5, log_errors=False, max_retries=5,
                 retryable_exceptions=(TencentCloudNetworkUnknownCLIRetryableError,))
  def _Exists(self):
    """Returns true if the subnet exists."""
    describe_cmd = util.TENCENT_PREFIX + [
        'vpc', 'DescribeSubnets',
        '--region', self.region,
        '--SubnetIds', json.dumps([self.id])
    ] + util.TENCENT_SUFFIX
    stdout, _ = util.IssueRetryableCommand(describe_cmd)
    try:
      response = json.loads(stdout)
    except ValueError as e:
      logging.warn("Encountered unexpected return from command '{}', retrying.".format(e))
      raise TencentCloudNetworkUnknownCLIRetryableError
    assert response['TotalCount'] < 2, 'Too many Subnets.'
    return response['TotalCount'] > 0

  @classmethod
  def _GetSubNetName(cls):
    return 'perfkit_subnet_{0}'.format(FLAGS.run_uri)
