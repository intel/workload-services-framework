#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

import datetime
import logging
import os
import posixpath
import re
import time
import yaml
import math
import subprocess  # nosec
import psutil
import uuid
import collections
from sut import SystemUnderTest
from sample import Sample
from performance_data import PerformanceData
import results as results

from absl import flags
FLAGS = flags.FLAGS

VIDEO_CODEC_DELIMITER = "//_"
VIDEO_RESULT_SUB_DIR = 'video_output_dir'

class FfmpegWorkload:
  """
  Function that kills all data and encoding processes. Some processes may not exist, leading to pkill returning a failure code.
  This function ignores failure.
  """
  def StopBenchmark(self):
    logging.info("Killing sar, dstat, and ffmpeg")
    os.system('pkill -9 sar')
    os.system('do pkill -9 dstat')
    os.system('pkill -9 ffmpeg')

  def __init__(self, run_tests, auto_mode="auto", config_file="benchmark_tests.yaml", videos_file="input_videos.yaml"):

    # Some generic functionality is factored out into the SystemUnderTest class
    self.sut = SystemUnderTest()

    if FLAGS.ffmpeg_debug_level_enable:
      logger = logging.getLogger()    # initialize logging class
      logger.setLevel(logging.NOTEST)  # default log level

    self.targets = []

    self.encoders = set()
    self.encoder_versions = {}

    self.svt_assembly = set()
    self.av1_assembly = set()

    self.work_directory="/home/"
    self.confpath=os.path.join(self.work_directory,"conf")

    self.video_files_dir=os.path.join(self.work_directory,"archive")
    #self.video_cache_dir=os.path.join(self.work_directory,"cache")
    self.video_cache_dir= FLAGS.ffmpeg_videos_dir
    self.bin_path="/usr/local/bin"
    self.use_cached_videos = self.video_cache_dir != ''

    self.run_tests=run_tests
    # Keep track of the success rate for this run
    self.num_tests_run = 0
    self.num_tests_passed = 0

    # The default threshold used when running LIVE mode
    self.default_fps_threshold = 60
    # The default CPU utilization to ensure tests succeeded
    self.default_cpu_threshold = 90.0

    # By default we are doing autoscaling. The initial instance count is initialized
    # here, but is set later when we read the YAML file to determine if the user is
    # overriding the autoscaling by specifying a specific number of instances.
    self.auto_scaling = True
    self.data_collection_cores_binding = False
    self.data_collection_stream_density = False
    self.auto_mode = auto_mode
    self.pkb_2 = FLAGS.pkb_2
    self.fixed_instance_count = 1

    self.cores_per_instance = 0
    self.cores_list = []
    self.numa_mem_set = []
    self.extract_duration = 10
    self.extract_frame = 500

    if "data-collection-cores-binding" in self.auto_mode:
        self.data_collection_cores_binding = True
        self.auto_scaling = False
        self.pkb_2 = False
    elif "data-collection-stream-density" in self.auto_mode:
        self.data_collection_stream_density = True
        self.auto_scaling = False
        self.pkb_2 = True
    elif "generic" in self.auto_mode:
        self.auto_scaling = True
        self.data_collection_cores_binding = False
        self.data_collection_stream_density = False
    else:
        self.auto_scaling = False
        self.data_collection_cores_binding = False
        self.data_collection_stream_density = False
        self.fixed_instance_count = int(auto_mode)
        if FLAGS.ffmpeg_cores_per_instance != "auto":
            self.cores_per_instance = int(FLAGS.ffmpeg_cores_per_instance)
        if FLAGS.ffmpeg_cores_list != "auto":
            self.numactl_flag = True
            self.cores_list = FLAGS.ffmpeg_cores_list.split(";")
            print("CORE list: ", FLAGS.ffmpeg_cores_list, self.cores_list, len(self.cores_list))
            if FLAGS.ffmpeg_numa_mem_set != "auto":
                self.numa_mem_set = FLAGS.ffmpeg_numa_mem_set.split(";")
                print("NUMA MEM SET: ", self.numa_mem_set, len(self.numa_mem_set))
                if len(self.cores_list) != len(self.numa_mem_set):
                    print("CORES_LIST num {} and NUMA_MEM_SET num {} not matched".format(len(self.cores_list),len(self.numa_mem_set)))
                    return
        if len(self.cores_list) > 0 and len(self.cores_list) != self.fixed_instance_count:
            print("Fixed instance: {} and cores list num {}: {} not matched".format(self.fixed_instance_count,len(self.cores_list),self.cores_list))
            return
        print("Fixed instance: {} and cores {} {} to run!".format(self.fixed_instance_count,FLAGS.ffmpeg_cores_per_instance, self.cores_per_instance))

    if FLAGS.ffmpeg_extract_duration != "auto":
      self.extract_duration = int(FLAGS.ffmpeg_extract_duration)
    
    if FLAGS.ffmpeg_extract_frame != "auto":
      self.extract_frame = int(FLAGS.ffmpeg_extract_frame)

    self.initial_instance_count =  0
    # The directories in which results are stored. After Provision and Prepare,
    # there is an output directory all_results_dir that holds the results for
    # each run. There can be multiple, separate, runs here, each of which has
    # its own directory, which includes the current date/time in the name
    self.all_results_dir = os.path.join(self.work_directory, 'results')
    self.run_date_time = time.strftime("%Y-%m-%d-%H-%M-%S")
    self.run_results_dir = "{}/{}_{}".format(self.all_results_dir, 'results', self.run_date_time)
    self.run_csv_filename = self.run_results_dir + "/results.csv"
    
    self.run_uri = str(uuid.uuid4())[-8:]
    
    self.results_collection = results.ResultsCollection()
    self.results_collection.add(results.CSV(self.run_csv_filename,"{}/results_{}.csv".format(os.getcwd(), self.run_uri)))
    self.results_collection.add(results.xlsx())

    # Read the list of available input videos
    self.videos_file=os.path.join(self.confpath,videos_file)
    self.available_videos = []
    self.ReadInputVideoFile()

    # Read the YAML configuration file into the self.config dictionary. ReadConfig also
    # populates a list of video files, referenced_videos, that are actually referenced
    # by the tests requested by the user. Later, we'll download and transcode only the
    # files that we actually need
    self.referenced_videos = []
    self.config = {}
    self.config_file=os.path.join(self.confpath,FLAGS.ffmpeg_config_file)
    print(FLAGS.ffmpeg_config_file)
    self.ReadConfigFile()

    # Some performance data collection during the run(s)
    self.perf_data = PerformanceData(self.sut)

    self.direct = False

    # Allow the FFMPEG benchmark to control the trace collectors. This is so we
    # can enable trace collection for only the last run. Once we find the right
    # number of iterations to use, the iteration is run again will the trace
    # collectors enabled
    self.control_traces = False

    self.ffmpeg_version = None

    self.numactl_flag = True if int(FLAGS.ffmpeg_enable_numactl) > 0 else False
    #print("NUMACTL : ",self.numactl_flag, FLAGS.ffmpeg_enable_numactl)
    self.cores_binding_flag = FLAGS.ffmpeg_enable_cores_binding
    if self.sut.IsArm64Target():
        self.numactl_flag = False
    self.prepare_time = 0
    self.ht_flag = FLAGS.ht_enable
    self.encoder_only_flag = False
    if FLAGS.ffmpeg_video_clip:
      video = self.referenced_videos[0]
      substrs = video.split(VIDEO_CODEC_DELIMITER)
      video_name = substrs[0].split('.')[0]
      codec_name = substrs[1]
      self.referenced_videos = [FLAGS.ffmpeg_video_clip+VIDEO_CODEC_DELIMITER+codec_name]

    if "encoder" in self.run_tests:
      self.encoder_only_flag = True

  def CreateResultsDirectoryForRun(self):
    os.system('mkdir -p {}'.format(self.run_results_dir))

  def RemoveAllResults(self):
    os.system('rm -rf {}/*'.format(self.all_results_dir))

  def Prepare(self):
    """Prepares the system for ffmpeg benchmark"""
    #self.always_call_cleanup = True
    #self.sut.MountRamDisk()
    # If we're using cached videos, they will be copied to the SUT during the Run
    # phase. Only the files actually used will be copied
    if self.encoder_only_flag:
      self.PrepareVideosForEncoder()

  def Cleanup(self):
    """Perform cleanup operation for the run"""
    self.RemoveAllResults()

  def InitializeOutputCSVValues(self):
    """Leverages the server info json to populate fields in the output file headers.
    """
    self.product_name = 'Not Found'
    self.TDP = 'Not Found'
    self.cpu_base = 'Not Found'
    self.mem_avail = self.get_mem_available()
    self.free_mem = self.get_mem_free() 
    self.mem_speed = 'Not Found'
    self.max_non_avx = 'Not Found'
    self.avx2_max = 'Not Found'
    self.avx512_max = 'Not Found'
    self.power_and_policy = 'Not Found'
    self.scaling_govs = self.sut.GetScalingGovernor()
    self.intel_turbo = 'Not Found'
    self.c_states = self.sut.GetCStates()
    #self.uncore = self.sut.GetUncore()

  def get_mem_available(self):
    available_regex = re.compile(r'[0-9]+\s+[0-9]+\s+[0-9]+\s+[0-9]+\s+[0-9]+\s+([0-9]+)')
    try:
      output = os.popen('free').read()
      split = output.split('\n')
      if split[1]:
        result = re.search(available_regex,split[1])
        return result.group(1) + ' kB'
    except:
      return 'Not Found'

  def get_mem_free(self):
    free_regex = re.compile(r'[0-9]+\s+[0-9]+\s+([0-9]+)')
    try:
      output = os.popen('free').read()
      split = output.split('\n')
      if split[1]:
        result = re.search(free_regex,split[1])
        return result.group(1) + ' kB'
    except:
      return 'Not Found'

  def InitializeOutputCSVFile(self):
    """Creates the output file headers.
    """
    cmd_output = os.popen('ffmpeg -version | grep "ffmpeg version"').read()
    ffmpeg_version = cmd_output.split(' ')[2]
    total_cores = self.sut.GetCoreCount()
    cores_per_socket = self.sut.GetCoresPerSocket()
    sockets = self.sut.GetSockets()
    file_header = 'FFmpeg Benchmark\n\n'
    file_header += 'Run Date & Time,{}\n\n'.format(self.run_date_time)
    file_header += '{:14s},="{}"\n'.format('Sub Test Case', self.run_tests)
    file_header += '{:14s},="{}"\n\n'.format('FFmpeg version', ffmpeg_version)
    file_header += '{:14s},="{}"\n'.format('SUT Model',self.product_name)
    file_header += '{:14s},="{}"\n'.format('CPU Model', self.sut.cpu_model)
    file_header += '{:14s},="{}"\n'.format('Kernel version', self.sut.kernel_version)
    file_header += '{:14s},="{}"\n'.format('CPU TDP',self.TDP)
    file_header += '{:14s},="{}"\n'.format('CPU Base Frequency',self.cpu_base)
    file_header += '{:14s},="{}"\n'.format('Physical Cores per CPU',cores_per_socket)
    file_header += '{:14s},="{}"\n'.format('SUT Sockets Under Test', sockets)
    file_header += '{:14s},="{}"\n'.format('Physical Cores Per SUT',total_cores)
    file_header += '{:14s},="{}"\n'.format('Threads Per Core',self.sut.threads_per_core)
    file_header += '{:14s},="{}"\n'.format('Logical Cores Under Test', self.sut.GetThreadCount())
    #file_header += '{:14s},="{}"\n'.format('Installed Memory',self.kb_mem_installed)
    file_header += '{:14s},="{}"\n'.format('Available Memory',self.mem_avail)
    file_header += '{:14s},="{}"\n'.format('Free Memory',self.free_mem)
    file_header += '{:14s},="{}"\n'.format('Memory Speed',self.mem_speed)
    file_header += '{:14s},="{}"\n'.format('Non-AVX Max All Cores Turbo Frequency',self.max_non_avx)
    file_header += '{:14s},="{}"\n'.format('AVX2 Max All Cores Turbo Frequency',self.avx2_max)
    file_header += '{:14s},="{}"\n'.format('AVX512 Max All Cores Turbo Frequency',self.avx512_max)
    file_header += '{:14s},="{}"\n'.format('Power and Policy',self.power_and_policy)
    file_header += '{:14s},="{}"\n'.format('Scaling Governors (Performance Mode: Total)',self.scaling_govs)
    file_header += '{:14s},="{}"\n'.format('Intel Turbo',self.intel_turbo)
    file_header += '{:14s},="{}"\n'.format('C-States',self.c_states)
    #file_header += '{:14s},="{}"\n'.format('Uncore Frequency (Min / Max)',self.uncore[0] + ' ' + self.uncore[1])
    file_header += '{:14s},="{}"\n\n'.format('SUT Operating System', self.sut.GetOsInfo())
    file_header += '{:14s},="{}"\n'.format('Benchmark Config file', self.config_file)
    file_header += '{:14s},="{}"\n'.format('Benchmark Results dir', self.run_results_dir)
    file_header += '{:14s},="{}"\n\n'.format('Benchmark Video dir', self.video_files_dir)
    file_header += 'Use Case Name,Duration (s),Codec,Resolution,uArch,Preset,FFmpeg Result (fps), Wall Clock Result (fps),# instances, lowest_fps, fps list,'
    file_header += 'CPU Utilization (%),CPU (MHz),Memory Utilization (%), Completion Codes, FFmpeg_args'
    self.results_collection.write(file_header)

  def CaculateInitialInstancesNumber(self,codec):
    base=8
    if codec == "svthevc":
        codec = "SVT-HEVC"
    elif codec == "svtav1":
        codec = "SVT-AV1"

    switcher = {
        "SVT-HEVC": 1,
        "SVT-AV1": 1,
        "x265": 2,
        "x264": 1,
        "vpx-vp9": 1,
    }
    factor_inc = {
        "SVT-HEVC": 2,
        "SVT-AV1": 1,
        "x265": 1,
        "x264": 2,
        "vpx-vp9": 2,
    }

    cores=psutil.cpu_count()
    base_cores=base*switcher.get(codec,1)
    instances= int(cores*1.0/base_cores+2*factor_inc.get(codec,1))
    return instances

  def GetInstances(self,fps_threshold):
    fps_defatult=60

    codec,preset,output,mode,resolution=self.run_tests.split("-")
    if codec == "svthevc":
        codec = "SVT-HEVC"
    elif codec == "svtav1":
        codec = "SVT-AV1"

    max_per_codec = {
        "SVT-HEVC": 16,
        "SVT-AV1": 16,
        "x265": 20,
        "x264": 32,
        "vpx-vp9": 24,
    }
    min_per_codec = {
        "SVT-HEVC": 3,
        "SVT-AV1": 3,
        "x265": 3,
        "x264": 4,
        "vpx-vp9": 3,
    }
    factor_per_transcode = {
        "SVT-HEVC": 4,
        "SVT-AV1": 4,
        "x265": 4,
        "x264": 3,
        "vpx-vp9": 3,
    }
    instances_per_core = {
        "SVT-HEVC": 0.04,
        "SVT-AV1": 0.04,
        "x265": 0.04,
        "x264": 0.08,
        "vpx-vp9": 0.08,
    }
    instances_per_resolution = {
        "480p": 0.25,
        "720p": 0.5,
        "1080p": 1,
        "2k": 4,
        "4k": 16,
    }
    instances_per_preset = {
        "veryslow": 0.25,
        "slow": 0.5,
        "medium": 1,
        "fast": 2,
        "veryfast": 4,
    }
    instances_per_output = {
        "1to1": 1,
        "1to4": 0.5,
        "1ton": 0.25,
    }

    cores=psutil.cpu_count()
    factor = 1.0
    if codec in instances_per_core:
        factor = factor * instances_per_core[codec]

    if codec in factor_per_transcode:
        factor = factor * factor_per_transcode[codec]

    if resolution in instances_per_resolution:
        factor = factor * instances_per_resolution[resolution]

    if preset in instances_per_preset:
        factor = factor * instances_per_preset[preset]

    if output in instances_per_output:
        factor = factor * instances_per_output[output]

    inc_instances = 1
    if cores <= 16:
        inc_instances = 1
    elif cores <= 48:
        inc_instances = 2
    else:
        inc_instances = 4

    max_instances = cores * factor * fps_defatult / fps_threshold
    max_instances = int((max_instances+inc_instances)/inc_instances)*inc_instances
    max_instances = max_instances if max_instances < max_per_codec[codec] else max_per_codec[codec]
    max_instances = max_instances if max_instances > min_per_codec[codec]  else min_per_codec[codec]

    return max_instances, inc_instances

  def CodecToPackage(self, codec):
    switcher = {
        "SVT-HEVC": "svthevc",
        "SVT-AV1": "svtav1",
        "x265": "x265",
        "x264": "x264",
        "vpx-vp9": "vp9",
    }
    return switcher.get(codec, "nothing")

  def CodecToOption(self, codec):
    switcher = {
        "SVT-HEVC": "-c:v libsvt_hevc",
        "SVT-AV1": "-c:v libsvtav1",
        "x265": "-c:v libx265",
        "x264": "-c:v libx264",
    }
    return switcher.get(codec, "nothing")

  def CodecToExecutableName(self, codec):
    switcher = {
        'SVT-HEVC': self.bin_path+'/SvtHevcEncApp',
        'SVT-AV1': self.bin_path+'/SvtAv1EncApp',
        'x265': self.bin_path+'/x265',
        'x264': self.bin_path+'/x264',
        'vpx-vp9': self.bin_path+'/vpxenc'
    }
    if self.direct:
      return switcher.get(codec, "nothing")
    executable_binary=self.bin_path+'/ffmpeg -y'
    if FLAGS.ffmpeg_extract_duration != "auto":
      executable_binary += " -t {}".format(self.extract_duration)
    if self.encoder_only_flag:
      return executable_binary+" -stream_loop 2"
    return executable_binary

  def PresetToOption(self, codec, preset):
    # The vp9 codec doesn't have any presets
    if codec == 'vpx-vp9':
      return ''
    return '-preset ' + str(preset)

  def TuneToOption(self, tune):
    return '-tune ' + str(tune)

  def GetTargets(self, initial_target_list):
    full_target_list = []

    for target in initial_target_list:
      if target not in self.config.keys():
        raise Exception('ERROR: The test \"{}\" is not present in the test configuration file'.format(target))
      elif 'group' in self.config[target].keys():
        for t1 in self.config[target]['group'].split():
          for sub_target in self.GetTargets([t1]):
            if sub_target not in full_target_list:
              full_target_list.append(sub_target)
      else:
        if target not in full_target_list:
          full_target_list.append(target)

    return full_target_list

  def ReadConfigFile(self):
    """Populate the config dictionary from the YAML configuration file
       and build a list of available input videos"""

    # Parse the YAML file into the self.config dictionary
    with open(self.config_file) as file:
      self.config = yaml.load(file, Loader=yaml.SafeLoader)

    # Create a list of the videos that are referenced by the requested tests.
    # These videos will be processed to specific video formats later, during
    # the Prepare phase.
    for test in self.GetTargets(self.run_tests.split(',')):
      if 'input_files' in self.config[test].keys():
        self.targets.append(test)
        for video in (self.config[test]['input_files']).split():
          try:
            # Each entry in the input video files list is a string that has both the input video
            # filename and the code name, separated by the VIDEO_CODEC_DELIMITER. We should change
            # this to use a more legit data structure
            encoded_name = video + VIDEO_CODEC_DELIMITER + self.config[test]['video_codec']['codec']
            self.encoders.add(self.config[test]['video_codec']['codec'])
            if encoded_name not in self.referenced_videos:
              self.referenced_videos.append(encoded_name)
            if self.config[test]['video_codec']['codec'] == 'SVT-HEVC':
              self.svt_assembly.add(self.config[test]['assembly'])
            if self.config[test]['video_codec']['codec'] == 'SVT-AV1':
              self.av1_assembly.add(self.config[test]['assembly'])
          except KeyError:
            logging.error('The \'{}\' entry in {} is invalid'.format(test, self.config_file))
    print(self.referenced_videos)

  def ReadInputVideoFile(self):
    with open(self.videos_file) as file:
      config = yaml.load(file, Loader=yaml.SafeLoader)
      self.available_videos = config['input_videos']
      return self.available_videos

  def execute(self,cmd):
      #cmd =["python3", "demos/demo_reconstruct.py", "-i",inpath, "-s",outpath,"--saveDepth", "True", "--saveObj", "True"]
      #p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=1, universal_newlines=True)
      p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=1, universal_newlines=True,shell=True)
      p.poll()
      p1=psutil.Process(p.pid)
      while p.returncode is None:
        next_line = p.stderr.readline()
        #print(next_line)
        p.poll()
      if p.returncode:
        return False 
      else:
        return True

  def PrepareVideosForEncoder(self):
    """Extract video files"""
    print("PrepareVideosForEncoder",flush=True)
    def Extract(video, duration=10, extract_frame=500):
      logging.info("start value is {}".format(video))
      substrs = video.split(VIDEO_CODEC_DELIMITER)
      video_name = substrs[0].split('.')[0]
      codec_name = substrs[1]
      print(video_name)
      cmd_select = 0
      if FLAGS.ffmpeg_extract_duration != "auto":
       duration = self.extract_duration
      elif FLAGS.ffmpeg_extract_frame != "auto":
        extract_frame = self.extract_frame
        cmd_select = 1

      logging.info("video filename is {}.y4m".format(video_name.lower()))
      cmd='cd {} && test -f  {}.y4m && echo "True" || echo "False"'.format(self.video_files_dir, video_name)
      video_exists = os.popen(cmd).read()
      logging.info("Raw video_exists is {}".format(video_exists))
      if video_exists.startswith('False'):
        retries = 3
        while True:
          try:
            video_file_path=self.video_files_dir+"/"+video_name
            if cmd_select == 0:
              cmd="ffmpeg -i {}.mp4 -ss 0 -t {} -strict -1 -pix_fmt yuv420p -y {}.y4m 2>&1 ".format(video_file_path, duration, video_file_path)
            else:
              cmd="ffmpeg -i {}.mp4 -vf \"select=between(n\,0\,{})\" -y -acodec copy {}.y4m 2>&1 ".format(video_file_path, extract_frame, video_file_path)
            print(cmd,flush=True)
            ret = self.execute(cmd)
            if ret:
              print("Prepare encoder input {}.y4m with {}s {} frames successfully!".format(video_file_path,duration,extract_frame))
              #os.system(cmd)
              break
          except Exception as e:
            retries -= 1
            logging.warning("failed to extract video from {}, retrying...".format(video_file_path+".mp4"))
            if retries == 0:
              raise e

    start_time = datetime.datetime.now()
    cmd='mkdir -p {}'.format(self.video_files_dir)
    os.system(cmd)
    for ref_video in self.referenced_videos:
      Extract(ref_video, self.extract_duration, self.extract_frame)
    end_time = datetime.datetime.now()
    self.prepare_time = end_time - start_time
  
  def PrepareVideos(self):
    """Download and extract video files"""
    def DownloadAndExtract(video):
      logging.info("start value is {}".format(video))
      substrs = video.split(VIDEO_CODEC_DELIMITER)
      video_name = substrs[0].split('.')[0]
      codec_name = substrs[1]

      for video_info in self.available_videos:
        if 'filename' in video_info:
          if video_name.lower() == video_info['filename'].lower():
            logging.info("video filename is {}.y4m".format(video_name.lower()))
            cmd='cd {} && test -f  {}.y4m && echo "True" || echo "False"'.format(self.video_files_dir, video_name)
            video_exists = os.popen(cmd).read()
            logging.info("Raw video_exists is {}".format(video_exists))
            if video_exists.startswith('False'):
              retries = 3
              while True:
                try:
                  cmd="cd {} && wget -q --no-check-certificate {}".format(self.video_files_dir, video_info['url'])
                  os.system(cmd)
                  break
                except Exception as e:
                  retries -= 1
                  if retries == 0:
                    raise e
                  logging.warning("failed to download video from {}, retrying...".format(video_info['url']))

            # 'veryslow' isn't a preset option for SVT-HEVC
            if codec_name == 'SVT-HEVC':
              preset = '3'
            elif codec_name == 'SVT-AV1':
              preset = '3'
            else:
              preset = 'veryslow'

            cmd='cd {} && test -f  {}_{}.mp4 && echo "True" || echo "False"'.format(self.video_files_dir, video_name,codec_name)
            video_exists = os.popen(cmd).read()
            logging.info("Mp4 video_exists is {}".format(video_exists))
            if video_exists.startswith('False'):
              ffmpeg_cmd = "ffmpeg -stream_loop 6 -i "
              ffmpeg_cmd += "{}/{}.y4m ".format(self.video_files_dir, video_info['filename'])
              ffmpeg_cmd += "{} {} ".format(self.CodecToOption(codec_name), self.PresetToOption(codec_name, preset))
              ffmpeg_cmd += "-b:v {} {}/".format(video_info['bitrate'], self.video_files_dir)
              ffmpeg_cmd += "/{}_{}.mp4".format(video_info['filename'], codec_name)
              print(ffmpeg_cmd)
              self.execute(ffmpeg_cmd)

    start_time = datetime.datetime.now()
    cmd='mkdir -p {}'.format(self.video_files_dir, self.video_files_dir)
    os.system(cmd)
    for ref_video in self.referenced_videos:
      DownloadAndExtract(ref_video)
    end_time = datetime.datetime.now()
    self.prepare_time = end_time - start_time

  def Run(self,arch):
    """Runs the ffmpeg benchmark"""

    # Ensure that the scaling governor is set to Performace instead of Powersave only
    # if hypervisor allows changing scaling governor mode.
    self.sut.EnsurePerformanceMode()

    # It is possible to invoke Run multiple times (--run_state=Run). Each run will have
    # a different timestamp, so the results will automatically be in a different results
    # directory. Let's create this output directory and initialize the output CSV file.
    self.CreateResultsDirectoryForRun()
    self.InitializeOutputCSVValues()
    self.InitializeOutputCSVFile()
    self.sut.CreateScriptsDirectory()

    # Get the list of targets (tests to be invoked) that the user has specified
    targets = self.GetTargets(self.run_tests.split(','))
    logging.info('targets: {}'.format(str(targets)))

    # Initialize an empty list of samples. This list will be populated by each test in the
    # run. In addition, a couple summary samples will be appended after the run.
    samples = []

    # Keep track of how long the overall run takes
    start_time = datetime.datetime.now()

    # For each test in the target list, get the parameters of the test from the
    # YAML-derived configuration and execute the test
    for test in sorted(targets):
      try:
        # These values are required for every test target
        codec = self.config[test]['video_codec']['codec']
        input_format = self.config[test]['input_format']
        unsupported_avx3 = set(('ARM',))
        vendor_id = self.sut.CheckLsCpu().data['Vendor ID']

        if len(input_format.split('-')) == 1:
            input_format = input_format+"-none"
        elif vendor_id in unsupported_avx3:
            input_format = input_format.split('-')[0] + "-none"

        video_files = self.config[test]['input_files'].split()

        if FLAGS.ffmpeg_video_clip:
          video_files = [FLAGS.ffmpeg_video_clip]

        full_output_mode = self.config[test]['output_mode']['type']
        output_mode, test_mode = full_output_mode.split('/', 2)

        # The user can specify a number of instances to use, which disables autoscaling. When
        # this value is is specified, the workload makes only one pass. The use of this option
        # in the YAML file applies to both LIVE and VOD modes
        if 'num_instances' in self.config[test].keys():
          self.auto_scaling = False
          self.data_collection_cores_binding = False
          self.data_collection_stream_density = False
          self.initial_instance_count = self.config[test]['num_instances']
        else:
          if test_mode == 'VOD':
            # For VOD mode, the instance count starts at 1 and increments by 1 each time
            self.initial_instance_count = 1
          elif test_mode == 'LIVE':
            # For LIVE mode, the instance count starts at 8 and the next instance count
            # is computed based on the results of the previous run
            self.initial_instance_count = 2 
          else:
            logging.error("Invalid test_mode specified")

        # The FPS threshold is optional. If not provided, the default will be used
        if 'fps_threshold' in self.config[test]['output_mode'].keys():
          fps_threshold = self.config[test]['output_mode']['fps_threshold']
        else:
          fps_threshold = self.default_fps_threshold

        # Optional variable that specifies whether to run the encoder/decoder directly
        if 'direct' in self.config[test]['video_codec']:
          self.direct = self.config[test]['video_codec']['direct']

        # There are no presets for VP9 or when using direct mode
        preset = ''
        if 'preset' in self.config[test]['video_codec']:
          preset = self.config[test]['video_codec']['preset']

        # The codec preset tuning parameter is also optional and not used in direct mode
        tune = ''
        if 'tune' in self.config[test]['video_codec']:
          tune = self.TuneToOption(self.config[test]['video_codec']['tune'])

        self.pvswitches = self.config[test].get('pre-video_switches')
        # Normal FFMPEG invocation includes the codec and any presets and preset tuning parameters,
        # while direct invocation only uses the rest of the command line ('args') from the YAML file. So,
        # if we're not in direct mode create the command-line parameters for the codec/preset/tune options
        # However, there is an exception: If in 1:n output mode, these options go with the command lines
        # for the separate output sections so we don't need to do anything here
        args = ''
        if not self.direct:
          # However, if we're using 1:n mode then the codec and preset options are provided later
          # with each of the outputs instead of here, which is at the beginning of the command line
          if output_mode != '1:n':
            # Convert the specifiec codec to a command-line option
            args = "{} ".format(self.CodecToOption(codec))

            # Limit max number of threads
            if codec == 'SVT-HEVC' and self.sut.GetThreadCount() > 264:
              args += "-thread_count 528 "

            if preset:
              # Convert the specified preset to a command-line option
              args += "{} ".format(self.PresetToOption(codec, preset))
              if tune:
                args += "{} ".format(tune)

        # Add the rest of the command line from 'args' section in the YAML file
        if output_mode == '1:n':
          ffmpeg_args = self.config[test]['video_codec']['args']
          ffmpeg_args = ffmpeg_args.replace("${codec}", self.CodecToOption(codec))
          ffmpeg_args = ffmpeg_args.replace("${preset}", self.PresetToOption(codec, preset))
          args = ffmpeg_args
        else:
          args += self.config[test]['video_codec']['args']
          logging.info("Running with args: {}".format(args))
        # modify ARM args
        if arch=="arm64":
          args=args.replace(":asm=avx2", "")
        logging.info("arch={} , args={}".format(arch, args))

      except KeyError:
        logging.error('The \'{}\' entry in {} is invalid'.format(test, self.config_file))

      for video_file in video_files:
        # If we're accessing the codec binaries directly rather than through the ffmpeg front-end,
        # then we use the raw (y4m) video files rather than the prepared versions (mp4)
        video_file_basename = video_file.split('.')[0]
        if self.direct:
          video_filename = video_file_basename + '.y4m'
        else:
          if FLAGS.pkb_2:
            if self.encoder_only_flag:
              video_filename = video_file_basename + '.y4m'
            else:
              video_filename = video_file_basename + '.mp4'
          else:
            video_filename = video_file_basename + '_' + codec + '.mp4'

        ramdisk_path = self.sut.GetRamDiskPath()

        # The video files will either be cached on the host, or in the video_files_dir on the SUT.
        # For either case, the required input file will be copied to the RAM disk
        already_in_ramdisk = os.popen('cd {} && test -f  \'{}\' && echo "True" || echo "False"'.format(ramdisk_path, video_filename)).read().split("\n")[0]
        logging.info("File {} already in RamDisk: {}".format(video_filename, already_in_ramdisk))

        self.RunMulti(test, args, ramdisk_path, video_filename, codec, input_format, full_output_mode, preset, fps_threshold, samples)
        #self.sut.DeleteFileFromRamDisk(video_filename)

    # Add a summary sample that provides the overall success rate (% tests meeting SLA)
    summary_metadata = {} 
    summary_metadata['num_tests_run'] = self.num_tests_run
    summary_metadata['num_tests_passed'] = self.num_tests_passed
    success_percentage = int((self.num_tests_passed / self.num_tests_run) * 100)

    # Add the total run-time for this iteration to the CSV file and transfer it from the SUT to the host
    end_time = datetime.datetime.now()
    diff_datetime = end_time - start_time
    run_time_interval = diff_datetime.seconds + diff_datetime.microseconds/1000000

    summary_metadata['success_percentage']=success_percentage
    summary_metadata['run_time']="{}".format(run_time_interval)
    samples.append(Sample('% of tests meeting SLA', success_percentage, '%', metadata=summary_metadata))

    self.results_collection.write('Total Runtime: {}'.format(run_time_interval))
    self.results_collection.close()

    #os.system('echo '"'\nSuccess Percentage(SLA): {}% {}/{}'"' >> {}'.format(success_percentage, self.num_tests_passed, self.num_tests_run, self.run_csv_filename))
    #os.system('echo '"'\nTotal Runtime: {}'"' >> {}'.format(diff_datetime, self.run_csv_filename))

    # Return the samples generated by the tests
    return samples,summary_metadata

  def GetNumberOfOutputFiles(self, ffmpeg_args):
    """Get the number of output files"""
    return ffmpeg_args.count('-c:v')

  def RunMulti(self, sub_test_name, ffmpeg_args, video_path, video_file, codec, input_format, full_output_mode, preset, fps_threshold, samples):
    """Create and run the ffmpeg workload bash script on the SUT"""
    logging.info('Running test: \"{}\" with video file: \"{}\"'.format(sub_test_name, video_file))

    # Create the output directory on the SUT for the results
    #test_results_dir = posixpath.join(self.run_results_dir, codec, input_format, full_output_mode, str(preset), video_file)
    test_results_dir = posixpath.join(self.run_results_dir, sub_test_name)
    logging.info('result dir {}'.format(test_results_dir))
    a_output = 'ffmpeg.out_'
    os.system('mkdir -p {}'.format(test_results_dir))

    # Initialize some key counters
    total_fps = prev_total_fps = best_total_fps = avg_cpu_utilization = lowest_fps = pre_lowest_fps = 0

    # Split the output mode and test mode from the combined output/test mode
    output_mode, test_mode = full_output_mode.split('/', 2)

    # Build the command line
    arg_array = [self.CodecToExecutableName(codec)]
    ffmpeg_frame_output = ""
    if FLAGS.ffmpeg_extract_duration == "auto" and FLAGS.ffmpeg_extract_frame != "auto":
      ffmpeg_frame_output += " -vframes {}".format(self.extract_frame)
    if self.direct:
      arg_array.extend([ffmpeg_args, posixpath.join(video_path, video_file),ffmpeg_frame_output])
    elif self.pvswitches:
      arg_array.extend([self.pvswitches, '-i', posixpath.join(video_path, video_file),ffmpeg_frame_output,ffmpeg_args])
    else:
      arg_array.extend(['-i', posixpath.join(video_path, video_file), ffmpeg_frame_output, ffmpeg_args])
    ffmpeg_cmd_line = ' '.join(arg_array)

    def CreateRunScript(num_inst, with_traces=False):
      script = '#!/bin/bash\n'

      # Create the output directory for this iteration
      suffix = "_w_traces" if with_traces else ""
      script += 'cd {} && mkdir -p {}_instance{}\n'.format(test_results_dir, num_inst, suffix)
      script += 'declare -A ffmpeg_wait_pids\n'
      if (codec == 'SVT-HEVC' or codec == 'SVT-AV1') and 'avx512' in input_format:
        script += 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$HOME/ffmpeg_build/lib:$HOME/ffmpeg_build/lib/avx512\n'
      elif (codec == 'SVT-HEVC' or codec == 'SVT-AV1') and 'avx2' in input_format:
        script += 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$HOME/ffmpeg_build/lib:$HOME/ffmpeg_build/lib/avx2\n'
      else:
        script += 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$HOME/ffmpeg_build/lib:$HOME/ffmpeg_build/lib/avx2\n'

      # Launch perf monitoring commands only if we're not doing the run with trace collectors enabled
      if not with_traces:
        script += 'pkill sar\npkill dstat\n'
        script += 'declare -A perf_wait_pids\n'
        script += 'sar -r 1 > {} 2>/dev/null &\n'.format(sar_output)
        script += 'perf_wait_pids[0]=$!\n'
        if test_mode == 'VOD':
          script += '(sleep 10; sar -u 2 30 > {}) 2>/dev/null &\n'.format(sar_cpu_output)
          script += '(sleep 10; sar -m CPU 2 30 > {}) 2>/dev/null &\n'.format(sar_cpu_mhz_output)
        else:
          script += '(sleep 10; sar -u 2 30 > {}) 2>/dev/null &\n'.format(sar_cpu_output)
          script += '(sleep 10; sar -m CPU 2 30 > {}) 2>/dev/null &\n'.format(sar_cpu_mhz_output)
        script += 'dstat --output {} >/dev/null 2>/dev/null &\n'.format(dstat_output)
        script += 'perf_wait_pids[1]=$!\n'
        script += '(while true; do sleep 2; echo -n \'{}\'; done;) &\n'.format('.')
        script += 'perf_wait_pids[2]=$!\n'
      script += 'date +%s.%N > {}/timestamps.txt\n'.format(test_results_dir)
      
      # Launch the ffmpeg processes
      toral_physical_cores=self.sut.GetCoresPerSocket()
      total_logical_cores=self.sut.GetLogicalCoreCount()
      cores_per_instance=int(total_logical_cores/num_inst)
      if self.data_collection_cores_binding:
        self.cores_per_instance = cores_per_instance
      if self.cores_per_instance > 0:
        cores_per_instance = self.cores_per_instance
      # print('cores_per_inst = ', cores_per_instance)
      # print('self.core_per_instance = ', self.cores_per_instance)

      ffmpeg_cmd_final = ""
      for i in range(num_inst):
        ffmpeg_cmd_final = ""
        # cd to per instance dir, so it's guaranteed that there won't be
        # an existing output file. When an output file exists, ffmpeg
        # will prompt you to overwrite or not in interactive session.
        # but fails when ffmpeg is run via subprocess, bash combination.
        # Directory for output file is created so that it can be torn down later.
        save_results_dir = '{}/{}_instance{}'.format(test_results_dir, num_inst, suffix)
        video_output_dir = '{}/{}'.format(save_results_dir, VIDEO_RESULT_SUB_DIR)
        script += 'mkdir -p {}\n'.format(video_output_dir)
        script += 'cd {}\n'.format(video_output_dir)
        if self.numactl_flag:
          numa_node = i % self.sut.GetNumaNodeCount()
          inst_idx = int(i / self.sut.GetNumaNodeCount())
          if len(self.cores_list) > 0:
              numa_cores = self.cores_list[i]
              numa_idx = 0
              for idx in range(self.sut.GetNumaNodeCount()):
                 if numa_cores[0] in self.sut.numa_cores_list[idx]:
                     numa_idx = idx
              if len(self.numa_mem_set) > 0:
                  numa_idx = int(self.numa_mem_set[i])

              if codec == "x265":
                  numa_pools = ["-" for idx in range(self.sut.GetNumaNodeCount())]
                  numa_pools[numa_idx] = str(len(numa_cores.split(",")))
                  numa_pools = "numa-pools="+(",").join(numa_pools)+":pools={}".format(str(len(numa_cores.split(","))))
                  ffmpeg_cmd_line_1 = re.sub(r'pools=\d+',numa_pools,ffmpeg_cmd_line)
              else:
                  ffmpeg_cmd_line_1 = ffmpeg_cmd_line
              ffmpeg_cmd_final = 'numactl --physcpubind={} --localalloc -- {} > {}/{}{:d} 2>&1 &\n' \
                  .format(numa_cores, ffmpeg_cmd_line_1, save_results_dir, a_output, i + 1)
              if len(self.numa_mem_set) > 0:
                  numa_mem_set = int(self.numa_mem_set[i])
                  ffmpeg_cmd_final = 'numactl --membind={:d} --physcpubind={} -- {} > {}/{}{:d} 2>&1 &\n' \
                     .format(numa_mem_set, numa_cores, ffmpeg_cmd_line_1, save_results_dir, a_output, i + 1) 
          elif self.cores_per_instance > 0:
              if codec == "x265":
                  numa_pools = ["-" for idx in range(self.sut.GetNumaNodeCount())]
                  numa_pools[numa_node] = str(cores_per_instance)
                  numa_pools = "numa-pools="+(",").join(numa_pools)+":pools={}".format(str(cores_per_instance))
                  ffmpeg_cmd_line_1 = re.sub(r'pools=\d+',numa_pools,ffmpeg_cmd_line)
                  ffmpeg_cmd_final = 'numactl --membind={:d} --cpunodebind={:d} -- {} > {}/{}{:d} 2>&1 &\n' \
                      .format(numa_node, numa_node, ffmpeg_cmd_line_1, save_results_dir, a_output, i + 1)
              else:
                  cores_begin = int(inst_idx*cores_per_instance)
                  cores_end = int((inst_idx+1)*cores_per_instance)
                  numa_cores = (",").join(self.sut.numa_cores_list[numa_node][cores_begin:cores_end])
                  if self.ht_flag and (cores_begin +toral_physical_cores) < self.sut.threads_per_core * self.sut.GetCoresPerSocket():
                      cores_begin = int(inst_idx*cores_per_instance)+toral_physical_cores
                      cores_end = int((inst_idx+1)*cores_per_instance)+toral_physical_cores
                      numa_cores = ",".join(numa_cores.split(",") + self.sut.numa_cores_list[numa_node][cores_begin:cores_end])
                  ffmpeg_cmd_final = 'numactl --membind={:d} --physcpubind={} -- {} > {}/{}{:d} 2>&1 &\n' \
                      .format(numa_node, numa_cores, ffmpeg_cmd_line, save_results_dir, a_output, i + 1)
          else:
              ffmpeg_cmd_final += 'numactl --membind={:d} --cpunodebind={:d} -- {} > {}/{}{:d} 2>&1 &\n' \
                  .format(numa_node, numa_node, ffmpeg_cmd_line, save_results_dir, a_output, i + 1)
        else:
          ffmpeg_cmd_final += '{} > {}/{}{} 2>&1 &\n'.format(ffmpeg_cmd_line, save_results_dir, a_output, i + 1)
        script += ffmpeg_cmd_final
        script += 'ffmpeg_wait_pids[{}]=$!\n'.format(i)
      # Wait for ffmpeg processes to complete
      script += 'sleep .5\n'
      script += 'ffmpeg_wait_pids[{:d}]=$!\n'.format(num_inst + 1)
      script += 'for pid in ${ffmpeg_wait_pids[*]}; do wait $pid; done\n'
      script += 'date +%s.%N >> {}/timestamps.txt\n'.format(test_results_dir)

      # Kill the monitoring processes
      if not with_traces:
        script += 'for pid in ${perf_wait_pids[*]}; do kill -9 $pid; done\n'
        script += 'killall -s SIGINT sar 2>/dev/null || true\n'

      # Output the whole script to the log so that we have it available for potential debugging
      logging.debug('script commands:\n{}'.format(script))
      return (script, save_results_dir, ffmpeg_cmd_final)

    # Initialize some tracking variables
    successful_samples = []
    best_total_fps_samples = []
    instance_list = []

    num_inst, max_instances_achieved = self.get_instances(input_format.split('-')[0], codec, preset)
    idx_cores_binding = 0

    # The main control loop to iteratively find the correct number of simultaneous instances
    while True:
      logging.info('Running {} instance(s) of ffmpeg with {},{},{},{},{}'
                   .format(num_inst, codec, input_format, output_mode, preset, video_file))

      # Compose the filenames for the various performance-related files
      instance_dir = posixpath.join(test_results_dir, "{}_instance".format(num_inst))
      dstat_output = posixpath.join(instance_dir, 'dstat.txt')
      sar_output = posixpath.join(instance_dir, 'sar-r.txt')
      sar_cpu_output = posixpath.join(instance_dir, 'sar-cpu.txt')
      sar_cpu_mhz_output = posixpath.join(instance_dir, 'sar-cpu-mhz.txt')

      # Create and execute the script
      (script, save_results_dir, ffmpeg_cmd_final) = CreateRunScript(num_inst)
      with open(os.path.expanduser('~/run_multi_ffmpeg1.sh'), 'w') as f:
        f.write(script)
      cpu_util_error = mem_util_error = timeout_error = isa_error = ten_bit_error = svt_error = False
      unsupported_avx3 = set(('ARM',))
      unsupported_10bit = set(('ARM',))
      unsupported_svt_hevc = set(('ARM',))
      vendor_id = self.sut.CheckLsCpu().data['Vendor ID']
      if vendor_id in unsupported_avx3 and (input_format.split('-')[1] =='avx512' or input_format.split('-')[1] == 'avx3'):
        isa_error = True
      if vendor_id in unsupported_10bit and video_file.find('10bit') != -1 and codec == 'x265':
        ten_bit_error = True
      if vendor_id in unsupported_svt_hevc and codec == 'SVT-HEVC':
        svt_error = True
      start = datetime.datetime.now().timestamp()
      try:
        if not isa_error and not ten_bit_error and not svt_error:
          logging.info('start_ffmpeg_processes')
          os.system('chmod +x ~/run_multi_ffmpeg1.sh && ~/run_multi_ffmpeg1.sh')
          logging.info('end_ffmpeg_processes')
      except:
        print("Error running benchmarks script")
        pass

      end = datetime.datetime.now().timestamp()
      (avg_active_read_bytes, avg_active_write_bytes) = self.perf_data.GetDiskMetrics(dstat_output)
      if not isa_error and not ten_bit_error and not svt_error:
        wall_clocks = os.popen('cat {}/timestamps.txt'.format(test_results_dir)).read()
        wall_clocks = wall_clocks.split()
        attempts_left = 5
        while len(wall_clocks) < 2 and attempts_left > 0:
          time.sleep(5)
          wall_clocks = os.popen('cat {}/timestamps.txt'.format(test_results_dir)).read()
          wall_clocks = wall_clocks.split()
          attempts_left -= 1
        wall_clock_start = float(wall_clocks[0])
        wall_clock_end = float(wall_clocks[1])

        frames = self.GetNumFrames(os.path.join(self.sut.GetRamDiskPath(),video_file))

        # Clean up output video directory
        os.system('rm -r {}/{}'.format(save_results_dir, VIDEO_RESULT_SUB_DIR))

        #Save the script under test name
        self.sut.SaveScript("-".join([sub_test_name, video_file]))

        # Check for errors in the output
        ffmpeg_output_file = '{}/{}'.format(save_results_dir, a_output)
        self.ScanLogfilesForErrors(codec, num_inst, ffmpeg_output_file)

        # Process performance stats
        avg_cpu_utilization = self.perf_data.GetAverageCpuUtilization(sar_cpu_output)
        avg_cpu_frequency = self.perf_data.GetAverageCpuFrequency(sar_cpu_mhz_output)
        cpu_util_error = avg_cpu_utilization < 90
        max_pct_mem_used = self.perf_data.GetMemoryUtilization(sar_output)
        mem_util_error = max_pct_mem_used > 99
        (avg_active_read_bytes, avg_active_write_bytes) = self.perf_data.GetDiskMetrics(dstat_output)
        normal = not any((cpu_util_error,mem_util_error,timeout_error))
        warning_message = 'Normal' if normal else 'Fatal: Duration > {}'.format(FLAGS.timeout_period) if timeout_error else 'Warning:'
        if all((timeout_error,cpu_util_error,mem_util_error)):
          warning_message += 'and Mem Util > 99% and CPU Util < 90%'
        elif timeout_error and cpu_util_error:
          warning_message += 'and CPU Util < 90%'
        elif timeout_error and mem_util_error:
          warning_message += 'and Mem Util > 99%'
        elif cpu_util_error and mem_util_error:
          warning_message += ' CPU Util < 90% and Mem Util > 99%'
        elif cpu_util_error:
          warning_message += ' CPU Util < 90%'
        elif mem_util_error:
          warning_message += ' Mem Util > 99%'

        # Get the FPS information from the output file
        (lowest_fps, all_last_fps, total_fps) = self.GetFpsInfoFromLogFile(codec, num_inst, ffmpeg_output_file)

      else:
        wall_clock_end = .1
        wall_clock_start= 0
        frames = 0
        total_fps = 0
        all_last_fps = 0
        avg_cpu_utilization = 0
        avg_cpu_frequency = 0
        max_pct_mem_used = 0
        if isa_error:
          warning_message = 'Fail: SUT does not support ISA'
        elif ten_bit_error:
          warning_message = 'Fail: x265 10bit not supported on ISA'
        elif svt_error:
          warning_message = 'Fail: SVT-HEVC not supported on ISA'
        else:
          warning_message = 'Fail: Unclear. Please store log files'

      # Append the output data to the CSV file on the SUT
      num_output_files = self.GetNumberOfOutputFiles(ffmpeg_args) if output_mode == '1:n' else 1
      row = ('{},{},{},{},{},{},{},{},="{}",{},{},{},{},{},{},"{}"'
             .format(sub_test_name,str(round(wall_clock_end-wall_clock_start,2)),codec.strip(),input_format.split('-')[0], input_format.split('-')[1],
                     preset,total_fps,str((frames * num_inst)/(wall_clock_end-wall_clock_start)), num_inst, lowest_fps, all_last_fps, round(avg_cpu_utilization,2),avg_cpu_frequency,
                     str(max_pct_mem_used), warning_message,ffmpeg_args))
      self.results_collection.write(row)
      if not isa_error and not ten_bit_error and not svt_error:
        self.CreateFPSSheets(sub_test_name,num_inst)

      # Keep track of the instance numbers that we've used. This will be used to determine when
      # we're finished looping
      instance_list.append(num_inst)

      logging.debug("num_inst: {}".format(num_inst))
      logging.debug("lowest_fps: {}".format(lowest_fps))
      logging.debug("total_fps: {}".format(total_fps))
      logging.debug("fps_threshold: {}".format(fps_threshold))
      logging.debug("avg_cpu_utilization: {}".format(avg_cpu_utilization))
      logging.debug("all_last_fps: {}".format(all_last_fps))
      logging.debug("total_logical_cores: {}".format(self.sut.GetLogicalCoreCount()))

      metadata = {}
      metadata['sub_test_name'] = sub_test_name
      metadata['codec'] = codec
      metadata['output_mode'] = output_mode
      metadata['test_mode'] = test_mode
      metadata['video_file'] = video_file
      metadata['preset'] = preset
      metadata['cpu_utilization'] = "{:.2f}".format(avg_cpu_utilization)
      metadata['lowest_fps'] = lowest_fps
      metadata['transcodes'] = round(total_fps / float(fps_threshold),2)
      metadata['density_instances'] = num_inst
      metadata['avg_cpu_frequency'] = "{:.2f}".format(avg_cpu_frequency)
      metadata['max_pct_mem_used'] = max_pct_mem_used
      metadata['avg_active_read_bytes'] = "{:.2f}".format(avg_active_read_bytes)
      metadata['avg_active_write_bytes'] = "{:.2f}".format(avg_active_write_bytes)
      metadata['all_last_fps'] = all_last_fps
      metadata['total_fps'] = total_fps
      metadata['fps_threshold'] = fps_threshold
      metadata['logical_core_number'] = self.sut.GetLogicalCoreCount()
      metadata['auto_mode'] = self.auto_mode
      metadata['cpu_threshold'] = self.default_cpu_threshold
      metadata['ffmpeg_args'] = ffmpeg_args
      metadata['Completion_Code'] = warning_message
      metadata['Use_Case_Name']   = sub_test_name
      metadata['FFmpeg_CMD_Line'] = ffmpeg_cmd_final
      metadata['prepare_time'] = self.prepare_time

      # If we were successful, note the # of instances and save the sample
      if warning_message == 'Normal':
        if float(total_fps) > float(best_total_fps):
          max_instances_achieved = num_inst
          best_total_fps = total_fps
          logging.debug("Run succeeded, updated max_instances_achieved: {}".format(max_instances_achieved))
          self.num_tests_passed += 1
          self.GenerateSampleForRun(metadata, successful_samples)

      # Calculate the new number of instances based on the total FPS across all instances, divided by the FPS threshold to achieve
      if self.auto_scaling and not self.pkb_2:
        new_num_inst = max(int(total_fps / float(fps_threshold)), 1)
        logging.debug("new_num_inst: {}".format(new_num_inst))

        # It may happen that we calculate the same number of instances as that which we just ran
        if num_inst == new_num_inst:
          # If so, if the run was successful, try one more instance (expecting to fail)
          if float(lowest_fps) >= float(fps_threshold):
            num_inst = num_inst + 1
          # Otherwise, if we failed this run, let's try one less (hoping to succeed)
          else:
            if num_inst > 1:
              num_inst = num_inst - 1
        else:
          num_inst = new_num_inst
      elif self.data_collection_cores_binding:
        logging.debug("total_fps: {}".format(total_fps))
        logging.debug("prev_total_fps: {}".format(prev_total_fps))
        logging.debug("best_total_fps: {}".format(best_total_fps))

        prev_total_fps = total_fps
        total_logical_cores=self.sut.GetLogicalCoreCount()
        numa_cores=int(total_logical_cores/self.sut.GetNumaNodeCount())
        cores_per_inst_list = [item+1 for item in range(numa_cores) if not (numa_cores % (item+1)) ]
        cores_per_inst = cores_per_inst_list[idx_cores_binding]

        idx_cores_binding = idx_cores_binding + 1
        if idx_cores_binding < len(cores_per_inst_list):
          cores_per_inst = cores_per_inst_list[idx_cores_binding]

        cur_num_inst = int(total_logical_cores/cores_per_inst)

        if cur_num_inst <= total_logical_cores:
          num_inst = cur_num_inst
        logging.debug("new_num_inst: {}, idx_cores_binding: {}, cores_per_inst: {}".format(num_inst,idx_cores_binding,cores_per_inst))
      elif self.data_collection_stream_density:
        pre_total_fps = total_fps
        if avg_cpu_utilization > 95:
          new_num_inst = num_inst-4
        elif avg_cpu_utilization > 90:
          new_num_inst = num_inst-2
        else:
          new_num_inst = num_inst-1
        logging.debug("new_num_inst: {}".format(new_num_inst))

        # It may happen that we calculate the same number of instances as that which we just ran
        if new_num_inst > 0:
          num_inst = new_num_inst
        else:
          num_inst = 1

      logging.debug("num_inst after recalc: {}".format(num_inst))
      logging.debug("max_instances_achieved: {}".format(max_instances_achieved))

      if num_inst in instance_list:
        # If we had a successful run, append the sample for most recent successful pass. Otherwise, append the
        # sample for this run, which failed. If the user has specified a particular number of instances, it is
        # possible that this fails this time. So, make sure also that we indeed have some successful samples.
        if (max_instances_achieved != 0) and (len(successful_samples) > 0):
          # The samples list has the samples for all of the successful runs. Return only the most recent by appending
          # to the samples list that was provided to this method
          logging.debug("Appending the sample for the most recent successful run: max_instances_achieved: {}".format(max_instances_achieved))
          samples.append(successful_samples[-1])
        elif len(best_total_fps_samples) > 0:
          logging.debug("LIVE fall back to VOD. Appending the sample for the most total FPS: max_instances_achieved: {}".format(max_instances_achieved))
          samples.append(best_total_fps_samples[-1])
        else:
          logging.debug("Appending the sample for this last (failed) run")
          logging.debug("max_instances_achieved: {}, num_inst: {}".format(max_instances_achieved, num_inst))
          self.GenerateSampleForRun(metadata, samples)

        logging.info('Breaking while, num_inst {:d}'.format(int(num_inst)))
        break

    # If we need to run any trace collectors, such as EMON, run with the max # of instances achieved.
    if max_instances_achieved != 0:

      if self.control_traces:
        logging.info('Running {} instances again with trace collectors enabled'.format(int(max_instances_achieved)))

        # Create and enable the run script
        (script, _) = CreateRunScript(max_instances_achieved, with_traces=True)
        script_filename = 'run_with_collectors.sh'
        os.system('echo \'{}\' > ~/{}'.format(script, script_filename))
        os.system('chmod +x ~/{}'.format(script_filename))

  def get_instances(self, resolution, codec, preset, test_mode=None):
    """Returns the number of instances to divide the CPU count by as a combination of resolution, codec, and preset

    Args:
        resolution (str): video resolution
        codec (str): encoding codec
        preset ([str): encoding preset
        test_mode (str, optional): LIVE or VOD. Defaults to None. Not used but may be in the future

    Returns:
        [type]: [description]
    """
    div_dict = {
      'x264':{
        '1080P':{
          'veryslow':4,
          'medium':2,
          'fast':2,
          'veryfast':2
        },
        '4k':{
          'veryslow':8,
          'medium':2,
          'fast':1
        }
      },
      'x265':{
        '1080P':{
          'veryslow':8,
          'medium':4,
          'slow': 4, 
          'fast':1
        },
        '4k':{
          'veryslow':8,
          'medium':2,
          'fast':1
        }
      },
      'SVT-HEVC':{
        '1080P':{
          '9':4,
          '7':8, 
          '5':8,
          '1':8
        },
        '4k':{
          '9':24,
          '7':24,
          '5':24,
          '1':30
        }
      },
      'SVT-AV1':{
        '1080P':{
          '12':8,
          '10':8,
          '9':8,
          '8':8,
          '7':8,
          '6':8,
          '5':8,
          '3':4  
        },
        '4k':{
          '12':12,
          '10':12, 
          '9':24,
          '8':16,
          '7':24
        }
      }
    }
    if FLAGS.instances:
      if os.path.exists(FLAGS.instances):
        with open(FLAGS.instances,'r') as f:
          instances = f.read()
        instances = json.loads(instances)
        return instances[codec][resolution][str(preset)], 0
    if FLAGS.divisors:
      if os.path.exists(FLAGS.divisors):
        with open(FLAGS.divisors,'r') as f:
          divisors = f.read()
        div_dict = json.loads(divisors)
    if self.pkb_2:
      numa_nodes = self.sut.GetNumaNodeCount()
      if self.auto_scaling:
        initial_num_inst = math.ceil(int(self.sut.GetThreadCount()) / div_dict[codec][resolution][str(preset)])
        if self.numactl_flag:
          initial_num_inst = int((initial_num_inst + numa_nodes - 1)/numa_nodes) * numa_nodes
      else:
        initial_num_inst = self.fixed_instance_count

      num_inst = initial_num_inst
      max_instances_achieved = 0
    else:
      if self.auto_scaling:
      # If we're autoscaling, the number of instances will be determined by doing successive runs. It is initialized
      # depending on whether we're doing LIVE or VOD mode
        num_inst = self.initial_instance_count if test_mode == 'LIVE' else 1
        max_instances_achieved = 0
      elif self.data_collection_cores_binding:
        num_inst = self.sut.GetLogicalCoreCount() 
        max_instances_achieved = 0
      else:
      # If we're not autoscaling, we already know the optimum number of instances and so we can initialize
      # num_inst and the instance_list accordingly.
      # that we've already tried
        num_inst = self.initial_instance_count
        max_instances_achieved = num_inst
    return int(num_inst), max_instances_achieved

  def GetFpsInfoFromLogFile(self, codec, num_inst, log_filename):
    last_fps_list = []

    for i in range(num_inst):
      instance_log_filename = "{}{:d}".format(log_filename, i + 1)
      #logging.info("instance_log_filename: {}".format(instance_log_filename))

      # Grab the codec output log and scan it for the frame rate
      codec_output = os.popen("cat {}".format(instance_log_filename)).read().split("\n")
      fps = self.GetFps(codec, codec_output)
      last_fps_list.append(float(fps))

    lowest_fps = (sorted(last_fps_list))[0]
    all_last_fps = '/'.join([str(i) for i in last_fps_list])
    fps_sum = round(sum(last_fps_list), 4)

    logging.info("lowest_fps: {}".format(lowest_fps))
    logging.info("all_last_fps: {} ".format(all_last_fps))
    logging.info("fps_sum: {}".format(fps_sum))

    return (lowest_fps, all_last_fps, fps_sum)

  def GetFps(self, codec, codec_output):
    """Get the FPS value from the output log file for the run
       If there is only one entry, return it when we find it.
       Otherwise, return the last entry"""
    lines = []
    for line in codec_output:
      lines.extend(line.splitlines())

    fps = 0.0

    # If the codec is invoked directly, the output has a different format than
    # if the ffmpeg front-end is used. So, different regular expressions are required
    if self.direct:
      # Scan the x264 binary output (the only supported direct mode so far)
      re_fps = re.compile('encoded \d+ frames, ([0-9]+\.[0-9]+) fps')

      for line in lines:
        result = re_fps.search(line)
        if result:
          fps = float(result.group(1))
          break
    else:
      # Scan the FFMPEG front-end output
      re_speed = re.compile(r'speed=\s*([0-9]+\.[0-9]+)x')
      re_fps = re.compile(r'fps=\s*([0-9]+)')
      # The format of Output streams are different than input. tbn follows fps in output
      # so we make sure our regex grabs lines that follow that format. We also grab the
      # playback fps of the first output stream, because that is the one that ffmpeg reports.
      re_playback_fps = re.compile(r'Output #0.*?Stream #0.*?(\d+)\sfps,[\n\s\t]+([0-9]+) tbn', re.DOTALL)

      speed = 0.0
      playback_fps = 0.0

      for line in lines:
        speed_result = re.search(re_speed, line)
        fps_result = re.search(re_fps, line)
        if speed_result:
          speed = float(speed_result.group(1))
        if fps_result:
          fps = float(fps_result.group(1))

      # We are only concerned with capturing the playback fps of the first output stream.
      playback_fps_result = re.search(re_playback_fps, str(codec_output))
      if playback_fps_result:
        playback_fps = float(playback_fps_result.group(1))

      if speed > 0:
        fps = round(speed * playback_fps, 4)

      logging.debug("GetFps: speed: {}".format(speed))
      logging.debug("GetFps: playback_fps: {}".format(playback_fps))
      logging.debug("GetFps: fps: {}".format(fps))

    return fps

  def GetErrorRegexesForCodec(self, codec):
    if self.direct:
      # The x264 case
      regex_fatal_error = re.compile("TODO: Some x264 regex")
      regex_nonfatal_error = re.compile("TODO: Some x264 regex", re.IGNORECASE)
    else:
      # The FFMPEG case
      regex_fatal_error = re.compile("Invalid argument")
      regex_nonfatal_error = re.compile("error|invalid", re.IGNORECASE)

    return (regex_fatal_error, regex_nonfatal_error)

  def ScanLogfilesForErrors(self, codec, num_inst, codec_output_file):
    """Report error/invalid count"""
    (regex_fatal_error, regex_nonfatal_error) = self.GetErrorRegexesForCodec(codec)

    # Each instance has an output log to scan
    for i in range(num_inst):
      error_count = 0
      instance_output_filename = "{}{:d}".format(codec_output_file, i + 1)

      # Get the output log contents for this instance
      log_output = os.popen("cat {}".format(instance_output_filename)).read()

      # Process each line to search for whether there were any invalid arguments
      # or any other errors
      for line in log_output:
        if regex_fatal_error.search(line):
          raise Exception("ERROR: Invalid argument found in logfile: {}".format(instance_output_filename))

        result = regex_nonfatal_error.search(line)
        if result:
          error_count += 1

      if error_count > 0:
        log_ref = logging.error
      else:
        log_ref = logging.info

      #log_ref("ffmpeg.out_{:d}: error_count={:d}".format((i + 1), error_count))

  def GenerateSampleForRun(self, metadata, samples):
    self.num_tests_run += 1
    samples.append(Sample("FFmpeg Result", metadata["total_fps"], 'frames per second', metadata=metadata))

  def CreateFPSSheets(self, sub_test,num_inst):
    """Reads every FFmpeg out file and creates a sheet containing all of the values

    Args:
        sub_test (str): Name of the subtest used to name the sheet
    """
    #instance_dir = posixpath.join(test_results_dir, "{}_instance".format(num_inst))
    directory = posixpath.join(self.run_results_dir, sub_test,"{}_instance".format(num_inst))
    sheet_name = sub_test if len(sub_test) < 32 else sub_test[:31]
    test_config = self.config[sub_test]
    #num_inst,_ = self.get_instances(test_config['input_format'].split('-')[0], test_config['video_codec']['codec'], test_config['video_codec']['preset'])
    re_fps = re.compile(r'frame=[\n\s\t]*([0-9]+)[\n\s\t]*fps=[\n\s\t]*([0-9]+).*size=[\n\s\t]*([0-9]*)kB.*?time=([0-9]*:[0-9]*:[0-9]*[.]?[0-9]+)[\n\s\t]*.*speed=([0-9]*.[0-9]*)x')
    header_string = ''
    for i in range(1,num_inst+1):
      header_string += 'ffmpeg_out_{},,,,,,'.format(i)
    self.results_collection.write(header_string,sheet=sheet_name)
    self.results_collection.write('frame,fps,size,time,speed,,'* num_inst, sheet=sheet_name)
    xl_lines = []
    for i in range(1, num_inst + 1):
      ffmpeg_log = os.popen('cat {}/ffmpeg.out_{}'.format(directory,i)).read()
      ffmpeg_log = ffmpeg_log.replace('\r','\n')
      lines = ffmpeg_log.split('\n')
      final_frame = 0
      line_num = 0
      for line in lines:
        result = re.search(re_fps, line)
        if result:
          if len(xl_lines) <= line_num:
            xl_lines.append('{},{},{}kb,{}kbits/s,{}x,'.format(result.group(1),result.group(2),result.group(3),result.group(4),result.group(5)))
          else:
            xl_lines[line_num] += (',' + '{},{},{}kb,{}kbits/s,{}x,'.format(result.group(1),result.group(2),result.group(3),result.group(4),result.group(5)))
          line_num += 1
    for line in xl_lines:
      self.results_collection.write(line,sheet=sheet_name)

  def GetNumFrames(self,video_file):
    loops = 1
    if self.pvswitches and 'stream_loop' in self.pvswitches:
      loops += int((self.pvswitches.split(' ')[1]))
    output = os.popen('{}/ffprobe {}'.format(self.bin_path,video_file)).read()
    output = output.split('\n')

    duration = 0
    duration = 0
    fps = 0
    duration_regex = re.compile(r'Duration: ([0-9]*):([0-9]*):([0-9]*.[0-9]*),')
    fps_regex = re.compile(r', ([0-9]*) fps,')
    for line in output:
      if 'Duration' in line:
        result = re.search(duration_regex, line)
        if result:
          hours = int(result.group(1))
          minutes = int(result.group(2))
          seconds = float(result.group(3))
          duration = seconds + minutes * 60 + hours * 60 * 60
      elif 'fps' in line:
        result = re.search(fps_regex, line)
        if result:
          fps = int(result.group(1))
    return duration * loops * fps

