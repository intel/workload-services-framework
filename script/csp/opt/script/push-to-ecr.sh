#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

registry_id=${1%.dkr.ecr.*}
region=${1%.amazonaws.com/*}
region=${region/*dkr.ecr./}
repository_name=${1#*.amazonaws.com/}
repository_name=${repository_name%:*}

if [[ "$(aws ecr describe-repositories --region $region)" != *"\"$repository_name\""* ]]; then
    aws ecr create-repository --repository-name $repository_name --region $region > /dev/null
fi
[ "$2" = "--create-only" ] || docker -D push $1
