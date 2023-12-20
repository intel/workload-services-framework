#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

from ffmpeg_util import FfmpegWorkload
import os

from absl import flags
from absl import app

# Define the ffmpeg-specific command-line options
flags.DEFINE_string('ffmpeg_config_file', 'benchmark_tests.yaml',
                    'The FFMPEG benchmark tests configuration file')

flags.DEFINE_string('ffmpeg_run_tests', '',
                    'A comma-separated list of tests to run')

flags.DEFINE_string('ffmpeg_videos_dir', '',
                    'The directory on the PKB host in which to find the input videos')

flags.DEFINE_string('ffmpeg_video_clip', '',
                    'The input video clip file on the PKB host')

flags.DEFINE_string('ffmpeg_cores_per_instance', 'auto',
                    'Mannually to set the cores for each instance, deatult it is determined automatically according usecase and platform!')

flags.DEFINE_string('ffmpeg_cores_list', 'auto',
                    'Mannually to set the cores list for single instance, deatult it is determined automatically according usecase and platform!')

flags.DEFINE_integer('ffmpeg_enable_numactl', 1,
                     'Set it to 1 to enable numactl')

flags.DEFINE_string('ffmpeg_numa_mem_set', 'auto',
                     'Set it to numa memory node in auto as default value, which ensure the same node number for membind and cpunodebind')

flags.DEFINE_integer('ffmpeg_debug_level_enable', 0,
                     'Set it 1 to enable logging debug level')

flags.DEFINE_string('ffmpeg_extract_duration', 'auto',
                     'It is #seconds video clips extracted from mp4 files for encoding or transcoding.')

flags.DEFINE_string('ffmpeg_extract_frame', 'auto',
                     'It is #frames video clips extracted from mp4 files for encoding or transcoding.')

flags.DEFINE_integer('ffmpeg_enable_cores_binding', 0,
                     'Set it to 1 to enable cores binding with numactl')

flags.DEFINE_integer('repeat_benchmark_on_timeout', 0,
                     'Retry a command if a timeout occurs.')
flags.DEFINE_integer('timeout_period', 7200,
                     'Period of time to give an FFmpeg test before cancelling')

flags.DEFINE_boolean('pkb_2', True, 'Enable PKB 2.0')
flags.DEFINE_boolean('ht_enable', True, 'Enable HT')

flags.DEFINE_string('divisors', None, 'Relative path to the file that contains divisor dictionary')
flags.DEFINE_string('instances',None, 'Relative path to a json containing instance settings')
FLAGS = flags.FLAGS


env=dict(os.environ)
usecase=env.get("USECASE")
tool=env.get("TOOL","ffmpeg")
arch=env.get("ARCH","amd64")
compiler=env.get("COMPILER","gcc")
mode=env.get("MODE","2")
numactl=env.get("NUMACTL","1")
ht_flag=env.get("HT","1")
videoclip=env.get("VIDEOCLIP","")
clip_extract_duration=env.get("CLIP_EXTRACT_DURATION","auto")
clip_extract_frame=env.get("CLIP_EXTRACT_FRAME","auto")
cores_per_instance=env.get("CORES_PER_INSTANCE","auto")
cores_list=env.get("CORES_LIST","auto")
config_file=env.get("CONFIG_FILE","pkb_2.0_config.yaml")
numa_mem_set=env.get("NUMA_MEM_SET","auto")


def ReinitializeFlags():
    FLAGS.ffmpeg_config_file = 'benchmark_tests.yaml'
    FLAGS.ffmpeg_run_tests = ''
    FLAGS.ffmpeg_videos_dir = ''
    FLAGS.ffmpeg_enable_numactl = 0
    FLAGS.ffmpeg_debug_level_enable = 0
    FLAGS.ffmpeg_enable_cores_binding = 0
    FLAGS.repeat_benchmark_on_timeout = 0
    FLAGS.timeout_period = 7200

def main(args):
    test_runs=usecase
    print("usecase", ":", test_runs+"-"+compiler+"-"+mode+"-"+tool+"-"+arch+"-"+numactl+"-"+cores_per_instance)
    auto_mode=mode
    if FLAGS.pkb_2:
        FLAGS.ffmpeg_config_file = "pkb_2.0_config.yaml"

    if config_file:
        FLAGS.ffmpeg_config_file = config_file
        print("Config File: ", FLAGS.ffmpeg_config_file)

    FLAGS.ffmpeg_cores_per_instance = cores_per_instance
    FLAGS.ffmpeg_cores_list = cores_list
    FLAGS.ffmpeg_enable_numactl = numactl
    FLAGS.ffmpeg_numa_mem_set = numa_mem_set
    FLAGS.ht_enable = True if int(ht_flag) > 0 else False
    print( FLAGS.ffmpeg_cores_list, FLAGS.ffmpeg_cores_list, FLAGS.ffmpeg_numa_mem_set)
    FLAGS.ffmpeg_video_clip = videoclip
    FLAGS.ffmpeg_extract_duration = clip_extract_duration
    FLAGS.ffmpeg_extract_frame = clip_extract_frame
    workload=FfmpegWorkload(test_runs,auto_mode)
    workload.Prepare()

    print("Entering run phase",flush=True)
    print("begin_region",flush=True)
    samples,summary=workload.Run(arch)
    print("end_region",flush=True)

    for sample in samples:
        metadata = sample.metadata
        for key,value in metadata.items():
            print(key, ":", value)

if __name__ == '__main__':
    try:
        app.run(main)
    except SystemExit:
        pass

