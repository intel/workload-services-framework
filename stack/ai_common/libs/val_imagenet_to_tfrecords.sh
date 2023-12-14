#!/usr/bin/env bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# Input args
IMAGENET_HOME=${1}

VALIDATION_TAR=${IMAGENET_HOME}/ILSVRC2012_img_val.tar
WORKDIR=$(pwd)

# Arg validation: Verify that the IMAGENET_HOME dir exists
if [[ -z ${IMAGENET_HOME} ]]; then
  echo "The directory of ImageNet tar files is required for arg 1"
  exit 1
elif [[ ! -d ${IMAGENET_HOME} ]]; then
  echo "The ImageNet directory (${IMAGENET_HOME}) specified in arg 1 does not exist"
  exit 1
elif [[ ! -f ${VALIDATION_TAR} ]]; then
  echo "The ImageNet validation tar file does not exist at ${VALIDATION_TAR}"
  exit 1
fi

# Download the labels file, if it doesn't already exist in the IMAGENET_HOME dir
LABELS_FILE=$IMAGENET_HOME/synset_labels.txt
if [[ ! -f ${LABELS_FILE} ]]; then
  wget -O $LABELS_FILE \
  https://raw.githubusercontent.com/tensorflow/models/v2.3.0/research/inception/inception/data/imagenet_2012_validation_synset_labels.txt
fi

# Setup folders
mkdir -p $IMAGENET_HOME/validation
cd $IMAGENET_HOME

# Extract validation and training
tar xf ${VALIDATION_TAR} -C $IMAGENET_HOME/validation

cd ${WORKDIR}
# Download `imagenet_to_gcs.py` script from the Intel model zoo repo to convert the dataset files to TF records
if [[ ! -f "${WORKDIR}/imagenet_to_gcs.py" ]]; then
    wget https://raw.githubusercontent.com/IntelAI/models/master/datasets/imagenet/imagenet_to_gcs.py
fi
python3 ${WORKDIR}/imagenet_to_gcs.py \
  --raw_data_dir=$IMAGENET_HOME \
  --local_scratch_dir=$IMAGENET_HOME/tf_records

# Combine the two folders in tf-records together
cd $IMAGENET_HOME/tf_records
mv validation $IMAGENET_HOME/tf_records
rm -rf ${IMAGENET_HOME}/ILSVRC2012_img_val.tar

cd ${WORKDIR}
