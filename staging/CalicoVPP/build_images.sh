#!/bin/bash

# shellcheck source=/dev/null
source ./common.sh

function usage {
    cat <<EOF

        build_images.sh is used to build docker images for Calico VPP with DSA testing. After building, below images will be generated,
            calicovpp_dsa_vpp:v1
            calicovpp_dsa_agent:v1
            calicovpp_dsa_vppl3fwd_tun:v1
            calicovpp_dsa_vppl3fwd_memif:v1

        Usage:
            ./build_images.sh [--help|-h]

        Example:
            ./build_images.sh                   # Build images

        Parameters:
            --help|-h: [Optional] Show help messages.

EOF
}

function check_env() {
    info "Checking environment..."
    check_os
    check_golang
    check_docker
}

function clone_code() {
    # Clone Calico VPP vpp-dataplane
    info "Preparing Calico VPP code..."
    git clone -b release/v3.23.0 https://github.com/projectcalico/vpp-dataplane.git "${CALICOVPP_DIR}"
    cd "${CALICOVPP_DIR}" || exit
    git apply "${BASE_DIR}/patch/calicovpp.patch"

    # Clone VPP and reset to 22.02 commit id 7911f29c518c6b2a678e13874f7f16eba03dab75
    info "Preparing VPP code..."
    git clone https://gerrit.fd.io/r/vpp "${VPP_DIR}"
    cd "${VPP_DIR}" || exit
    git reset --hard 7911f29c518c6b2a678e13874f7f16eba03dab75

    # Copy VPP code to Calico VPP folder
    info "Coping VPP code to Calico VPP folder..."
    VPP_BUILD_DIR="${CALICOVPP_DIR}/vpp-manager/vpp_build/"
    cp -r "${VPP_DIR}" "${VPP_BUILD_DIR}"
    cd "${VPP_BUILD_DIR}" || exit
    git apply "${BASE_DIR}/patch/vpp.patch"
    git add .
}

function build_images() {
    # Build agent bin and image
    info "Building Calico VPP agent image..."
    cd "${CALICOVPP_DIR}" || exit
    make -C ./calico-vpp-agent image
    docker tag calicovpp/agent:latest calicovpp_dsa_agent:v1

    # Copy version file
    cp ./calico-vpp-agent/version ./vpp-manager/images/ubuntu

    # Build vpp bin and image
    info "Building Calico VPP vpp image..."
    make -C ./vpp-manager vpp imageonly
    docker tag calicovpp/vpp:latest calicovpp_dsa_vpp:v1

    cd "${BASE_DIR}" || exit
    http_proxy=${http_proxy:-""}
    https_proxy=${https_proxy:-""}
    no_proxy=${no_proxy:-""}

    # Build VPPL3FWD memif image
    info "Building VPPL3FWD memif image..."
    docker build --network=host --build-arg https_proxy="${https_proxy}" --build-arg http_proxy="${http_proxy}" --build-arg no_proxy="${no_proxy}" \
        -f ./dockerfile/Dockerfile_vppl3fwd_memif -t calicovpp_dsa_vppl3fwd_memif:v1 .

    # Build VPPL3FWD tun image
    info "Building VPPL3FWD tun image..."
    docker build --network=host --build-arg https_proxy="${https_proxy}" --build-arg http_proxy="${http_proxy}" --build-arg no_proxy="${no_proxy}" \
        -f ./dockerfile/Dockerfile_vppl3fwd_tun -t calicovpp_dsa_vppl3fwd_tun:v1 .
}

function show_images() {
    info "Calico VPP with DSA related images:"
    docker images | grep calicovpp_dsa
}

##############################################################

# Parse input arguments
UNKNOWN_ARGS=""
while [[ "$1" != "" ]]
do
    arg=$1
    case $arg in
        --help|-h)
            usage && exit
            ;;
        *) UNKNOWN_ARGS="$UNKNOWN_ARGS $arg"
            ;;
    esac
    shift
done
[[ -z "$UNKNOWN_ARGS" ]] || error "Unknown arguments:$UNKNOWN_ARGS"

BASE_DIR=$(pwd)
CALICOVPP_DIR="${BASE_DIR}/vpp-dataplane"
VPP_DIR="${BASE_DIR}/vpp"

rm -rf "${CALICOVPP_DIR}"
rm -rf "${VPP_DIR}"

check_env
clone_code
build_images
show_images
