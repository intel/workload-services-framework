#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
file(GLOB global_legacy_jdk_variants "cmake/legacy-jdk/*.cmake")
foreach(jdk_variant ${global_legacy_jdk_variants})
    include(${jdk_variant})
endforeach()

list(APPEND legacy_jdk_variants
   ${legacy_openjdk_versions}
   ${legacy_dragonwell_versions}
   ${legacy_zulu_versions})

foreach(jdk ${legacy_jdk_variants})
   add_stack("${jdk}-ubuntu24")
endforeach()
