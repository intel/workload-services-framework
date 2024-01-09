changecom(`@')
# ffmpegmediaxcode-x264-defn(`VERSION')-amd64gcc-avx2
changecom(`#')

#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
ARG `RELEASE'
ARG `IMAGESUFFIX'
FROM ffmpeg-base-defn(`VERSION')-amd64gcc-avx2${`IMAGESUFFIX'}${`RELEASE'}

COPY conf/* /home/conf/

WORKDIR /home
RUN  mkfifo /export-logs
CMD  (python3 /home/run.py ; echo $? > status) 2>&1 | tee benchmark_${CODEC}_${PRESET}_${NTON}_${MODE}_${RESOLUTION}_$(date +"%m-%d-%y-%H-%M-%S").log && \
     tar cf /export-logs status results $(find . -name "*.log") && \
     sleep infinity
