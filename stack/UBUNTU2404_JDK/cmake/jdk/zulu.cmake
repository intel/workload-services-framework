#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
list(APPEND zulu_versions
    zulu-16.32.15
    zulu-17.36.17
    zulu-18.32.13
    zulu-19.30.11)

list(REMOVE_DUPLICATES zulu_versions)

foreach(jdk ${zulu_versions})
   add_stack("${jdk}-ubuntu24")
endforeach()
