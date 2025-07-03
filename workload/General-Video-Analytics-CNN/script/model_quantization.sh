#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
set -e
 
#Install Miniforge3
MINIFORGE_DOWNLOAD_URL="https://github.com/conda-forge/miniforge/releases/download/24.3.0-0/Miniforge3-Linux-x86_64.sh"
if [ ! -f "$MINIFORGE_DOWNLOAD_URL" ]; then
    curl -L -O "$MINIFORGE_DOWNLOAD_URL"
fi
rm -rf ~/miniforge3
bash Miniforge3-Linux-x86_64.sh -b
rm -rf Miniforge3-Linux-x86_64.sh
export PATH=$PATH:~/miniforge3/bin
 
#Validate COCO datasets
DOWNLOAD_URL="http://images.cocodataset.org/zips/val2017.zip"
TARGET_FILE="val2017.zip"
EXPECTED_MD5="442b8da7639aecaf257c1dceb8ba8c80"
OUTPUT_DIR="val2017"
 
if [ ! -f "$TARGET_FILE" ]; then    
    timeout 180s wget "$DOWNLOAD_URL" -O "$TARGET_FILE" --show-progress || { 
        echo "[ERROR] Failed to download file from $DOWNLOAD_URL (timeout or network issue)"
        echo "Please manually download the file and save it to: $TARGET_FILE"
        exit 1
    }    
fi
 
echo "[INFO] Verifying file integrity..."
CALCULATED_MD5=$(md5sum "$TARGET_FILE" | awk '{print $1}')
if [ "$CALCULATED_MD5" != "$EXPECTED_MD5" ]; then
    echo "[WARNING] MD5 mismatch! File may be corrupted."
    exit 1
fi
 
rm -rf "$OUTPUT_DIR"
unzip -q "$TARGET_FILE"
 
#Universal function: safely create and activate conda environment
setup_conda_env() {
    local env_name=$1
    local python_version=$2
    echo "[INFO] Creating $env_name environment..."
    if conda env list | grep -q "$env_name"; then
        echo "[WARN] Environment $env_name already exists, reusing it."
    else
        conda create --name "$env_name" python="$python_version" -y
    fi
 
    # Make sure conda is available
    source ~/miniforge3/etc/profile.d/conda.sh 2>/dev/null || {
        echo "[ERROR] Conda not initialized. Running conda init..."
        conda init bash
        source ~/.bashrc
    }
 
    conda activate "$env_name"
}
 
#MobileNetV2 Quantization
echo "[INFO] Start MobileNetV2  Quantization..."
setup_conda_env "mbnet" "3.9"
pip install openvino-dev==2024.1.0 onnx==1.18.0 torch==1.11.0 torchvision==0.12.0 nncf==2.16.0 fastdownload --break-system-packages
 
echo "[INFO] Downloading MobileNetV2 model..."
omz_downloader --name mobilenet-v2-pytorch
omz_converter --name mobilenet-v2-pytorch --precisions FP16
 
echo "[INFO] Running quantization to INT8..."
python3  mobilenet_nncf.py
if [ -f "mobilenet-v2.bin" ] ; then
    echo "[INFO] MobileNetV2 quantization passed!"
else
    echo "[ERROR] MobileNetV2 quantization failed!"
    exit 1
fi
 
#YOLOV10 Quantization
echo "[INFO] Start YOLOv10 Quantization..."
SCRIPT_VERSION="899fcd6ca773d058435d5c1d0e393e2711fa83f5"
SCRIPT_URL="https://raw.githubusercontent.com/open-edge-platform/edge-ai-libraries/$SCRIPT_VERSION/libraries/dl-streamer/samples/download_public_models.sh"
wget "$SCRIPT_URL" -O ./download_public_models.sh
chmod +x ./download_public_models.sh
sed -i 's/ultralytics --upgrade/ultralytics==8.3.153/g' ./download_public_models.sh
sed -i 's/nncf --upgrade/nncf==2.16.0/g' ./download_public_models.sh
export MODELS_PATH=$PWD/datasets
./download_public_models.sh yolov10m coco128
 
conda deactivate
 
if [ -f "datasets/public/yolov10m/INT8/yolov10m.bin" ] ; then
    echo "[INFO] YOLOV10 quantization passed!"
else
    echo "[ERROR] YOLOV10 quantization failed!"
    exit 1
fi
 
#YOLOV5s/YOLOV5m Quantization
echo "[INFO] Start YOLOv5s/YOLOv5m Quantization..."
setup_conda_env "yolo" "3.9"
 
#Install OpenVINO 2022.3.0
pip install openvino-dev==2022.3.0 torch==1.11.0 torchvision==0.12.0 onnx==1.18.0 --break-system-packages
 
#Download YOLOV5 repo
echo "[INFO] Cloning YOLOV5 repo ..."
YOLOV5_REPO="https://github.com/ultralytics/yolov5"
YOLOV5_REPO_BRANCH="v7.0"
git clone "$YOLOV5_REPO" -b "$YOLOV5_REPO_BRANCH"
cd yolov5
pip install -r requirements.txt
opt_in_out --opt_out
 
#Convert to FP16
echo "[INFO] Downloading and converting YOLOV5 model to FP16 ..."
python3 export.py  --weights yolov5s.pt --imgsz 640 --batch 1 --include onnx
python3 export.py  --weights yolov5m.pt --imgsz 640 --batch 1 --include onnx
mo  --input_model yolov5s.onnx --model_name yolov5s --scale 255 --reverse_input_channels --output Conv_198,Conv_217,Conv_236 --data_type FP16 --output_dir yolov5/FP16
mo  --input_model yolov5m.onnx --model_name yolov5m --scale 255 --reverse_input_channels --output Conv_271,Conv_290,Conv_309 --data_type FP16 --output_dir yolov5/FP16
 
#Quantize the FP16 to INT8 with pot 
SITE_PACKAGES=$(python3 -c 'import site; print(site.getsitepackages()[0])')
sed -i '318s/\[0\]$//' "$SITE_PACKAGES/openvino/tools/pot/algorithms/quantization/utils.py"
 
echo "[INFO] Running quantization to INT8 ..."
pot -q default --preset performance -m yolov5/FP16/yolov5s.xml -w yolov5/FP16/yolov5s.bin -n yolov5s_int8 --engine simplified --data-source ../val2017  --output-dir ../yolov5s_FP16 -d
pot -q default --preset performance -m yolov5/FP16/yolov5m.xml -w yolov5/FP16/yolov5m.bin -n yolov5m_int8 --engine simplified --data-source ../val2017  --output-dir ../yolov5m_FP16 -d
conda deactivate
 
if [ -f "../yolov5m_FP16/optimized/yolov5m_int8.bin" ] ; then
    echo "[INFO] Yolov5 quantization passed!"
else
    echo "[ERROR] Yolov5 quantization failed!"
    exit 1
fi
 
#Clean
#cd ..
#rm -rf yolov5 public val2017
#conda remove -n yolo --all -y
#conda remove -n mbnet --all -y
