#!/bin/bash

# shellcheck source=/dev/null
source ./common.sh

function usage {
    cat <<EOF

        reset_env.sh is used to reset K8S, uninstall K8S or uninstall all related components.
        By default is to reset K8S, if need to uninstall K8S component or all components, need to specify '--uninstall k8s' or '--uninstall all'.

        Usage:
            ./reset_env.sh [--uninstall k8s|all] [-y] [--help|-h]

        Example:
            ./reset_env.sh                   # Reset K8S environment
            ./reset_env.sh --uninstall k8s   # Reset K8S env and uninstall K8S components
            ./reset_env.sh --uninstall all   # Reset K8S env and uninstall all related components, includes Docker, K8S, Golang, DPDK tool

        Parameters:
            --uninstall k8s|all: [Optional] Specify if need to uninstall K8S component or uninstall all related components, includes Docker, 
                K8S, Golang, DPDK tool, etc.
            -y: [Optional] Confirm reset.
            --help|-h: [Optional] Show help messages.

EOF
}

function reset_k8s() {
    confirm "K8S will be reset"
    do_reset_k8S
    delete_k8s_config
    flush_iptables
    restart_docker_service
    rebind_nic_interface
    info "Succeed to reset K8S."
}

function uninstall_k8s() {
    confirm "K8S will be uninstalled"
    do_reset_k8S
    do_uninstall_k8S
    delete_k8s_config
    flush_iptables
    restart_docker_service
    rebind_nic_interface
    info "Succeed to uninstall K8S."
}

function uninstall_all() {
    confirm "All components will be uninstalled"
    do_reset_k8S
    do_uninstall_k8S
    delete_k8s_config
    do_uninstall_docker
    delete_docker_config
    uninstall_golang
    uninstall_dpdk_tool
    uninstall_unused_packages
    flush_iptables
    rebind_nic_interface
    info "Succeed to uninstall all components."
}

function do_reset_k8S() {
    info "Reseting K8S..."
    [[ -x "$(command -v kubeadm)" ]] && sudo kubeadm reset --force
}

function do_uninstall_k8S() {
    info "Uninstalling K8S..."
    [[ -x "$(command -v kubelet)" ]] && sudo systemctl stop kubelet
    sudo apt purge -y kubeadm kubectl kubelet --allow-change-held-packages
}

function do_uninstall_docker() {
    info "Uninstalling Docker..."
    if [[ -x "$(command -v docker)" ]]; then
        docker stop "$(docker ps -aq)"
        docker system prune -f
        docker volume rm -f "$(docker volume ls -q)"
        docker image rm -f "$(docker image ls -q)"
        sudo systemctl stop docker
        sudo systemctl stop containerd
    fi
    sudo apt purge docker-ce docker-ce-cli containerd.io -y
}

function delete_k8s_config() {
    info "Deleting K8S configurations..."
    sudo rm -rf /etc/kubernetes/
    sudo rm -rf /run/kubernetes/
    sudo rm -rf /etc/sysctl.d/kubernetes.conf
    sudo rm -rf /etc/cni/
    sudo rm -rf /opt/cni/
    sudo rm -rf /var/lib/cni/
    sudo rm -rf /var/run/calico/
    sudo rm -rf /var/lib/calico
    sudo rm -rf /var/etcd
    sudo rm -rf /var/lib/etcd/
    sudo rm -rf /var/run/vpp/
    sudo rm -rf "$HOME/.kube"
}

function delete_docker_config() {
    info "Deleting Docker configurations..."
    sudo rm -rf /etc/docker/
    sudo rm -rf /etc/systemd/system/docker.service.d/
    sudo rm -rf /var/lib/docker
    sudo rm -rf /var/lib/containerd
    sudo rm -rf /etc/modules-load.d/containerd.conf 
}

function restart_docker_service() {
    info "Restarting Docker service..."
    if ! [[ -x "$(command -v docker)" ]]; then
        warn "Docker has NOT been installed."
        return
    fi
    sudo systemctl daemon-reload || error "Failed to reload daemon."
    sudo systemctl restart containerd || error "Failed to restart containerd service."
    sudo systemctl restart docker || error "Failed to restart Docker service."
}

function flush_iptables() {
    info "Flushing iptables..."
    sudo iptables -t nat -F
}

function uninstall_golang() {
    info "Uninstalling Golang..."
    sudo rm -f /usr/local/bin/go && sudo rm -rf /usr/local/go
}

function uninstall_dpdk_tool() {
    info "Uninstalling DPDK tool..."
    sudo rm -f /usr/local/bin/dpdk-devbind.py && sudo rm -rf /usr/local/dpdk-*
}

function uninstall_unused_packages() {
    info "Uninstalling unused packages..."
    sudo apt autoremove -y
}

# Rebind NIC interface from DPDK to kernel
function rebind_nic_interface() {
    [[ -f "$CONFIG_PARAMS_FILE" ]] || return
    info "Rebinding NIC interface..."
    interface_pci=$(grep "NIC interface pci" < "$CONFIG_PARAMS_FILE" | awk '{ print $3 }')
    if [[ -z $interface_pci ]]; then
        warn "Interface PCI number is empty, skip rebinding."
        return
    fi
    sudo dpdk-devbind.py -u "$interface_pci" --force > /dev/null 2>&1
    sudo dpdk-devbind.py -b ice "$interface_pci" --force > /dev/null 2>&1
}

##############################################################

# Define uninstallation types
UNINSTALL_TYPE_K8S="k8s"
UNINSTALL_TYPE_ALL="all"

# Parse input arguments
UNKNOWN_ARGS=""
while [[ "$1" != "" ]]
do
    arg=$1
    case $arg in
        --uninstall|-u)
            shift
            [ "$1" = "" ] && error "$arg flag must be followed by a value"
            [ "$1" != $UNINSTALL_TYPE_K8S ] && [ "$1" != $UNINSTALL_TYPE_ALL ] && \
                error "$arg flag can only be '$UNINSTALL_TYPE_K8S' or '$UNINSTALL_TYPE_ALL'."
            uninstall_type=$1
            ;;
        -y)
            skip_confirm="true" && export skip_confirm
            ;;
        --help|-h)
            usage && exit
            ;;
        *) UNKNOWN_ARGS="$UNKNOWN_ARGS $arg"
            ;;
    esac
    shift
done
[[ -z "$UNKNOWN_ARGS" ]] || error "Unknown arguments:$UNKNOWN_ARGS"

# Check operations
if [[ -z "$uninstall_type" ]]; then
    reset_k8s
elif [[ "$uninstall_type" = "$UNINSTALL_TYPE_K8S" ]]; then
    uninstall_k8s
elif [[ "$uninstall_type" = "$UNINSTALL_TYPE_ALL" ]]; then
    uninstall_all
else
    error "Unknow uninstallation type: $uninstall_type"
fi
