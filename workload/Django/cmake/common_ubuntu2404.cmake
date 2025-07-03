#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("django_ubuntu2404")

add_testcase("django_tls_on_3nodes_ubuntu2404" "on" "3" "ubuntu2404")
add_testcase("django_tls_off_3nodes_ubuntu2404" "off" "3" "ubuntu2404")
add_testcase("django_tls_on_3nodes_ubuntu2404_gated" "on" "3" "ubuntu2404")
add_testcase("django_tls_on_3nodes_ubuntu2404_pkm" "on" "3" "ubuntu2404")