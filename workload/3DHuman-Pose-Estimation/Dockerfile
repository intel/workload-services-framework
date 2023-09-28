# 3dhuman-pose-estimation

#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
ARG BASE_VER="latest"
FROM 3dhuman-pose-base:${BASE_VER}

# WSF Entrypoint
RUN  mkfifo /export-logs
CMD ["/bin/bash", "-c", "(python -m main -i resources/${INPUT_VIDEO} -if ${INFERENCE_FRAMEWORK} -d ${INFERENCE_DEVICE} -pm online -npb; echo $? > status) 2>&1 | tee output.logs && tar cf /export-logs status output.logs && sleep infinity"]