#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
import logging
import os
import re
import psutil

_COLON_SEPARATED_RE = re.compile(r'^\s*(?P<key>.*?)\s*:\s*(?P<value>.*?)\s*$')

def _ParseTextProperties(text):
  """Parses raw text that has lines in "key:value" form.

  When comes across an empty line will return a dict of the current values.

  Args:
    text: Text of lines in "key:value" form.

  Yields:
    Dict of [key,value] values for a section.
  """
  current_data = {}
  for line in (line.strip() for line in text.splitlines()):
    if line:
      m = _COLON_SEPARATED_RE.match(line)
      if m:
        current_data[m.group('key')] = m.group('value')
      else:
        logging.debug('Ignoring bad line "%s"', line)
    else:
      # Hit a section break
      if current_data:
        yield current_data
        current_data = {}
  if current_data:
    yield current_data

class LsCpuResults(object):
  """Holds the contents of the command lscpu."""

  def __init__(self):
    """LsCpuResults Constructor.

    The lscpu command on Ubuntu 16.04 does *not* have the "--json" option for
    json output, so keep on using the text format.

    Args:
      lscpu: A string in the format of "lscpu" command

    Raises:
      ValueError: if the format of lscpu isnt what was expected for parsing

    Example value of lscpu is:
    Architecture:          x86_64
    CPU op-mode(s):        32-bit, 64-bit
    Byte Order:            Little Endian
    CPU(s):                12
    On-line CPU(s) list:   0-11
    Thread(s) per core:    2
    Core(s) per socket:    6
    Socket(s):             1
    NUMA node(s):          1
    Vendor ID:             GenuineIntel
    CPU family:            6
    Model:                 79
    Stepping:              1
    CPU MHz:               1202.484
    BogoMIPS:              7184.10
    Virtualization:        VT-x
    L1d cache:             32K
    L1i cache:             32K
    L2 cache:              256K
    L3 cache:              15360K
    NUMA node0 CPU(s):     0-11
    """
    lscpu = os.popen('lscpu ').read()
    self.data = {}
    for stanza in _ParseTextProperties(lscpu):
      self.data.update(stanza)

    def GetInt(key):
      if key in self.data and self.data[key].isdigit():
        return int(self.data[key])
      raise ValueError('Could not find integer "{}" in {}'.format(
          key, sorted(self.data)))

    if 'NUMA node(s)' in self.data:
      self.numa_node_count = GetInt('NUMA node(s)')
    else:
      self.numa_node_count = None
    self.logical_cores = GetInt('CPU(s)')
    if 'Core(s) per socket' in self.data:
      self.cores_per_socket = GetInt('Core(s) per socket')
      self.socket_count = GetInt('Socket(s)')
    else:
      self.cores_per_socket = GetInt('Core(s) per cluster')
      self.socket_count = GetInt('Cluster(s)')

    self.threads_per_core = GetInt('Thread(s) per core')

