changecom(`@')
# `gva-cnn-pipeline-dlstreamer'-translit(PLATFORM,`A-Z',`a-z')`'patsubst(`'patsubst(WORKLOAD,`general-video-analytics-cnn',`'),`-generic',`')`'
changecom(`#')

#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
ARG `RELEASE'
FROM `gva-cnn-datasets'`${RELEASE}' AS datasets
FROM `gva-cnn-base'-translit(PLATFORM,`A-Z',`a-z')`'DEVICE`${RELEASE}' AS runner
WORKDIR /home/kpi
COPY --from=datasets /home/kpi/datasets /home/kpi/datasets

ARG DLSTREAMER_VER=2025.0.1.3
ARG DLSTREAMER_REPO=intel-dlstreamer
RUN wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | gpg --dearmor | tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null
RUN wget -O- https://eci.intel.com/sed-repos/gpg-keys/GPG-PUB-KEY-INTEL-SED.gpg | tee /usr/share/keyrings/sed-archive-keyring.gpg > /dev/null
RUN bash -c 'echo "deb [signed-by=/usr/share/keyrings/sed-archive-keyring.gpg] https://eci.intel.com/sed-repos/$(source /etc/os-release && echo $VERSION_CODENAME) sed main" > /etc/apt/sources.list.d/sed.list'
RUN bash -c 'echo -e "Package: *\nPin: origin eci.intel.com\nPin-Priority: 1000" > /etc/apt/preferences.d/sed'
RUN bash -c 'echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/openvino/2025 ubuntu24 main" > /etc/apt/sources.list.d/intel-openvino-2025.list'
RUN apt-get update --fix-missing && apt --fix-broken install -y && apt install -y ${DLSTREAMER_REPO}=${DLSTREAMER_VER}
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

COPY run_dlstreamer.sh /home/kpi/
ENV XDG_RUNTIME_DIR=/home/.xdg_runtime_dir
RUN mkfifo /export-logs && mkdir -p /home/kpi/output/results/logs
CMD (/home/kpi/run_dlstreamer.sh; echo $? > status) 2>&1 | tee /home/kpi/output/results/logs/benchmark_${TestSuit}.log && \
     tar cf /export-logs status dlstreamer.log output/results/logs $(find . -name "*.log") && \
     sleep infinity
