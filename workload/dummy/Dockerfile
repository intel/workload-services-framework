# dummy

# Copyright (c) 2022 Intel Corporation
# SPDX-License-Identifier: Apache License 2.0

# The last of the first two comment lines defines the docker image name. If the comment
# line starts with #, then the image will be pushed to the docker registry if defined.
# If comment line starts with ##, then the image is a local image and will not be pushed. 
# See doc/dockerfile.md for full documentation.  

# You can use any base OS in your workload. Popular choices are ubuntu, debian and alpine.
# Declare the OS ingredient as OS_VER and OS_IMAGE.
ARG OS_VER=3.15
ARG OS_IMAGE=alpine

FROM ${OS_IMAGE}:${OS_VER}

# For any major ingredients of the workload, list them as pairs of _VER and _REPO ARGS.
# This will be extracted by the script to the github Wiki in the workload ingredient 
# table. You can also use _VER/_PACKAGE, _VER/_IMAGE pairs for the same purpose. 
ARG DUMMY_VER=0.7
ARG DUMMY_REPO=https://github.com/dummy/dummy.git

# See QATzip for an example of git cloning a repository with access control. 

COPY run_test.sh /

# This is the standarized logs collection sequence. In this example, the logs is the 
# standard output but the logs can contain anything relevant to the workload execution. 
# The logs are archived together with the workload exit code to a fifo /export-logs. 
# Then sleep infinity for logs retrievial.
RUN  mkfifo /export-logs
CMD  (/run_test.sh; echo $? > status) 2>&1 | tee output.logs && \
     tar cf /export-logs status output.logs && \
     sleep infinity
