#!/bin/bash -ex

DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
(( EUID != 0 )) && exec sudo -E -- "$0" "$@"

#kill existed nginx and python
killall nginx | true
killall python3 | true
sleep 3

unset http_proxy
unset https_proxy

#set your NGINX path and DLB library path here
NGX_DLB=<NGINX DLB Path>
DLB_DEPLOY=<DLB Path>


function reload_dlb ()
{
    cd ${DLB_DEPLOY}/driver/dlb2

    if [ -e "dlb2.ko" ]; then
	rmmod dlb2 | true
	rmmod dlb2 | true
        dlb2_exist=`lsmod | grep dlb2 | xargs | awk '{print $1}'`
        if [[ -v ${dlb2_exist} ]]; then 
            printf "failed to unload dlb2 kernel module\n"
	    exit 1
	fi
 	#modprobe mdev
        # modprobe vfio_mdev
        sudo insmod dlb2.ko dyndbg | true
        # insmod dlb2.ko dyndbg
        echo "module dlb2 -p" > /sys/kernel/debug/dynamic_debug/control
        echo "DLB kernel module insmoded"
    else
        echo "dlb2.ko compile failed!"
    fi
    echo "dlb2.ko driver installed successfully"

    cd ${DIR}

    #reset the dlb device
    n=`ls /sys/class/dlb2/ |wc -l`

    if [ ${n} -eq 0 ];then
        echo "no dlb device found in the system /sys/class/dlb2/"
        exit
    fi

    echo "found ${n} dlb device in the system"

    rm -rf /dev/shm/dlb*

    n=`expr ${n} - 1`

    for i in `seq 0 ${n}`
    do
        echo 1 > /sys/class/dlb2/dlb${i}/device/reset
    done
    echo "dlb environment setup successfully, go on for next steps"
}
reload_dlb

function restrict_nginx_mem_usage () 
{
    # Cgroups setting to limiting memeory size to simuluate IO heavy case
    if [ ! -d "/sys/fs/cgroup/memory/nginx" ]; then
        cd /sys/fs/cgroup/memory
        mkdir nginx
        cd -
    fi
    NGX_MEM_LIMIT=$(( 1024*1024*1024*32 ))

    echo $NGX_MEM_LIMIT > /sys/fs/cgroup/memory/nginx/memory.limit_in_bytes
    if [ $? -ne 0 ]; then
        echo "Setting cgroup memroy failed"
        exit
    fi
    echo "Setting cgroup memory ($NGX_MEM_LIMIT) successfully"
    cat /sys/fs/cgroup/memory/nginx/memory.limit_in_bytes
}
restrict_nginx_mem_usage

#start nginx server
cd ${NGX_DLB}
ulimit -n 655350
#LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${DLB_DEPLOY}/libdlb cgexec -g memory:nginx --sticky ${NGX_DLB}/sbin/nginx -c ${NGX_DLB}/etc/nginx/nginx.conf
#export LD_LIBRARY_PATH=${DLB_DEPLOY}/libdlb
#echo $LD_LIBRARY_PATH
rm -rf /lib64/libdlb.so
#cp ${DLB_DEPLOY}/libdlb/libdlb.so /lib64/libdlb.so
export LD_LIBRARY_PATH=<libdlb path>:$LD_LIBRARY_PATH
cgexec -g memory:nginx --sticky sh -c "LD_LIBRARY_PATH=<libdlb path> ${NGX_DLB}/sbin/nginx -c ${NGX_DLB}/etc/nginx/nginx.conf"
echo > ${NGX_DLB}/var/www/log/error.log
echo > ${NGX_DLB}/error.log
cd ${DIR}

sleep 1
#netstat -ano | grep LISTEN | grep tcp
#curl http://192.168.100.1:8080

### check cache disks:
printf "\nCache disks should correctly mounted as descripted in nginx.conf:\n\n"
df -h | grep nvme


