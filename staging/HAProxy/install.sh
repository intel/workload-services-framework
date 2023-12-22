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

        install.sh is used to install necessary components for setting up HAProxy server or client testing environment.

        Usage:
            sudo ./install.sh --role server|client [--help|-h]

        Example:
            sudo ./install.sh --role server                     # Install server components
            sudo ./install.sh --role client                     # Install client components

        Parameters:
            --role server|client: [Required] Specify installation role, value can be server or client.
            --help|-h: [Optional] Show help messages.

EOF
}

function install_dependencies() {
    info "Installing dependency components..."
    (apt-get update && apt-get install -y \
    git gcc g++ cmake make automake autoconf libtool libboost-all-dev nasm yasm perl zlib1g-dev pkg-config lua5.3 liblua5.3-dev libpcre3 \
    libpcre3-dev libsystemd-dev wget socat bsdmainutils build-essential libudev-dev unzip libnl-3-dev libnl-genl-3-dev && apt-get clean) || \
    error "Failed to install dependency components."
}

function remove_existing_openssl() {
    info "Removing existing openssl..."
    (apt-get remove -y openssl) || \
    error "Failed to remove existing openssl."
}

function install_openssl() {
    info "Installing openssl..."
    cd "$BASE_DIR" && [ -d "$BASE_DIR/openssl" ] && rm -rf "$BASE_DIR/openssl"
    OPENSSL_REPO=https://github.com/openssl/openssl.git
    (git clone --depth 1 -b "OpenSSL_${OPENSSL_VER}" ${OPENSSL_REPO} openssl && \
    cd openssl && ./config && make depend && make -j && make install && ldconfig) || \
    error "Failed to install openssl."
}

function install_haproxy() {
    info "Installing HAProxy..."
    cd "$BASE_DIR" && [ -d "$BASE_DIR/haproxy" ] && rm -rf "$BASE_DIR/haproxy"
    HAPROXY_REPO="https://github.com/haproxy/haproxy"
    (git clone --depth 1 -b "${HAPROXY_VER}" ${HAPROXY_REPO} haproxy && \
    cd haproxy && make -j TARGET=linux-glibc USE_OPENSSL=1 SSL_INC="${OPENSSL_INCLUDE_DIR}" SSL_LIB="$OPENSSL_LIBRARIES_DIR" USE_LUA=1 \
    USE_PCRE=1 USE_SYSTEMD=1 USE_ENGINE=1 USE_PTHREAD_EMULATION=1 LUA_LIB_NAME=lua5.3 LUA_LIB=/usr/lib LUA_INC=/usr/include/lua5.3/ && make install) || \
    error "Failed to install HAProxy."

    info "Generating certificate for HAProxy..."
    [ -d "$HAPROXY_KEYS_DIR" ] && rm -rf "$HAPROXY_KEYS_DIR"
    mkdir "$HAPROXY_KEYS_DIR"
    (openssl req -x509 -new -batch -nodes -subj '/CN=localhost' -keyout "$HAPROXY_KEYS_DIR/haproxy-tls.key" -out "$HAPROXY_KEYS_DIR/haproxy-tls.pem" && \
    cat "$HAPROXY_KEYS_DIR/haproxy-tls.key" "$HAPROXY_KEYS_DIR/haproxy-tls.pem" > "$HAPROXY_KEYS_DIR/haproxy-tls-combined.pem") || \
    error "Failed to generate certificate for HAProxy."
}

