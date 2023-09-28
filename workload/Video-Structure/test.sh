#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
logAnalyze() {
    local file_format="$1"
    local count=0
    while IFS= read -r line; do
        if [[ $line == *"overall"* ]]; then
            ((count++))
        fi
    done < "${file_format}.log"
    echo "$count"
}

CHECK_PKM=""
CHECK_GATED="true"
COREFORSTREAMS=1
STREAMNUMBER=1
DETECTION_MODEL="yolon"
DETECTION_INFERENCE_INTERVAL=3
DETECTION_THRESHOLD=0.6
CLASSIFICATION_INFERECE_INTERVAL=9
CLASSIFICATION_OBJECT="vehicle"
DECODER_BACKEND="CPU"
MODEL_BACKEND="CPU"
unit_=1
streams_=1

while [[ $# -gt 0 ]]; do
    case $1 in
        --CHECK_PKM) CHECK_PKM="$2"; shift ;;
        --CHECK_GATED) CHECK_GATED="$2"; shift ;;
        --COREFORSTREAMS) COREFORSTREAMS="$2"; shift ;;
        --STREAMNUMBER) STREAMNUMBER="$2"; shift ;;
        --DETECTION_MODEL) DETECTION_MODEL="$2"; shift ;;
        --DETECTION_INFERENCE_INTERVAL) DETECTION_INFERENCE_INTERVAL="$2"; shift ;;
        --DETECTION_THRESHOLD) DETECTION_THRESHOLD="$2"; shift ;;
        --CLASSIFICATION_INFERECE_INTERVAL) CLASSIFICATION_INFERECE_INTERVAL="$2"; shift ;;
        --CLASSIFICATION_OBJECT) CLASSIFICATION_OBJECT="$2"; shift ;;
        --DECODER_BACKEND) DECODER_BACKEND="$2"; shift ;;
        --MODEL_BACKEND) MODEL_BACKEND="$2"; shift ;;
        *) shift ;;
    esac
    shift
done

echo "CHECK_PKM: $CHECK_PKM"
echo "CHECK_GATED: $CHECK_GATED"
echo "COREFORSTREAMS: $COREFORSTREAMS"
echo "STREAMNUMBER: $STREAMNUMBER"
echo "DETECTION_MODEL: $DETECTION_MODEL"
echo "DETECTION_INFERENCE_INTERVAL: $DETECTION_INFERENCE_INTERVAL"
echo "DETECTION_THRESHOLD: $DETECTION_THRESHOLD"
echo "CLASSIFICATION_INFERECE_INTERVAL: $CLASSIFICATION_INFERECE_INTERVAL"
echo "CLASSIFICATION_OBJECT: $CLASSIFICATION_OBJECT"
echo "DECODER_BACKEND: $DECODER_BACKEND"
echo "MODEL_BACKEND: $MODEL_BACKEND"


core=$(nproc)
directory_to_numa_info="/sys/devices/system/node/"
numa_number=$(ls -d /sys/devices/system/node/node* | wc -l)


if [[ `cat /proc/cpuinfo | grep -e "cpu cores" | sort | uniq| awk -F: '{print $2}'` == `cat /proc/cpuinfo | grep -e "siblings" | sort | uniq| awk -F: '{print $2}'` ]]; then
    HYPER_THREAD_ON=0
    numa_limit=$(($core / $numa_number))
else
    HYPER_THREAD_ON=1
    numa_limit=$(($core / 2 / $numa_number))
fi

