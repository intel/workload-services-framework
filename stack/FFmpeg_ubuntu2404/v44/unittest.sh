#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

ffmpeg -y -i /home/archive/Mixed_40sec_1920x1080_60fps_8bit_420_crf23_veryslow.mp4 -c:v libx264 -preset medium -x264-params "keyint=120:min-keyint=120:sliced-threads=0:scenecut=0:asm=avx2:threads=8" -tune psnr -profile:v high -b:v 6M -maxrate 12M -bufsize 24M -r 60  -y 1080p.mp4

