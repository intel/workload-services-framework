>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

This is a base stack for media transcode workload with FFmpeg. It supports x264, x265, SVT-HEVC and SVT-AV1 codec library. It has a number of tests that are available to be run. Each test is defined in the default workload description file [`benchmark_tests`](conf/pkb_2.0_config.yaml). It supports two versions of FFmpeg: 4.4 and 6.0(`FFmpeg_v44` and `FFmpeg_v60`).


### Docker Image

#### Docker Image with workload benchmarking scripts and dataset
The ffmpeg stack contains 2 docker images: `ffmpeg-base-vXX-amd64gcc-avx2`, `ffmpeg-base-vXX-amd64gcc-avx3`, where `vXX` is the version of FFmpeg(`v44` or `v60`). The two amd64 arch contain ffmpeg programs compiled using gcc.


### Suppported versions
#### FFmpeg v4.4
```
FFmpeg        -  tag: n4.4
LibX264 Codec -  tag: 5db6aa6cab1b146e07b60cc1736a01f21da01154
LibX265 Codec -  tag: 3.1
SVT_HEVC Codec - tag: v1.5.1
SVT_AV1 Codec  - tag: v0.9.1
```


#### FFmpeg v6.0
The following codecs and tools were updated in Q2' 2023
```
FFmpeg        -  tag: release/6.0 
LibX264 Codec -  tag: baee400fa9ced6f5481a728138fed6e867b0ff7f
LibX265 Codec -  tag: Release_3.5 
SVT_HEVC Codec - tag: 6cca5b932623d3a1953b165ae6b093ca1325ac44
SVT_AV1 Codec  - tag: v1.5.0 
```

