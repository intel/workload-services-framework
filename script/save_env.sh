#!/bin/bash
###############################################################################
#This script to save the env including kernel,net setting,hugepage etc.       #
#Pls run this script before start the workload.                               #
#This script will generate a restore.sh for using after the workload finished.#
#Also you should add the special setting for your workload.                   #
###############################################################################

set -e
IFS_old=$IFS      # record separator
IFS=$'\n'         # use "\n" as separator

set_sysctl(){
    echo "sysctl \"$(sysctl $1 | sed 's/ //g')\"" >> ${file_name}
}

set_net(){
    set_sysctl $1
}

set_kernel(){
    set_sysctl $1
}

set_vm(){
    set_sysctl $1
}

set_hugepages(){
    command=$(cat $1 | cut -d '[' -f2 | cut -d ']' -f1)
    echo "echo $command > $1" >> ${file_name}
}

set_ulimit(){
    echo "ulimit -n $(ulimit -n)" >> ${file_name}
}

check_os() {
    system_vesion=$(lsb_release -i | awk '{print $3}')
        if [ $system_vesion == $1 ]; then
            echo "system vesion is $system_vesion" 
        else
            echo "[erro] system vesion Don't match" 
            exit 1
        fi
}

set_grubby(){
    check_os $1
    n_line=$(grep '^GRUB_CMDLINE_LINUX=' -n /etc/default/grub | cut -d ':' -f 1)
    str=$(grep '^GRUB_CMDLINE_LINUX=' /etc/default/grub | cut -d '=' -f2)
    str=$(echo $str | sed 's/\"//g'| sed $'s/\'//g')
    echo "sed -i 's/^GRUB_CMDLINE_LINUX=/#GRUB_CMDLINE_LINUX=/' /etc/default/grub" >> ${file_name}
    echo "sed -i \"$n_line a \GRUB_CMDLINE_LINUX=\'$str\'\" /etc/default/grub" >> ${file_name}
    if [ "Ubuntu" == $1 ]; then       
        echo "update-grub" >> ${file_name}
    elif [ "CentOS" == $1 ]; then
        echo "grub2-mkconfig -o /boot/grub2/grub.cfg" >> ${file_name}
    fi
        echo "reboot" >> ${file_name}
}

set_system_kernel(){
    check_os $1
    if [ "Ubuntu" == $1 ]; then
        n_line=$(grep '^GRUB_DEFAULT=' -n /etc/default/grub | cut -d ':' -f 1)
        str=$(grep '^GRUB_DEFAULT=' /etc/default/grub | cut -d '=' -f2)
        str=$(echo $str | sed 's/\"//g'| sed $'s/\'//g')
        echo "sed -i 's/^GRUB_DEFAULT=/#GRUB_DEFAULT=/' /etc/default/grub" >> ${file_name}
        echo "sed -i \"$n_line a \GRUB_DEFAULT=$str\" /etc/default/grub" >> ${file_name}
        echo "update-grub" >> ${file_name}
    elif [ "CentOS" == $1 ]; then
        kernel_version=$(uname -r)
        echo "grubby --set-default /boot/vmlinuz-${kernel_version}" >> ${file_name}
    fi
        echo "reboot" >> ${file_name}
}

make_sure_new_file(){
    if [[ -a ${file_name} ]];then
        echo "[info] file exist, delete"
        rm ${file_name}
    else
        echo "[info] file not exist, touch it"
        touch ${file_name}
    fi
}

write_first_line(){
    # echo $str_fist_line > $1
    cat > ${file_name} << EOF
#!/bin/bash
set -e
EOF
}

# remove command if not only
remove_command(){
    head_line=$(grep -n $1 ${file_name} | head -1 | cut -d ':' -f1)
    tail_line=$(grep -n $1 ${file_name} | tail -1 | cut -d ':' -f1)
    cmd=$(grep -n $1 ${file_name} | head -1 | cut -d ':' -f2)
    if [ $head_line -ne $tail_line ];then
        sed -i "${head_line}d" ${file_name}
        echo $tail_line
    fi
}

file_name="restore.sh"
make_sure_new_file
write_first_line

# Net
set_net net.core.rmem_max
set_net net.ipv4.tcp_rmem
set_net net.ipv4.tcp_wmem
set_net net.core.netdev_max_backlog
set_net net.core.somaxconn
set_net net.ipv4.tcp_no_metrics_save

# Kernel
set_kernel kernel.sched_cfs_bandwidth_slice_us
set_kernel kernel.sched_child_runs_first
set_kernel kernel.sched_latency_ns
set_kernel kernel.sched_migration_cost_ns
set_kernel kernel.sched_min_granularity_ns
set_kernel kernel.sched_nr_migrate
set_kernel kernel.sched_rr_timeslice_ms
set_kernel kernel.sched_rt_period_us
set_kernel kernel.sched_rt_runtime_us
set_kernel kernel.sched_schedstats
set_kernel kernel.sched_tunable_scaling
set_kernel kernel.sched_wakeup_granularity_ns
set_kernel kernel.numa_balancing

# VM
set_vm vm.dirty_expire_centisecs
set_vm vm.dirty_writeback_centisecs
set_vm vm.dirty_ratio
set_vm vm.dirty_background_ratio
set_vm vm.swappiness
set_vm vm.overcommit_memory

#hugepage
set_hugepages /sys/kernel/mm/transparent_hugepage/enabled
set_hugepages /sys/kernel/mm/transparent_hugepage/defrag 
set_hugepages /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages 

# ulimit
set_ulimit

# grubby
#set_grubby Ubuntu
set_grubby CentOS

# system_kernel 
#set_system_kernel Ubuntu
set_system_kernel CentOS


# remove redundant command
# this is for you set both gruby and system kernel, if only one, pls comment this cmd.
remove_command reboot

IFS=$IFS_old # back separator
