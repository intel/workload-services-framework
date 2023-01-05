# malconv

ARG OS_VER=stream8 
ARG OS_IMAGE=quay.io/centos/centos
FROM ${OS_IMAGE}:${OS_VER}
WORKDIR /home 

# install dependencies
ARG NEURAL_COMPRESSOR_VER=1.14.0
ARG NEURAL_COMPRESSOR_REPO=pip
ARG PROTOBUF_VER=3.20.0
ARG PROTOBUF_REPO=pip
ARG NUMPY_REPO=pip
ARG NUMPY_VER=1.22.0
RUN dnf update -y && \ 
    dnf remove -y python36 && \ 
    dnf install -y git python39-pip curl wget numactl python39 python39-devel gcc gcc-c++ unzip zip java-11-openjdk perl perl-Data-Dumper procps-ng && \ 
    dnf --enablerepo=powertools install -y opencv && \
    pip3 install --upgrade pip && \
    pip3 install neural-compressor==${NEURAL_COMPRESSOR_VER} protobuf==${PROTOBUF_VER} onnxruntime_extensions progress tf2onnx onnxruntime scikit-learn setuptools protobuf numpy==${NUMPY_VER} wheel packaging requests opt_einsum && \
    pip3 install -U --user keras_preprocessing --no-deps

# build & install tensorflow
ARG BAZEL_VER=5.1.1
ARG BAZEL_REPO=https://github.com/bazelbuild/bazel/releases/download/5.1.1/bazel-5.1.1-installer-linux-x86_64.sh
ARG TENSORFLOW_VER=2.10.0
ARG TENSORFLOW_REPO=https://github.com/tensorflow/tensorflow/archive/refs/tags/v2.10.0.tar.gz
ARG ONEDNN_VER=2.5.4
ARG ONEDNN_REPO=https://github.com/oneapi-src/oneDNN/archive/refs/tags/v2.5.4.tar.gz
RUN wget ${TENSORFLOW_REPO} && \
    tar -xvf v2.10.0.tar.gz && \
    wget ${BAZEL_REPO} && \
    chmod +x bazel-5.1.1-installer-linux-x86_64.sh && \
    ./bazel-5.1.1-installer-linux-x86_64.sh && \
    cd tensorflow-2.10.0/tensorflow && \
    sed -i "187c\        sha256 = \"a463ab05129e3e307333ff49d637568fa6ae1fb81742f40918b618e8ef714987\"," workspace2.bzl && \
    sed -i "188c\        strip_prefix = \"oneDNN-2.5.4\"," workspace2.bzl && \
    sed -i "189c\        urls = tf_mirror_urls(\"https://github.com/oneapi-src/oneDNN/archive/refs/tags/v2.5.4.tar.gz\")," workspace2.bzl && \
    cd .. &&\
    if [ `lscpu | grep avx512 | wc -l` -eq "0" ]; then bazel build  -c opt --config=mkl --cxxopt=-D_GLIBCXX_USE_CXX11_ABI=0 --copt=-O3 --copt=-march=skylake --copt=-Wformat --copt=-Wformat-security  --copt=-fstack-protector --copt=-fPIC --copt=-fpic --linkopt=-znoexecstack --linkopt=-zrelro --linkopt=-znow --linkopt=-fstack-protector //tensorflow/tools/pip_package:build_pip_package; else bazel build  -c opt --config=mkl --cxxopt=-D_GLIBCXX_USE_CXX11_ABI=0 --copt=-O3 --copt=-march=skylake-avx512 --copt=-Wformat --copt=-Wformat-security  --copt=-fstack-protector --copt=-fPIC --copt=-fpic --linkopt=-znoexecstack --linkopt=-zrelro --linkopt=-znow --linkopt=-fstack-protector //tensorflow/tools/pip_package:build_pip_package; fi  &&\
    bazel clean && \
    if [ `lscpu | grep avx512 | wc -l` -eq "0" ]; then bazel build  -c opt --config=mkl --cxxopt=-D_GLIBCXX_USE_CXX11_ABI=0 --copt=-O3 --copt=-march=skylake --copt=-Wformat --copt=-Wformat-security  --copt=-fstack-protector --copt=-fPIC --copt=-fpic --linkopt=-znoexecstack --linkopt=-zrelro --linkopt=-znow --linkopt=-fstack-protector //tensorflow/tools/pip_package:build_pip_package; else bazel build  -c opt --config=mkl --cxxopt=-D_GLIBCXX_USE_CXX11_ABI=0 --copt=-O3 --copt=-march=skylake-avx512 --copt=-Wformat --copt=-Wformat-security  --copt=-fstack-protector --copt=-fPIC --copt=-fpic --linkopt=-znoexecstack --linkopt=-zrelro --linkopt=-znow --linkopt=-fstack-protector //tensorflow/tools/pip_package:build_pip_package; fi  &&\
    sed -i "252c\\\"${PYTHON_BIN_PATH:-python3}\" setup.py bdist_wheel ${PKG_NAME_FLAG} >/dev/null" ./bazel-bin/tensorflow/tools/pip_package/build_pip_package && \
    ./bazel-bin/tensorflow/tools/pip_package/build_pip_package dnn25 && \
    pip3 install ./dnn25/tensorflow-2.10.0-cp39-cp39-linux_x86_64.whl

# Model address
ARG MALCONV_MODEL_VER=17b459c8a23ac17d7423c2627b837b3e8cb326c2
ARG MALCONV_MODEL_PACKAGE=https://raw.githubusercontent.com/elastic/ember/master/malconv/malconv.h5
# get model file
RUN wget ${MALCONV_MODEL_PACKAGE} && \
# make fake testing data
    mkdir fakeData && \
    cd fakeData && \
    mkdir KNOWN && \
    mkdir MALICIOUS && \
    for ((i=0; i<2000;++i));do head -c 1M </dev/urandom > ./KNOWN/$i; done && \
    for ((i=0; i<2000;++i));do head -c 1M </dev/urandom > ./MALICIOUS/$i; done
    

COPY script/test.sh script/malconv_test.py script/analyze_scores.py script/h5_to_saved.py script/malconv_int8.yaml script/onnx_quantize.py script/quantize.py script/freeze_saved_model.py script/malconv_bf16.yaml script/onnx.yaml ./

# quantization
RUN mv malconv.h5 emberMalconv.h5 && \
    python3 h5_to_saved.py -m emberMalconv.h5 -o ember_malconv_saved_model && \
    python3 freeze_saved_model.py ember_malconv_saved_model emberMalconv.fp32.pb && \
	python3 -m tf2onnx.convert --opset 13 --input emberMalconv.fp32.pb --inputs input_1:0 --outputs Identity:0 --output emberMalconv.fp32.onnx && \
	python3 quantize.py -i ./fakeData  -m emberMalconv.fp32.pb -c malconv_int8.yaml -o emberMalconv.int8.pb && \
	python3 quantize.py -i ./fakeData  -m emberMalconv.fp32.pb -c malconv_bf16.yaml -o emberMalconv.bf16.pb && \
	python3 onnx_quantize.py -i ./fakeData  -m emberMalconv.fp32.onnx -c onnx.yaml -o emberMalconv.int8.onnx


RUN mkfifo /export-logs
CMD (./test.sh --model ${MODEL} --framework ${FRAMEWORK} --precision ${PRECISION} --isa ${ISA} --mode ${MODE} --cores ${CORES} --tag ${TAG}; echo $? > status) 2>&1 | tee output.logs && \
	tar cf /export-logs status output.logs && \
	sleep infinity
