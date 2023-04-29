#!/bin/bash -e
# ###########################
#
# This file show the list of parameters/options that can be modified when running the specjbb workload
#
#   for @example to change the [SPECJBB_CLIENT_POOL_SIZE] parameter to 300 (currently default's to 210)
#   set the variable to the value you want by using export(ing) it to the value you wish. This example is 300
#     1) SPECJBB_CLIENT_POOL_SIZE=300
#     then run the test
#     2) ctest -V -R <test_case_name>
#
#   @notes
#     - certain values are calculated at run time, if not explicitly set like in the @example above e.g [SPECJBB_TIER_1_THREADS] @see for @formulae
#     - the rest of the values are explicitly set here, if not overridden by the user like in the @example above
#     - you can override as many variables as you wish in the list below
#

# #############
#  Survivor Ratio used in Backend JVM
#    Defaults to 28 if not specified. (default: '28') (an integer)
#    @Notes: Used with multi_mode only
# #############
SPECJBB_BACKEND_SURVIVOR_RATIO=${SPECJBB_BACKEND_SURVIVOR_RATIO}

# #############
#  Client pool size
#    (default: '210') (an integer)
#    @Notes: Used with multi_mode only
# #############
SPECJBB_CLIENT_POOL_SIZE=${SPECJBB_CLIENT_POOL_SIZE:-210}

# #############
#  Heap memory settings per controller JVM
#    Defaults to \"-Xms2g -Xmx2g -Xmn1536m\" if not specified. Note that the memory units are required. (default: '-Xms2g -Xmx2g -Xmn1536m')
#    @Notes: Used with multi_mode only
# #############
SPECJBB_CONTROLLER_HEAP_MEMORY=${SPECJBB_CONTROLLER_HEAP_MEMORY:-"-Xms2g -Xmx2g -Xmn1536m"}

# #############
#  Customer Driver Threads
#    (default: '64') (an integer)
#    @Notes: Used with multi_mode only
# #############
SPECJBB_CUSTOMER_DRIVER_THREADS=${SPECJBB_CUSTOMER_DRIVER_THREADS:-64}

# #############
#  Customer Driver Threads Probe
#    (default: '64') (an integer)
#    @Notes: Used with multi_mode only
# #############
SPECJBB_CUSTOMER_DRIVER_THREADS_PROBE=${SPECJBB_CUSTOMER_DRIVER_THREADS_PROBE:-64}

# #############
#  Customer Driver Threads Saturate
#    (default: '64') (an integer)
#    @Notes: Used with multi_mode only
# #############
SPECJBB_CUSTOMER_DRIVER_THREADS_SATURATE=${SPECJBB_CUSTOMER_DRIVER_THREADS_SATURATE:-64}

# #############
#  specjbb duration for PRESET and LOADLEVEL (default: '600') (an integer)
# #############
SPECJBB_DURATION=${SPECJBB_DURATION:-600}

# #############
#  SPECjbb garbage collector threads per group
#    Defaults to @formulae (total vCPUs / number of groups) if not specified, for all machines except ....
#    Defaults to @formulae (Core(s) per socket / number of groups) for SPR and ICX machines
#    @Notes: Used with multi_mode only
# #############
SPECJBB_GC_THREADS=${SPECJBB_GC_THREADS}

# #############
#  Number of SPECjbb groups to create
#   Defaults to number of NUMA nodes if not specified. (an integer)
# #############
SPECJBB_GROUPS=${SPECJBB_GROUPS}

# #############
#  Injector memory settings per injector JVM
#    Defaults to \"-Xms2g -Xmx2g -Xmn1536m\" if not specified for all platforms expect SRP machines.  Note that the memory units are required.
#    @Notes: Used with multi_mode only
# #############
SPECJBB_INJECTOR_HEAP_MEMORY=${SPECJBB_INJECTOR_HEAP_MEMORY:-"-Xms2g -Xmx2g -Xmn1536m"}

