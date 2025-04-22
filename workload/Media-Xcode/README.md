>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

This is a transcode workload with FFmpeg. It has a number of tests that are available to be run. Each of these tests is defined in the default workload description file [`benchmark_tests_v44`](v44/conf/pkb_2.0_config.yaml) and [`benchmark_tests_v60`](v60/conf/pkb_2.0_config.yaml).    
The workload has two primary modes of operation: LIVE mode and VOD mode. In both cases, the workload attempts to find the optimal number of simultaneous ffmpeg instances to run using different autoscaling algorithms. For LIVE and VOD mode, the goal is to measure the total fps as the transcoding capability.

`NOTE:` FFmpeg is an open source project licensed under LGPL and GPL. See https://www.ffmpeg.org/legal.html. You are solely responsible for determining if your use of FFmpeg requires any additional licenses. Intel is not responsible for obtaining any such licenses, nor liable for any licensing fees due, in connection with your use of FFmpeg.

### Test Case

The format is as the usecase_compiler_mode. The v44 new test case can be added in the [`benchmark_tests_v44`](v44/conf/pkb_2.0_config.yaml) and v60 new test case can be added in the [`benchmark_tests_v60`](v60/conf/pkb_2.0_config.yaml)
The usecase is defined as codec-resolution-preset-instruction:
- `codec`: The codec used (x264, x265, svt-hevc, svt-av1)
- `preset`: The name of the ffmpeg preset used for the codec
- `resolution`: It define the input resolution for the video clip.
- `instruction`: It define the instruction set to accelerate the transcoding, such as avx2, avx3, non, etc. non means no assemly optimization.

The compiler to building the SW stack:
- `compiler`: The software stack is built with specified compiler, such as  gcc, aocc etc.

The mode for test usecase:
- `mode`: It defines the density test case. the value can be 1,2,...,n, and generic,data-collection-cores-binding,data-collection-stream-density. The number of transcoding instances or FPS will be explored when in auto mode. 1 means only 1 transcoding instance is running. n means n transcoding instances are running at the same time. The default value is 1. `generic` will get the better KPI for the live and vode transcoding. `data-collection-cores-binding`, `data-collection-stream-density` are spefied for the data collection with auto tuning.

here is example to run AVC-1080p-medium-avx2 with 1 instance
```
MODE=1 ctest.sh -R AVC-1080p-medium-avx2
```

- `CORES_PER_INSTANCE`: it define how many cores are used to run one instance. Default value is `auto`, which is determerted and scaled automatically according to usecase. It also support mannual tuning mode with specified cores number for each instance,generally it will combine with `MODE` together.

here is an example to run AVC-1080p-medium-avx2 with 4 cores per instance and only 1 instance will run.
```
MODE=1 CORES_PER_INSTANCE=4 ctest.sh -R AVC-1080p-medium-avx2
```

- `CORES_LIST`: it define which cores are used to run 1 instance. Default value is `auto`, which is determerted and scaled automatically according to usecase. It also support mannual tuning mode with specified cpu cores number for each instance and seperated by `;` between instancces,generally it will combine with `MODE` together.

here is an example to run AVC-1080p-medium-avx2 .
```
1 instance with cores 1,2,3,4
MODE=1 CORES_LIST=1,2,3,4 ctest.sh -R AVC-1080p-medium-avx2

2 instance with cores 1,2,3,4 and 5,6,7,8
MODE=2 CORES_LIST=1,2,3,4;5,6,7,8 ctest.sh -R AVC-1080p-medium-avx2
```

- `NUMA_MEM_SET`: if define the numa memory policy set. Default value is `auto`, which keep the memory locally with numa node. It also support mannual tuning with specified cpu cores. `NUMA_MEM_SET` is seperated by `;` between instance. it is used with `MODE` and `CORES_LIST` together.

here is an example to run AVC-1080p-medium-avx2 .
```
1 instance with cores 1,2,3,4, memory bind with node 0/1
MODE=1 CORES_LIST=1,2,3,4 NUMA_MEM_SET=0 ctest.sh -R AVC-1080p-medium-avx2
MODE=1 CORES_LIST=1,2,3,4 NUMA_MEM_SET=1 ctest.sh -R AVC-1080p-medium-avx2

2 instance with cores 1,2,3,4 and 5,6,7,8 with node 0/1
MODE=2 CORES_LIST=1,2,3,4;5,6,7,8 NUMA_MEM_SET=0;0 ctest.sh -R AVC-1080p-medium-avx2
MODE=2 CORES_LIST=1,2,3,4;5,6,7,8 NUMA_MEM_SET=1;1 ctest.sh -R AVC-1080p-medium-avx2
```

- `HT`: it define Hyper Thread on/off. The default value is `1`, which means `on`. `0` means `off`. When you try this parameter, please make sure the setting of HT mode in BIOS.

here is an exmaple:
```
MODE=1 CORES_PER_INSTANCE=4 HT=1 ctest.sh -R AVC-1080p-medium-avx2
```

- `CLIP_EXTRACT_DURATION`: It defines the extraction of #seconds video clips from mp4 files for encoding or transcoding. The default value is "auto", which means 10s for encoding and full duration for transcoding.

- `CLIP_EXTRACT_FRAME`: It defines the extraction of #frames video clips from mp4 files for encoding or transcoding. The default value is "auto", which means the extraction depends on the `CLIP_EXTRACT_DURATION` paramter. `CLIP_EXTRACT_DURATION` and `CLIP_EXTRACT_FRAME` are conflicting. DO NOT set all of them at same time.

