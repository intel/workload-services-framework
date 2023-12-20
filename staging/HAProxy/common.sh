#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# This script defines common functions

# Versions
export OPENSSL_VER="1_1_1u"
export HAPROXY_VER="v2.8.0"
export NGINX_VER="1.25.1"
export IPP_CRYPTO_VER="ippcp_2021.7.1"
export IPSEC_MB_VER="v1.3"
export QATENGINE_VER="v1.2.0"
export QATHW_OOT_DRIVER_VER="QAT20.L.1.0.50-00003"
export QATHW_OOT_DRIVER_VER_1X="QAT.L.4.19.0-00005"
export WRK_VER="4.2.0"

# Dirs
BASE_DIR=$(pwd)
export BASE_DIR
export CONFIGS_DIR=$BASE_DIR/configs
export CONFIGS_DEP_DIR=$BASE_DIR/configs_dep
export HAPROXY_KEYS_DIR=$BASE_DIR/keys
export QAT_OOT_DRIVER_DIR="/opt/intel/QAT"
export OPENSSL_INCLUDE_DIR="/usr/local/include"
export OPENSSL_LIBRARIES_DIR="/usr/local/lib"
export OPENSSL_ROOT_DIR="/usr/local"
export IPSEC_MB_LIBRARIES_DIR="/usr/local/lib"
export NGINX_WEB_ROOT="/var/www/html/haproxy_nginx_root"

# Configuration parameters file
export CONFIG_PARAMS_FILE=$CONFIGS_DEP_DIR/config_params.txt

# Ulimit config file
export ULIMIT_CONFIG_FILE="/etc/security/limits.d/haproxy.conf"

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

# Check if NIC interface exists. Format: var_name var_vals
function check_nic_interfaces() {
    IFS=',' read -ra nic_array <<< "$2"
    for nic in "${nic_array[@]}"; do
        sudo ethtool "$nic" > /dev/null 2>&1 || error "Interface '$nic' does not exist."
        sudo ethtool "$nic" | grep -q "Link detected: yes" || error "Interface '$nic' is not linked."
    done
}

# Check OS
function check_os() {
    os_name=$(grep 'NAME="Ubuntu"' < /etc/os-release)
    os_ver=$(grep 'VERSION_ID="22.04"' < /etc/os-release)
    [[ -n "${os_name}" && -n "${os_ver}" ]] || error "Only Ubuntu 22.04 is supported."
}

# Check if current user is root
function check_is_user_root() {
    [ ! "$(id -u)" -ne 0 ] || error "Please use root account to run this script."
}
