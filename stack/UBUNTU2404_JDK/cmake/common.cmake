#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
file(GLOB global_jdk_variants "cmake/jdk/*.cmake")
foreach(jdk_variant ${global_jdk_variants})
    include(${jdk_variant})
endforeach()
