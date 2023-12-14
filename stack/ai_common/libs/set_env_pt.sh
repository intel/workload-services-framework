#! /bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
source "$DIR"/ai_common/libs/info.sh

echo "============ Setting PyTorch environment variable ============"

if [ -n "$CUSTOMER_ENV" ]; then
    export $CUSTOMER_ENV
fi

# Set pt public env variale
function set_pt_public_env {
    kmp_b="KMP_BLOCKTIME=1"
    kmp_a="KMP_AFFINITY=granularity=fine,compact,1,0"
    echo "Set ENV ${kmp_b}"
    echo "Set ENV ${kmp_a}"
    export ${kmp_b} ${kmp_a}
}

# Set pt ISA env variable
function set_pt_ISA_env {
    if [[ "$PRECISION" =~ "avx" ]]; then
        pt_ISA_env_cmd="ONEDNN_MAX_CPU_ISA=avx512_core_vnni"
        echo "Set ENV ${pt_ISA_env_cmd}"
        export ${pt_ISA_env_cmd}
    elif [[ "$PRECISION" =~ "amx" ]]; then
        pt_ISA_env_cmd="ONEDNN_MAX_CPU_ISA="
        echo "Set ENV ${pt_ISA_env_cmd}"
        export ${pt_ISA_env_cmd}
    else
        echo "not support precision ${PRECISION}"
    fi
}

# Set pt OMP env variable
function set_pt_OMP_env {
    if [ "$MODE" == "throughput" ] && [ "$FUNCTION" == "inference" ] && [ "$TOPOLOGY" == "dlrm" ]; then
        pt_OMP_env_cmd="OMP_NUM_THREADS=1"
    else
        pt_OMP_env_cmd="OMP_NUM_THREADS=${CORES_PER_INSTANCE}"
    fi
    echo "Set ENV ${pt_OMP_env_cmd}"
    export ${pt_OMP_env_cmd}
}

# Set oneDNN env variable
function set_onednn_env {
    if [[ "$DNNL_PRIMITIVE_CACHE_CAPACITY_topology" =~ "$TOPOLOGY" ]]; then
        echo "Set ENV DNNL_PRIMITIVE_CACHE_CAPACITY=1024"
        export DNNL_PRIMITIVE_CACHE_CAPACITY=1024
    fi
    if [[ "$TOPOLOGY" =~ "ssd_rn34" ]]; then
        if [[ "$PRECISION" =~ "int8" ]]; then
            echo "Set ENV DNNL_GRAPH_CONSTANT_CACHE=1"
            export DNNL_GRAPH_CONSTANT_CACHE=1
        fi
    fi
}

# Set case env variable
function set_case_env {
    if [[ "$TOPOLOGY" =~ "resnet50" ]] && [ "$FUNCTION" == "training" ]; then
        echo "Set ENV USE_IPEX=1"
        export USE_IPEX=1
    fi
}

# Set pt verbose env variable
function set_pt_verbose_env {
    if [ "$ONEDNN_VERBOSE" == "True" ]; then
        pt_verbose_value="DNNL_VERBOSE=1, MKLDNN_VERBOSE=1"
    else
        pt_verbose_value="DNNL_VERBOSE=0, MKLDNN_VERBOSE=0"
    fi
    echo "Set ENV ${pt_verbose_value}"
    export ${pt_verbose_value}
}

# Set all pt env variable
function set_pt_env {
    set_pt_public_env
    set_pt_ISA_env
    set_pt_OMP_env
    set_onednn_env
    set_case_env
}