shell() {

    ideal_streams=$(($core / $unit_ * $streams_))
    if [ $((ideal_streams % 2)) -eq 1 ] && [ $numa_number -gt 1 ];then
        let ideal_streams=$ideal_streams-1
    fi

    unit=$unit_

    streams=$streams_

    if [[ $DECODER_BACKEND == "GPU" ]]; then
        if [[ $file_format == "h264" ]]; then
            DECODE_PARAMS=" ! h264parse ! vaapih264dec ! video/x-raw\(memory:VASurface\) "
        elif [[ $file_format == "h265" ]]; then
            DECODE_PARAMS=" ! h265parse ! vaapih265dec ! video/x-raw\(memory:VASurface\) "
        else
            echo "Unsupported video file format"
            echo "false"
            exit 1
        fi
    elif [[ $DECODER_BACKEND == "CPU" ]]; then
        if [[ $file_format == "h264" || $file_format == "h265" ]]; then
            DECODE_PARAMS=" ! decodebin force-sw-decoders=true "
        else
            echo "Unsupported video file format"
            echo "false"
            exit 1
        fi
    else
        echo "Unsupported backend"
        echo "false"
        exit 1
    fi

    declare -A models
    models["yolon"]="/opt/intel/dlstreamer/samples/yolo5n.xml"
    models["yolos"]="/opt/intel/dlstreamer/samples/yolo5s.xml"
    models["yolom"]="/opt/intel/dlstreamer/samples/yolo5m.xml"
    models["yolol"]="/opt/intel/dlstreamer/samples/yolo5l.xml"
    

    get_label_path_cmd="cd / && find -name coco_80cl.txt"
    labels_file_path=$(eval "$get_label_path_cmd" | sed -n '1s/^\.\(.*\)$/\1/p')
    DETECTION_PARAMS=" ! gvadetect model-proc=/opt/intel/dlstreamer/samples/gstreamer/model_proc/public/yolo-v5.json labels-file=${labels_file_path} inference-interval=${DETECTION_INFERENCE_INTERVAL} model=${models[${DETECTION_MODEL}]}"
    CLASSIFICATION_PARAMS=" ! gvaclassify model=/opt/intel/dlstreamer/samples/resnet50.xml inference-interval=${CLASSIFICATION_INFERECE_INTERVAL}"

    if [[ $DECODER_BACKEND == "GPU" && $MODEL_BACKEND == "GPU" ]]; then
        DETECTION_PARAMS+=" threshold=${DETECTION_THRESHOLD} device=${MODEL_BACKEND} batch-size=1 nireq=1 pre-process-backend=vaapi-surface-sharing"
        CLASSIFICATION_PARAMS+=" device=${MODEL_BACKEND} batch-size=1 nireq=1 pre-process-backend=vaapi-surface-sharing object-class=${CLASSIFICATION_OBJECT}"
    elif [[ $DECODER_BACKEND == "GPU" && $MODEL_BACKEND == "CPU" ]]; then
        DETECTION_PARAMS+=" threshold=${DETECTION_THRESHOLD} device=${MODEL_BACKEND} batch-size=1 nireq=1 pre-process-backend=ie"
        CLASSIFICATION_PARAMS+=" device=${MODEL_BACKEND} batch-size=1 nireq=1 pre-process-backend=ie object-class=${CLASSIFICATION_OBJECT}"
    elif [[ $DECODER_BACKEND == "CPU" && $MODEL_BACKEND == "GPU" ]]; then
        DETECTION_PARAMS+=" threshold=${DETECTION_THRESHOLD} device=${MODEL_BACKEND} batch-size=64 nireq=4 pre-process-backend=ie"
        CLASSIFICATION_PARAMS+=" device=${MODEL_BACKEND} batch-size=1 nireq=1 pre-process-backend=ie object-class=${CLASSIFICATION_OBJECT}"
    elif [[ $DECODER_BACKEND == "CPU" && $MODEL_BACKEND == "CPU" ]]; then
        DETECTION_PARAMS+=" threshold=${DETECTION_THRESHOLD} device=${MODEL_BACKEND} batch-size=1 nireq=1 pre-process-backend=ie ie-config=CPU_THREADS_NUM=1,CPU_THROUGHPUT_STREAMS=1,CPU_BIND_THREAD=NUMA"
        CLASSIFICATION_PARAMS+=" device=${MODEL_BACKEND} batch-size=1 nireq=1 pre-process-backend=ie ie-config=CPU_THREADS_NUM=1,CPU_THROUGHPUT_STREAMS=1,CPU_BIND_THREAD=NUMA object-class=${CLASSIFICATION_OBJECT}"
    else
        echo "Unsupported backend"
        echo "false"
        exit 1
    fi
    
    Execution_task="gst-launch-1.0 filesrc location=/opt/intel/dlstreamer/samples/`find . -name *.${file_format}`${DECODE_PARAMS}${DETECTION_PARAMS} \
        ! queue${CLASSIFICATION_PARAMS} ! gvafpscounter ! fakesink async=true >> ${file_format}.log &"

    fileName="test_script.sh"
    echo "#!/bin/bash" > "$fileName"
    chmod +x "$fileName"
    echo "echo \"1\" > log &" >> "$fileName"

###
    for (( i=0; i<$streams; i++ )); do
        if (( core/numa_number == unit )) ; then
            for set_core in `lscpu|grep NUMA| awk -F: '{print $2}'|sed -e 's/^[ \t]*//g' -e 's/[ \t]*$//g'|sed 1d` ; do
                echo "numactl -C $set_core $Execution_task" >> "$fileName"
            done
        elif (( core/numa_number > unit )) ;then
            if (( $HYPER_THREAD_ON == 1 )); then
                if (( $unit == 1 )); then
                    for (( j=0; j<$core; j++ )); do
                        echo "numactl -C $j $Execution_task" >> "$fileName"
                    done
                elif (( $unit % 2 != 0 )); then
                    echo "ERROR! Please Check your input COREFORSTREAMS(unit) parameter or close HYPER_THREAD"
                else
                    p1=0
                    p2=$((core / 2))
                    pp=0
                    while (( $pp < $numa_limit )); do
                        for (( k=0; k<$numa_number; k++ )); do
                            echo "numactl -C $((p1+numa_limit*k))-$((p1+numa_limit*k+(unit / 2 -1))),$((p2+numa_limit*k))-$((p2+numa_limit*k+(unit / 2 - 1))) $Execution_task" >> "$fileName"                       
                        done
                        p1=$((p1 + unit/2))
                        pp=$(( p1+(unit / 2 -1) ))
                        p2=$((p2 + unit/2))
                    done
                fi
            elif (( $HYPER_THREAD_ON == 0 )); then
                if (( $unit == 1 )); then
                    for (( j=0; j<$core; j++ )); do
                        echo "numactl -C $j $Execution_task" >> "$fileName"
                    done
                else
                    p1=0
                    pp=0
                    while (( $pp < $numa_limit )); do
                        for (( k=0; k<$numa_number; k++ )); do
                            echo "numactl -C $((p1+numa_limit*k))-$((p1+numa_limit*k+(unit -1))) $Execution_task" >> "$fileName"                      
                        done
                        p1=$((p1 + unit))
                        pp=$(( p1+(unit -1) ))
                    done
                fi

            fi
        else
            echo "ERROR! Please Check your input COREFORSTREAMS(unit) parameter"
        fi
    done

    sleep 2
    ./test_script.sh

    times=0
    while true; do
        times=$((times+1))
        ans=$(logAnalyze "$file_format")

        if ((ans == ideal_streams)); then
            break
        fi

        if ((times > 1000)); then
            echo "fail"
            break
        fi
        sleep 5
    done
}

