#!/bin/bash

# This script defines common functions

# K8S version
export K8S_VER=1.23.12-00

# Dirs
BASE_DIR=$(pwd)
export BASE_DIR
export CONFIGS_DIR=$BASE_DIR/configs
export CONFIGS_DEP_DIR=$BASE_DIR/configs_dep

# Configuration parameters file
export CONFIG_PARAMS_FILE=$CONFIGS_DEP_DIR/config_params.txt

# Logs functions
function logdate { date "+%Y-%m-%d %H:%M:%S"; }
function info { echo "$(logdate) [INFO] $*"; }
function warn { echo "$(logdate) [WARN] $*"; }
function error { echo "$(logdate) [ERROR] $*"; exit 1; }

# Show confirm message
function confirm() {
    if [[ "${skip_confirm:-''}" != "true" ]]; then
        read -r -p "${1}. Are you sure to continue? [y/N] " response
        case "${response}" in
            [yY][eE][sS]|[yY])
                return
                ;;
            *)
                exit 0
                ;;
        esac
    fi
}

# Check if value is empty or not. Format: var_name var_val
function check_not_empty() {
    [[ -n "$2" ]] || error "$1 value cannot be empty."
}

# Check if number is in range. Format: var_name var_val var_min var_max
function check_number_in_range() {
    [[ $2 =~ ^-?[0-9]+$ ]] || error "$1 value '$2' is not a number."
    [[ $2 -ge $3 && $2 -le $4 ]] || error "$1 value '$2' is not in range [$3,$4]."
}

# Check if value exists or not. Format: var_name var_val var_val1 var_val2 ...
function check_value_exist() {
    local e
    for e in "${@:3}"; do 
        [ "$e" = "$2" ] && return 
    done
    error "$1 value '$2' is not supported, accept values: ${*:3}."
}

# Check if value is a valid CIDR. Format: var_name var_val
function check_cidr() {
    [[ "$2" =~ ^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/(3[0-2]|[1-2][0-9]|[1-9]))$ ]] || error "'$2' is not a valid CIDR."
}

# Check if NIC interface exists. Format: var_name var_val
function check_nic_interface() {
    sudo ethtool "$2" > /dev/null 2>&1 || error "Interface '$2' does not exist."
    sudo ethtool "$2" | grep -q "Link detected: yes" || error "Interface '$2' is not linked."
}

# Check ipv4 address. Format: var_name var_val
function check_ipv4_address() {
    [[ "$2" =~ ^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$ ]] || error "'$2' is not a valid IPv4 address."
}

# Check MAC address. Format: var_name var_val
function check_mac_address() {
    [[ "$2" =~ ^([a-fA-F0-9]{2}:){5}[a-fA-F0-9]{2}$ ]] || error "'$2' is not a valid MAC address."
}

# Check if DSA device exist. Format: var_name var_val
function check_dsa_device() {
    sudo lspci -v | grep 0b25 | awk '{print $1}' | grep -q -e "^${2}$" || error "DSA device '$2' does not exist."
}

# Check if swap is disabled
function check_swap() {
    [[ -z "$(swapon -s)" ]] || error "Swap is enabled, please disable it and try again."
}

# Check hugepages, hugepage size should be 1G, hugepages should be >= 16
function check_hugepages() {
    grep Hugepagesize < /proc/meminfo | grep -q 1048576 || error "Hugepage size is not 1G."
    hugepages=$(grep HugePages_Total < /proc/meminfo | awk '{print $2}')
    [[ $hugepages -ge 16 ]] || error "Hugepages cannot be less than 16."
}

# Check OS
function check_os() {
    os_name=$(grep 'NAME="Ubuntu"' < /etc/os-release)
    os_ver=$(grep 'VERSION_ID="22.04"' < /etc/os-release)
    [[ -n "${os_name}" && -n "${os_ver}" ]] || error "Only Ubuntu 22.04 is supported."
}

# Check Golang
function check_golang() {
    [[ -x "$(command -v go)" ]] || error "Golang is not installed."
}

# Check docker service
function check_docker() {
    [[ -x "$(command -v docker)" ]] || error "Docker is not installed."
    sudo systemctl status docker > /dev/null || error "Docker service is stopped."
}

# Check K8S
function check_k8s() {
    [[ -x "$(command -v kubeadm)" && -x "$(command -v kubelet)" && -x "$(command -v kubectl)" ]] || error "K8S is not installed."
}

# Check if K8S has been configured
function check_if_has_configured() {
    sudo systemctl status kubelet > /dev/null && error "K8S has been configured, please run command './reset_env.sh -y' to reset it before configuring."
}

# Check if Calico VPP with DSA images exists
function check_calicovpp_dsa_images() {
    docker images | grep  -q -e "^calicovpp_dsa_vpp *v" || error "Cannot find Docker image: calicovpp_dsa_vpp:v1"
    docker images | grep  -q -e "^calicovpp_dsa_agent *v1" || error "Cannot find Docker image: calicovpp_dsa_agent:v1"
}

# Check l3fwd dsa/sw image
function check_l3fwd_dsa_sw_image() {
    docker images | grep  -q -e "^calicovpp_dsa_vppl3fwd_memif *v1" || error "Cannot find Docker image: calicovpp_dsa_vppl3fwd_memif:v1"
}

# Check l3fwd tun image
function check_l3fwd_tun_image() {
    docker images | grep  -q -e "^calicovpp_dsa_vppl3fwd_tun *v1" || error "Cannot find Docker image: calicovpp_dsa_vppl3fwd_tun:v1"
}
