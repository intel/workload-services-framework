#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
list(APPEND openjdk_versions
   openjdk-16.0.2
   openjdk-17.0.1
   openjdk-18.0.2
   openjdk-20)

list(REMOVE_DUPLICATES openjdk_versions)

foreach(jdk ${openjdk_versions})
   add_stack("${jdk}")
endforeach()