# #############
#  string of any extra Java parameters that need to be passed to Backend JVM (default: '')
#    @Notes: Used with multi_mode only
# #############
SPECJBB_JAVA_PARAMETERS=${SPECJBB_JAVA_PARAMETERS}

# #############
#  Large page size in m (megabyte) or G (gigabytes), when used
#    (default: '2m') if empty uses the default large page size for the environment as the maximum large page size.
#    @Notes: Used with multi_mode only
# #############
SPECJBB_HUGE_PAGE_SIZE=${SPECJBB_HUGE_PAGE_SIZE}
# NOTE: default value was moved here from generate_multi_mode_config.sh

# #############
#  Controls the % of max RT when the load level stage should start
#    This is particularly helpful with telemetry analysis as different values have to be used to capture critical jOPS / max jOPS thresholds. Use 0.5-0.55 for critical and 0.95 for max. (default: '0.95') (a number in the range [0.0, 1.0])
#    @Notes: Used with multi_mode only
# #############
SPECJBB_LOADLEVEL_START=${SPECJBB_LOADLEVEL_START:-0.95}

# #############
#  Controls the % step of load level stage
#    (default: '1') (an integer)
#    @Notes: Used with multi_mode only
# #############
SPECJBB_LOADLEVEL_STEP=${SPECJBB_LOADLEVEL_STEP:-1}

# #############
#  Map reducer pool size
#    Defaults to @formulae (total vCPUs / number of groups) if not specified. (an integer)
#    @Notes: Used with multi_mode only
# #############
SPECJBB_MAPREDUCER_POOL_SIZE=${SPECJBB_MAPREDUCER_POOL_SIZE}

# #############
#  specjbb preset Injection Rate when SPECJBB_RUN_TYPE=PRESET
#   (default: '1000') (an integer)
# #############
SPECJBB_PRESET_IR=${SPECJBB_PRESET_IR:-1000}

# #############
#  rt start point percentage (default: '0') (an integer)
#    @Notes: Used with multi_mode only
# #############
SPECJBB_RTSTART=${SPECJBB_RTSTART:-0}

# #############
#  <HBIR_RT|HBIR_RT_LOADLEVELS|PRESET>: specjbb run-type like HBIR_RT, LOADLEVEL, PRESET (default: 'HBIR_RT')
# #############
SPECJBB_RUN_TYPE=${SPECJBB_RUN_TYPE:-HBIR_RT}

# #############
#  Selector runner count
#    Defaults to number of groups if not specific (an integer)
#    @Notes: Used with multi_mode only
# #############
SPECJBB_SELECTOR_RUNNER_COUNT=${SPECJBB_SELECTOR_RUNNER_COUNT}

# #############
#  Number of tier 1 threads per group @see specjbb config specjbb.forkjoin.workers.Tier1
#    Defaults to @formulae (${SPECJBB_DEFAULT_T1_T2_T3_MULTIPLIERS}[col_1] * (# cores / SPECJBB_GROUPS)) if not specified for all machines except ....
#    Defaults to @formulae (${SPECJBB_DEFAULT_T1_T2_T3_MULTIPLIERS}[col_1] * ${SPECJBB_GC_THREADS}) when an SPR or ICX machine
#    @Notes: Used with multi_mode only (an integer)
# #############
SPECJBB_TIER_1_THREADS=${SPECJBB_TIER_1_THREADS}

# #############
#  Number of tier 2 threads per group @see specjbb config specjbb.forkjoin.workers.Tier2
#    Defaults to @formulae (${SPECJBB_DEFAULT_T1_T2_T3_MULTIPLIERS}[col_2] * (# cores / SPECJBB_GROUPS)) if not specified for all machines except ....
#    Defaults to @formulae (${SPECJBB_DEFAULT_T1_T2_T3_MULTIPLIERS}[col_2] * ${SPECJBB_GC_THREADS}) when an SPR or ICX machine
#    @Notes: Used with multi_mode only (an integer)
# #############
SPECJBB_TIER_2_THREADS=${SPECJBB_TIER_2_THREADS}

