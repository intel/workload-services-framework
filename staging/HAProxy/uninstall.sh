#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# shellcheck source=/dev/null
source ./common.sh

function usage {
    cat <<EOF

        uninstall.sh is used to uninstall all HAProxy related components.

        Usage:
            sudo ./uninstall.sh [-y] [--help|-h]

        Example:
            sudo ./uninstall.sh                     # Uninstall all HAProxy related components

        Parameters:
            --help|-h: [Optional] Show help messages.

EOF
}

function uninstall_openssl() {
    info "Uninstalling openssl..."
    [ -d "$BASE_DIR/openssl" ] || return
    (cd "$BASE_DIR/openssl" && make uninstall && rm -rf "$BASE_DIR/openssl") || \
    error "Failed to uninstall openssl."
}

function uninstall_haproxy() {
    info "Uninstalling HAProxy..."
    [ -d "$BASE_DIR/haproxy" ] || return
    (cd "$BASE_DIR/haproxy" && make uninstall && rm -rf "$BASE_DIR/haproxy" && rm -rf "$HAPROXY_KEYS_DIR") || \
    error "Failed to uninstall haproxy."
}

function uninstall_nginx() {
    info "Uninstalling Nginx..."
    (rm -rf /usr/local/bin/nginx && rm -rf /usr/local/nginx && rm -rf /usr/local/share/nginx && \
    rm -rf "$NGINX_WEB_ROOT" && rm -rf "$BASE_DIR/nginx-${NGINX_VER}"*) || \
    error "Failed to uninstall Nginx."
}

function uninstall_ipp_crypto() {
    info "Uninstalling ipp_crypto..."
    (rm -rf /usr/local/lib/libcrypto_mb.so* && rm -rf /usr/local/include/crypto_mb && rm -rf /usr/local/lib/libcrypto_mb.a && \
    rm -rf "$BASE_DIR/ipp-crypto") || \
    error "Failed to uninstall ipp_crypto."
}

function uninstall_ipsec_mb() {
    info "Uninstalling intel-ipsec-mb..."
    [ -d "$BASE_DIR/intel-ipsec-mb" ] || return
    (cd "$BASE_DIR/intel-ipsec-mb" && \
    make uninstall LIB_INSTALL_DIR="${IPSEC_MB_LIBRARIES_DIR}" && rm -rf "$BASE_DIR/intel-ipsec-mb") || \
    error "Failed to uninstall intel-ipsec-mb."
}

function uninstall_qatengine() {
    info "Uninstalling qatengine..."
    (rm -rf /usr/local/lib/engines-1.1) || \
    error "Failed to uninstall qatengine."
}

function uninstall_qat_contig_mem() {
    info "Uninstalling qat_contig_mem..."
    lsmod | grep qat_contig_mem && (rmmod qat_contig_mem || error "Failed to remove module qat_contig_mem.")
    (rm -rf "$BASE_DIR/QAT_Engine"*) || \
    error "Failed to uninstall intel-ipsec-mb."
}

function uninstall_qathw_oot_driver() {
    info "Uninstalling QATHW OOT driver..."
    [ -d "$QAT_OOT_DRIVER_DIR" ] || return
    if [ ! -f "$QAT_OOT_DRIVER_DIR/Makefile" ]; then
        warn "Makefile $QAT_OOT_DRIVER_DIR/Makefile doesn't exist, just delete folder $QAT_OOT_DRIVER_DIR."
        rm -rf "$QAT_OOT_DRIVER_DIR"
        return
    fi
    (cd "$QAT_OOT_DRIVER_DIR" && make uninstall && rm -rf "$QAT_OOT_DRIVER_DIR") || \
    error "Failed to uninstall QATHW OOT driver."
}

function uninstall_wrk() {
    info "Uninstalling wrk..."
    (rm -rf "/usr/local/bin/wrk" && rm -rf "$BASE_DIR/wrk") || \
    error "Failed to uninstall wrk."
}

function stop_services() {
    info "Stopping Nginx and HAProxy services..."
    pgrep -f "nginx -c" > /dev/null && (sudo pkill nginx || error "Failed to stop Nginx service.")
    pgrep -f "haproxy -D -f" > /dev/null && (sudo pkill haproxy || error "Failed to stop HAProxy service.")
}

function delete_configuration_files() {
    info "Deleting configuration files..."
    (rm -rf "$CONFIGS_DEP_DIR") || \
    error "Failed to delete configuration dir, $CONFIGS_DEP_DIR"
    (rm -f "$ULIMIT_CONFIG_FILE") || \
    error "Failed to delete ulimit configuration file, $ULIMIT_CONFIG_FILE"
}

function uninstall() {
    confirm "Uninstall all HAProxy related componenets"
    stop_services
    uninstall_wrk
    uninstall_haproxy
    uninstall_nginx
    uninstall_ipp_crypto
    uninstall_ipsec_mb
    uninstall_qatengine
    uninstall_qat_contig_mem
    uninstall_qathw_oot_driver
    uninstall_openssl
    delete_configuration_files
}

function check_conditions() {
    info "Checking environment and parameters..."
    check_is_user_root
    check_os
}

##############################################################

# Parse input arguments
UNKNOWN_ARGS=""
while [[ "$1" != "" ]]
do
    arg=$1
    case $arg in
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

check_conditions
uninstall

info "Succeed to uninstall all components."
