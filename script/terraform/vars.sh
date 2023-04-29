#!/bin/bash -e

overwrite () {
    if [ "$_kk" != "$1" ] || [ "$_vv" != "$2" ]; then
        eval "export $1=\"$2\""
        echo "OVERWRITE: $1=$2"
    fi
}

convert_mcp () {
    case "$1" in
    sandybridge)
        echo "Intel Sandy Bridge"
        ;;
    ivybridge)
        echo "Intel Ivy Bridge"
        ;;
    haswell)
        echo "Intel Haswell"
        ;;
    broadwell)
        echo "Intel Broadwell"
        ;;
    skylake)
        echo "Intel Skylake"
        ;;
    cascadelake)
        echo "Intel Cascade Lake"
        ;;
    icelake)
        echo "Intel Ice Lake"
        ;;
    rome)
        echo "AMD Rome"
        ;;
    milan)
        echo "AMD Milan"
        ;;
    *)
        echo "${1//%20/ }" | tr '_' ' '
        ;;
    esac
}
    
_kk="$1"
_vv="$2"
case "$1" in
*_*_MACHINE_TYPE) # preempt *_MACHINE_TYPE
  overwrite "${1%_MACHINE_TYPE}_INSTANCE_TYPE" "$2"
  ;;
*_MACHINE_TYPE)
  overwrite "${1%_MACHINE_TYPE}_WORKER_INSTANCE_TYPE" "$2"
  ;;
*_*_INSTANCE_TYPE) # preempt *_INSTANCE_TYPE
  ;;
*_INSTANCE_TYPE)
  overwrite "${1%_INSTANCE_TYPE}_WORKER_INSTANCE_TYPE" "$2"
  ;;
*_*_MIN_CPU_PLATFORM) # preempt *_MIN_CPU_PLATFORM
  overwrite "$1" "$(convert_mcp "$2")"
  ;;
*_MIN_CPU_PLATFORM)
  overwrite "${1%_MIN_CPU_PLATFORM}_WORKER_MIN_CPU_PLATFORM" "$(convert_mcp "$2")"
  ;;
*_*_THREADS_PER_CORE) # preempt *_THREADS_PER_CORE
  ;;
*_THREADS_PER_CORE)
  overwrite "${1%_THREADS_PER_CORE}_WORKER_THREADS_PER_CORE" "$2"
  ;;
*_*_CPU_CORE_COUNT) # preempt *_CPU_CORE_COUNT
  ;;
*_CPU_CORE_COUNT)
  overwrite "${1%_CPU_CORE_COUNT}_WORKER_CPU_CORE_COUNT" "$2"
  ;;
*_*_NIC_TYPE) # preempt *_NIC_TYPE
  ;;
*_NIC_TYPE)
  overwrite "${1%_NIC_TYPE}_WORKER_NIC_TYPE" "$2"
  ;;
*_*_IMAGE) # preempt *_IMAGE
  ;;
*_IMAGE)
  overwrite "${1%_IMAGE}_WORKER_IMAGE" "$2"
  ;;
*_*_OS_TYPE) # preempt *_OS_TYPE
  ;;
*_OS_TYPE)
  overwrite "${1%_OS_TYPE}_WORKER_OS_TYPE" "$2"
  ;;
*_*_OS_DISK_SIZE) # preempt *_OS_DISK_SIZE
  ;;
*_OS_DISK_SIZE)
  overwrite "${1%_OS_DISK_SIZE}_WORKER_OS_DISK_SIZE" "$2"
  ;;
*_*_OS_DISK_TYPE) # preempt *_OS_DISK_TYPE
  ;;
*_OS_DISK_TYPE)
  overwrite "${1%_OS_DISK_TYPE}_WORKER_OS_DISK_TYPE" "$2"
  ;;
*_*_OS_DISK_IOPS) # preempt *_OS_DISK_IOPS
  ;;
*_OS_DISK_IOPS)
  overwrite "${1%_OS_DISK_IOPS}_WORKER_OS_DISK_IOPS" "$2"
  ;;
*_*_OS_DISK_THROUGHPUT) # preempt *_OS_DISK_THROUGHPUT
  ;;
*_OS_DISK_THROUGHPUT)
  overwrite "${1%_OS_DISK_THROUGHPUT}_WORKER_OS_DISK_THROUGHPUT" "$2"
  ;;
*_DISK_SPEC_*_DISK_FORMAT) # preempt *_DISK_FORMAT
  ;;
*_DISK_FORMAT)
  overwrite "${1%_DISK_FORMAT}_DISK_SPEC_1_DISK_FORMAT" "$2"
  ;;
*_DISK_SPEC_*_DISK_TYPE) # preempt *_DISK_TYPE
  ;;
*_DISK_TYPE)
  overwrite "${1%_DISK_TYPE}_DISK_SPEC_1_DISK_TYPE" "$2"
  ;;
*_DISK_SPEC_*_DISK_COUNT) # preempt *_DISK_COUNT
  ;;
*_DISK_COUNT)
  overwrite "${1%_DISK_COUNT}_DISK_SPEC_1_DISK_COUNT" "$2"
  ;;
*_DISK_SPEC_*_DISK_SIZE) # preempt *_DISK_SIZE
  ;;
*_DISK_SIZE)
  overwrite "${1%_DISK_SIZE}_DISK_SPEC_1_DISK_SIZE" "$2"
  ;;
*_DISK_SPEC_*_DISK_IOPS) # preempt *_DISK_IOPS
  ;;
*_DISK_IOPS)
  overwrite "${1%_DISK_IOPS}_DISK_SPEC_1_DISK_IOPS" "$2"
  ;;
*_DISK_SPEC_*_DISK_THROUGHPUT) # preempt *_DISK_THROUGHPUT
  ;;
*_DISK_THROUGHPUT)
  overwrite "${1%_DISK_THROUGHPUT}_DISK_SPEC_1_DISK_THROUGHPUT" "$2"
  ;;
*_DISK_SPEC_*_DISK_PERFORMANCE) # preempt *_DISK_PERFORMANCE
  ;;
*_DISK_PERFORMANCE)
  overwrite "${1%_DISK_PERFORMANCE}_DISK_SPEC_1_DISK_PERFORMANCE" "$2"
  ;;
*_NETWORK_SPEC_*_NETWORK_COUNT) # preempt *_NETWORK_COUNT
  ;;
*_NETWORK_COUNT)
  overwrite "${1%_NETWORK_COUNT}_NETWORK_SPEC_1_NETWORK_COUNT" "$2"
  ;;
*_NETWORK_SPEC_*_NETWORK_TYPE) # preempt *_NETWORK_TYPE
  ;;
*_NETWORK_TYPE)
  overwrite "${1%_NETWORK_TYPE}_NETWORK_SPEC_1_NETWORK_TYPE" "$2"
  ;;
*_SPOT_INSTANCE)
  overwrite "SPOT_INSTANCE" "$2"
  ;;
esac
  
