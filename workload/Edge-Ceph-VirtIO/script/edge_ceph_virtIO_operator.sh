#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
set -x

# export all of the options for env deployment.
export $(echo ${BENCHMARK_OPTIONS//"-D"/""} | tr -t ';' '\n')
export $(echo ${CONFIGURATION_OPTIONS//"-D"/""} | tr -t ';' '\n')

BASE_PATH=/opt/rook
WORK_PATH=${BASE_PATH}/benchmark
CONFIG_FILE_PATH=${WORK_PATH}/template
KUBEVIRT_CONFIG_PATH=${CONFIG_FILE_PATH}/kubevirt
BENCH_LOG_PATH=${WORK_PATH}/logs
BENCHMARK_NS="${CLUSTER_NS:-"ABCDEFG"}"
CEPH_CLUSTER_NS="${ROOK_CEPH_STORAGE_NS:-"rook-ceph"}"
KUBEVIRT_NS="${KUBEVIRT_NS:-"kubevirt"}"
TEST_CASE="${TEST_CASE:-"virtIO"}"
TEST_OPERATION_MODE="${TEST_OPERATION_MODE:-"random"}"
TIMEOUT="7200,3600"  # Wait for log collection | WAIT POD ready timeout, seconds
CEPH_CLUSTER=${CEPH_CLUSTER:-"my-cluster"}
CEPH_STORAGE_CLASS=${CEPH_STORAGE_CLASS:-"rook-ceph-block"}
CEPH_CONFIG_ENABLED=${CEPH_CONFIG_ENABLED:-"0"}
OSD_MEMORY_TARGET=${OSD_MEMORY_TARGET:-"8589934592"}
CLUSTERNODES=${CLUSTERNODES:-1}
BENCHMARK_CLIENT_NODES=${BENCHMARK_CLIENT_NODES:-3}
TEST_CASE_COMP=${TEST_CASE_COMP:-0}

WAIT_VM=${WAIT_VM:-1800}
HUGEPAGE_REQ=${HUGEPAGE_REQ:-32768}  #Hugepage required for workload test, default: 32768Mi
VM_NAME="${VM_NAME:-"ubuntu"}"
PVC_NAME="${PVC_NAME:-"pvc"}"


BENCHMARK_SELECTOR="${BENCHMARK_SELECTOR:-"app=rook-ceph-benchmark"}"
BENCHMARK_CONTAINER="${BENCHMARK_SELECTOR/*=/}"
BENCHMARK_LOGS="${WORK_PATH}/${TEST_CASE}-logs"

# For operation args:
OPERATOR_ARG="ALL"
DEBUG_MODE="${DEBUG_MODE:-0}" # disable debug mode by default

ROOK_CEPH_CONFIG_PATH="${ROOK_CEPH_CONFIG_PATH:-"/opt/rook/benchmark/rook/deploy/examples"}"
CRD_CEPHCLUSTER="${CRD_CEPHCLUSTER:-"CephCluster"}"
CRD_CEPHBLOCK="${CRD_CEPHBLOCK:-"CephBlockPool"}"


# logs directory
mkdir -p "$BENCHMARK_LOGS"
echo "DGB_MODE:${DEBUG_MODE}"

function help_usage() {
  echo "--deploy    Deploy the environment without benchmark"
  echo "--benchmark Deploy the environment and run benchmark, the testcase depends on env"
  echo "--cleanup   Clean up the environment"
  echo "--all       [Default]Deploy the environment and benchmark, and will cleanup environment."
  echo "--help      Show help tips"
}

function check_args() {
    # Parse the parameter for the main entrypoint.
    echo $*
    if [[ $# == 0 || $* =~ ^"--help"$ ]]; then
      help_usage;
      exit 0;
    fi 

    if [[ $* =~ "--all" ]]; then
      export OPERATOR_ARG="ALL";    # 
    elif [[ $* =~ "--deploy" ]];then
      export OPERATOR_ARG="DEPLOY";
    elif [[ $* =~ "--benchmark" ]];then
      export OPERATOR_ARG="BENCH";
    elif [[ $* =~ "--cleanup" ]];then
      export OPERATOR_ARG="CLEANUP";
    else
      echo "please see --help";
      help_usage;
      exit 0;
    fi
}

deploy_ceph_toolbox () {
    echo "- Start the rook-ceph toolbox "
    kubectl -n $CEPH_CLUSTER_NS apply -f ${CONFIG_FILE_PATH}/ceph_toolbox.yaml
    sleep 2s
    kubectl --namespace=$CEPH_CLUSTER_NS wait pod --for=condition=ready --selector=app=rook-ceph-tools --timeout=${TIMEOUT/*,/}s
    echo "- Rook-ceph toolbox ready"
}

# Calculate the RBD image size
# per RBD image size = Ceph Capacity/replica size/client(VM) number/rbd number per client(VM) * 60%
#args: None
calculate_rbd_img_size() {
    # Check toolbox exist or not
    if [ -z "$(kubectl -n $CEPH_CLUSTER_NS get pods -A|grep rook-ceph-tools)" ]; then
        echo " *** No toolbox exist for rook-ceph, deploy the toolbox firstly."
        # deploy toolbox.
        deploy_ceph_toolbox
        sleep 10s
    fi

    TOOLBOX_PODNAME=`kubectl -n $CEPH_CLUSTER_NS get pods -A|grep rook-ceph-tools|awk '{print$2}'`
    CEPH_CAPACITY_NUM=$(kubectl exec -it $TOOLBOX_PODNAME -n rook-ceph -- ceph -s |grep usage|awk -F "/" '{print$2}'|awk '{print$1}')
    CEPH_CAPACITY_UNIT=$(kubectl exec -it $TOOLBOX_PODNAME -n rook-ceph -- ceph -s |grep usage|awk -F "/" '{print$2}'|awk '{print$2}')
    REPLICATED_SIZE=$(kubectl exec -it $TOOLBOX_PODNAME -n rook-ceph -- ceph osd dump |grep replicapool|awk -F "size" '{print$2}'|awk '{print$1}')
    # CEPH_CAPACITY unit:Gi
    if [ "$CEPH_CAPACITY_UNIT" = "TiB" ];then
        CEPH_CAPACITY=$(echo "$CEPH_CAPACITY_NUM * 1024" | bc)
    elif [ "$CEPH_CAPACITY_UNIT" = "GiB" ];then
        CEPH_CAPACITY=$CEPH_CAPACITY_NUM
    fi
    if [ "$VM_SCALING" = "0" ];then
        RBD_IMG_SIZE=$(echo "$CEPH_CAPACITY / $REPLICATED_SIZE / $BENCHMARK_CLIENT_NODES / $RBD_IMAGE_NUM / 5 * 3" | bc)"G"
    elif [ "$VM_SCALING" = "1" ];then
        RBD_IMG_SIZE=$(echo "$CEPH_CAPACITY / $REPLICATED_SIZE / $MAX_VM_COUNT / $RBD_IMAGE_NUM / 5 * 3" | bc)"G"
    fi
    TEST_DATASET_SIZE=$RBD_IMG_SIZE
    BENCHMARK_OPTIONS=${BENCHMARK_OPTIONS}";-DTEST_DATASET_SIZE=${TEST_DATASET_SIZE}"
    CONFIGURATION_OPTIONS=${CONFIGURATION_OPTIONS}";-DRBD_IMG_SIZE=${RBD_IMG_SIZE};-DPVC_BLOCK_SIZE=${PVC_BLOCK_SIZE}"
    PVC_BLOCK_SIZE=$RBD_IMG_SIZE
}

# args: None
trap_kubernetes () {
    echo "Kubernetes trap occurs with status $? at line[$1]"
    kubectl get pods -A -o wide
    sleep infinity  # TODO: maybe should remove this.
}

# args: 
#   $1 - benchmark container name
#   $2 ~~ - pods run the benchmark. 
extract_logs () {

    container=$1; shift
    for pod1 in $@; do
        echo "get benchmark pod $pod1"
        # mkdir -p "$pod1"
        # kubectl exec --namespace=$CEPH_CLUSTER_NS $pod1 -c $container -- bash -c 'cat /export-test-logs' | tar -xf - -C "$pod1"        
        kubectl exec --namespace=$CEPH_CLUSTER_NS $pod1 -c $container -- bash -c 'cat /export-test-logs' | tar -xf - -C "$BENCHMARK_LOGS"
    done
}

# args: exit_code
data_collection_and_exit () {
    exit_code=$1
    cd "$BENCHMARK_LOGS" && echo ${exit_code} > status && tar cf /export-logs status $(find . -name "*.log")

    sleep infinity
}

# -- cleanup VMs
delete_vms () {
    # -- benchmark cleanup
    kubectl -n ${BENCHMARK_NS} get vmi
    echo "End of log collection, delete the VM..."
    # need to delete one by one
    i=1
    while [ "$i" -le "${BENCHMARK_CLIENT_NODES}" ]; do
        if [ -n "$(kubectl -n ${BENCHMARK_NS} get vmi)" ]; then
            kubectl -n ${BENCHMARK_NS} delete -f ${CONFIG_FILE_PATH}/VM$i.yaml
        fi
        sleep 20s
        i=$(($i+1))
    done
    sleep 15s
}

# Collect VM related pod's logs and exit, args: exit_code
vmlogs_collection_and_exit () {
    # Collect kubevirt related pod's logs
    for kubevirt_pod in $(kubectl get pod -n ${KUBEVIRT_NS} -o jsonpath='{.items[*].metadata.name}'); do
        mkdir -p ${BENCHMARK_LOGS}/${kubevirt_pod}
        kubectl -n ${KUBEVIRT_NS} logs "${kubevirt_pod}" > "${BENCHMARK_LOGS}"/"${kubevirt_pod}"/"$kubevirt_pod"_log.log
        kubectl -n ${KUBEVIRT_NS} describe pod "${kubevirt_pod}" > "${BENCHMARK_LOGS}"/"${kubevirt_pod}"/"$kubevirt_pod"_describe.log
    done
    # Collect virt-launcher pod's logs
    for vm_pod in $(kubectl get pod -o jsonpath='{.items[*].metadata.name}'); do
        if [ ! -z "$(echo ${vm_pod} | grep virt-launcher)" ]; then
            mkdir -p ${BENCHMARK_LOGS}/${vm_pod}
            kubectl logs "${vm_pod}" > "${BENCHMARK_LOGS}"/"${vm_pod}"/"$vm_pod"_log.log
            kubectl describe pod "${vm_pod}" > "${BENCHMARK_LOGS}"/"${vm_pod}"/"$vm_pod"_describe.log
        fi
    done
    echo " - Finish VM pod logs collection..."
    # Cleanup_environment and exit
    cleanup_environment
    data_collection_and_exit $1;
}

check_ceph_cluster_namespace () {
    if [ -z "$(kubectl get namespace | grep "${CEPH_CLUSTER_NS}" )" ]; then 
        echo " *** ERROR: NAMESPACE [$CEPH_CLUSTER_NS] for rook-ceph is not exist! Please set the correct namespace for ceph cluster and check the ceph status firstly."
        data_collection_and_exit 1;
    fi
}

check_ceph_cluster_status () {
    echo "- Check the Ceph cluster status.. "
    check_ceph_cluster_namespace
    check_time=0
    kubectl --namespace=$CEPH_CLUSTER_NS get cephcluster
    while [ -z "$(kubectl -n $CEPH_CLUSTER_NS get cephcluster \
    | grep ${CEPH_CLUSTER} | grep -e "Ready" | grep -e "HEALTH_OK" )" ]; do
        if [ "$check_time" -gt ${TIMEOUT/*,/} ]; then
            echo "*** WARNING: Checking cluster status timeout, status is:"
            kubectl -n $CEPH_CLUSTER_NS get cephcluster
            data_collection_and_exit 1
        fi
        sleep 5s
        check_time=$(($check_time + 1))
    done
    echo "- Ceph cluster is ready and health"
}

check_hugepage () {
    echo "Start to check hugepages..."

    for node in $(kubectl get nodes |awk '{print $1}'|grep -v NAME);do
        Hugepage=$(kubectl describe node $node |grep -A10 Capacity |grep hugepages-2Mi |awk '{print $NF}')
        echo "Node $node hugepage capacity: $Hugepage"
        if [ -n "echo $Hugepage |grep Gi" ];then
            Hugepage_Num=$(echo $Hugepage |awk -F "Gi" '{print $1}')
            Hugepage_Cap=$(echo "$Hugepage_Num * 1024" | bc)
        elif [ -n "echo $Hugepage |grep Mi" ];then
            Hugepage_Cap=$(echo $Hugepage |awk -F "Mi" '{print $1}')
        fi

        if [ "$Hugepage_Cap" -lt "$HUGEPAGE_REQ" ];then
            echo "Node $node does not have enough hugepage for workload"
            exit -1
        else
            echo "Node $node has enough hugepage"
        fi
    done
}

# args: 
env_precheck_hook () {
    echo "Health check for the validation environment."
    # 1. Ceph healthy status
    # 2. kubevirt status
    # 3. CPU list?
    # 4. Hugememory check when conducting vhost testcase

    # Ceph healthy status checking.
    # Print Ceph status

    if [ "$CHECK_CEPH_STATUS" = "1" ];then
        check_ceph_cluster_status
    else
        echo "Do not check ceph status..."
    fi

    # check if hugepage is enough
    if [ "$TEST_CASE" = "vhost" ];then
        check_hugepage
    fi    

    if [ -z "$(kubectl api-resources | grep -i "${CRD_CEPHCLUSTER}" )" ]; then
        echo " *** ERROR: CRD $CRD_CEPHCLUSTER for rook-ceph is not exist!, please pre-set the CRD firstly."
        data_collection_and_exit 1;
    fi

    # - For Block device prerequisites.
    if [ -z "$(kubectl api-resources | grep -i "${CRD_CEPHBLOCK}" )" ]; then
        echo " *** ERROR: CRD $CRD_CEPHBLOCK for rook-ceph is not exist!, please pre-set the CRD firstly."
        data_collection_and_exit 1;
    fi

    # Currently, single node cluster is jsut for development, not used for production.
    # If user want to run on single node cluster with multi-nodes cofig, it should break here.
    # 'CLUSTERNODES' should be >= Nodes count in k8s cluster (K8S_CLUSTER_NODES).
    # User need to change 'CLUSTERNODES' to 1 in validate.sh on sinle node k8s cluster 
    K8S_CLUSTER_NODES=$(kubectl get nodes -A -o wide | grep Ready | wc -l)
    if [ ${CLUSTERNODES} -gt ${K8S_CLUSTER_NODES} ]; then
        echo " *** ERROR: No sufficient nodes[${K8S_CLUSTER_NODES}-Nodes] for the ceph cluster configuration[Need ${CLUSTERNODES} nodes]."
        kubectl get nodes -A -o wide --show-labels
        data_collection_and_exit 1;
    fi
}

# args:
deploy_kubevirt () {
    echo " == Deploy the kubevirt for VM cases == "

    echo "- Apply the kubevirt operation  "
    kubectl -n ${KUBEVIRT_NS} apply -f ${KUBEVIRT_CONFIG_PATH}/kubevirt-operator.yaml
    sleep 5s

    echo "- Apply the kubevirt CRDs  "
    kubectl -n ${KUBEVIRT_NS} apply -f ${KUBEVIRT_CONFIG_PATH}/kubevirt-cr.yaml
    sleep 5s

    #Check the deployment status
    check_time=0
    kubectl -n ${KUBEVIRT_NS} get kubevirt.kubevirt.io/kubevirt -o=jsonpath="{.status.phase}" 2>/dev/null
    while [ -z "$(kubectl -n ${KUBEVIRT_NS} get kubevirt.kubevirt.io/kubevirt \
            -o=jsonpath="{.status.phase}" \
            | grep -i Deployed)" ]; do

        if [ "$check_time" -gt ${TIMEOUT/*,/} ]; then
            echo "*** WARNING: Checking kubevirt deployment status timeout, status is:"
            kubectl -n ${KUBEVIRT_NS} get kubevirt.kubevirt.io/kubevirt
            exit -1
        fi
        sleep 5s
        check_time=$(($check_time + 1))
    done

    echo "- Apply the kubevirt successfully  "
    # Check all of kubevirt resource 
    #kubectl -n ${KUBEVIRT_NS} get all
}

# args:
cleanup_kubevirt () {
    # Check the kubevirt environment firstly before cleanup.
    if [ -n "$(kubectl -n ${KUBEVIRT_NS} get kubevirt.kubevirt.io/kubevirt \
            -o=jsonpath="{.status.phase}" | grep -i Deployed)" ]; then
        echo " == Start to clean up the kubevirt environment, please ensure all of VMs are destoryed == "
        kubectl delete -f ${KUBEVIRT_CONFIG_PATH}/kubevirt-cr.yaml
        sleep 3s
        echo "- Delete the kubevirt operation resource "
        kubectl delete -f ${KUBEVIRT_CONFIG_PATH}/kubevirt-operator.yaml
        sleep 5s
    else
        echo "- No kubevirt operation resource found"
    fi
}

# args:
deploy_spdk_daemonset () {
    echo "Start to deploy spdk-vhost daemonset"
    kubectl apply -f ${CONFIG_FILE_PATH}/rook-ceph-spdk-vhost.yaml
    sleep 3s
    check_time=0
    while [ "$(kubectl -n $CEPH_CLUSTER_NS get daemonset \
    | grep ceph-spdk-vhost-daemon | awk -F " " '{print $4}' )" != "${CLUSTERNODES}" ]; do
        if [ "$check_time" -gt ${TIMEOUT/*,/} ]; then
            echo "*** WARNING: Checking daemonset status timeout, please check if the nodes are labeled correctly, status is:"
            kubectl -n $CEPH_CLUSTER_NS get daemonset
            cleanup_environment
            data_collection_and_exit 1
        fi
        sleep 5s
        check_time=$(($check_time + 1))
    done
    echo "SPDK-Vhost daemonset deployed successfully!"
}

# args:
cleanup_spdkvhost () {
    echo "Cleanup the spdk-vhost resources"
    # check the vhost resources status and cleanup.
    if [ -n "$(kubectl -n $CEPH_CLUSTER_NS get daemonset | grep ceph-spdk-vhost-daemon)" ]; then
        echo " == Start to clean up the spdk-vhost environment == "
        kubectl delete -f ${CONFIG_FILE_PATH}/rook-ceph-spdk-vhost.yaml
    else
        echo "- No spdkvhost daemonset resource found"
    fi
    TOOLBOX_PODNAME=`kubectl get po -A|grep rook-ceph-tools|awk '{print$2}'`
    check_time=0
    time_out_spdk=36
    sleep 5s
    while [ -n "$(kubectl exec -it $TOOLBOX_PODNAME -n $CEPH_CLUSTER_NS -- rbd ls replicapool)" ];do
        if [ "$check_time" -gt "$time_out_spdk" ]; then
            echo "*** WARNING: SPDK BDEVs are not completely deleted, will continue environment cleanup anyway!"
            break;
        fi
        sleep 5s
        check_time=$(($check_time + 1))
    done
    # Check if kubevirt-vhost communication files are cleaned up
    if [ -f "/var/tmp/vhost.message" ]; then
        rm -rf /var/tmp/vhost.message
    fi
}

# args: 
block_IO_function_bench () {

    echo " == To bench edge ceph block interface == "
    
    # - Start the benchmark.
    echo "- Start the ${TEST_CASE} benchmark POD "
    kubectl create -f ${ROOK_CEPH_CONFIG_PATH}/rook-ceph-rbd-benchmark.yaml
    # TODO: TBC for the container level ceph rbd test.
    sleep 5s
    kubectl --namespace=$CEPH_CLUSTER_NS wait pod --for=condition=ready --selector=${BENCHMARK_SELECTOR} --timeout=${TIMEOUT/*,/}s
    echo "- [${BENCHMARK_CLIENT_NODES}x]-Benchmark POD is ready "

    # -- Collect the logs from benchmark pod.
    echo "- Collect benchmark logs "
    export BENCHMARK_LOGS BENCHMARK_CONTAINER CEPH_CLUSTER_NS BENCHMARK_SELECTOR
    export -pf extract_logs

    echo "- Waiting for the ${BENCHMARK_CLIENT_NODES} benchmark implementation... "
    if [ "${BENCHMARK_CLIENT_NODES}" == "1" ]; then 
        timeout ${TIMEOUT/,*/}s bash -c "extract_logs ${BENCHMARK_CONTAINER} $(kubectl get pod --namespace=$CEPH_CLUSTER_NS --selector="$BENCHMARK_SELECTOR" -o=jsonpath="{.items[*].metadata.name}")"
    else
        # Multi-client for benchmark pod to test ceph cluster.

        # Prepare stage for benchmark PODs 
        for benchmark_pod in $(kubectl -n "${CEPH_CLUSTER_NS}" get pod --selector="$BENCHMARK_SELECTOR" -o jsonpath='{.items[*].metadata.name}'); do

            mkdir -p ${BENCHMARK_LOGS}/${benchmark_pod}
            echo " - Waiting for Benchmark POD ${benchmark_pod} initialization..."
            timeout ${TIMEOUT/*,/}s kubectl -n ${CEPH_CLUSTER_NS} exec ${benchmark_pod} -- bash -c 'cat /export-test-logs' | tar -xf - -C "${BENCHMARK_LOGS}/${benchmark_pod}"

            if [ "$?" != "0" ]; then
                echo "*** WARNING: Benchmark POD ${benchmark_pod} is not prepared for running test!"
                kubectl -n ${CEPH_CLUSTER_NS} describe pod "${benchmark_pod}" > "${BENCHMARK_LOGS}"/"${benchmark_pod}"/"$benchmark_pod".desc
                kubectl -n ${CEPH_CLUSTER_NS} logs "${benchmark_pod}" > "${BENCHMARK_LOGS}"/"${benchmark_pod}"/"$benchmark_pod".log
            fi

        done

        # Trigger to start benchmark, and collect data 
        echo " - Trigger the Benchmark POD to start the test..."
        touch start_test
        for benchmark_pod in $(kubectl -n "${CEPH_CLUSTER_NS}" get pod --selector="$BENCHMARK_SELECTOR" -o jsonpath='{.items[*].metadata.name}'); do
            timeout ${TIMEOUT/*,/}s kubectl -n ${CEPH_CLUSTER_NS} cp ./start_test ${benchmark_pod}:/
        done

        # Collecting data 
        for benchmark_pod in $(kubectl -n "${CEPH_CLUSTER_NS}" get pod --selector="$BENCHMARK_SELECTOR" -o jsonpath='{.items[*].metadata.name}'); do
            echo " - Collecting data from Benchmark POD ${benchmark_pod}..."
            timeout ${TIMEOUT/,*/}s kubectl -n ${CEPH_CLUSTER_NS} exec ${benchmark_pod} -- bash -c 'cat /export-test-logs' | tar -xf - -C "${BENCHMARK_LOGS}/${benchmark_pod}"
            # temperarily use one status file.
            cp ${BENCHMARK_LOGS}/${benchmark_pod}/status ${BENCHMARK_LOGS}/
        done

    fi

    # -- benchmark cleanup
    echo "End of log collection, delete the benchmark pod..."
    kubectl delete -f ${CONFIG_FILE_PATH}/rook-ceph-rbd-benchmark.yaml
    sleep 5s
}

run_gated_benchmark () {
    echo "- Start to bench the ${TEST_CASE} cases..."

    ${WORK_PATH}/fio/fio -filename=./testfile \
        -direct=1 \
        -iodepth 1 \
        -thread \
        -rw=write \
        -ioengine=libaio \
        -bs=1M \
        -size=${TEST_DATASET_SIZE}M \
        -numjobs=2 \
        -runtime=${TEST_DURATION} \
        -group_reporting \
        -name=randreadtest \
        -output=${BENCHMARK_LOGS}/gated_random_read_$(date +"%m-%d-%y-%H-%M-%S").log

        echo $? > ${BENCHMARK_LOGS}/status
    echo "- End of the edge ceph ${TEST_CASE} benchmark"    
}


# args: 
#   $1 - vm_number
#   $2 - vm_ip_address
compare_vm_ip () {
    CURRENT_VM_IP=$(kubectl get vmi | awk 'NR=="'"$1"'"{print $4}')
    # If VM IP changed,then collect logs and exit ,exit code 2 means VM IP changed error
    if [ "$CURRENT_VM_IP" != "$2" ]; then
        echo " - VM's IP has changed,start to collect logs and exit..."
        vmlogs_collection_and_exit 2        
    fi       
}

# Save original IP of VMs to array
declare -a VM_IP_ADDR

deploy_vms () {
    echo " == start to deploy the VMs =="
    # Generate ssh-key
    echo "- Genereate the RSA key for no-password access "
    if test -f "~/.ssh/id_rsa"; then
        rm ~/.ssh/id_rsa
    fi
    ssh-keygen -f ~/.ssh/id_rsa -N ""
    PUBKEY=`cat ~/.ssh/id_rsa.pub`
    echo "- Create VM "
    for i in $(seq 1 $BENCHMARK_CLIENT_NODES); do
        sed -i "s%ssh-rsa.*%$PUBKEY%" ${CONFIG_FILE_PATH}/VM$i.yaml
        kubectl -n ${BENCHMARK_NS} apply -f ${CONFIG_FILE_PATH}/VM$i.yaml
        sleep 10s
    done

    # Check VM status and collect logs
    kubectl -n ${BENCHMARK_NS} get vms
    # Waiting for VM started
    kubectl wait --for=condition=ready vmi --all --timeout=300s
    sleep 15s
    kubectl -n ${BENCHMARK_NS} get vmi
}

# export VM logs by FIFO
# args:
#   $1 - vm_ip_address
#   $2 - vm name
#   $3 - vm sequence number
export_vm_logs () {
    check_time=0
    while (! ssh -o StrictHostKeyChecking=no -l root $1 'cat /export-test-logs' | tar -xf - -C "${BENCHMARK_LOGS}/$2" 2>/dev/null); do
        sleep 5s
        if [ "$check_time" -gt ${TIMEOUT/*,/} ]; then
            echo "*** ERROR: vm connection status timeout, please have a check"
            # Cleanup_environment and exit
            cleanup_environment
            data_collection_and_exit 1
        fi
        check_time=$(($check_time + 1))
        # Compare current vm ip with the original ip,if VM IP changed,then collect logs and exit
        compare_vm_ip $3 ${VM_IP_ADDR[$3]}
    done
}

# shake hand with VM ,wait until VMs being ready for benchmarking
prepare_vm_benchmark () {
    echo " == start to prepare benchmarking in the VMs =="
    # Sleep to wait VM prefill finished
    sleep $WAIT_VM
    # Record VMs IP addresses
    num_line=2
    for benchmark_vmi in $(kubectl get vmi -o jsonpath='{.items[*].metadata.name}'); do
        VM_IP_ADDR[$num_line]=$(kubectl get vmi | awk 'NR=="'"$num_line"'"{print $4}')
        num_line=$(($num_line + 1))
    done    
    echo " - Finish VM IP record, start to wait for VM's ready message..." 
    # Start to wait for VM's ready message
    num_line=2
    for benchmark_vmi in $(kubectl get vmi -o jsonpath='{.items[*].metadata.name}'); do
        # Compare current vm ip with the original ip,if VM IP changed,then collect logs and exit
        compare_vm_ip $num_line ${VM_IP_ADDR[$num_line]}
        check_time=0
        mkdir -p ${BENCHMARK_LOGS}/${benchmark_vmi}
        while(! ssh -o StrictHostKeyChecking=no -l root $CURRENT_VM_IP "echo 'ssh to VM succeed...'" 2>/dev/null); do
            sleep 5s 
            if [ "$check_time" -gt ${TIMEOUT/*,/} ]; then
                echo "*** ERROR: vm connection status timeout, please have a check"
                # Cleanup_environment and exit
                cleanup_environment
                data_collection_and_exit 1
            fi 
            # If VM IP changed,then collect logs and exit
            compare_vm_ip $num_line ${VM_IP_ADDR[$num_line]}   
            check_time=$(($check_time + 1))
        done
        echo " - ssh connection to VM ${benchmark_vmi} succeed..."
        # Collect VM-ready logs
        export_vm_logs $CURRENT_VM_IP $benchmark_vmi $num_line
        num_line=$(($num_line + 1))
        echo " - VM${num_line} ${benchmark_vmi} is ready"
    done
    echo "All VM is ready ,start to send start_test signal to VM..." 
    # Start to send benchmark launch signal
    num_line=2
    for benchmark_vmi in $(kubectl get vmi -o jsonpath='{.items[*].metadata.name}'); do
        # Compare current vm ip with the original ip,if VM IP changed,then collect logs and exit
        compare_vm_ip $num_line ${VM_IP_ADDR[$num_line]}     
        (ssh -o StrictHostKeyChecking=no -l root $CURRENT_VM_IP 'touch /home/start_test') &
        num_line=$(($num_line + 1))
        echo " - VM${num_line} ${benchmark_vmi} create start_test successfully..."
    done
    echo " - Finished start_test file creation in VM..."
}

# Start to do benchmarking
benchmark_vms () {
    # Benchmark start flag for emon test
    echo "Start benchmark"
    num_line=2
    for benchmark_vmi in $(kubectl get vmi -o jsonpath='{.items[*].metadata.name}'); do
        # Compare current vm ip with the original ip,if VM IP changed,then collect logs and exit
        compare_vm_ip $num_line ${VM_IP_ADDR[$num_line]}
        mkdir -p ${BENCHMARK_LOGS}/${benchmark_vmi}
        # Collect logs
        export_vm_logs $CURRENT_VM_IP $benchmark_vmi $num_line
        num_line=$(($num_line + 1))
        cat ${BENCHMARK_LOGS}/${benchmark_vmi}/status 
        cp ${BENCHMARK_LOGS}/${benchmark_vmi}/status ${BENCHMARK_LOGS}/
        echo "Finished one VM's benchmark..."
    done
    # Benchmark end flag for emon test
    echo "Finish benchmark"
    # -- cleanup VMs after benchmark finished
    delete_vms
}

run_migration_benchmark () {
    # Deploy the VMs
    deploy_vms
    # Start benchmarking in VM
    prepare_vm_benchmark
    # Wait FIO benchmarking 30s before doing live migration
    sleep 30s
    
    for i in $(seq 1 $BENCHMARK_CLIENT_NODES); do
        kubectl -n ${BENCHMARK_NS} apply -f ${CONFIG_FILE_PATH}/live-migration$i.yaml
        sleep 5s
        vm_name=${VM_NAME}$i
        check_migration_time=0
        while [ -z "$(kubectl -n ${BENCHMARK_NS} get pod | grep ${vm_name} |grep "Completed")" ]; do
             if [ "$check_migration_time" -gt $MIGRATION_TIMEOUT ]; then
                echo "vm live migration time out, migration failed."
                # Live-migration failed , the KPI(IOPS & BW) should be 0
                echo -e "read: IOPS=0, BW=0MiB/s" > ${BENCHMARK_LOGS}/${benchmark_vmi}/${TEST_CASE}_random_read_${TEST_OPERATION_MODE}_$(date +"%m-%d-%y-%H-%M-%S").log
                # Cleanup_environment and exit
                cleanup_environment
                data_collection_and_exit 1
            fi
            sleep 1s
            check_migration_time=$(($check_migration_time + 1))
        done

    done
    # VM IP will change after live-migration,refresh IP here
    num_line=2
    for benchmark_vmi in $(kubectl get vmi -o jsonpath='{.items[*].metadata.name}'); do
        VM_IP_ADDR[$num_line]=$(kubectl get vmi | awk 'NR=="'"$num_line"'"{print $4}')
        num_line=$(($num_line + 1))
    done
    # Start to benchmark fio in new VMs after migration
    benchmark_vms
}

run_recovery_benchmark () {
    # Deploy the VMs
    deploy_vms
    # Start benchmarking in VM
    prepare_vm_benchmark
    # after FIO running on VMs, sleep 30s before kill SPDK
    wait_to_kill_spdk=30
    sleep $wait_to_kill_spdk
    # kill SPDK application
    for vhost_daemon in $(kubectl -n ${CEPH_CLUSTER_NS} get po | grep ceph-spdk-vhost-daemon |awk '{print$1}');do
        kubectl exec -n ${CEPH_CLUSTER_NS} -i $vhost_daemon -- ./spdk/scripts/rpc.py spdk_kill_instance SIGKILL 2>/dev/null
        if [ "$?" -eq 0 ];then
            echo "killed SPDK process succefully, wait for live recovery!"
        else
            echo "*** WARNING: unable to kill spdk, please check SPDK app status"
        fi
    done
    echo "benchmark live recovery"
    num_line=2
    # live-recovery tolerate time = fio benchmark time + wait recovery time + wait to kill spdk time + 30s
    RECOVERY_TIMEOUT=$(($TEST_DURATION + $WAIT_RECOVERY_TIME + $wait_to_kill_spdk + 300))
    check_recovery_time=0
    for benchmark_vmi in $(kubectl get vmi -o jsonpath='{.items[*].metadata.name}'); do
        # compare current vm ip with the original ip,if VM IP changed,then collect logs and exit
        compare_vm_ip $num_line ${VM_IP_ADDR[$num_line]}
        mkdir -p ${BENCHMARK_LOGS}/${benchmark_vmi}
        # check live-recovery status
        while (! ssh -o StrictHostKeyChecking=no -l root $CURRENT_VM_IP 'cat /logs/status' 2>/dev/null); do
            sleep 1s
             if [ "$check_recovery_time" -gt $RECOVERY_TIMEOUT ]; then
                echo "vm live recovery time out, recovery failed..."
                echo 1 > ${BENCHMARK_LOGS}/${benchmark_vmi}/status
                # live-recovery failed , the KPI(IOPS & BW) should be 0
                echo -e "read: IOPS=0, BW=0MiB/s" > ${BENCHMARK_LOGS}/${benchmark_vmi}/${TEST_CASE}_random_read_${TEST_OPERATION_MODE}_$(date +"%m-%d-%y-%H-%M-%S").log
                # Cleanup_environment and exit
                cleanup_environment
                data_collection_and_exit 1
            fi
            check_recovery_time=$(($check_recovery_time + 1))
            # compare current vm ip with the original ip, if VM IP changed,then collect logs and exit
            compare_vm_ip $num_line ${VM_IP_ADDR[$num_line]}
        done
        # export vm logs only when live-recovery succeed
        export_vm_logs $CURRENT_VM_IP $benchmark_vmi $num_line
        cat ${BENCHMARK_LOGS}/${benchmark_vmi}/status
        cp ${BENCHMARK_LOGS}/${benchmark_vmi}/status ${BENCHMARK_LOGS}/
        num_line=$(($num_line + 1))
        echo "Finished one VM's benchmark..."
    done
}

deploy_and_benchmark () {
    if kubectl>/dev/null 2>/dev/null; then
        trap 'trap_kubernetes ${LINENO}' ERR SIGINT

        if [[ "${TEST_CASE}" == "virtIO" || "${TEST_CASE}" == "vhost" ]]; then
            # deploy kubevirt 
            deploy_kubevirt

            if [ "${TEST_CASE}" == "vhost" ]; then
                # deploy the vhost deamonset for vhost cases
                echo "Deploy the spdk-vhost daemonset for acceleration"
                deploy_spdk_daemonset
            elif [ "${TEST_CASE}" == "virtIO" ]; then
                STORAGE_CLASS=$(kubectl get sc | awk 'NR==2{print $1}')
                if [ "$STORAGE_CLASS" != "rook-ceph-block" ]; then
                    echo "***WARNING: Storageclass rook-ceph-block not found, please have a check!"
                    cleanup_environment
                    data_collection_and_exit 1
                fi
            fi                
            if [ "${TEST_OPERATION_MODE}" == "live-recovery" ]; then
                # Benchmark for live-recovery case
                run_recovery_benchmark
            elif [ "${TEST_OPERATION_MODE}" == "live-migration" ]; then
                # Benchmark for live-migration case
                run_migration_benchmark
            else
                # Benchmark for sequitial/random write/read case
                deploy_vms
                prepare_vm_benchmark
                benchmark_vms
            fi

        elif [ "${TEST_CASE}" == "gated" ]; then
            # test bm cases.
            run_gated_benchmark
        fi

        trap - ERR SIGINT 
    else
        echo "Deploy failed, kubenetes not supported!"
    fi
}

cleanup_environment () {
    if [ "${TEST_CASE}" == "gated" ]; then
        echo "${TEST_CASE} case, don't need cleanup."
        return 0
    fi 

    if kubectl>/dev/null 2>/dev/null; then

        # set trap for cleanup
        trap 'trap_kubernetes ${LINENO}' ERR SIGINT 

        # Cleanup VM resoruces.
        delete_vms

        # Cleanup the kubevirt resoruces.
        cleanup_kubevirt

        if [ "${TEST_CASE}" == "vhost" ]; then
            # cleanup the vhost deamonset for vhost cases
            cleanup_spdkvhost
        fi
        # Finish the cleanup process, clean trap.
        trap - ERR SIGINT 

    else
        echo "Failed for cleanup, kubenetes not supported!"
    fi
}

wait_ceph_cluster_ready () {
    # ceph cluster's pod should be in running status or Completed status
    check_time=0
    CEPH_STATUS_TIMEOUT=50
    while [ "$check_time" -lt ${CEPH_STATUS_TIMEOUT/*,/} ]; do
        ceph_cluster_ready="True"
        for pod_name in $(kubectl get po -n ${CEPH_CLUSTER_NS} \
        | grep -v STATUS | grep -E 'rook-ceph-mgr|rook-ceph-osd|rook-ceph-mon' | awk '{print $3}'); do
            if [[ "$pod_name" != "Running" && "$pod_name" != "Completed" ]]; then
                ceph_cluster_ready="False"
            fi      
        done 
        if [ "$ceph_cluster_ready" == "True" ]; then
            echo " - ceph cluster is ready..."
            return 0
        else
            sleep 5
            check_time=$(($check_time + 1))
            echo " - Wait for pod to be ready..."
        fi
    done
    echo "*** WARNING: wait ceph cluster ready timeout, please have a check"
    kubectl get po -n ${CEPH_CLUSTER_NS} > "${BENCHMARK_LOGS}"/ceph_cluster_status.log
    data_collection_and_exit 1
}

# Deploy ceph override configuration
# $1: override configuration yaml file
ceph_config_override () {
    # Deploy ceph override configuration yaml file
    #kubectl -n ${CEPH_CLUSTER_NS} apply -f ${CONFIG_FILE_PATH}/ceph_configmap.yaml
    kubectl -n ${CEPH_CLUSTER_NS} apply -f ${CONFIG_FILE_PATH}/"$1"
    OSD=$(kubectl get po -n ${CEPH_CLUSTER_NS} |grep rook-ceph-osd |grep -v rook-ceph-osd-prepare-|awk '{print $1}')
    # Re-deploy osd to let ceph configuration take effect
    for osds in $OSD; do
        kubectl delete -n ${CEPH_CLUSTER_NS} po/$osds --force
        sleep 5
        # After re-deployed,need ti wait ceph cluster to be ready
        wait_ceph_cluster_ready
    done
    echo " - Restart OSDs succeed..."
    # Re-deploy MGR to let ceph configuration take effect
    MGR=$(kubectl get po -n ${CEPH_CLUSTER_NS} |grep rook-ceph-mgr |awk '{print $1}')
    kubectl delete -n rook-ceph po/$MGR --force
    sleep 5
    # After re-deployed,need ti wait ceph cluster to be ready
    wait_ceph_cluster_ready
    echo " - Restart MGR succeed..."
    # Re-deploy MON to let ceph configuration take effect
    MON=$(kubectl get po -n rook-ceph |grep rook-ceph-mon |awk '{print $1}')
    for mons in $MON; do
        kubectl delete -n rook-ceph po/$mons --force
        sleep 5
        # After re-deployed,need ti wait ceph cluster to be ready
        wait_ceph_cluster_ready
    done
    echo " - Restart MONs succeed..."
}

# Check ceph version for qat cases, since only ceph version 17+ supports qat acceleration.
# If ceph version matches, no need to redeploy ceph,but need to reconfig ceph.
check_ceph_version_for_qatcase () {

    if [ -n "$(kubectl get po -n $CEPH_CLUSTER_NS |grep rook-ceph-tools)" ];then
        TOOLBOX_PODNAME=`kubectl -n $CEPH_CLUSTER_NS get pods -A|grep rook-ceph-tools|awk '{print$2}'`
        CEPH_VERSION=`kubectl -n $CEPH_CLUSTER_NS exec -it $TOOLBOX_PODNAME -- ceph -v`
        if [[ ! "$CEPH_VERSION" =~ "ceph version 17.2.5" ]];then
            echo "Ceph version too old, please deploy specific version for Ceph-QAT"
            sleep 10s
            data_collection_and_exit 1
        fi
    else
        echo "Ceph-tools pod does not exist, please have a check and run benchmark again"
        data_collection_and_exit 1
    fi

}

# Parse the arguments for bench operator.
check_args $*

if [ "$OPERATOR_ARG" == "CLEANUP" ]; then 
    echo "Clean up the environment."
    exit 0
fi

# Retrieve the informantion about the list of worker node IP address.
# In Service framework, it is critical to restrict any newly launched pods 
# to be within the cluster workers that the workload is assigned to run, but not 
# all of the nodes in k8s cluster.
#  - name: CLUSTER_WORKERS
#      value: 10.67.121.66,10.67.121.67,10.67.121.68
if [ -n "$CLUSTER_WORKERS" ]; then
    node_array=(${CLUSTER_WORKERS//,/ })  
    # Check how many nodes we have been authorized and assigned.
    #ASSIGNED_WORKER_COUNT=$(echo $CLUSTER_WORKERS | tr -t ',' '\n' | wc -l)
    ASSIGNED_WORKER_COUNT=${#node_array[*]}
    if [ $ASSIGNED_WORKER_COUNT -lt $CLUSTERNODES  ]; then
        echo " *** ERROR: No sufficient node [$ASSIGNED_WORKER_COUNT] for ceph cluster deployment, we need [$CLUSTERNODES] nodes";
        echo " *** Assigned node list :["$CLUSTER_WORKERS"]"
        data_collection_and_exit 1;
    fi
    echo "Try to deploy ceph storage on these "$CLUSTERNODES"-node:[$CLUSTER_WORKERS]"; 
    # Currently, the largest cluster is 3-nodes.
    # DEPLOY_NODE1 / DEPLOY_NODE2 / DEPLOY_NODE3
    if [ $ASSIGNED_WORKER_COUNT -gt $CLUSTERNODES ]; then
        unset node_array[0]
    fi
    i=1
    for node_i in ${node_array[@]}
    do 
        echo "Set DEPLOY_NODE$i with $node_i"
        export DEPLOY_NODE$i="$node_i"
        i=$(($i + 1))
        #echo "$DEPLOY_NODE1 and $DEPLOY_NODE2 and $DEPLOY_NODE3"
    done
    #Cumulus backend run in WSF will come here, set to "PARTIAL" mode for node selection.
    NODE_SELECT="PARTIAL"
    BENCHMARK_OPTIONS=${BENCHMARK_OPTIONS}";-DNODE_SELECT=${NODE_SELECT}"

else 
    echo "WARN: No restrict node list:["$CLUSTER_WORKERS"], please ensure the nodes selection for ceph is under control"
fi

if [ "$TEST_CASE_COMP" == "1" ]; then
    check_ceph_version_for_qatcase
fi

env_precheck_hook
sleep 5s # for system stability after purge

# Auto calculate rbd image size according to different 
calculate_rbd_img_size

# Convert the m4 file to k8s yaml
bash ./build_yaml_file.sh template

# Health check before run validation
# Also need to check CRD setting.

# Deploy configuration override for ceph
if [ "${CEPH_CONFIG_ENABLED}" == "1" ]; then
    # print current ceph config
    kubectl get -n ${CEPH_CLUSTER_NS} configmap rook-config-override -o yaml
    # Deploy configuration override for ceph
    ceph_config_override ceph_configmap.yaml
    # Print current ceph config
    kubectl get -n ${CEPH_CLUSTER_NS} configmap rook-config-override -o yaml
    # Need to check ceph cluster status after deploy ceph configuration
    check_ceph_cluster_status
    echo " - CEPH configuration has been succeessfully deployed..."
else
    echo " - Skip configuration override for ceph,keep default ceph configuration"
fi

# Deploy the environment and benchmark
echo "Start to Deploy and benchmark"
deploy_and_benchmark | tee "$BENCHMARK_LOGS"/deploy_bench_$(date +"%m-%d-%y-%H-%M-%S").log

if [[ "$OPERATOR_ARG" == "DEPLOY" || "$OPERATOR_ARG" == "BENCH" ]]; then 
    echo "Benchmark is done, cluster is still alive, need to cleanup manually!"
    exit 0
fi

if [ "${DEBUG_MODE}" == "4" ]; then
    echo "DGB_MODE:${DEBUG_MODE}, benchamrk is finished, waiting for cleanup!"

    while [ ! -f /debug_flag ]; do
        sleep 5
    done

    rm -f /debug_flag
fi

echo "Clean up the environment"
sleep 15s # 
cleanup_environment | tee "$BENCHMARK_LOGS"/cleanup_$(date +"%m-%d-%y-%H-%M-%S").log
sleep 15s

# # If we want connect the ceph cluster in current POD, then
# # need to initial the system with rook-ceph toolbox.
# # Intial the ceph cluster accessability with toolbox.
# echo "Initialize test with toolbox"
# sleep 60s
# /bin/bash -c -m /usr/local/bin/toolbox.sh &
# echo "End of the initialization!"

# # Benchmark the ceph after the stack ready.
echo "Collect benchmark logs"
sync && cd "$BENCHMARK_LOGS" && tar cf /export-logs status $(find . -name "*.log")  && \

echo "Test finished" && \
sleep infinity
