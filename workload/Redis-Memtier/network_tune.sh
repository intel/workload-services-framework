#Only for aws/hypervisor
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
lscpu | grep -q Hypervisor && {
    echo "test in cloud"
    ena_driver=$(lsmod | grep ena)
    NODE_OWN_IP_ADDRESS=$(hostname -I | awk '{print $1}')
    if [ "$NODE_OWN_IP_ADDRESS" ] && [ "$ena_driver" ]; then
        for dir in /sys/class/net/*/; do # list directories
            devname=$(basename $dir)     # print everything after the final"/"
            confirm_nic_info=$(ip a s $devname)
            if [[ "$confirm_nic_info" =~ $NODE_OWN_IP_ADDRESS ]]; then
                echo "found interface $devname as worker node nic ip"
                lines_num=$(ls -l /sys/class/net/$devname/queues | wc -l)
                # if [ $lines_num -eq 17 ]; then
                    echo "found the right rx and tx queues number in /sys/class/net/$devname/queues"
                    local_cpu_lists=$(cat /sys/class/net/$devname/device/local_cpus)
                    echo "local cpu list for nic is $local_cpu_lists"
                    for ((ii = 0; ii <= 15; ii = ii + 1)); do
                        echo "try to modify /sys/class/net/$devname/queues/rx-$ii/rps_cpus"
                        if [ -s "/sys/class/net/$devname/queues/rx-$ii/rps_cpus" ]; then
                            echo "/sys/class/net/$devname/queues/rx-$ii/rps_cpus exist and not zero file size"
                            cat /sys/class/net/$devname/queues/rx-$ii/rps_cpus
                            echo $local_cpu_lists | sudo tee /sys/class/net/$devname/queues/rx-$ii/rps_cpus
                            cat /sys/class/net/$devname/queues/rx-$ii/rps_cpus
                        fi
                    done
                # fi
                break
            fi
        done
    fi
} || {
    echo "test in local bare metal"
}
