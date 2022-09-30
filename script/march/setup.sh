#!/bin/bash -e

version () {
    printf '%02d' $(echo "$1" | tr . ' ' | sed -e 's/ 0*/ /g')
}

check_flag () {
    grep flags: $1 2> /dev/null | sed 's|^.*F$|F|'
}

if docker version | grep -q -E 'OS/Arch:.*linux/amd64'; then
    # check binfmt_misc version
    kernel_version=$(uname -r | sed 's|-.*||')
    if [[ "$(version $kernel_version)" < "$(version 4.8)" ]]; then
        echo "Fixed_Binary not supported in kernel version earlier than 4.8"
        exit 3
    fi

    # check F flag in /proc/sys/fs/binfmt_misc/qemu-aarch64
    march_path="/proc/sys/fs/binfmt_misc/qemu-aarch64"
    if [ -z "$(check_flag $march_path)" ]; then
        docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
        if [ -z "$(check_flag $march_path)" ]; then
            echo "Failed to setup qemu with Fixed_Binary flags"
            exit 3
        fi
    fi
fi