class SystemUnderTest:
  def __init__(self):

    self.ramdisk_root = "/home/archive"

    cmd_output = os.popen("uname -m").read()
    self.machine_name = cmd_output.rstrip(os.linesep)
    self.os_info = os.uname()[0]

    cmd_output = os.popen("uname -r").read()
    self.kernel_version = cmd_output.rstrip(os.linesep)

    self.lscpu_cache = LsCpuResults()

    if self.IsArm64Target():
        cpu_info=os.popen('cat /proc/cpuinfo | grep "CPU"').read().split("\n")
        self.cpu_model = cpu_info[0].split(":")[1]+" -"+cpu_info[1].split(":")[1]+" -"+cpu_info[2].split(":")[1]+" -"+cpu_info[3].split(":")[1]
        self.numa_node_count = 1
    else:
        self.cpu_model = os.popen('cat /proc/cpuinfo | grep "model name"').read().split("\n")[0].split(":")[1]
    self.numa_node_count = int(os.popen('lscpu | grep "NUMA node(s)"').read().split(":")[1].split("\n")[0])
    self.numa_node_count = self.lscpu_cache.numa_node_count
    self.threads_per_core = self.lscpu_cache.threads_per_core
    self.core_count = None
    self.core_count = self.GetCoreCount()
    self.thread_count = None
    self.numa_cores_list=[]
    numa_info = os.popen('numactl --hardware').read().split("\n")
    for idx in range(self.numa_node_count):
        cores_list = numa_info[3*idx+1].split(":")[1].strip().split(" ")
        self.numa_cores_list.append(cores_list)
    
    self.scripts_dir = '~/scripts_dir'
    
  @staticmethod
  def GetFingerPrint():
      raise NotImplementedError()
    
  def IsArm64Target(self):
    return self.machine_name == 'aarch64'

  def CheckLsCpu(self):
    if not self.lscpu_cache:
      self.lscpu_cache = LsCpuResults()
    return self.lscpu_cache

  def GetOsInfo(self):
    return self.os_info

  def GetNumaNodeCount(self):
    return self.numa_node_count

  def GetRamDiskPath(self):
    return self.ramdisk_root

  def MountRamDisk(self):
    mount_flag, _ = os.system('mount|grep -q "{}" && echo "True" || echo "False"'.format(self.ramdisk_root))
    if mount_flag.startswith('True'):
      os.system("rm -rf {}/*".format(self.ramdisk_root))
      os.system("umount -l {}".format(self.ramdisk_root))
    os.system("mkdir -p {}".format(self.ramdisk_root))
    os.system("mount -t tmpfs -o size=1G tmpfs {}".format(self.ramdisk_root))

  def UnmountRamDisk(self):
    mount_flag, _ = os.system('mount|grep -q "{}" && echo "True" || echo "False"'.format(self.ramdisk_root))
    if mount_flag.startswith('True'):
      os.system("rm -rf {}/*".format(self.ramdisk_root))
      os.system("umount -l {}".format(self.ramdisk_root))
    os.system("rmdir {}".format(self.ramdisk_root))

  def CopyFileToRamDisk(self, filename):
    #os.system('cp {} {}/'.format(filename, self.ramdisk_root))
    pass

  def DeleteFileFromRamDisk(self, filename):
    os.system('rm {}/{}'.format(self.ramdisk_root, filename))
  
  def CreateScriptsDirectory(self):
    os.system('mkdir -p {}'.format(self.scripts_dir))
    
  def SaveScript(self,test_name):
    os.system('mv ~/run_multi_ffmpeg1.sh {}/{}'.format(self.scripts_dir,test_name))

  def ParseUncoreOuput(self,output):
    minimum = None
    maximum = None
    if len(output) == 2:
      minimum = output[0]
      maximum = output[1]
    elif len(output) == 3:
      minimum = output[0]
      maximum = output[1:]
    else:
      minimum = output[1:]
      maximum = output[2:]
    if minimum:
      minimum = str(int(minimum, 16) * 100) + ' GHz'
    if maximum:
      maximum = str(int(maximum,16) * 100) + ' GHz'
    return minimum, maximum

  def GetUncore(self):
    check = self.CheckLsCpu() 
    unsupported_uncore = set(('AMD','ARM'))
    if check.data['Vendor ID'] in unsupported_uncore:
      return ['Not','Found']
    try:
      self.os.popen('modprobe msr')
      output, _ = self.os.popen('rdmsr 0x620')
      return self.ParseUncoreOuput(output.strip())
    except:
      return ['Not', 'Found']


  def GetCStates(self):
    # self.os.popen('ls -d /sys/devices/system/cpu/*')
    pass

  def GetScalingGovernor(self):
    if not self.CheckScalingGovernor():
      return "0:0"
    no_of_scaling_governors = os.system('ls /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2> /dev/null | wc -l | xargs echo -n')
    if int(no_of_scaling_governors == 0):
      logging.info("/sys/devices/system/cpu/cpu*/cpufreq/scaling_governor does not exists.")
      logging.info("Scaling governor mode stays unchanged.")
      return '0:0'
    total_in_performance = 0
    scaling_governers = os.popen('cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor').read()
    scaling_list = scaling_governers.split('\n')
    for governor in scaling_list:
      if governor == 'performance':
        total_in_performance += 1
    return "{}:{}".format(total_in_performance,no_of_scaling_governors)

  def CheckScalingGovernor(self):
    try:
      scaling_governers, _ = os.popen('cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor').read()
    except:
      return False
    scaling_list = scaling_governers.split('\n')
    for governor in scaling_list:
      if governor == 'powersave':
        return False
    return True
  def SetPerformanceMode(self):
    #os.popen('echo "performance" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor')
    pass

  def EnsurePerformanceMode(self):
    """
    Set scaling governor mode to performance if possible.
    """
    no_of_scaling_governers = os.popen('ls /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2> /dev/null | wc -l | xargs echo -n').read()
    if int(no_of_scaling_governers) == 0:
      logging.info("/sys/devices/system/cpu/cpu*/cpufreq/scaling_governor does not exists.")
      logging.info("Scaling governor mode stays unchanged.")
      return

    if self.CheckScalingGovernor():
      return
    else:
      self.SetPerformanceMode()

  def GetThreadCount(self):
    if not self.thread_count:
      check = self.CheckLsCpu()
      self.thread_count = check.cores_per_socket * check.socket_count * check.threads_per_core
    return self.thread_count

  def GetCoreCount(self):
    if not self.core_count:
      # core_regex = re.compile(r'\d{1}-(\d+)')
      # cores_line = self.vm.CheckLsCpu().data.get('On-line CPU(s) list', None)
      # self.core_count = int(re.search(core_regex, cores_line).group(1))

      # cores_line = int(self.vm.CheckLsCpu().data.get('Core(s) per socket', None))
      # self.core_count = int(cores_line)
      check = self.CheckLsCpu()
      self.core_count = check.cores_per_socket * check.socket_count
    return self.core_count

  def GetCoresPerSocket(self):
    check = self.CheckLsCpu()
    return check.cores_per_socket

  def GetSockets(self):
    check = self.CheckLsCpu()
    return check.socket_count

  def GetLogicalCoreCount(self):
    check = self.CheckLsCpu()
    return check.logical_cores

  def GetVirtualMemorySizeInMB(self):
    return psutil.virtual_memory().total / 1024 / 1024
