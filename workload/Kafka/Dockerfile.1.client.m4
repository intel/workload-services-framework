changecom(`@')
# kafka-client-patsubst(WORKLOAD,`.*_',`')
changecom(`#')

#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
ARG `RELEASE'
ARG `IMAGESUFFIX'
FROM patsubst(WORKLOAD,`_',`-')-base`${IMAGESUFFIX}${RELEASE}'

# Copy helper script and testcases
COPY script/common.sh ${BASE_DIR}
COPY script/run_test.sh ${BASE_DIR}
COPY script/start_test.py ${BASE_DIR}
ENV PATH=$PATH:${BASE_DIR}

RUN mkfifo /export-logs

CMD (./run_test.sh; echo $? > status) 2>&1 | tee ${K_IDENTIFIER}_std.logs && \
    cat log* > ${K_IDENTIFIER}_output.logs && \
    sync status ${K_IDENTIFIER}_output.logs ${K_IDENTIFIER}_std.logs && \
    tar cf /export-logs status ${K_IDENTIFIER}_output.logs ${K_IDENTIFIER}_std.logs && \
    sleep infinity