- `VIDEOCLIP`: This allow running the test case with specified video clip as input. Now only video clips in the container /home/archive can be used.
```
CLIP_EXTRACT_DURATION=30 VIDEOCLIP=Mixed_40sec_3840x2160_60fps_10bit_420_crf23_veryslow.mp4 ctest.sh -R SVT-HEVC-4k-preset5-avx2-encoder
```

Here are defined test cases for transcoding: 

#### Test Case for x264 with ffmpeg:
- `AVC-1080p-fast-avx2`
- `AVC-1080p-medium-avx2`
- `AVC-1080p-veryslow-avx2`


#### Test Case for x265 with ffmpeg:

- `x265-1080p-medium-avx2`
- `x265-1080p-slow-avx2`
- `x265-4k-veryslow-avx2`
- `x265-1080p-medium-avx3`
- `x265-1080p-slow-avx3`
- `x265-4k-veryslow-avx3`


#### Test Case for SVT HEVC with ffmpeg:
- `SVT-HEVC-1080p-preset9-avx2`
- `SVT-HEVC-1080p-preset5-avx2`
- `SVT-HEVC-1080p-preset1-avx2`
- `SVT-HEVC-4k-preset9-avx2`
- `SVT-HEVC-4k-preset5-avx2`
- `SVT-HEVC-1080p-preset5-avx3`
- `SVT-HEVC-4k-preset9-avx3`
- `SVT-HEVC-4k-preset5-avx3`
- `SVT-HEVC-4k-preset1-avx3`

#### Test Case for SVT AV1 with ffmpeg:
- `SVT-AV1-1080p-12-avx2`
- `SVT-AV1-1080p-10-avx2`
- `SVT-AV1-1080p-8-avx2`
- `SVT-AV1-1080p-6-avx2`
- `SVT-AV1-1080p-5-avx2`
- `SVT-AV1-1080p-3-avx2`
- `SVT-AV1-4k-12-avx2`
- `SVT-AV1-4k-10-avx2`
- `SVT-AV1-4k-8-avx2`
- `SVT-AV1-1080p-12-avx3`
- `SVT-AV1-1080p-10-avx3`
- `SVT-AV1-1080p-8-avx3`
- `SVT-AV1-1080p-6-avx3`
- `SVT-AV1-1080p-5-avx3`
- `SVT-AV1-4k-12-avx3`
- `SVT-AV1-4k-10-avx3`
- `SVT-AV1-4k-8-avx3`

### Docker Image

The workload contains 2 docker images: `media-xcode-v44-amd64gcc` and `media-xcode-v60-amd64gcc`. Configure the docker image with the environment variable `USECSAE`, `TOOL`, `ARCH`, `COMPILER`, `MODE`, `NUMACTL`, `CORES_PER_INSTANCE`, `HT`. `pass` for the workload to return successfully and `fail` for the workload to return a failure status.

Below is an example of running the AVC-1080p-medium-avx2 test case on the local x86 machine.

```mkdir -p logs
assembly=avx2
id=$(docker run --rm --detach  --privileged --net=host -e HTTP_PROXY=$HTTP_PROXY -e HTTPS_PROXY=$HTTPS_PROXY -e http_proxy=$http_proxy -e https_proxy=$https_proxy -e USECASE=AVC-1080p-medium-avx2 -e TOOL=ffmpeg -e ARCH=amd64 -e COMPILER=gcc -e MODE=generic -e NUMACTL=1 -e CORES_PER_INSTANCE=auto -e HT=1 media-xcode-v60-amd64gcc:latest)
docker exec $id cat /export-logs | tar xf - -C logs
docker rm -f $id
```

### KPI

Run the [`kpi.sh`](kpi.sh) script to generate the KPIs.

Here is one kpi example:

```
cpu_utilization(%): 99.63
lowest_fps: 2.718
transcodes(instances): 19.27
density_instances : 192
avg_cpu_frequency(MHz): 2798.20
*total_fps(frames per seconds): 578.118
fps_threshold : 30
cpu_threshold : 90.0
num_tests_run: 1
num_tests_passed : 1
success_percentage(%): 100
run_time : 895.737527
fps/core: 4.52
fps/core/GHz: 1.61
```

The following KPIs are defined:

- `cpu_utilization`: the average cpu usage.
- `lowest_fps`: the lowest fps of all ffmpeg instances.
- `transcodes(instances)`: the equivalent number of transcodes, calculated by total_fps/fps_threshold.
- `density_instances`: the FFmpeg instance number.
- `avg_cpu_frequency`: the average cpu frequency.
- `total_fps`: the total fps in the sub test.
- `fps_threshold`: the acceptance criteria of test result.
- `cpu_threshold`: the acceptance criteria of test result.
- `num_tests_run`: the total number of sub tests.
- `num_tests_passed`: the number of sub tests are passed.
- `success_percentage`: the pass rate.
- `run_time`: the time of running the transcodng.
- `fps/core`: metric for per core performance.
- `fps/core/GHz`: metric for per core performance considering CPU frequency.

### Index Info
- Name: `Media-Xcode`  
- Category: `Media`  
- Platform: `SPR`, `ICX`, `EMR`, `SRF`, `ROME`, `MILAN`, `GENOA`, `BERGAMO`
- Keywords: `x264`, `x265`, `svt-hevc`, `svt-av1`
- Permission:   