if [[ $CHECK_GATED == "true" ]]; then
    touch h264.log
    gst-launch-1.0 filesrc location=/opt/intel/dlstreamer/samples/`find . -name *.h264` ! decodebin ! \
    gvadetect model=/opt/intel/dlstreamer/samples/yolo5n.xml model-proc=/opt/intel/dlstreamer/samples/gstreamer/model_proc/public/yolo-v5.json  \
    device=CPU ! queue ! gvaclassify model=/opt/intel/dlstreamer/samples/resnet50.xml device=CPU \
      object-class=vehicle ! gvafpscounter ! fakesink async=true >> h264.log

    times=0
    while true; do
        ((times++))
        ans=$(logAnalyze "h264")
        if [[ $ans -eq 1 ]]; then
            break
        fi
        if [[ $times -gt 1000 ]]; then
            echo "fail"
            break
        fi
        sleep 5
    done
    touch h265.log
    gst-launch-1.0 filesrc location=/opt/intel/dlstreamer/samples/`find . -name *.h265` ! decodebin ! \
    gvadetect model=/opt/intel/dlstreamer/samples/yolo5n.xml model-proc=/opt/intel/dlstreamer/samples/gstreamer/model_proc/public/yolo-v5.json  \
    device=CPU ! queue ! gvaclassify model=/opt/intel/dlstreamer/samples/resnet50.xml device=CPU \
      object-class=vehicle ! gvafpscounter ! fakesink async=true >> h265.log

    times=0
    while true; do
        ((times++))
        ans=$(logAnalyze "h265")
        if [[ $ans -eq 1 ]]; then
            break
        fi
        if [[ $times -gt 1000 ]]; then
            echo "fail"
            break
        fi
        sleep 5
    done

    log_cmd="./generate_result.sh"
    ret=$(eval "$log_cmd")
    echo "$ret"
else
    if [[ $CHECK_PKM == "true" ]]; then
        unit_h264=28
        unit_h265=28
        streams_h264=55
        streams_h265=39

        DETECTION_MODEL="yolon"
        DETECTION_INFERENCE_INTERVAL=3
        DETECTION_THRESHOLD=0.6
        CLASSIFICATION_INFERECE_INTERVAL=3
        CLASSIFICATION_OBJECT="vehicle"
        DECODER_BACKEND="CPU"
        MODEL_BACKEND="CPU"
    else
        unit_h264=$COREFORSTREAMS
        unit_h265=$COREFORSTREAMS
        streams_h264=$STREAMNUMBER
        streams_h265=$STREAMNUMBER
    fi
    file_format="h264"
    unit_=$unit_h264
    streams_=$streams_h264
    shell $file_format "$unit_" "$streams_" "$DETECTION_MODEL" "$DETECTION_INFERENCE_INTERVAL" "$DETECTION_THRESHOLD" \
        "$CLASSIFICATION_INFERECE_INTERVAL" "$CLASSIFICATION_OBJECT" "$DECODER_BACKEND" "$MODEL_BACKEND"
    file_format="h265"
    unit_=$unit_h265
    streams_=$streams_h265
    shell $file_format "$unit_" "$streams_" "$DETECTION_MODEL" "$DETECTION_INFERENCE_INTERVAL" "$DETECTION_THRESHOLD" \
        "$CLASSIFICATION_INFERECE_INTERVAL" "$CLASSIFICATION_OBJECT" "$DECODER_BACKEND" "$MODEL_BACKEND"

    log_cmd="./generate_result.sh"
    ret=$(eval "$log_cmd")
    echo "$ret"
fi
