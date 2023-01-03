#!/bin/bash

# shellcheck source=/dev/null
source ./common.sh

function usage {
    cat <<EOF

        install_env.sh is used to install necessary components for Calico VPP with DSA image building and testing.

        Usage:
            ./install_env.sh [--help|-h]

        Example:
            ./install_env.sh                   # Install components

        Parameters:
            --help|-h: [Optional] Show help messages.

EOF
}

function install_golang() {
    GO_PKG=go1.19.3.linux-amd64.tar.gz
    for i in $(seq 10); do
        info "Installing Golang..."
        if curl -OL https://golang.org/dl/${GO_PKG} && \
            sudo rm -f /usr/local/bin/go && sudo rm -rf /usr/local/go && \
            sudo tar -C /usr/local -xzf ${GO_PKG} && rm -f ${GO_PKG} && \
            sudo ln -s /usr/local/go/bin/go /usr/local/bin/go; then
            info "Installed Golang successfully."
            return
        fi
        warn "Failed to install Golang, waiting 30s and retry...#${i}"
        sleep 30
    done
    error "Failed to install Golang."
}

function install_docker() {
    info "Installing Docker..."
    DOCKER_VER=5:20.10.18~3-0~ubuntu-jammy
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository -y "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get update
    sudo apt-get -y install containerd.io=1.6.10-1 docker-ce=${DOCKER_VER} docker-ce-cli=${DOCKER_VER} --allow-change-held-packages

    setup_docker_proxy
    setup_docker_config
    sudo usermod -aG docker "$USER" || error "Failed to add current user to docker group."

    sudo systemctl daemon-reload
    sudo systemctl restart docker > /dev/null
    # Check Docker status and restart if failed
    for i in $(seq 10); do
        if sudo systemctl status docker > /dev/null; then
            info "Start Docker successfully."
            return
        fi
        warn "Failed to start Docker service, waiting 30s and retry...#${i}"
        sleep 30
        info "Starting Docker..."
        sudo systemctl start docker > /dev/null
    done
    error "Failed to install Docker."
}

function setup_docker_proxy() {
    info "Setting Docker proxy..."
    sudo mkdir -p /etc/systemd/system/docker.service.d
    if [[ -n "${http_proxy}" ]]; then
        sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=${http_proxy}"
EOF
    fi
    if [[ -n "${https_proxy}" ]]; then
        sudo tee /etc/systemd/system/docker.service.d/https-proxy.conf <<EOF
[Service]
Environment="HTTPS_PROXY=${https_proxy}"
EOF
    fi
    if [[ -n "${no_proxy}" ]]; then
        sudo tee /etc/systemd/system/docker.service.d/no-proxy.conf <<EOF
[Service]
Environment="NO_PROXY=${no_proxy}"
EOF
    fi
}

function setup_docker_config() {
    info "Setting Docker configuration..."
    sudo mkdir -p /etc/docker
    sudo tee /etc/docker/daemon.json <<EOF
{
    "insecure-registries" : [],
    "exec-opts":["native.cgroupdriver=systemd"],
    "experimental": true,
    "registry-mirrors": []
}
EOF
}

function install_k8s() {
    info "Installing K8S..."
    sudo DEBIAN_FRONTEND='noninteractive' /usr/bin/apt-get -y install apt-transport-https ca-certificates curl
    sudo curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
    sudo add-apt-repository -y "deb [arch=$(dpkg --print-architecture)] http://apt.kubernetes.io/ kubernetes-xenial main"
    sudo apt-get -y install kubeadm="${K8S_VER}" kubelet="${K8S_VER}" kubectl="${K8S_VER}" || error "Failed to install K8S related components."
}

function install_dpdk_tool() {
    DPDK_VER=21.05
    DPDK_PKG=dpdk-${DPDK_VER}.tar.xz
    for i in $(seq 10); do
        info "Installing DPDK tool..."
        if curl -OL https://fast.dpdk.org/rel/${DPDK_PKG} && \
            sudo rm -f /usr/local/bin/dpdk-devbind.py && sudo rm -rf /usr/local/dpdk-* && \
            sudo tar -C /usr/local -xf ${DPDK_PKG} && rm -f ${DPDK_PKG} && \
            sudo ln -s /usr/local/dpdk-${DPDK_VER}/usertools/dpdk-devbind.py /usr/local/bin/dpdk-devbind.py; then
            info "Installed DPDK tool successfully."
            return
        fi
        warn "Failed to install DPDK tool, waiting 30s and retry...#${i}"
        sleep 30
    done
    error "Failed to install DPDK tool."
}

function install_building_tools() {
    info "Installing building components..."
    sudo apt-get -y install make gcc git python3 ethtool net-tools || error "Failed to install building components."
}

function config_network_parameters() {
    info "Configuring network parameters..."
    sudo tee /etc/modules-load.d/95-vpp.conf <<EOF
vfio-pci
EOF
    sudo modprobe vfio-pci || error "Failed to configure vfio-pci driver."
}

function disable_firewall() {
    info "Disabling firewall..."
    sudo ufw disable > /dev/null || error "Failed to disable firewall."
}

function check_installation_status() {
    info "Checking installation status..."
    # Check Golang
    if [[ -x "$(command -v go)" ]]; then
        info "Golang has been installed - OK"
    else
        warn "Golang has NOT been installed - FAILED"
    fi
    # Check Docker and service
    if [[ -x "$(command -v docker)" ]]; then
        info "Docker has been installed - OK"
    else
        warn "Docker has NOT been installed - FAILED"
    fi
    if sudo systemctl status docker > /dev/null; then
        info "Docker service has been started - OK"
    else
        warn "Docker service has NOT been started - FAILED"
    fi
    # Check K8S
    if [[ -x "$(command -v kubeadm)" && -x "$(command -v kubelet)" && -x "$(command -v kubectl)" ]]; then
        info "K8S has been installed - OK"
    else
        warn "K8S has NOT been installed - FAILED"
    fi
    # Check DPDK tool
    if [[ -x "$(command -v dpdk-devbind.py)" ]]; then
        info "DPDK tool has been installed - OK"
    else
        warn "DPDK tool has NOT been installed - FAILED"
    fi
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

check_os
install_golang
install_docker
install_k8s
install_dpdk_tool
install_building_tools
config_network_parameters
disable_firewall
check_installation_status
