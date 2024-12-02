#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

if(PLATFORM MATCHES "ARMv")
    set(IMAGEARCH "linux/arm64")
    set(IMAGESUFFIX "-arm64")
    add_subdirectory(script/multi-arch)
else()
    set(IMAGEARCH "linux/amd64")
    set(IMAGESUFFIX "")
endif()


