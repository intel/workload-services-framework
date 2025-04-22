# JDK that only supports x86 architectures
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
list(APPEND legacy_openjdk_versions
   openjdk-8   
   openjdk-11.0.11)

list(REMOVE_DUPLICATES legacy_openjdk_versions)

#foreach(jdk ${legacy_openjdk_versions})
#   add_stack("jdk_${jdk}")
#endforeach()
