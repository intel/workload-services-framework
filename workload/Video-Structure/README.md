>
> **Note: The Workload Services Framework is a benchmarking framework and is not intended to be used for the deployment of workloads in production environments. It is recommended that users consider any adjustments which may be necessary for the deployment of these workloads in a production environment including those necessary for implementing software best practices for workload scalability and security.**
>
### Introduction
This is an Intel Deep Learning Streamer pipeline with a decoder, object detection, and object classification components. This pipeline takes video as input to identify vehicles. Object detection uses YOLO model. Object classification uses ResNet-50 model.

### Preparation

Videos: User needs to provide two videofiles in h264 and h265 format to get the result.
Models: User need to provide yolov5 models to get the result.
```
video/
├── yolo5n.xml
├── yolo5n.bin
├── resnet50.xml
├── resnet50.bin
├── video1.h264
└── video1.h265
```
### Test Case
The test cases are based on 2 video files both are 135 MB.

The Video Structuring Workload provides following test cases:
- `Throughput_1_1_yolon_3_0.3_9_person_2203_CPU_CPU`: This test case with 1 as core used per core set, 1 as stream number running on one core set, yolon as detection model, 3 as inference interval, 0.3 as detectino threshold, 9 as classification invterval, person as classification objection from detection result, 2203 as using OpenVINO 22.03, CPU as decoder backend, CPU as model inference backend.
- `Throughput_gated`: This test case validates this workload for function test.
- `Throughput_pkm`: This test case calculate this workload FPS.
- `Throughput_28_1_yolon_3_0.3_9_vehicle_2203_GPU_CPU`: This test case with 28 as core used per core set, 1 as stream number running on one core set, yolon as detection model, 3 as inference interval, 0.3 as detectino threshold, 9 as classification invterval, vehicle as classification objection from detection result, 2203 as using OpenVINO 22.03, GPU as decoder backend, CPU as model inference backend.

we expose parameters like inference_number which indicates one inference per selected frames, core_set which indicates selected number of core as one set, stream_number which indicates selected streams running on one core_set.

Exposed parameter: 

- **`CHECK_GATED`**: Running gated testcase, only one stream running on the workload, by default it's false, you can change it by setting CHECK_GATED=true. 

- **`CHECK_PKM`**: Running performance testcase, by default it's false, you can change it by setting CHECK_PKM=true.


- **`COREFORSTREAMS`**: How many cores bind in one group, by default it's 1, you can change it by setting COREFORSTREAMS=1, recommand as same as the number in one numanode.

- **`STREAMNUMBER`**: How many streams running in one core bind, by default it's 1, you can change it by setting COREFORSTREAMS=1.

- **`DETECTION_IMAGE_OR_VIDEO`**: inference on image or video, by default it's video, you can change it by setting DETECTION_IMAGE_OR_VIDEO=image. Video setting has h264 and h265 video format. Image setting has 500x500 and 1080p image. 


- **`DETECTION_MODEL`**: Which yolo model will using on object detection, by default it's yolov5n, you can change t by setting DETECTION_MODEL="yolon". The choice is "yolon", "yolos", "yolom", "yolol".


- **`DETECTION_INFERENCE_INTERVAL`**: Detection interval between inference requests, by default it's 3, You can change it by setting DETECTION_INFERENCE_INTERVAL=3.


- **`DETECTION_THRESHOLD`**: Threshold for detection results, by default it's 0.3. Range: 0 - 1. You can enable it by setting DETECTION_THRESHOLD=0.3.


- **`CLASSIFICATION_INFERECE_INTERVAL`**: Classificaiton interval between inference requests, by default it's 9. You can change it by setting DETECTION_INFERENCE_INTERVAL=9.

- **`CLASSIFICATION_OBJECT`**: Filter for Region of Interest class label on this element input, It takes effect when CLASSIFICATION_OBJECT=vehicle, default value is vehicle.

