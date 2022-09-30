#!/bin/bash -e

if [[ -z "$NODE_IP" ]]; then
    echo "Node ip not found"
    exit 1
fi
echo "Node ip: $NODE_IP"

# find network device by node ip
function get_network_device_by_ip() {
    node_ip=$1
    ALL_NETWORK_DEVICES=($(ls /sys/class/net))
    for dev in "${ALL_NETWORK_DEVICES[@]}"
    do
        output=$(ifconfig $dev)
        if [[ "$output" =~ "$node_ip" ]]; then
            rtn_net_dev=$dev # device found by node ip
            break
        fi
    done
    echo "$rtn_net_dev"
}
NET_DEV=$(get_network_device_by_ip $NODE_IP)
if [[ -z "$NET_DEV" ]]; then
    echo "Network device not found"
    exit 2
fi
echo "Network device $NET_DEV found"

## if network device receive queue size less than cpu cores
## enable steering to bind rx queue cpu using local cpu list
RX_QUEUE_SIZE=$(ls /sys/class/net/$NET_DEV/queues/rx-* -d | wc -l)
RPS_SOCK_FLOW_ENTRIES=${RPS_SOCK_FLOW_ENTRIES:-32768}
echo "Network device $NET_DEV rx/tx queue size $RX_QUEUE_SIZE"
if ${DEBUG:-false}; then
    set -x
fi

#interrupt bind
if ${ENABLE_IRQ_AFFINITY:-true}; then
    function set_irq_smpaffinity() {
        net_device=$1
        irq_list=($(cat /proc/interrupts | grep "$net_device" | awk -F: '{print $1}'))
        irq_len=${#irq_list[@]}
        echo "Network device $net_device interrupt list: ${irq_list[@]}"

        lscpu -p=CPU,NODE|sed -e '/^#/d' > /tmp/cpu_numa_map
        local_cpulist=$(cat /sys/class/net/$net_device/device/local_cpulist)
        local_node=$(lscpu |grep "$local_cpulist"|awk '/NUMA node/{print $2}'|awk -F 'node' '{print $2}')
        local_node_cores=($(cat /tmp/cpu_numa_map|grep ",$local_node"|awk -F ',' '{print $1}'))
        echo "Network device $net_device local cpu list: ${local_node_cores[@]}"
        core_len=${#local_node_cores[@]}
        for(( i=0; i < irq_len; i++ ))
        do
            irq=${irq_list[$i]}
            core_index=$((i % core_len))
            core=${local_node_cores[$core_index]}
            echo "$core" > /proc/irq/$irq/smp_affinity_list
            echo "Network device $net_device binding interrupt $irq on core $core"
        done
    } # end function
    echo "Set network interrupt cpu affnity on device $NET_DEV"
    set_irq_smpaffinity "$NET_DEV"
fi

# rps bind
if ${ENABLE_RPSRFS_AFFINITY:-true}; then
    local_cpulist=$(cat /sys/class/net/$net_device/device/local_cpulist)
    echo "Network device $NET_DEV with cpu affinity on node: $(lscpu |grep "$local_cpulist")"
    DEV_LOCAL_CPUS=$(cat /sys/class/net/$NET_DEV/device/local_cpus) # bitmask of local_cpulist
    RPS_FLOW_CNT_VALUE=$(( RPS_SOCK_FLOW_ENTRIES / RX_QUEUE_SIZE ))
    for((i=0; i < RX_QUEUE_SIZE; i++))
    do
        # rps
        if [[ -f "/sys/class/net/$NET_DEV/queues/rx-$i/rps_cpus" ]]; then
            echo "$DEV_LOCAL_CPUS" > /sys/class/net/$NET_DEV/queues/rx-$i/rps_cpus
        fi
        
        # rfs
        echo "$RPS_SOCK_FLOW_ENTRIES" > /proc/sys/net/core/rps_sock_flow_entries
        if [[ -f "/sys/class/net/$NET_DEV/queues/rx-$i/rps_flow_cnt" ]]; then
            echo $RPS_FLOW_CNT_VALUE > /sys/class/net/$NET_DEV/queues/rx-$i/rps_flow_cnt
        fi
    done
fi
if ${DEBUG:-false}; then
    set +x
fi
