#!/bin/bash

# ######################################
# Script that configure's Specjbb and JVM runtime options, from user input and underlying containers node capabilities
# Globals:
#   None
# Arguments:
#   @see usage()
# Example:
#  ./generate_multi_mode_config.sh --specjbb_client_pool_size=100 --specjbb_...
# Return:
# 	0 if successfully generated configuration, non-zero otherwise.
# ######################################

# ######################################
# Append JVM Options to Specjbb services
# Globals:
#   JVM_OPTS_TI_TEMPLATE
#   JVM_OPTS_CT_TEMPLATE
#   JVM_OPTS_BE_TEMPLATE
# Arguments:
#   $1 Extra JVM opts for each service
# ######################################
appendJVM_OPTS() {
    append_opts=$1
    JVM_OPTS_TI_TEMPLATE="${JVM_OPTS_TI_TEMPLATE} ${append_opts}"
    JVM_OPTS_CT_TEMPLATE="${JVM_OPTS_CT_TEMPLATE} ${append_opts}"
    JVM_OPTS_BE_TEMPLATE="${JVM_OPTS_BE_TEMPLATE} ${append_opts}"
}

# ######################################
# Generates the JVM Options for each of the Specjbb services
# Globals:
#   SPECJBB_INJECTOR_HEAP_MEMORY
#   SPECJBB_CONTROLLER_HEAP_MEMORY
#   SPECJBB_XMS
#   SPECJBB_XMX
#   SPECJBB_XMN
#   SPECJBB_GC_THREADS
#   SPECJBB_BACKEND_SURVIVOR_RATIO
#   SPECJBB_JAVA_PARAMETERS
#   SPECJBB_INJECTOR_JAVA_PARAMETERS
#   SPECJBB_CONTROLLER_JAVA_PARAMETERS
#   SPECJBB_WORKLOAD_CONFIG
# Arguments:
#   None
# Return:
# 	 Pipe delimited JVM options for TI|CT|BE
# ######################################
setJVM_OPTS() {

    # Load JVM options template from config->calculate.sh custom configuration
    IFS='|' read -r jvm_opts_ti_template jvm_opts_ct_template jvm_opts_be_template < <(get_jvm_options)
    if [[ -z ${jvm_opts_ti_template} && -z ${jvm_opts_ct_template} && -z ${jvm_opts_be_template} ]]; then

        # if get_jvm_options returns empty, use default JVM configuration
        gc_version="-XX:+UseParallelOldGC"
        if [[ $(java -version 2>&1 | grep -Po "version.*" | awk '{print $2}' | grep -Po "[0-9]{1,}" | head -n 1) -ge 14 ]]; then
            gc_version="-XX:+UseParallelGC"
        fi
        jvm_opts_ti_template="-server ${SPECJBB_INJECTOR_HEAP_MEMORY} ${gc_version} -XX:ParallelGCThreads=2"
        jvm_opts_ct_template="-server ${SPECJBB_CONTROLLER_HEAP_MEMORY} ${gc_version} -XX:ParallelGCThreads=2"
        jvm_opts_be_template=$(echo -e "-Xms${SPECJBB_XMS} -Xmx${SPECJBB_XMX} -Xmn${SPECJBB_XMN} ${gc_version} -XX:ParallelGCThreads=${SPECJBB_GC_THREADS} 
            -showversion -XX:+AlwaysPreTouch -XX:-UseAdaptiveSizePolicy
            -XX:SurvivorRatio=${SPECJBB_BACKEND_SURVIVOR_RATIO} -XX:MaxTenuringThreshold=15 -XX:InlineSmallCode=10k -verbose:gc 
            -XX:-UseCountedLoopSafepoints -XX:LoopUnrollLimit=20 -XX:MaxGCPauseMillis=500 
            -XX:AdaptiveSizeMajorGCDecayTimeScale=12 -XX:AdaptiveSizeDecrementScaleFactor=2 
            -server -XX:TargetSurvivorRatio=95 -XX:AllocatePrefetchLines=3 
            -XX:AllocateInstancePrefetchLines=2 -XX:AllocatePrefetchStepSize=128 
            -XX:AllocatePrefetchDistance=384 -XX:-PrintGCDetails ${SPECJBB_JAVA_PARAMETERS}" | tr -d "\n" | sed "s/[ ]\{2,\}/ /g")
    fi

    echo "$jvm_opts_ti_template|$jvm_opts_ct_template|$jvm_opts_be_template"
}

# ######################################
# Generates specjbb2015 and template-M configuration with environment substitution
# Globals:
#   BACKEND_CMDLINE
#   CHIPS
#   CONTROLLER_CMDLINE
#   CORES
#   CPU
#   DATE
#   GROUP_COUNT
#   JVM
#   KERNEL
#   MEMORY
#   OS
#   SPECJBB_CLIENT_POOL_SIZE
#   SPECJBB_CUSTOMER_DRIVER_THREADS
#   SPECJBB_CUSTOMER_DRIVER_THREADS_PROBE
#   SPECJBB_CUSTOMER_DRIVER_THREADS_SATURATE
#   SPECJBB_DURATION
#   SPECJBB_GROUP_COUNT
#   SPECJBB_LOADLEVEL_START
#   SPECJBB_LOADLEVEL_STEP
#   SPECJBB_MAPREDUCER_POOL_SIZE
#   SPECJBB_PRESET_IR
#   SPECJBB_RT_CURVE_START
#   SPECJBB_RUN_TYPE
#   SPECJBB_SELECTOR_RUNNER_COUNT
#   SPECJBB_TIER_1_THREADS
#   SPECJBB_TIER_2_THREADS
#   SPECJBB_TIER_3_THREADS
#   SPECJBB_WORKER_POOL_MAX
#   SPECJBB_WORKER_POOL_MIN
#   THREADS
#   TX_CMDLINE
# Arguments:
#   $1 resultant template-M.raw location
#   $2 resultant specjbb2015.props location
# Return:
# 	0 if success, non-zero otherwise.
# ######################################
generateConfig() {
    template_m_file=$1
    specjbb2015_file=$2

    # get machine specs for injecting into configuration(s)
    getMachineDetails

    # inject templates into configurations
    export TX_CMDLINE=${JVM_OPTS_TI_TEMPLATE}
    export BACKEND_CMDLINE=${JVM_OPTS_BE_TEMPLATE}
    export CONTROLLER_CMDLINE=${JVM_OPTS_CT_TEMPLATE}

    # replace the {{variables}} with ${VARIABLE} for environment substitution and output to configuration location(s)
    CURRENT_DIR=$(dirname -- "$(readlink -f -- "$0")")
    mkdir -p "$(dirname "$template_m_file")"
    sed -e "s/\([{]\{2,\}\)\([^}}]*\)\([}]\{1\}\)/$\{\U\2/g" "$CURRENT_DIR"/../templates/template-M.raw.j2 | envsubst >"$template_m_file"
    chmod 777 "$template_m_file"
    log "Generated ${template_m_file}"

    SPECJBB_DURATION=$(bc <<<"${SPECJBB_DURATION} * 100")
    mkdir -p "$(dirname "$specjbb2015_file")"
    sed -e "s/\([{]\{2,\}\)\([^}}]*\)\([}]\{1\}\)/$\{\U\2/g" "$CURRENT_DIR"/../templates/specjbb2015.props.js | envsubst >"$specjbb2015_file"
    chmod 777 "$specjbb2015_file"
    SPECJBB_DURATION=$(bc <<<"${SPECJBB_DURATION} / 100")
    log "Generated ${specjbb2015_file}"

    return 0
}

# --------------------- Tuning default(s) ------------------------
CURRENT_DIR=$(dirname -- "$(readlink -f -- "$0")")

. $CURRENT_DIR/parse_arguments.sh "$@"

# ----------------------- main----------------------------

if [ "${SPECJBB_USE_NUMA_NODES}" == false ]; then
    NUMA_NODES=0
fi

log "Running .... $(basename "$0")"

# Load configuration interface
workload_configuration=$(echo ${SPECJBB_WORKLOAD_CONFIG} | cut -d_ -f3)
. ${USER_WORK_DIR}/configs/${workload_configuration}/calculate.sh

# Tune defaults that require calculation based on underlying machine's available resources
[ "${SPECJBB_PRINT_VARS}" == "true" ] && printVariables >/tmp/input.vars

# Get specjbb groups from calculate.sh interface
export SPECJBB_GROUPS=$(get_specjbb_groups)
export SPECJBB_GROUP_COUNT=${SPECJBB_GROUPS}
export SPECJBB_RT_CURVE_START=$(bc <<<"${SPECJBB_RTSTART} / 100")

cpus_per_group=$((NUM_CPUS / SPECJBB_GROUPS))
[ -z "${SPECJBB_MAPREDUCER_POOL_SIZE}" ] && export SPECJBB_MAPREDUCER_POOL_SIZE=${cpus_per_group}
[ -z "${SPECJBB_SELECTOR_RUNNER_COUNT}" ] && export SPECJBB_SELECTOR_RUNNER_COUNT=${SPECJBB_GROUPS}

SPECJBB_GC_THREADS=$(get_specjbb_gc_threads "${PLATFORM}" "${SPECJBB_GC_THREADS}")

log "Calculating Threads for ${PLATFORM}-${workload_configuration},Specjbb_GC_Threads=${SPECJBB_GC_THREADS},Specjbb_groups=${SPECJBB_GROUPS},Cores/socket=$(lscpu | grep "Core(s) per socket:" | awk -F ':' '{print $2}' | grep -Po '[0-9]+'),VCpus=$(grep -c ^processor /proc/cpuinfo)"
IFS='|' read -r tier_1_threads tier_2_threads tier_3_threads < <(get_specjbb_tier_threads)
if [[ -z ${tier_1_threads} && -z ${tier_2_threads} && -z ${tier_3_threads} ]]; then

    IFS='|' read -r specjbb_default_t1_mult specjbb_default_t2_mult specjbb_default_t3_mult < <(getDefaultTierThreadMultiplier)
    log "Using platform specific calculations"

    # If tier_x threads are not set in configuration, use the following to calculate
    if [[ "${PLATFORM}" =~ ^(ICX)$ ]]; then

        tier_1_threads=$(printf '%.0f' "$(bc <<<"${specjbb_default_t1_mult} * ${SPECJBB_GC_THREADS}")")
        tier_2_threads=$(printf '%.0f' "$(bc <<<"(!(${SPECJBB_GC_THREADS} - 1)) + (${specjbb_default_t2_mult} * ${SPECJBB_GC_THREADS})")")
        tier_3_threads=$(printf '%.0f' "$(bc <<<"${specjbb_default_t3_mult} * ${SPECJBB_GC_THREADS}")")

    elif [[ "${PLATFORM}" =~ ^(SPR)$ ]]; then

        tier_1_threads=$(printf '%.0f' "$(bc <<<"${specjbb_default_t1_mult} * ${SPECJBB_GC_THREADS}")")
        tier_2_threads=$(printf '%.0f' "$(bc <<<"(!(${SPECJBB_GC_THREADS} - 1)) + (${specjbb_default_t2_mult} * ${SPECJBB_GC_THREADS})")")
        tier_3_threads=$(printf '%.0f' "$(bc <<<"${specjbb_default_t3_mult} * ${SPECJBB_GC_THREADS}")")

    else

        tier_1_threads=$(printf '%.0f' "$(bc <<<"${specjbb_default_t1_mult} * ${SPECJBB_GC_THREADS}")")
        tier_2_threads=$(printf '%.0f' "$(bc <<<"${specjbb_default_t2_mult} * ${SPECJBB_GC_THREADS}")")
        if [ "$tier_2_threads" == 0 ]; then
            tier_2_threads=1
        fi

        tier_3_threads=$(printf '%.0f' "$(bc <<<"${specjbb_default_t3_mult} * ${SPECJBB_GC_THREADS}")")
    fi
fi

# Export for injecting into template configuration
export SPECJBB_TIER_1_THREADS=${SPECJBB_TIER_1_THREADS:-$tier_1_threads}
export SPECJBB_TIER_2_THREADS=${SPECJBB_TIER_2_THREADS:-$tier_2_threads}
export SPECJBB_TIER_3_THREADS=${SPECJBB_TIER_3_THREADS:-$tier_3_threads}

log "Tier Threads: T1=$SPECJBB_TIER_1_THREADS, T2=$SPECJBB_TIER_2_THREADS, T3=$SPECJBB_TIER_3_THREADS, GC Threads:${SPECJBB_GC_THREADS}"

if [[ "${SPECJBB_HUGE_PAGE_SIZE}" == "1G" && "${SPECJBB_BACKEND_SURVIVOR_RATIO}" -ge $(echo "$SPECJBB_XMX" | grep -Po "[0-9]+") ]]; then
    printf "%s\n" "Warning, survivor ratio is greater than heap size. OpenJDK does not currently support this" >&2
fi

# Set base line memory for xmn,xms,xmx
IFS='|' read -r specjbb_xmx specjbb_xms specjbb_xmn < <(get_specjbb_backend_heap_sizes ${cpus_per_group})
SPECJBB_XMX=$(getHeapValue "${SPECJBB_XMX}" "${specjbb_xmx}")
SPECJBB_XMS=$(getHeapValue "${SPECJBB_XMS}" "${specjbb_xms}")
SPECJBB_XMN=$(getHeapValue "${SPECJBB_XMN}" "${specjbb_xmn}")

# Final run time Options for TI/CT/BE services
IFS='|' read -r JVM_OPTS_TI_TEMPLATE JVM_OPTS_CT_TEMPLATE JVM_OPTS_BE_TEMPLATE < <(setJVM_OPTS)

# Extra tuning if avx and large pages are requested to be used
has_avx_instruction_set=$([ "$(grep -Po avx /proc/cpuinfo | sort | uniq | wc -l)" = 0 ] && echo false || echo true)
if [[ "${SPECJBB_USE_AVX}" = true && ${has_avx_instruction_set} = false ]]; then
    log "Machine does not have AVX instruction set. Removing option from JVM_OPTS"
else
    [[ "${SPECJBB_USE_AVX}" == "true" ]] && appendJVM_OPTS "-XX:UseAVX=0"
fi

[[ "${SPECJBB_USE_HUGE_PAGES}" == "true" ]] && appendJVM_OPTS "-XX:+UseLargePages"
[[ "${SPECJBB_USE_TRANSPARENT_HUGE_PAGES}" == "true" ]] && appendJVM_OPTS "-XX:+UseTransparentHugePages"
[[ "${SPECJBB_USE_HUGE_PAGES}" == "true" && ${SPECJBB_HUGE_PAGE_SIZE} ]] && appendJVM_OPTS "-XX:LargePageSizeInBytes=${SPECJBB_HUGE_PAGE_SIZE}"

# Generate config files based on the variables set above
generateConfig "${SPECJBB_WORK_DIR}/${SPECJBB_KITVERSION}/config/template-M.raw" \
    "${SPECJBB_WORK_DIR}/${SPECJBB_KITVERSION}/config/specjbb2015.props"

# --------------------- print variables ------------------------
CONFIG_RESULT=$?

# Print Variables (before and after)
if [[ "${SPECJBB_PRINT_VARS}" == "true" ]]; then
    log "Printing variables [Before] and [After] configuration"
    printVariables >/tmp/output.vars
    paste /tmp/input.vars /tmp/output.vars | pr -t -e80
fi

# -------------- generate runtime configuration -----------------
if [[ $CONFIG_RESULT == 0 ]]; then
    # Generate runtime variables file
    rm -f "$CONFIG_RUNTIME_VARS"
    mkdir -p "${SPECJBB_LOG_DIR}"
    for var in $(printenv | grep -P "NUMA_NODES|SPECJBB_GROUPS|SPECJBB_KITVERSION|SPECJBB_LOG_DIR|SPECJBB_RUN_TYPE|SPECJBB_WORK_DIR|TI_JVM_COUNT"); do
        echo "export $var" >>"$CONFIG_RUNTIME_VARS"
    done

    for var in ${!JVM_OPTS@}; do
        printf "%s%b\"\n" "export $var=\"" "${!var}" >>"$CONFIG_RUNTIME_VARS"
    done
fi

exit $CONFIG_RESULT
