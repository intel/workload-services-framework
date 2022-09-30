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

"""Utilities for working with Tencent Cloud resources."""


import re
import shlex
import six

from perfkitbenchmarker import errors
from absl import flags
from perfkitbenchmarker import vm_util

TENCENT_PATH = 'tccli'
TENCENT_PREFIX = [TENCENT_PATH]
# Tencent positional args such as 'vpc' and 'CreateVpc' must come before flags, so format flag must come later.
TENCENT_SUFFIX = ['--output', 'json']
INSTANCE = 'instance'
FLAGS = flags.FLAGS

ADD_USER_TEMPLATE = '''#!/bin/bash
echo "{0} ALL = NOPASSWD: ALL" >> /etc/sudoers
useradd {0} --home /home/{0} --shell /bin/bash -m
mkdir /home/{0}/.ssh
echo "{1}" >> /home/{0}/.ssh/authorized_keys
chown -R {0}:{0} /home/{0}/.ssh
chmod 700 /home/{0}/.ssh
chmod 600 /home/{0}/.ssh/authorized_keys
'''


def TokenizeCommand(cmd):
  # This probably doesnt work for most Tencent commands that have JSON args - it strips quotes it seems
  cmd_line = ' '.join(cmd)
  cmd_args = shlex.split(cmd_line)
  return cmd_args


def IsRegion(region_or_zone):
  if not re.match(r'[a-z]{2}-[a-z]+$', region_or_zone):
    return False
  else:
    return True


def GetRegionFromZone(zone):
  """Returns the region a zone is in """
  m = re.match(r'([a-z]{2}-[a-z]+)-[0-9]?$', zone)
  if not m:
    raise ValueError(
        '%s is not a valid Tencent zone' % zone)
  return m.group(1)


@vm_util.Retry()
def IssueRetryableCommand(cmd, env=None):
  """Tries running the provided command until it succeeds or times out.

  Args:
    cmd: A list of strings such as is given to the subprocess.Popen()
        constructor.
    env: An alternate environment to pass to the Popen command.

  Returns:
    A tuple of stdout and stderr from running the provided command.
  """
  stdout, stderr, retcode = vm_util.IssueCommand(cmd, env=env)
  if retcode:
    raise errors.VmUtil.CalledProcessException(
        'Command returned a non-zero exit code.\n')
  if stderr:
    raise errors.VmUtil.CalledProcessException(
        'The command had output on stderr:\n%s' % stderr)
  return stdout, stderr


def AddTags(resource_id, region, **kwargs):
  """Adds tags to a Tencent cloud resource created by PerfKitBenchmarker.

  Args:
    resource_id: An extant Tencent cloud resource to operate on.
    region: The Tencent cloud region 'resource_id' was created in.
    **kwargs: dict. Key-value pairs to set on the instance.
  """
  if not kwargs:
    return

  tag_cmd = TENCENT_PREFIX + [
      'tag', 'AddResourceTag',
      '--Resource', f'qcs::cvm:{region}::{INSTANCE}/{resource_id}'
  ]
  for _, (key, value) in enumerate(six.iteritems(kwargs)):
    tmp_cmd = tag_cmd.copy()
    tmp_cmd.extend([
        '--TagKey', str(key),
        '--TagValue', str(value)
    ])
    vm_util.IssueRetryableCommand(tmp_cmd)


def AddDefaultTags(resource_id, region):
  """Adds tags to a Tencent cloud resource created by PerfKitBenchmarker.

  By default, resources are tagged with "owner" and "perfkitbenchmarker-run"
  key-value
  pairs.

  Args:
    resource_id: An extant Tencent cloud resource to operate on.
    region: The Tencent cloud region 'resource_id' was created in.
  """
  tags = {'owner': FLAGS.owner, 'perfkitbenchmarker-run': FLAGS.run_uri}
  AddTags(resource_id, region, **tags)
