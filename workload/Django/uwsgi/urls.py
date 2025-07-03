# Copyright 2017-present, Facebook, Inc.
# All rights reserved.
#
# This source code is licensed under the license found in the
# LICENSE file in the root directory of this source tree.
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

from django.urls import re_path

from . import views


urlpatterns = [
    re_path(r'^$', views.index, name='index'),
    re_path(r'^feed_timeline$', views.feed_timeline, name='feed_timeline'),
    re_path(r'^timeline$', views.timeline, name='timeline'),
    re_path(r'^bundle_tray$', views.bundle_tray, name='bundle_tray'),
    re_path(r'^inbox$', views.inbox, name='inbox'),
    re_path(r'^seen$', views.seen, name='seen'),
]