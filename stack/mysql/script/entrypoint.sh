#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
/prepare_database.sh
/usr/local/bin/docker-entrypoint.sh "$@"