# #############
#  Number of tier 3 threads per group @see specjbb config specjbb.forkjoin.workers.Tier3
#    Defaults to @formulae (${SPECJBB_DEFAULT_T1_T2_T3_MULTIPLIERS}[col_3] * (# cores / SPECJBB_GROUPS)) if not specified for all machines except ....
#    Defaults to @formulae (${SPECJBB_DEFAULT_T1_T2_T3_MULTIPLIERS}[col_3] * ${SPECJBB_GC_THREADS}) when an SPR or ICX machine
#    @Notes: Used with multi_mode only (an integer)
# #############
SPECJBB_TIER_3_THREADS=${SPECJBB_TIER_3_THREADS}

# #############
#  Used for calculating specjbb.forkjoin.workers.Tier* threads automatically, based on underlying machine. *ONLY* when SPECJBB_TIER_1_THREADS, SPECJBB_TIER_2_THREADS and/or SPECJBB_TIER_3_THREADS above are not set explicitly by the user
#    @note This value is a csv string @example SPECJBB_DEFAULT_T1_T2_T3_MULTIPLIERS="7,0.25,1.2"
#          with each [column] in the csv string representing the automatic default thread multiplier i.e Tier1ThreadMultiplier=7, Tier2ThreadMultiplier=0.25, Tier3ThreadMultiplier=1.2 from above @example
#
#    Defaults to SPECJBB_DEFAULT_T1_T2_T3_MULTIPLIERS="7,0.25,1.2" for all machines except ...
#                SPECJBB_DEFAULT_T1_T2_T3_MULTIPLIERS="8.50,0.23,1.00" when an ICX or SPR machine
#                SPECJBB_DEFAULT_T1_T2_T3_MULTIPLIERS="6.5,2,1" for Zulu JDK based test cases
#
#    @formulae used to automatically calculate  SPECJBB_TIER_1_THREADS=( ${SPECJBB_DEFAULT_T1_T2_T3_MULTIPLIERS}[column_1] * (total vCPUs / number of groups) ) for all machines except
#    @formulae used to automatically calculate  SPECJBB_TIER_1_THREADS=( ${SPECJBB_DEFAULT_T1_T2_T3_MULTIPLIERS}[column_1] * ${SPECJBB_GC_THREADS} ) when an ICX or SPR machine
#
#    @Notes: Same applies for SPECJBB_TIER_1_THREADS and SPECJBB_TIER_2_THREADS, just substitute the appropriate column and variable. Used with multi_mode only
#
# #############
SPECJBB_DEFAULT_T1_T2_T3_MULTIPLIERS="${SPECJBB_DEFAULT_T1_T2_T3_MULTIPLIERS}"

# #############
#
#   (default: 0.1)
# #############
export SPECJBB_RT_CURVE_WARMUP_STEP=${SPECJBB_RT_CURVE_WARMUP_STEP:-0.1}

# #############
#
#   (default: 95)
# #############
export SPECJBB_SM_REPLENISH_LOCALPERCENT=${SPECJBB_SM_REPLENISH_LOCALPERCENT:-95}

# #############
#  If enabled, uses latest available AVX version
#    (default: 'true')
#    @Notes: Used with multi_mode only
# #############
SPECJBB_USE_AVX=${SPECJBB_USE_AVX:-true}

# #############
#  If enabled, large pages are used
#    (default: 'false')
#    @Notes: Used with multi_mode only
# #############
SPECJBB_USE_HUGE_PAGES=${SPECJBB_USE_HUGE_PAGES:-false}

# #############
#  Worker pool max
#    (default: '90') (an integer)
#    @Notes: Used with multi_mode only
# #############
SPECJBB_WORKER_POOL_MAX=${SPECJBB_WORKER_POOL_MAX:-90}

