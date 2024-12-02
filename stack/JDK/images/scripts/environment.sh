#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

export JAVA_HOME=${JDK_INSTALL_DIR}/${JDK_VER}/
export JRE_HOME=${JDK_INSTALL_DIR}/${JDK_VER}/jre/
export PATH=${JDK_INSTALL_DIR}/${JDK_VER}/bin:$PATH:${JDK_INSTALL_DIR}/${JDK_VER}/jre/bin