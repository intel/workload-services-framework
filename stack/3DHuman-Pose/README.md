>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction

This is base image for 3d human pose workload. It is used as a reference for 3d human pose workload development with OpenCV, Pytorch and OpenVINO.



### Docker Image

The base image creates a single docker image: `3dhuman-pose-base`. 

### Usage

Before using it, you need to do the following preparations:
1. Create a new folder to store the downloads: Inside this folder create a new folder called "motion-tracking-sdk".
2. Download SDK: Anyone that has a NDA agreement with Intel can download the source code to run the workload. Download it to the "motion-tracking-sdk" folder.
3. Download the pre-training model and test video: Some of them may require registering a third-party account or unzipping the archive.
- [smpl_mean_params.npz](http://visiondata.cis.upenn.edu/spin/data.tar.gz)
- [2020_05_31-00_50_43-best-51.749683916568756.pt](https://dl.fbaipublicfiles.com/eft/2020_05_31-00_50_43-best-51.749683916568756.pt)
- [w32_256x192_adam_lr1e-3.yaml](https://raw.githubusercontent.com/HRNet/HRNet-Human-Pose-Estimation/master/experiments/coco/hrnet/w32_256x192_adam_lr1e-3.yaml)
- [pose_hrnet_w32_256x192.pth](https://drive.google.com/drive/folders/1nzM_OBV9LbAEA7HClC0chEyf_7ECDXYA)
- [yolox_nano.pth](https://github.com/Megvii-BaseDetection/YOLOX/releases/download/0.1.1rc0/yolox_nano.pth)
- [video_short.mp4](https://dl.fbaipublicfiles.com/eft/sampledata_frank.tar)
- [single_totalbody.mp4](https://dl.fbaipublicfiles.com/eft/sampledata_frank.tar)

You should rename the downloaded file and place it to the ```resource``` directory under the motion-tracking-sdk folder.
The structure of the ```resources``` directory is as follows:

```
resources/
├── hmr
│ ├── mean_params.npz
│ └── 2020_05_31-00_50_43-best-51.749683916568756.pt
├── hrnet
│ ├── w32_256x192_adam_lr1e-3.yaml
│ └── pose_hrnet_w32_256x192.pth
├── yolox
│ └── yolox_nano.pth
├── video_short.mp4
└── single_totalbody.mp4
```
This image only provide common python enviroment, model files and code repo for 3D human pose workloads.
Construct your dedicated workload based on this base image, refer to `Dockerfile` in [`3DHuman-Pose-Estimation`](../../workload/3DHuman-Pose-Estimation).
```
ARG RELEASE=latest
FROM 3dhuman-pose-base${RELEASE}
```

### Test Case

Workload [`3DHuman-Pose-Estimation`](../../workload/3DHuman-Pose-Estimation) uses this stack as base, which provide test cases as below:

- latency_cpu_pytorch
- latency_cpu_openvino
- latency_gated
- latency_pkm

We expose parameters like `INFERENCE_FRAMEWORK` as the framework used for inference,
of which value could be `torch` or `openvino`.
`INFERENCE_DEVICE` specify the device used for inference, at current time only `cpu` is supported.
`INPUT_VIDEO` specify the video used for input.

### KPI

Workload [`3DHuman-Pose-Estimation`](../../workload/3DHuman-Pose-Estimation) uses this stack as base.

[`3DHuman-Pose-Estimation`](../../workload/3DHuman-Pose-Estimation) generates following KPI:

- **`average fps `: Average fps of running pipeline.
- **`average latency `: Average latency of processing one frame in pipeline.


### Index Info
- Name: `3DHuman-Pose`
- Category: `Edge`
- Platform: `ICX`, `SPR`
- Keywords: `YOLO`, `HRNet`, `HMR`

### See Also

- [3DHuman-Pose-Estimation](../../workload/3DHuman-Pose-Estimation)  
