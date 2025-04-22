#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
check_license(media.xiph.org "\n\nPlease accept downloading dataset from media.xiph.org for media transcoding. The terms and conditions of the data set license apply. Intel does not grant any rights to the data files.\n\n")
add_stack("ffmpeg_ubuntu2404_v44" LICENSE "media.xiph.org")
add_testcase(${stack}_avx2_sanity avx2)
add_testcase(${stack}_avx3_sanity avx3)

add_stack("ffmpeg_ubuntu2404_v60" LICENSE "media.xiph.org")
add_testcase(${stack}_avx2_sanity avx2)
add_testcase(${stack}_avx3_sanity avx3)