# malconv
ARG OS_VER=stream8 
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
ARG OS_IMAGE=quay.io/centos/centos
ARG MODEL_IMAGE=docker.io/intel/malconv-model-base
ARG MODEL_VER=latest

FROM ${MODEL_IMAGE}:${MODEL_VER} as file
FROM ${OS_IMAGE}:${OS_VER}
COPY --from=file /IntelOptMalconv.h5 /home/IntelOptMalconv.h5 
WORKDIR /home 

# install dependencies
ARG NEURAL_COMPRESSOR_VER=2.3
ARG NEURAL_COMPRESSOR_REPO=pip
ARG NUMPY_REPO=pip
ARG NUMPY_VER=1.22.0
ARG INTEL_TENSORFLOW_VER=2.11.0
ARG INTEL_TENSORFLOW_REPO=pip
ARG ONNXRUNTIME_REPO=pip
ARG ONNXRUNTIME_VER=1.12.0
ARG ONNXRUNTIME_EXTENSIONS_REPO=pip
ARG ONNXRUNTIME_EXTENSIONS_VER=0.9.0
ARG TF2ONNX_REPO==pip
ARG TF2ONNX_VER==1.13.0
ARG SCIKIT_LEARN_REPO==pip
ARG SCIKIT_LEARN_VER==1.3.2

RUN dnf update -y && \ 
    dnf remove -y python36 && \ 
    dnf install -y git python39-pip curl wget numactl python39 python39-devel gcc gcc-c++ unzip zip java-11-openjdk perl perl-Data-Dumper procps-ng && \ 
    dnf --enablerepo=powertools install -y opencv && \
    pip3 install --upgrade pip && \
    pip3 install intel-tensorflow==${INTEL_TENSORFLOW_VER} neural-compressor==${NEURAL_COMPRESSOR_VER} onnxruntime_extensions==${ONNXRUNTIME_EXTENSIONS_VER} progress tf2onnx==${TF2ONNX_VER} onnxruntime==${ONNXRUNTIME_VER} scikit-learn==${SCIKIT_LEARN_VER} setuptools numpy==${NUMPY_VER} wheel packaging requests opt_einsum && \
    pip3 install -U --user keras_preprocessing --no-deps

# make fake testing data
RUN mkdir fakeData && \
    cd fakeData && \
    mkdir KNOWN && \
    mkdir MALICIOUS && \
    for ((i=0; i<2000;++i));do head -c 1M </dev/urandom > ./KNOWN/$i; done && \
    for ((i=0; i<2000;++i));do head -c 1M </dev/urandom > ./MALICIOUS/$i; done
    

COPY script/test.sh script/malconv_test.py script/analyze_scores.py script/h5_to_saved.py script/malconv_int8.yaml script/onnx_quantize.py script/quantize.py script/freeze_saved_model.py script/malconv_bf16.yaml script/onnx.yaml ./

# quantization
RUN python3 h5_to_saved.py -m IntelOptMalconv.h5  -o intel_malconv_saved_model && \
    python3 freeze_saved_model.py intel_malconv_saved_model IntelOptMalconv.fp32.pb && \
	python3 -m tf2onnx.convert --opset 13 --input IntelOptMalconv.fp32.pb --inputs input_1:0 --outputs Identity:0 --output IntelOptMalconv.fp32.onnx && \
	python3 quantize.py -i ./fakeData  -m IntelOptMalconv.fp32.pb -c malconv_int8.yaml -o IntelOptMalconv.int8.pb && \
	python3 quantize.py -i ./fakeData  -m IntelOptMalconv.fp32.pb -c malconv_bf16.yaml -o IntelOptMalconv.bf16.pb && \
	python3 onnx_quantize.py -i ./fakeData  -m IntelOptMalconv.fp32.onnx -c onnx.yaml -o IntelOptMalconv.int8.onnx


RUN mkfifo /export-logs
CMD (./test.sh --model ${MODEL} --framework ${FRAMEWORK} --precision ${PRECISION} --isa ${ISA} --mode ${MODE} --cores ${CORES} --tag ${TAG}; echo $? > status) 2>&1 | tee output.logs && \
	tar cf /export-logs status output.logs && \
	sleep infinity