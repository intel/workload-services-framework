#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
if(PLATFORM STREQUAL "GRAVITON2")
  set(PLATFORM_CONV_FROM " (${red}${PLATFORM}${reset})")
  set(PLATFORM "ARMv8")
elseif(PLATFORM STREQUAL "GRAVITON3")
  set(PLATFORM_CONV_FROM " (${red}${PLATFORM}${reset})")
  set(PLATFORM "ARMv9")
endif()
