changecom(`@')
# STACK-unittest
changecom(`#')

#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
ARG `IMAGESUFFIX'
ARG `RELEASE'

FROM STACK-base`${IMAGESUFFIX}${RELEASE}'

COPY unittest.sh /
RUN chmod +x /unittest.sh \
    && mkfifo /export-logs

CMD (sh /unittest.sh;  echo $? > status) 2>&1 && \
    tar cf /export-logs status && \
    sleep infinity
