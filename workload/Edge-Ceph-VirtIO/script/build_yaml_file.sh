#!/bin/bash -e
# build_yaml_file used to compile m4 file, transform the yaml.m4 file to yaml file.
#args: 
# $1 -- path contains the m4 files.
#
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

NAMESPACE="${CLUSTER_NS:-"rook-ceph"}"
CONFIG_PATH="${1:-"template"}" # ./template/*.yaml.m4
TEST_CASE="${TEST_CASE:-"block"}"
TEST_DURATION="${TEST_DURATION:-"300"}"
PVC_BLOCK_SIZE="${PVC_BLOCK_SIZE:-"686G"}"
VM_NAME="${VM_NAME:-"ubuntu"}"
PVC_NAME="${PVC_NAME:-"pvc"}"

# Add addtional parameter for benchmark.
BENCH_OPTIONS="$(echo $BENCHMARK_OPTIONS | tr ';' ' ')"
CONFIG_OPTIONS="$(echo $CONFIGURATION_OPTIONS | tr ';' ' ')"

# args: yaml.m4 file
generate_kubernetes_yaml () {
    (  m4 -I${CONFIG_PATH}  \
      -DPLATFORM=$PLATFORM \
      -DIMAGEARCH=$IMAGEARCH \
      -DWORKLOAD=$WORKLOAD \
      -DNAMESPACE=$NAMESPACE \
      -DCLUSTERNODES=$CLUSTERNODES \
      -DDOCKER_IMAGE_GUESTOS=$DOCKER_IMAGE_GUESTOS \
      -DDOCKER_IMAGE_VHOST=$DOCKER_IMAGE_VHOST \
      -DDOCKER_IMAGE_CEPH_BM_TEST=$DOCKER_IMAGE_CEPH_BM_TEST \
      -DDOCKER_IMAGE_ROOK_CEPH_QAT=$DOCKER_IMAGE_ROOK_CEPH_QAT \
      -DKUBEVIRT_OPERATOR_DOCKER_IMAGE=$KUBEVIRT_OPERATOR_DOCKER_IMAGE \
      -DTEST_CASE=$TEST_CASE \
      -DBENCHMARK_OPTIONS=$BENCHMARK_OPTIONS \
      -DCONFIGURATION_OPTIONS=$CONFIGURATION_OPTIONS \
      -DROOK_CEPH_STORAGE_NS=$ROOK_CEPH_STORAGE_NS \
      $CONFIG_OPTIONS \
      $BENCH_OPTIONS \
      "$@" \
    )
}

# Generate VM yaml file
generate_vm_yaml () {
    i=1
    while [ "$i" -le "$1" ];do
        m4 -I${CONFIG_PATH} \
        -DTEST_CASE=$TEST_CASE \
        -DVM_NAME=$VM_NAME$i \
        -DPVC_NAME=$PVC_NAME$i \
        -DVM_SCALING=$VM_SCALING \
        -DVM_CPU_NUM=$VM_CPU_NUM \
        -DVM_HUGEMEM=$VM_HUGEMEM \
        -DCPU_PLACEMENT=$CPU_PLACEMENT \
        -DPVC_BLOCK_SIZE=$PVC_BLOCK_SIZE \
        -DRBD_IMG_SIZE=$RBD_IMG_SIZE \
        -DRBD_IMAGE_NUM=$RBD_IMAGE_NUM \
        -DDOCKER_IMAGE_GUESTOS=$DOCKER_IMAGE_GUESTOS \
        -DBENCHMARK_OPTIONS=$BENCHMARK_OPTIONS \
        -DCONFIGURATION_OPTIONS=$CONFIGURATION_OPTIONS \
        "${CONFIG_PATH}/VM.yaml.m4" > "${CONFIG_PATH}/VM$i.yaml"
        i=$(($i+1))
    done
}

# Generate live-migration yaml file
generate_migration_yaml () {
    i=1
    while [ "$i" -le "$1" ];do
        m4 -I${CONFIG_PATH} \
        -DVM_NAME=$VM_NAME$i \
        "${CONFIG_PATH}/live-migration.yaml.m4" > "${CONFIG_PATH}/live-migration$i.yaml"
        i=$(($i+1))
    done
}

echo "== Start to Build kubernetes config file from m4, at $CONFIG_PATH"
echo "- Attach to namespace to [$NAMESPACE]."
# Build all m4 file to yaml.
for m4file in `find $CONFIG_PATH/ -name "*.yaml.m4"`
do 
  #echo "transfer $m4file"  # m4file is the file name with path.
  generate_kubernetes_yaml "$m4file" > "${m4file%.m4}"
done

generate_vm_yaml ${BENCHMARK_CLIENT_NODES}
echo $TEST_OPERATION_MODE
if [ "${TEST_OPERATION_MODE}" == "live-migration" ]; then
  generate_migration_yaml ${BENCHMARK_CLIENT_NODES}
fi