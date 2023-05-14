### Introduction

This is the demo application with smartlab action recognition and smartlab object detection algorithms.
This demo takes multi-view video inputs to identify actions and objects, then evaluates scores of current state.
Action recognition architecture uses two encoders for front-view and top-view respectively, and a single decoder.
Object detection uses two models for each view to detect large and small objects, respectively.

### Preparation

Anyone that has a NDA agreement with Intel can download the necessary files to run the workload. 
The necessary files include the following components:
- Code: create the whole pipeline to run the demo.
- FFmpeg related file: the file is used to enable ffmpeg in python.
- GPU driver: the driver is used for GPU releated testcases.

After download it, please create a new folder named script and put the files in it. The whole folder structure should be as follows.
```
workload/
├── script
├── template
├── build.sh
├── cluster-config.yaml.m4
├── CMakeLists.txt
├── create_sql.sql
├── Dockerfile.1.instance
├── Dockerfile.2.mysql
├── Dockerfile.3.redis
├── Dockerfile.4.rtsp
├── kpi.sh
├── kubernetes-config.yaml.m4
├── README.md
├── run_inst.sh
├── run_mysql.sh
├── run_rtsp.sh
└── validate.sh
```

The user also needs to prepare the following materials in the script folder:
- Models: the models is used to detect objections and segment actions. User needs to provide at least four yolox models for detect objections and two mstcn models for segment actions. (If the user wants to use the multiview mode, then two multiview models are also needed.) All these models should be in OpenVINO format with at least 2 files (.xml and .bin). Please rename the files and put them in the models folder in this structure:
```
models/
├── yolox
│   ├── top
│   │   ├── model.bin
│   │   └── model.xml
│   ├── top_scale
│   │   ├── model.bin
│   │   └── model.xml
│   ├── side
│   │   ├── model.bin
│   │   └── model.xml
│   └── side_ruler
│       ├── model.bin
│       └── model.xml
├── mstcn
│   ├── inferred_model.bin
│   ├── inferred_model.xml
│   ├── mobilenet.bin
│   └── mobilenet.xml
└── multiview
    ├── encoder_top.bin
    ├── encoder_top.xml
    ├── encoder_side.bin
    └── encoder_side.xml
```
- Videos: the videos is used to generate frames from rstp server. User needs to provide two corresponding videos in .mp4 format to show the front and side image of the experiment respectively.Please rename the files and put them in the videos folder in this structure:
```
videos/
├── side.mp4
└── top.mp4
```

The final content and structure of the script folder should be as follows:
```
script/
├── driver
├── exp_services
├── models
├── videos
└── smartlab_demo.py
```

### Test Case

There are five defined test cases: 
- `acc_inference`: This test case calculate this workload accuracy.
- `fps_inference_pkm`: This test case calculate this workload FPS.
- `fps_inference_gated`: This test case validates this workload for function test.
- `fps_ai_device_CPU_video_decode_CPU`:This test case use CPU for AI infer and CPU to decode and test FPS of this workload.
- `fps_ai_device_CPU_video_decode_GPU`: This test case use CPU for AI infer and GPU to decode and test FPS of this workload.

we expose parameters like ai_device which indicates the device that used to infer,
video_decode which indicates the device that used to decode the video
and database option switch to control the whether scores will be stored or not.
So as to enable SG1 for video decode, we use ffmpeg as a decode tool, some dependencies are installed as showed in Dockerfile.instance.

### Docker Image

The workload contains several docker image: `Dockerfile.instance`, `Dockerfile.mysql`, `Dockerfile.redis`, `Dockerfile.rtsp`.

DOCKER_BUILDKIT=1 docker build --secret id=.netrc,src=$HOME/.netrc -f Dockerfile.instance -t smt_instance .
docker run --privileged=true --net=host --name=smtlab_ins -it smt_instance bash

### KPI

Run the [`kpi.sh`](kpi.sh) script to generate the KPIs. 

The following KPI is defined:
- `Average FPS`: The workload average FPS.  

### Performance BKM

This workload can run on any system with a `docker` or `Kubernete` setup.  

### Index Info

- Name: `Smart Science YOLO MSTCN OpenVINO`
- Category: `ML/DL/AI`
- Platform: `ICX`
- keywords:`YOLOX`, `MSTCN`