function install_nginx() {
    info "Installing Nginx..."
    cd "$BASE_DIR" && [ -d "$BASE_DIR/nginx-${NGINX_VER}" ] && rm -rf "$BASE_DIR/nginx-${NGINX_VER}"*
    NGINX_PACKAGE="https://nginx.org/download/nginx-${NGINX_VER}.tar.gz"
    (wget --no-check-certificate "${NGINX_PACKAGE}" && tar -xvf "nginx-${NGINX_VER}.tar.gz" && rm "nginx-${NGINX_VER}.tar.gz" && \
    cd "nginx-${NGINX_VER}" && \
    ./configure \
    --prefix=/var/www \
    --conf-path=/usr/local/share/nginx/conf/nginx.conf \
    --sbin-path=/usr/local/bin/nginx \
    --pid-path=/run/nginx.pid \
    --lock-path=/run/lock/nginx.lock \
    --modules-path=/var/www/modules/ \
    --without-http_rewrite_module \
    --with-http_ssl_module \
    --with-pcre \
    --with-cc-opt="-O3 -I/usr/local/include/openssl -Wno-error=deprecated-declarations -Wimplicit-fallthrough=0" \
    --with-ld-opt="-Wl,-rpath=/usr/local/lib -L/usr/local/lib" && \
    make -j && make install) || \
    error "Failed to install Nginx."
    chmod -R 777 /var/www || error "Failed to change permission of /var/www/"

    info "Generating Nginx testing files..."
    [ -d "$NGINX_WEB_ROOT" ] && rm -rf "$NGINX_WEB_ROOT"
    mkdir "$NGINX_WEB_ROOT" || error "Failed to create Nginx web root dir, $NGINX_WEB_ROOT"
    (touch "$NGINX_WEB_ROOT/handshake" && \
    dd bs=1 count=1024 if=/dev/zero of="$NGINX_WEB_ROOT/data_1KB" && \
    dd bs=1 count=2048 if=/dev/zero of="$NGINX_WEB_ROOT/data_2KB" && \
    dd bs=1 count=4096 if=/dev/zero of="$NGINX_WEB_ROOT/data_4KB" && \
    dd bs=10 count=1024 if=/dev/zero of="$NGINX_WEB_ROOT/data_10KB" && \
    dd bs=100 count=1024 if=/dev/zero of="$NGINX_WEB_ROOT/data_100KB" && \
    dd bs=512 count=1024 if=/dev/zero of="$NGINX_WEB_ROOT/data_512KB" && \
    dd bs=1024 count=1024 if=/dev/zero of="$NGINX_WEB_ROOT/data_1MB" && \
    dd bs=1024 count=2048 if=/dev/zero of="$NGINX_WEB_ROOT/data_2MB" && \
    dd bs=1024 count=4096 if=/dev/zero of="$NGINX_WEB_ROOT/data_4MB" && \
    dd bs=1024 count=10240 if=/dev/zero of="$NGINX_WEB_ROOT/data_10MB") || \
    error "Failed to generate Nginx testing files."
}

function install_ipp_crypto() {
    info "Installing ipp-crypto..."
    cd "$BASE_DIR" && [ -d "$BASE_DIR/ipp-crypto" ] && rm -rf "$BASE_DIR/ipp-crypto"
    IPP_CRYPTO_REPO="https://github.com/intel/ipp-crypto"
    (git clone --depth 1 -b "${IPP_CRYPTO_VER}" ${IPP_CRYPTO_REPO} ipp-crypto && \
    cd ipp-crypto/sources/ippcp/crypto_mb && \
    cmake . -B"../build" \
    -DOPENSSL_INCLUDE_DIR="${OPENSSL_INCLUDE_DIR}" \
    -DOPENSSL_LIBRARIES="${OPENSSL_LIBRARIES_DIR}" \
    -DOPENSSL_ROOT_DIR="${OPENSSL_ROOT_DIR}" && \
    cd ../build && make -j crypto_mb && make install) || \
    error "Failed to installing ipp-crypto."
}

function install_ipsec_mb() {
    info "Installing intel-ipsec-mb..."
    cd "$BASE_DIR" && [ -d "$BASE_DIR/intel-ipsec-mb" ] && rm -rf "$BASE_DIR/intel-ipsec-mb"
    IPSEC_MB_REPO="https://github.com/intel/intel-ipsec-mb"
    (git clone --depth 1 -b "${IPSEC_MB_VER}" ${IPSEC_MB_REPO} && \
    cd intel-ipsec-mb && make -j && make install LIB_INSTALL_DIR="${IPSEC_MB_LIBRARIES_DIR}") || \
    error "Failed to install intel-ipsec-mb."
}

function install_qat_contig_mem() {
    info "Installing qat_contig_mem..."
    cd "$BASE_DIR" && [ -d "$BASE_DIR/QAT_Engine" ] && rm -rf "$BASE_DIR/QAT_Engine"
    cd "$BASE_DIR" && [ -d "$BASE_DIR/QAT_Engine_ori" ] && rm -rf "$BASE_DIR/QAT_Engine_ori"
    lsmod | grep qat_contig_mem && (rmmod qat_contig_mem || error "Failed to remove module qat_contig_mem.")
    QATENGINE_REPO="https://github.com/intel/QAT_Engine"
    (git clone --depth 1 -b "${QATENGINE_VER}" ${QATENGINE_REPO} && mv "$BASE_DIR/QAT_Engine" "$BASE_DIR/QAT_Engine_ori") || \
    error "Failed to prepare QAT engine code."
    (cp -r "$BASE_DIR/QAT_Engine_ori" "$BASE_DIR/QAT_Engine" && cd "$BASE_DIR/QAT_Engine/qat_contig_mem" && git checkout "${QATENGINE_VER}" && \
    make && make load && make test) || \
    error "Failed to install qat_contig_mem."
    (chmod 666 /dev/qat_contig_mem ) || \
    error "Failed to change permission of /dev/qat_contig_mem."
}

