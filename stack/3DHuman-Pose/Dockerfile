# 3dhuman-pose-base

#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
ARG OS_VER=22.04
ARG OS_IMAGE=ubuntu

FROM ${OS_IMAGE}:${OS_VER}

# install dependencies
ARG WGET_VERSION=1.21.2-2ubuntu1
RUN apt-get update && apt-get install -y --no-install-recommends  wget=${WGET_VERSION}  && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install miniconda
ARG CONDA_DIR=/opt/conda
ARG CONDA_VER=Miniconda3-py39_4.12.0-Linux-x86_64.sh
ARG CONDA_REPO=https://repo.anaconda.com/miniconda
RUN wget -nv --no-check-certificate  ${CONDA_REPO}/${CONDA_VER} -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p ${CONDA_DIR}
ARG CONDA_EXE=${CONDA_DIR}/condabin/conda

# Conda enviroment setup
ARG ENV_NAME=3dhuman
ARG PYTHON_VERSION=3.9
RUN ${CONDA_EXE} create --name ${ENV_NAME} python=${PYTHON_VERSION}
ENV PATH=${CONDA_DIR}/envs/${ENV_NAME}/bin:$PATH

# Copy sdk
WORKDIR /3DHuman-Pose-Estimation
COPY motion-tracking-sdk .

# Install python libs
RUN pip install --no-cache-dir  -r requirements.txt

ARG OPENCV_PYTHON_HEADLESS_VAR=4.5.5.62
ARG OPENCV_PYTHON_HEADLESS_REPO=https://pypi.python.org/simple
RUN pip install --no-cache-dir opencv-python-headless==${OPENCV_PYTHON_HEADLESS_VAR}  --index-url=${OPENCV_PYTHON_HEADLESS_REPO} && \
    python -m tool.torch2openvino