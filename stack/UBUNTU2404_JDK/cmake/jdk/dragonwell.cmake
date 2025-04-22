#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
list(APPEND dragonwell_versions
   dragonwell-11.0.18 )

foreach(jdk ${dragonwell_versions})
   add_stack("${jdk}-ubuntu24")
endforeach()
