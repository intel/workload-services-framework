#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

TEMPLATE_FILE=cassandra.yaml.template
OUTPUT_FILE=cassandra.yaml

cp ${TEMPLATE_FILE} ${OUTPUT_FILE}