- **`DETECTION_PARALLEL`**: Set it when you want to have two classification model inference after object detection, It takes effect when DETECTION_PARALLEL=parallel, default value is none.

- **`DECODER_BACKEND`**: Target device for decode, It takes effect when DECODER_BACKEND=CPU, default value is CPU.

- **`MODEL_BACKEND`**: Target device for inference, It takes effect when MODEL_BACKEND=CPU, default value is CPU.


Use the following commands to show the list of test cases:
```
cd build
cmake -DPLATFORM=SPR -DREGISTRY= ..
cd workload/Video-Structure
./ctest.sh -N
```


### Docker Image
The workload contains a single docker image: `video-structure`. Configure the docker image with the environment variable `CONFIG`: `pass` for the workload to return successfully and `fail` for the workload to return a failure status.  
The `video-structure` image is built by the following command:
```
make
```

```
mkdir -p logs-video-structure
id=$(docker run -e http_proxy -e https_proxy --device=/dev/dri -e CHECK_PKM=false -e CHECK_GATED=true -e COREFORSTREAMS=1 -e STREAMNUMBER=1 -e DETECTION_MODEL=yolon -e DETECTION_INFERENCE_INTERVAL=3 -e DETECTION_THRESHOLD=0.6 -e CLASSIFICATION_INFERECE_INTERVAL=3 -e CLASSIFICATION_OBJECT=vehicle -e DECODER_BACKEND=CPU -e MODEL_BACKEND=CPU -e NV_GPU= -e CLASSIFICATION_TIMES= --rm --detach video-structure:latest)
docker exec $id cat /export-logs | tar xf - -C logs-video-structure
docker rm -f $id
```



### KPI

Run the kpi.sh script to generate the KPIs. The KPI script uses the following command line options:
Run the [`kpi.sh`](kpi.sh) script to generate the KPIs. For example, if we want to see the kpi generated by the target testcase `test_video-structure_Throughput_gated`, we can use the following commands:  

```
cd logs-video-structure_Throughput_gated
bash kpi.sh
```

The following KPI are generated:

- **`h265 average fps `: Average fps of running pipeline with h265 file 
- **`h264 average fps `: Average fps of running pipeline with h264 file 
- **`stream number`: How many streams run 

### System Requirements
See [Intel dGPU Setup](https://dgpu-docs.intel.com/driver/installation.html) for Intel GPU testcase system setup instructions.
### Performance BKM

The recommended system setup on SPR platform

#### BIOS Configuration
- CPU Power and Performance Policy: Performance
- SNC: SNC-4
- Package C State: C0/C1 state
- C1E: Enabled
- Processor C6: Enabled
- Hardware P-States: Native Mode
- Turbo Boost: Enabled
- Transparent Huge Pages: always
- Automatic NUMA Balancing: Enabled
- Frequency Governer: performance

#### Hardware ans OS Configuration
- CPU Model: Intel(R) Xeon(R) Platinum 8480+
- Base Frequency: 2.0GHz 
- Maximum Frequency: 3.8GHz
- All-core Maximum Frequency: 3.0GHz
- CPU(s): 224
- Thread(s) per Core: 2
- Core(s) per Socket: 56
- Socket(s): 2
- NUMA Node(s): 8
- Prefetchers: L2 HW, L2 Adj., DCU HW, DCU IP
- TDP: 350 watts
- Frequency Driver: intel_pstate
- Memory: 512G (4800 MT/s)
- Max C-State: 9
- Huge Pages Size: 2048 kB

### Setup Workload with RA
If you use the Reference Architecture to set up your system, use the On-Premises VSS profile for best performance. 

Detail please refer to https://networkbuilders.intel.com/solutionslibrary/network-and-edge-reference-system-architectures-integration-intel-workload-services-framework-user-guide.


### Index Info

- Name: `Video Structure`
- Category: `Edge`
- Platform: `SPR`
- Keywords: `ResNet-50`, `YOLO`, `GPU`
- Permission: 