# #############
#  Worker pool min
#    (default: '1') (an integer)
#    @Notes: Used with multi_mode only
# #############
SPECJBB_WORKER_POOL_MIN=${SPECJBB_WORKER_POOL_MIN:-1}

# #############
#  Performance tune grouping option for BE service. Whether to tune the BE service at "regular" or "max" level if SPECJBB_XMN,SPECJBB_XMX,SPECJBB_XMS is not set by the user
#    Defaults to regular
#    @Notes: Used with multi_mode only
# #############
SPECJBB_TUNE_OPTION=${SPECJBB_TUNE_OPTION:-regular}

# #############
#  Max Heap size per backend JVM
#    If not set by user and SPECJBB_TUNE_OPTION=regular, @defaults to 4g
#    If not set by user and SPECJBB_TUNE_OPTION=max, uses @formulae (1 * (cores / SPECJBB_GROUPS))g
#    If set by user please note that the memory unit is required (m|g|k)
#    @Notes: Used with multi_mode only
# #############
SPECJBB_XMX=${SPECJBB_XMX}

# #############
#  Min Heap size per backend JVM
#    If not set by user @defaults to value of ${SPECJBB_XMX}
#    If set by user please note that the memory unit is required (m|g|k)
#    @Notes: Used with multi_mode only
# #############
SPECJBB_XMS=${SPECJBB_XMS}

# #############
#  Nursery size per backend JVM
#    If not set by user @defaults to value of ${SPECJBB_XMX} - 2
#    If set by user please note that the memory unit is required (m|g|k)
#    @Notes: Used with multi_mode only
# #############
SPECJBB_XMN=${SPECJBB_XMN}

# #############
# Print generated Variables. Default false
# #############
SPECJBB_PRINT_VARS=${SPECJBB_PRINT_VARS:-false}

# #############
# Set minimum huge page memory needed for workload to run
# To check limits on underlying machine @see
#    /sys/kernel/mm/hugepages/hugepages-*/nr_hugepages or
#    kubectl describe node <worker> | grep "hugepages-.*"
#    @Notes:
#       This variable is used to setup hugepages automatically when used with any backend i.e terraform, kubernetes, @expect docker, which when docker has to be manually configured by the user
#       HUGEPAGE_SIZE*MEMORY_NEEDED
#       @example huge page size of 1Gi that requires a total 32Gi of memory
#       HUGEPAGE_MEMORY_NUM=1Gi*32Gi
#       Rule of thumb @formulae for (amount of memory needed): SPECJBB_XMX*SPECJBB_GROUPS+2*SPECJBB_GROUPS+2+2 @see README.md notice(s)
# #############
HUGEPAGE_MEMORY_NUM=${HUGEPAGE_MEMORY_NUM:-2Mb*16Gi}

# #############
# If the target platform/machine is to be run with kuberentes (instead of docker) and Huge pages is configured, then you also need to specify the number of
# cpu units, that you are requesting for that machine
#    @Notes:
#       kubernetes specific setting
#       1 CPU unit is equivalent to 1 physical CPU core, or 1 virtual core, depending on whether the node is a physical host or a virtual machine running inside a physical machine
# #############
HUGEPAGE_KB8_CPU_UNITS=${HUGEPAGE_KB8_CPU_UNITS:-8}

# #############
# Set to true by default to use numa nodes
# If numa nodes are not required, can be set to false
#     @Note:If set to false, it is recommended to set value of SPECJBB_GROUPS to 1.
# #############
SPECJBB_USE_NUMA_NODES=${SPECJBB_USE_NUMA_NODES:-true}

# #############
#  JDK Version to be used with specjbb
#    Defaults to 17.0.1 for OpenJDK
# #############
JDK_PACKAGE=${JDK_PACKAGE}
