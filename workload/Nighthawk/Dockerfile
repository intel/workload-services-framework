# nighthawk

#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
ARG NIGHTHAWK_VER=sha256:4df9d32ac1c901136b507a1ace093ef3ea4ab16b29c51102a5ffd4564d73f1bc
ARG NIGHTHAWK_IMAGE=envoyproxy/nighthawk-dev

FROM ${NIGHTHAWK_IMAGE}@${NIGHTHAWK_VER}
# COPY --from=redboxoss/scuttle:latest /scuttle /bin/scuttle
RUN apk add util-linux && apk add curl && apk add bash && apk add busybox-extras && apk add zlib=1.2.12-r3
COPY test-server.yaml /etc/envoy/
RUN mkfifo /export-logs