function install_qathw_oot_driver_impl(){

    info "Installing QATHW OOT driver..."
    # Configure no_proxy to download OOT file
    no_proxy_tmp=$no_proxy
    no_proxy_tmp=${no_proxy_tmp//,.intel.com/}
    no_proxy_tmp=${no_proxy_tmp//,intel.com/}
    no_proxy_tmp=${no_proxy_tmp//.intel.com,/}
    export no_proxy=$no_proxy_tmp
    [ -d "$QAT_OOT_DRIVER_DIR" ] && rm -rf "$QAT_OOT_DRIVER_DIR"
    mkdir -p "$QAT_OOT_DRIVER_DIR"
    cd "$QAT_OOT_DRIVER_DIR" || error "Failed to find directory: $QAT_OOT_DRIVER_DIR"   

    if [[ $NUM_QAT_2 -ne 0 ]]; then
        info "Installing QAT 2.0 Driver..."
        QAT_OOT_DRIVER_FILE=${QATHW_OOT_DRIVER_VER}.tar.gz
        QAT_OOT_DRIVER_REPO=https://downloadmirror.intel.com/783270/${QAT_OOT_DRIVER_FILE}
    else
    info "Installing QAT 1.X Driver..."
        QAT_OOT_DRIVER_FILE=${QATHW_OOT_DRIVER_VER_1X}.tar.gz
        QAT_OOT_DRIVER_REPO=https://downloadmirror.intel.com/743650/${QAT_OOT_DRIVER_FILE}
    fi

    (wget --no-check-certificate "$QAT_OOT_DRIVER_REPO" && tar -xavf "$QAT_OOT_DRIVER_FILE" && ./configure && make -j install && adf_ctl status) || \
    error "Failed to install QATHW OOT driver."
    # Configure /etc/4xxx_dev0.conf and /etc/4xxx_dev1.conf
    info "Configure QATHW OOT driver..."
    cd "$BASE_DIR" || error "Failed to find directory: $BASE_DIR"

    if [[ $NUM_QAT_2 -ne 0 ]]; then
        info "Configure QAT 2.0 Device..."
        (SERVICES_ENABLED="asym" SECTION_NAME=SHIM CY_INSTANCES=8 DC_INSTANCES=0 PROCESSES=4 ./qat-invoke.sh) || \
        error "Failed to configure QAT OOT driver."
    else
        info "Configure QAT 1.X Device..."
        (SERVICES_ENABLED="cy" SECTION_NAME=SHIM CY_INSTANCES=8 DC_INSTANCES=0 PROCESSES=4 ./qat-invoke-1x.sh) || \
        error "Failed to configure QAT OOT driver."  
    fi

}

function install_qathw_oot_driver() {

    NUM_QAT_2=$(lspci | grep -c 494)
    export NUM_QAT_2
    NUM_QAT_QAT_1X=$(lspci | grep -c C62x)
    export NUM_QAT_QAT_1X

    if [[ $NUM_QAT_2 -ne 0 ]] || [[ $NUM_QAT_QAT_1X -ne 0 ]]; then
        install_qathw_oot_driver_impl
        install_qat_contig_mem
    else
        info "No QATHW detected, skipping oot driver installation"
    fi
}

function install_wrk() {
    info "Installing wrk... "
    cd "$BASE_DIR" && [ -d "$BASE_DIR/wrk" ] && rm -rf "$BASE_DIR/wrk"
    WRK_REPO=https://github.com/wg/wrk.git
    (git clone --depth 1 -b "${WRK_VER}" ${WRK_REPO} wrk && cd wrk && \
    sed -i "s/-O2/-O3/g" Makefile && make -j WITH_OPENSSL=/usr/local && strip wrk && cp wrk /usr/local/bin) || \
    error "Failed to install wrk."
}

function install_ulimit_config() {
    info "Installing ulimit config file..."
    {
        echo "* soft nofile 20480"
        echo "* hard nofile 20480"
        echo "root soft nofile 20480"
        echo "root hard nofile 20480"
    } > "$ULIMIT_CONFIG_FILE"
}

function install_server() {
    remove_existing_openssl
    install_openssl
    install_haproxy
    install_nginx
    install_ipp_crypto
    install_ipsec_mb
    install_qathw_oot_driver
    install_wrk
    install_ulimit_config
}

function install_client() {
    install_openssl
    install_wrk
    install_ulimit_config
}

function check_parameters() {
    check_not_empty "--role" "$role"
}

function check_conditions() {
    info "Checking environment and parameters..."
    check_is_user_root
    check_os
    check_parameters
}

##############################################################

# Role
ROLE_SERVER="server"
ROLE_CLIENT="client"
role=""

# Parse input arguments
UNKNOWN_ARGS=""
while [[ "$1" != "" ]]
do
    arg=$1
    case $arg in
        --role)
            shift
            check_not_empty "$arg" "$1"
            roles=("$ROLE_SERVER" "$ROLE_CLIENT")
            check_value_exist "$arg" "$1" "${roles[@]}"
            role=$1
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
install_dependencies

if [[ "$role" = "$ROLE_SERVER" ]]; then
    install_server
elif [[ "$role" = "$ROLE_CLIENT" ]]; then
    install_client
else
    error "Unknown role type: $role"
fi

info "Succeed to install all required components."
