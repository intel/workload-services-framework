#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

nssds="$(gcloud compute machine-types describe $1 --zone $2 --format json | sed -n '/local SSD/{s/^.*, *\([0-9]*\) *local SSD.*/\1/;p;q}')"
cat <<EOF
{
  "local_ssds": "${nssds:-0}"
}
EOF
