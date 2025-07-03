#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

if [ -n "$SCALING_GOVERNOR" ]; then
   echo "$SCALING_GOVERNOR" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
fi

BindCMD=""
Bind=${G_Bind:-true}
CPU_Bind=${G_CPU_Bind:-"0-7"}
if [[ ${Bind} = true ]]; then
BindCMD="taskset -c ${CPU_Bind} "
fi
TestTimeout=${TestTimeout:-120}
NumofVAStreams=${G_NumofVAStreams:-1}

DetectionInferenceBatchSize=1
if [[ $TestName =~ gpu-bs8 ]]; then
    DetectionInferenceBatchSize=8
fi

DetectionInferenceDevice=GPU.0
if [[ $TestName =~ "igpu" ]]; then
    DetectionInferenceDevice=GPU.0
elif [[ $TestName =~ "dgpu" ]]; then
    DetectionInferenceDevice=GPU.0
fi

ClassifyInferenceBatchSize=$DetectionInferenceBatchSize
ClassifyInferenceDevice=$DetectionInferenceDevice
if [[ $TestName =~ ivpu ]] then
    ClassifyInferenceBatchSize=1
    ClassifyInferenceDevice=NPU
fi

ModelPath="/home/kpi/datasets/model"
YoloModelProc=""
if [[ $TestName =~ "light" ]]; then
    YoloModelFile="$ModelPath/yolov5s-v6-1.xml"
    YoloModelProc="model-proc=$ModelPath/yolo-v5.json"
elif [[ $TestName =~ "medium" ]]; then
    YoloModelFile="$ModelPath/yolov5m-v6-1.xml"  
    YoloModelProc="model-proc=$ModelPath/yolo-v5.json"
else
    YoloModelFile="$ModelPath/yolov10m.xml"
fi

Resnet50File="$ModelPath/resnet-v1-50-tf.xml"
Mobilenetv2File="$ModelPath/mobilenet-v2-1.0-224.xml"

VideoPath="/home/kpi/datasets/video"
VideoFile="$VideoPath/intersection_1080p_30p_2M_loop10.h265"

cat <<EOL > generated_script.sh
export LIBVA_DRIVER_NAME=iHD
export GST_PLUGIN_PATH=/opt/intel/dlstreamer/build/intel64/Release/lib:/opt/intel/dlstreamer/gstreamer/lib/gstreamer-1.0:/opt/intel/dlstreamer/gstreamer/lib/
export LD_LIBRARY_PATH=/opt/intel/vpu:/opt/intel/dlstreamer/gstreamer/lib:/opt/intel/dlstreamer/build/intel64/Release/lib:/opt/intel/dlstreamer/lib/gstreamer-1.0:/usr/lib:/opt/intel/dlstreamer/build/intel64/Release/lib:/opt/opencv:/opt/openh264:/opt/rdkafka:/opt/ffmpeg:/usr/local/lib/gstreamer-1.0:/usr/local/lib
export LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri
export GST_VA_ALL_DRIVERS=1
export PATH=/opt/intel/dlstreamer/gstreamer/bin:/opt/intel/dlstreamer/build/intel64/Release/bin:\$PATH

gst-launch-1.0 \\
EOL

if [[ $TestName =~ ivpu ]] then

for ((i=0; i<NumofVAStreams; i++)); do
  cat <<EOL >> generated_script.sh
filesrc location=$VideoFile ! h265parse ! vaapih265dec ! queue ! \\
gvadetect model=$YoloModelFile device=$DetectionInferenceDevice nireq=2 $YoloModelProc pre-process-backend=vaapi-surface-sharing batch-size=$DetectionInferenceBatchSize ie-config=GPU_THROUGHPUT_STREAMS=2 inference-interval=3 inference-region=0 model-instance-id=yolov5s-0 scale-method=fast ! queue ! \\
vaapipostproc crop-right=1696 crop-bottom=856 ! queue ! \\
gvaclassify model=/home/kpi/datasets/model/resnet-v1-50-tf.xml device=$ClassifyInferenceDevice nireq=2 model-proc=/home/kpi/datasets/model/classification.json pre-process-backend=opencv batch-size=$ClassifyInferenceBatchSize inference-interval=3 inference-region=0 model-instance-id=resnet50-0 ! queue ! \\
gvaclassify model=/home/kpi/datasets/model/mobilenet-v2-1.0-224.xml device=$ClassifyInferenceDevice nireq=2 model-proc=/home/kpi/datasets/model/classification.json pre-process-backend=opencv batch-size=$ClassifyInferenceBatchSize inference-interval=3 inference-region=0 model-instance-id=mobilenetv2-0 ! queue ! \\
gvafpscounter starting-frame=2000 ! fakesink async=false \\
EOL
done

else

for ((i=0; i<NumofVAStreams; i++)); do
  cat <<EOL >> generated_script.sh
filesrc location=$VideoFile ! h265parse ! vah265dec ! queue ! \\
gvadetect model=$YoloModelFile device=$DetectionInferenceDevice nireq=2 $YoloModelProc pre-process-backend=va-surface-sharing batch-size=$DetectionInferenceBatchSize ie-config=GPU_THROUGHPUT_STREAMS=2 inference-interval=3 inference-region=0 model-instance-id=yolov5s-0 scale-method=fast ! queue ! \\
gvaclassify model=/home/kpi/datasets/model/resnet-v1-50-tf.xml device=$ClassifyInferenceDevice nireq=2 model-proc=/home/kpi/datasets/model/classification.json pre-process-backend=va-surface-sharing batch-size=$ClassifyInferenceBatchSize ie-config=GPU_THROUGHPUT_STREAMS=2 inference-interval=3 inference-region=0 model-instance-id=resnet50-0 scale-method=fast ! queue ! \\
gvaclassify model=/home/kpi/datasets/model/mobilenet-v2-1.0-224.xml device=$ClassifyInferenceDevice nireq=2 model-proc=/home/kpi/datasets/model/classification.json pre-process-backend=va-surface-sharing batch-size=$ClassifyInferenceBatchSize ie-config=GPU_THROUGHPUT_STREAMS=2 inference-interval=3 inference-region=0 model-instance-id=mobilenetv2-0 scale-method=fast ! queue ! \\
gvafpscounter starting-frame=2000 ! fakesink async=false \\
EOL
done

fi


echo "Script generated as 'generated_script.sh'"

chmod +x generated_script.sh
timeout ${TestTimeout} ${BindCMD} ./generated_script.sh | tee /home/kpi/dlstreamer.log
pipeline_fps=$(tac "dlstreamer.log" | grep -m 1 "average" | awk -F 'per-stream=' '{print $2}' | awk '{print $1}')

echo "kpi No. of VAs : $NumofVAStreams"
echo "kpi pipeline_fps : $pipeline_fps"
