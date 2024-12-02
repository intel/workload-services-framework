#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

if ! docker ps > /dev/null 2> /dev/null; then
    curl -h > /dev/null 2>&1 || yum install -y curl

    GET_DOCKER_URL=https://get.docker.com
    (curl -o - $GET_DOCKER_URL || wget -O - $GET_DOCKER_URL) | bash

    if [ "$(id -u)" -ne 0 ]; then
        echo "Add the user to the docker group"
        sudo usermod -aG docker "$(id -un)"
        echo "Please log out and log back to take effect"
    fi

    docker_proxy_conf="/etc/systemd/system/docker.service.d/proxy.conf"
    if [ ! -r "$docker_proxy_conf" ]; then
        echo "Setup docker proxy settings"
        sudo mkdir -p $(dirname $docker_proxy_conf)
        printf "[Service]\nEnvironment=\"HTTP_PROXY=$http_proxy\" \"HTTPS_PROXY=$https_proxy\" \"NO_PROXY=$no_proxy\"\n" | sudo tee $docker_proxy_conf
        sudo systemctl daemon-reload
        sudo systemctl restart docker
    fi
fi
