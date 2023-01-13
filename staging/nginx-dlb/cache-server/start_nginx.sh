#!/bin/bash -ex

#kill existed nginx and python
killall nginx | true
killall python3 | true
sleep 3

unset http_proxy
unset https_proxy


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
}
restrict_nginx_mem_usage

#start nginx server
#set your nginx folder here
NGX_DIR=<nginx folder path>
ulimit -n 655350
cd $NGX_DIR
cgexec -g memory:nginx --sticky $NGX_DIR/sbin/nginx -c $NGX_DIR/etc/nginx/nginx.conf

cd ${DIR}

sleep 1
#netstat -an | grep LISTEN | grep tcp

### check cache disks:
printf "\n  Cache disks should correctly mounted as descripted in nginx.conf:\n\n"
df -h | grep nvme

printf "\n  Check listening TCP ports:\n\n"
netstat -ano | grep LISTEN | grep tcp
