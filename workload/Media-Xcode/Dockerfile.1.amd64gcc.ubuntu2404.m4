changecom(`@')
# media-xcode-defn(`VERSION')-amd64gcc-ubuntu2404
changecom(`#')

#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
ARG `RELEASE'
ARG `IMAGESUFFIX'

FROM ffmpeg-base-defn(`VERSION')-amd64gcc-avx3-ubuntu2404${`IMAGESUFFIX'}${`RELEASE'} as avx3

FROM ffmpeg-base-defn(`VERSION')-amd64gcc-avx2-ubuntu2404${`IMAGESUFFIX'}${`RELEASE'}

COPY scripts/ffmpeg_util.py /home/
COPY defn(`VERSION')/conf/* /home/conf/
COPY --from=avx3 /avx3 /avx3

WORKDIR /home
RUN  mkfifo /export-logs
CMD  (python3 /home/run.py ; echo $? > status) 2>&1 | tee benchmark_${CODEC}_${PRESET}_${NTON}_${MODE}_${RESOLUTION}_$(date +"%m-%d-%y-%H-%M-%S").log && \
     tar cf /export-logs status results $(find . -name "*.log") && \
     sleep infinity
