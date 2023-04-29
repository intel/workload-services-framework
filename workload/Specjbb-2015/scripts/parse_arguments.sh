#!/bin/bash -e

# ######################################
# Script that parses input arguments set by specjbb*.env.sh and sets appropriate local and global variables
# @note Global variables are set to allow for environment substitution into the ./template config files
#
# Globals:
#   None
# Arguments:
#   Array of SPECJBB_ input arguments. For full details @see usage()
# Example:
#  ./parse_arguments.sh --specjbb_client_pool_size=100 --specjbb_...
# Return:
# 	0 if successfully generated configuration, non-zero otherwise.
# ######################################

readonly SPECJBB_MEMORY_PER_CORE=1
readonly TI_JVM_COUNT=1
export TI_JVM_COUNT
NUM_CPUS=$(grep -c processor /proc/cpuinfo)
readonly NUM_CPUS
export NUM_CPUS

# ######################################
# Print help contents to screen
# Output:
# 	 Writes input arguments and their description to stdout
# ######################################
usage() {
    echo -e "
Usage:
 --specjbb_backend_survivor_ratio: Survivor Ratio used in Backend JVM.  Defaults to 28 if not specified.
    (default: '28')
    (an integer)
 
 --specjbb_client_pool_size: Client pool size.
    (default: '210')
    (an integer)
 
 --specjbb_controller_heap_memory: Heap memory settings per controller JVM. Defaults to \"-Xms2g -Xmx2g -Xmn1536m\" if not specified. Note that the memory units are required.
    (default: '-Xms2g -Xmx2g -Xmn1536m')
 
 --specjbb_customer_driver_threads: Customer Driver Threads.
    (default: '64')
    (an integer)
 
 --specjbb_customer_driver_threads_probe: Customer Driver Threads Probe.
    (default: '64')
    (an integer)
 
 --specjbb_customer_driver_threads_saturate: CUstomer Driver Threads Saturate.
    (default: '64')
    (an integer)
 
 --specjbb_duration: specjbb duration for PRESET and LOADLEVEL
    (default: '600')
    (an integer)
 
 --specjbb_gc_threads: SPECjbb garbage collector threads per group. Defaults to (total vCPUs / number of groups) if not specified, for all machines except for
                       SPR and ICX machines which defaults to ...............   (Core(s) per socket / number of groups)
    (an integer)
 
 --specjbb_groups: Number of SPECjbb groups to create. Defaults to number of NUMA nodes if not specified.
    (an integer)
 
 --specjbb_injector_heap_memory: Injector memory settings per injector JVM. Defaults to \"-Xms2g -Xmx2g -Xmn1536m\" if not specified.  Note that the memory units are required.
    (default: '-Xms2g -Xmx2g -Xmn1536m')
 
 --specjbb_java_parameters: string of any extra Java parameters that need to be passed to Backend JVM
    (default: '')

 --specjbb_injector_java_parameters: string of any extra Java parameters that need to be passed to Injector JVM
    (default: '')

 --specjbb_controller_java_parameters: string of any extra Java parameters that need to be passed to Controller JVM
    (default: '')

 --specjbb_kitversion: SPECjbb kit version. This must be available in SPECjbb repo in order to be used.
    (default: '1.03')
 
 --specjbb_huge_page_size: Large page size in m (megabyte) or G (gigabytes), when used.
    (default: '2m') if empty uses the default large page size for the environment as the maximum large page size.
    (an integer)
 
 --specjbb_loadlevel_start: Controls the % of max RT when the load level stage should start. This is particularly helpful with telemetry analysis as different values have to be used to capture critical jOPS / max jOPS thresholds. Use 0.5-0.55 for critical and 0.95
    for max.
    (default: '0.95')
    (a number in the range [0.0, 1.0])
 
 --specjbb_loadlevel_step: Controls the % step of load level stage.
    (default: '1')
    (an integer)
 
 --specjbb_mapreducer_pool_size: Map reducer pool size. Defaults to (total vCPUs / number of groups) if not specified.
    (an integer)
 
 --specjbb_preset_ir: specjbb preset Injection Rate when specjbb_run_type=PRESET.
    (default: '1000')
    (an integer)
 
 --specjbb_rtstart: rt start point percentage
    (default: '0')
    (an integer)
 
 --specjbb_run_type: <HBIR_RT|HBIR_RT_LOADLEVELS|PRESET>: specjbb run-type like HBIR_RT, LOADLEVEL, PRESET
    (default: 'HBIR_RT')
 
 --specjbb_selector_runner_count: Selector runner count. Defaults to number of groups if not specified
    (an integer)
 
 --specjbb_tier_1_threads: Number of tier 1 threads per group. Defaults to (${SPECJBB_DEFAULT_T1_MULT} * # cores / specjbb_groups) if not specified.
    (an integer)
 
 --specjbb_tier_2_threads: Number of tier 2 threads per group. Defaults to (${SPECJBB_DEFAULT_T2_MULT} * # cores / specjbb_groups) if not specified.
    (an integer)
 
 --specjbb_tier_3_threads: Number of tier 3 threads per group. Defaults to (${SPECJBB_DEFAULT_T3_MULT} * # cores / specjbb_groups) if not specified.
    (an integer)

 --specjbb_default_t1_t2_t3_multipliers: Default multiplier for automatically calculating specjbb_tier_x_threads (1 - 3) above, if specjbb_tier_x_threads (1 - 3) threads have not been specified.
    (csv string: 7,0.25,1.2)

 --[no]specjbb_use_avx: If enabled, uses latest available AVX version.
    (default: 'true')

 --[no]specjbb_use_huge_pages: If enabled, large pages are used.
    (default: 'true')
 
 --specjbb_worker_pool_max: Worker pool max.
    (default: '90')
    (an integer)
 
 --specjbb_worker_pool_min: Worker pool min.
    (default: '1')
    (an integer)
 
 --specjbb_xmn: Nursery size per backend JVM. Defaults to (1 * (cores / specjbb_groups) - 2)g for max-jop tuning if not specified. Defaults to ((total memory - (7 + 2 * specjbb_groups)) / specjbb_groups) - 3 for critical-jop tuning. Note that the memory unit is
    required.
 
 --specjbb_xms: Min Heap size per backend JVM. Defaults to (1 * (cores / specjbb_groups))g for max-jop tuning if not specified. Defaults to (total memory - (7 + 2 * specjbb_groups)) / specjbb_groups for critical-jop tuning. Note that the memory unit is required.
 
 --specjbb_xmx: Max Heap size per backend JVM. Defaults to (1 * (cores / specjbb_groups))g for max-jop tuning if not specified. Defaults to (total memory - (7 + 2 * specjbb_groups)) / specjbb_groups for critical-jop tuning. Note that the memory unit is required.

 --specjbb_workload_config: Customer Test case configuration in the format of [mode_pki_customer]. e.g multijvm_crit_general @see CMakeLists.txt @param #3

~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 Output arguments:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 --specjbb_print_vars: Print generated Variables. Default false

 --config_runtime_vars: Location of output variables file needed for specjbb runtime service. Defaults to /tmp/runtime.vars 
	"
}

# ######################################
# Print(s) Specjbb and Jvm Variables
# Output:
# 	 Writes out all SPECJBB AND JVM_OPTS to stdout
# ######################################
printVariables() {
    for var in $(echo "${!SPECJBB@}" | sort); do
        printf "%-42s %b\n" "$var" "${!var}"
    done
    echo " "
    for var in ${!JVM_OPTS@}; do
        printf "%-42s %b\n" "$var" "${!var}"
    done
    echo " "
}

# ######################################
# Sets specific machine details as environmental variables, so they can be injected into specjbb configuration for machine specific tuning
# Globals:
#    SPECJBB_GROUPS
# Arguments:
#    None
# ######################################
getMachineDetails() {
    export DATE=$(date "+%Y-%m-%d %H:%M:%S.%6N")
    export MEMORY=$(bc <<<"( $(grep MemTotal /proc/meminfo | awk '{print $2}') / ( 1024 ^ 2 ))")
    export THREADS=$(grep -c processor /proc/cpuinfo)
    export CHIPS=$(lscpu | grep "Socket(s)" | grep -Po "[0-9]{1,}")
    export CORES=$(grep -c processor /proc/cpuinfo)
    export CPU=$(lscpu | grep "Model name:" | awk -F ':' '{print $2}' | sed "s/^[ ]\{1,\}//g")
    export OS=$(grep PRETTY_NAME /etc/os-release | awk -F '=' '{print $2}' | tr -d '"')
    export KERNEL=$(uname -r)
    export JVM=$(java --version | tail -n 1)
    export GROUP_COUNT=${SPECJBB_GROUPS}
}

# ######################################
# Get default Tier threads multiplier, which is used for calculating specjbb.forkjoin.workers.Tier* threads automatically,
# *ONLY* when SPECJBB_TIER_1_THREADS, SPECJBB_TIER_2_THREADS and/or SPECJBB_TIER_3_THREADS are not set explicitly by the user
# Globals:
#   SPECJBB_DEFAULT_T1_T2_T3_MULTIPLIERS     csv string value if explicitly set by the user @example 7,0.25,1.20
#   PLATFORM                                 for targeted machine @example ICX
# Arguments:
#   None
# ######################################
getDefaultTierThreadMultiplier() {

    specjbb_default_t1_mult=7
    specjbb_default_t2_mult=0.25
    specjbb_default_t3_mult=1.20
    
    if [ -z "${SPECJBB_DEFAULT_T1_T2_T3_MULTIPLIERS}" ]; then
        memtotal=$(grep "MemTotal" /proc/meminfo | grep -Po "[0-9]+")
        memtotal_gb=$((memtotal / (1024 ** 2)))
        online_cpu_count=$(grep -c ^processor /proc/cpuinfo)
        
        if [[ "${PLATFORM}" =~ ^(SPR|ICX)$ ]]; then
            specjbb_default_t1_mult=8.50
            specjbb_default_t2_mult=0.23
            specjbb_default_t3_mult=1.00
        fi

        # Higher spec machines, need to reduce thread count on SPR platforms, if user has not specified explictly the tier multiplier
        if [[ $online_cpu_count -ge 224 && $memtotal_gb -gt 1000 && "${PLATFORM}" == "SPR" ]]; then
            specjbb_default_t1_mult=2
            specjbb_default_t2_mult=1
            specjbb_default_t3_mult=1
        fi

    else
        IFS=',' read -r specjbb_default_t1_mult specjbb_default_t2_mult specjbb_default_t3_mult < <(echo "${SPECJBB_DEFAULT_T1_T2_T3_MULTIPLIERS}")
    fi

    echo "${specjbb_default_t1_mult}|${specjbb_default_t2_mult}|${specjbb_default_t3_mult}"
}

# ######################################
# Get Heap value i.e Xmx|Xms|Xmn based on value configured by user and api value if over-ridden
# Globals:
#   None
# Arguments:
#   env_value   @values include SPECJBB_XMX|SPECJBB_XMS|SPECJBB_XMN
#   api_value   value with which to override env_value above
# ######################################
function getHeapValue(){
    env_value="$1"
    api_value="$2"

    if [[ -n "${env_value}" && -n "${api_value}" && "${env_value}" != "${api_value}" ]]; then
        echo -e "Configured Heap value:${env_value} 
        Is configured to be over-written by API: get_specjbb_backend_heap_sizes 
        with new value:${api_value}" >&2

        echo "${api_value}"
    elif [ -z "${env_value}" ]; then
        echo "${api_value}"
    else
        echo "${env_value}"
    fi
}

# ######################################
# Print log with timestamp
# Output:
# 	 Writes argument to stdout with timestamp
# ######################################
log() {
    printf "%s%b\"\n" "[$(date +%FT%T)] " "$1"
}

# Variables for export for environment substitution for generating template files @see specjbb.env.sh for defaults
export NUMA_NODES=$(lscpu | grep -P "NUMA node\(s\):" | grep -Po "[0-9]{1,}")
[ -z "$NUMA_NODES" ] && export NUMA_NODES=1

export SPECJBB_BACKEND_SURVIVOR_RATIO
export SPECJBB_CLIENT_POOL_SIZE
export SPECJBB_CUSTOMER_DRIVER_THREADS
export SPECJBB_CUSTOMER_DRIVER_THREADS_PROBE
export SPECJBB_CUSTOMER_DRIVER_THREADS_SATURATE
export SPECJBB_DURATION
export SPECJBB_LOADLEVEL_START
export SPECJBB_LOADLEVEL_STEP
export SPECJBB_PRESET_IR
export SPECJBB_WORKER_POOL_MAX
export SPECJBB_WORKER_POOL_MIN
export SPECJBB_RUN_TYPE
export SPECJBB_GROUPS

# Variables whose scope is current file only @see specjbb.env.sh for defaults
SPECJBB_CONTROLLER_HEAP_MEMORY=
SPECJBB_INJECTOR_HEAP_MEMORY=
SPECJBB_JAVA_PARAMETERS=
SPECJBB_INJECTOR_JAVA_PARAMETERS=
SPECJBB_CONTROLLER_JAVA_PARAMETERS=
SPECJBB_HUGE_PAGE_SIZE=
SPECJBB_RTSTART=
SPECJBB_USE_AVX=
SPECJBB_USE_NUMA_NODES=
SPECJBB_USE_HUGE_PAGES=
SPECJBB_PRINT_VARS=

CONFIG_RUNTIME_VARS=/tmp/runtime.vars

# --------------------- Read input argument(s) --specjbb_* ------------------------
while [[ $# -gt 0 ]]; do
    opt="$1"
    shift #expose next argument
    case "$opt" in
    "--") break 2 ;;
    "") break 2 ;;

    "--specjbb_backend_survivor_ratio="*)
        specjbb_backend_survivor_ratio="${opt#*=}"
        export SPECJBB_BACKEND_SURVIVOR_RATIO=${specjbb_backend_survivor_ratio:-${SPECJBB_BACKEND_SURVIVOR_RATIO}}
        ;;

    "--specjbb_client_pool_size="*)
        specjbb_client_pool_size="${opt#*=}"
        export SPECJBB_CLIENT_POOL_SIZE=${specjbb_client_pool_size:-${SPECJBB_CLIENT_POOL_SIZE}}
        ;;

    "--specjbb_controller_heap_memory="*)
        specjbb_controller_heap_memory=$(echo "${opt#*=}" | xargs)
        SPECJBB_CONTROLLER_HEAP_MEMORY=${specjbb_controller_heap_memory:-${SPECJBB_CONTROLLER_HEAP_MEMORY}}
        ;;

    "--specjbb_customer_driver_threads="*)
        specjbb_customer_driver_threads="${opt#*=}"
        export SPECJBB_CUSTOMER_DRIVER_THREADS=${specjbb_customer_driver_threads:-${SPECJBB_CUSTOMER_DRIVER_THREADS}}
        ;;

    "--specjbb_customer_driver_threads_probe="*)
        specjbb_customer_driver_threads_probe="${opt#*=}"
        export SPECJBB_CUSTOMER_DRIVER_THREADS_PROBE=${specjbb_customer_driver_threads_probe:-${SPECJBB_CUSTOMER_DRIVER_THREADS_PROBE}}
        ;;

    "--specjbb_customer_driver_threads_saturate="*)
        specjbb_customer_driver_threads_saturate="${opt#*=}"
        export SPECJBB_CUSTOMER_DRIVER_THREADS_SATURATE=${specjbb_customer_driver_threads_saturate:-${SPECJBB_CUSTOMER_DRIVER_THREADS_SATURATE}}
        ;;

    "--specjbb_duration="*)
        specjbb_duration="${opt#*=}"
        export SPECJBB_DURATION=${specjbb_duration:-${SPECJBB_DURATION}}
        ;;

    "--specjbb_gc_threads="*)
        specjbb_gc_threads="${opt#*=}"
        SPECJBB_GC_THREADS=${specjbb_gc_threads:-${SPECJBB_GC_THREADS}}
        ;;

    "--specjbb_groups="*)
        specjbb_groups="${opt#*=}"
        export SPECJBB_GROUPS=${specjbb_groups:-${SPECJBB_GROUPS}}
        ;;

    "--specjbb_injector_heap_memory="*)
        specjbb_injector_heap_memory=$(echo "${opt#*=}" | xargs)
        SPECJBB_INJECTOR_HEAP_MEMORY=${specjbb_injector_heap_memory:-${SPECJBB_INJECTOR_HEAP_MEMORY}}
        ;;

    "--specjbb_java_parameters="*)
        specjbb_java_parameters=$(echo "${opt#*=}" | xargs)
        SPECJBB_JAVA_PARAMETERS=${specjbb_java_parameters:-${SPECJBB_JAVA_PARAMETERS}}
        ;;

    "--specjbb_injector_java_parameters="*)
        specjbb_injector_java_parameters=$(echo "${opt#*=}" | xargs)
        SPECJBB_INJECTOR_JAVA_PARAMETERS=${specjbb_injector_java_parameters:-${SPECJBB_INJECTOR_JAVA_PARAMETERS}}
        ;;

    "--specjbb_controller_java_parameters="*)
        specjbb_controller_java_parameters=$(echo "${opt#*=}" | xargs)
        SPECJBB_CONTROLLER_JAVA_PARAMETERS=${specjbb_controller_java_parameters:-${SPECJBB_CONTROLLER_JAVA_PARAMETERS}}
        ;;

    "--specjbb_kitversion="*)
        specjbb_kitversion="${opt#*=}"
        export SPECJBB_KITVERSION=${specjbb_kitversion:-${SPECJBB_KITVERSION}}
        ;;

    "--specjbb_huge_page_size="*)
        specjbb_huge_page_size="${opt#*=}"
        SPECJBB_HUGE_PAGE_SIZE=${specjbb_huge_page_size:-${SPECJBB_HUGE_PAGE_SIZE}}
        ;;

    "--specjbb_loadlevel_start="*)
        specjbb_loadlevel_start="${opt#*=}"
        export SPECJBB_LOADLEVEL_START=${specjbb_loadlevel_start:-${SPECJBB_LOADLEVEL_START}}
        ;;

    "--specjbb_loadlevel_step="*)
        specjbb_loadlevel_step="${opt#*=}"
        export SPECJBB_LOADLEVEL_STEP=${specjbb_loadlevel_step:-${SPECJBB_LOADLEVEL_STEP}}
        ;;

    "--specjbb_mapreducer_pool_size="*)
        specjbb_mapreducer_pool_size="${opt#*=}"
        export SPECJBB_MAPREDUCER_POOL_SIZE=${specjbb_mapreducer_pool_size:-${SPECJBB_MAPREDUCER_POOL_SIZE}}
        ;;

    "--specjbb_preset_ir="*)
        specjbb_preset_ir="${opt#*=}"
        export SPECJBB_PRESET_IR=${specjbb_preset_ir:-${SPECJBB_PRESET_IR}}
        ;;

    "--specjbb_rtstart="*)
        specjbb_rtstart="${opt#*=}"
        SPECJBB_RTSTART=${specjbb_rtstart:-${SPECJBB_RTSTART}}
        ;;

    "--specjbb_run_type="*)
        specjbb_run_type="${opt#*=}"
        export SPECJBB_RUN_TYPE=${specjbb_run_type:-${SPECJBB_RUN_TYPE}}
        ;;

    "--specjbb_selector_runner_count="*)
        specjbb_selector_runner_count="${opt#*=}"
        export SPECJBB_SELECTOR_RUNNER_COUNT=${specjbb_selector_runner_count:-${SPECJBB_SELECTOR_RUNNER_COUNT}}
        ;;

    "--specjbb_tier_1_threads="*)
        specjbb_tier_1_threads="${opt#*=}"
        export SPECJBB_TIER_1_THREADS=${specjbb_tier_1_threads:-${SPECJBB_TIER_1_THREADS}}
        ;;

    "--specjbb_tier_2_threads="*)
        specjbb_tier_2_threads="${opt#*=}"
        export SPECJBB_TIER_2_THREADS=${specjbb_tier_2_threads:-${SPECJBB_TIER_2_THREADS}}
        ;;

    "--specjbb_tier_3_threads="*)
        specjbb_tier_3_threads="${opt#*=}"
        export SPECJBB_TIER_3_THREADS=${specjbb_tier_3_threads:-${SPECJBB_TIER_3_THREADS}}
        ;;

    "--specjbb_default_t1_t2_t3_multipliers="*)
        specjbb_default_t1_t2_t3_multipliers="${opt#*=}"
        export SPECJBB_DEFAULT_T1_T2_T3_MULTIPLIERS=${specjbb_default_t1_t2_t3_multipliers:-${SPECJBB_DEFAULT_T1_T2_T3_MULTIPLIERS}}
        ;;

    "--specjbb_worker_pool_max="*)
        specjbb_worker_pool_max="${opt#*=}"
        export SPECJBB_WORKER_POOL_MAX=${specjbb_worker_pool_max:-${SPECJBB_WORKER_POOL_MAX}}
        ;;

    "--specjbb_worker_pool_min="*)
        specjbb_worker_pool_min="${opt#*=}"
        export SPECJBB_WORKER_POOL_MIN=${specjbb_worker_pool_min:-${SPECJBB_WORKER_POOL_MIN}}
        ;;

    "--specjbb_use_huge_pages="*)
        specjbb_use_huge_pages="${opt#*=}"
        SPECJBB_USE_HUGE_PAGES=${specjbb_use_huge_pages:-${SPECJBB_USE_HUGE_PAGES}}
        ;;

    "--specjbb_use_avx="*)
        specjbb_use_avx="${opt#*=}"
        SPECJBB_USE_AVX=${specjbb_use_avx:-${SPECJBB_USE_AVX}}
        ;;

    "--specjbb_xmn="*)
        specjbb_xmn="${opt#*=}"
        SPECJBB_XMN=${specjbb_xmn:-${SPECJBB_XMN}}
        ;;

    "--specjbb_tune_option="*)
        specjbb_tune_option="${opt#*=}"
        SPECJBB_TUNE_OPTION=${specjbb_tune_option:-${SPECJBB_TUNE_OPTION}}
        ;;

    "--specjbb_xms="*)
        specjbb_xms="${opt#*=}"
        SPECJBB_XMS=${specjbb_xms:-${SPECJBB_XMS}}
        ;;

    "--specjbb_xmx="*)
        specjbb_xmx="${opt#*=}"
        SPECJBB_XMX=${specjbb_xmx:-${SPECJBB_XMX}}
        ;;

    "--specjbb_print_vars="*)
        specjbb_print_vars="${opt#*=}"
        SPECJBB_PRINT_VARS=${specjbb_print_vars:-${SPECJBB_PRINT_VARS}}
        ;;

    "--specjbb_work_dir="*)
        specjbb_work_dir="${opt#*=}"
        SPECJBB_WORK_DIR=${specjbb_work_dir:-${SPECJBB_WORK_DIR}}
        ;;

    "--specjbb_log_dir="*)
        specjbb_log_dir="${opt#*=}"
        SPECJBB_LOG_DIR=${specjbb_log_dir:-${SPECJBB_LOG_DIR}}
        ;;

    "--config_runtime_vars="*)
        config_runtime_vars="${opt#*=}"
        CONFIG_RUNTIME_VARS=${config_runtime_vars:-${CONFIG_RUNTIME_VARS}}
        ;;

    "--specjbb_use_numa_nodes="*)
        specjbb_use_numa_nodes="${opt#*=}"
        export SPECJBB_USE_NUMA_NODES=${specjbb_use_numa_nodes:-${SPECJBB_USE_NUMA_NODES}}
        ;;

    "--specjbb_rt_curve_warmup_step="*)
        specjbb_rt_curve_warmup_step="${opt#*=}"
        SPECJBB_RT_CURVE_WARMUP_STEP=${specjbb_rt_curve_warmup_step:-${SPECJBB_RT_CURVE_WARMUP_STEP}}
        ;;

    "--specjbb_sm_replenish_localpercent="*)
        specjbb_sm_replenish_localpercent="${opt#*=}"
        SPECJBB_SM_REPLENISH_LOCALPERCENT=${specjbb_sm_replenish_localpercent:-${SPECJBB_SM_REPLENISH_LOCALPERCENT}}
        ;;

    "--specjbb_use_transparent_huge_pages="*)
        specjbb_use_transparent_huge_pages="${opt#*=}"
        export SPECJBB_USE_TRANSPARENT_HUGE_PAGES=${specjbb_use_transparent_huge_pages:-${SPECJBB_USE_TRANSPARENT_HUGE_PAGES}}
        ;;

    "--specjbb_workload_config="*)
        specjbb_workload_config="${opt#*=}"
        SPECJBB_WORKLOAD_CONFIG=${specjbb_workload_config:-${SPECJBB_WORKLOAD_CONFIG}}
        ;;
    *)
        usage
        echo >&2 "Invalid option: [$opt]"
        echo "Input Args: $*"
        exit 1
        ;;

    esac
done
