#!/bin/bash

# ######################################
# Script that configure's Specjbb and JVM runtime options, from user input and underlying containers node capabilities
# Globals:
#   None
# Arguments:
#   @see usage()
# Example:
#  ./generate_composite_config.sh --specjbb_client_pool_size=100 --specjbb_...
# Return:
# 	0 if successfully generated configuration, non-zero otherwise.
# ######################################

# ######################################
# Tune Memory based on what resources underlying OS
# Globals:
#   SPECJBB_MEMORY_PER_CORE
# Arguments:
#   $1 Number of groups in underlying os (default(s) to number NUMA nodes)
# ######################################
tuneMax() {
    cpus_per_group=$1
    baseline_memory=$((cpus_per_group * SPECJBB_MEMORY_PER_CORE))

    # Adjusts memory sizes between 32GB and 48GB as these are problematic due to Java Compressed OOPS.
    if (((baseline_memory >= 32) && (baseline_memory <= 48))); then
        baseline_memory=31
    fi

    calculated_xmn=$((baseline_memory - 2))
    if [[ ${calculated_xmn} -le 1 ]]; then
        calculated_xmn=1
    fi

    echo "${baseline_memory}g|${baseline_memory}g|${calculated_xmn}g"
}

# ######################################
# Extract heap value in Mb based on input configuration
# Globals:
#   None
# Arguments:
#   $1 extact_key             @example Xms|Xmn|Xmx
#   $2 heap_configuration     @example -Xms2g -Xmx2g -Xmn1536m
# ######################################
extract_heap_configuration_in_mb() {
    extract_key="$1"
    heap_configuration="$2"

    extracted_key=$(echo "$heap_configuration" | grep -Po "${extract_key}[^ ]+")
    extracted_key_value=$(echo "$extracted_key" | grep -Po "[0-9]+")
    extracted_key_metric=$(echo "$extracted_key" | grep -Po "(m|M|g|G)$")

    if [[ "${extracted_key_metric}" =~ (g|G) ]]; then
        echo $((extracted_key_value * 1024))
    elif [[ ${extracted_key_metric} =~ (m|M) ]]; then
        echo "$extracted_key_value"
    else
        echo >&2 "Unsupported heap metric: $extracted_key_metric input:$2"
        exit 1
    fi
}

# ######################################
# Calculate total memory for heap, key
# Globals:
#   SPECJBB_INJECTOR_HEAP_MEMORY       @example -Xms2g -Xmx2g -Xmn1536m
#   SPECJBB_CONTROLLER_HEAP_MEMORY     @example -Xms2g -Xmx2g -Xmn1536m
#   SPECJBB_XMS                        @example 2g
#   SPECJBB_XMX                        @example 2g
#   SPECJBB_XMN                        @example 1536m
#   SPECJBB_GROUPS                     @example 2
# Arguments:
#   $1 key                             @example (Xmx|Xmn|Xms)
# ######################################
calculate_total_heap_memory_in_mb() {
    key=$1

    # Input configured->Injector heap*groups
    result=$(extract_heap_configuration_in_mb "$key" "${SPECJBB_INJECTOR_HEAP_MEMORY}")
    ((result = result * SPECJBB_GROUPS))

    # Input configured->Controller heap*1
    ((result = result + $(extract_heap_configuration_in_mb "$key" "${SPECJBB_CONTROLLER_HEAP_MEMORY}")))

    # Input configured->Backend heap*groups
    backend_heap=$(extract_heap_configuration_in_mb "$key" "-Xms${SPECJBB_XMS} -Xmx${SPECJBB_XMX} -Xmn${SPECJBB_XMN}")
    ((backend_heap = backend_heap * SPECJBB_GROUPS))

    ((result = result + backend_heap))

    echo $result
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
#   SPECJBB_JAVA_PARAMETERS
# Arguments:
#   None
# Return:
# 	 JVM options for combined TI|CT|BE "composite mode"
# ######################################
setJVM_OPTS() {

    gc_version="-XX:+UseParallelOldGC"
    if [[ $(java -version 2>&1 | grep -Po "version.*" | awk '{print $2}' | grep -Po "[0-9]{1,}" | head -n 1) -ge 14 ]]; then
        gc_version="-XX:+UseParallelGC"
    fi

    total_xmx=$(calculate_total_heap_memory_in_mb "Xmx")
    total_xms=$(calculate_total_heap_memory_in_mb "Xms")
    total_xmn=$(calculate_total_heap_memory_in_mb "Xmn")

    jvm_opts_template=$(echo -e "-Xms${total_xms}m -Xmx${total_xmx}m -Xmn${total_xmn}m ${gc_version} -XX:ParallelGCThreads=${SPECJBB_GC_THREADS} 
                -showversion -XX:+AlwaysPreTouch -XX:-UseAdaptiveSizePolicy
                -XX:SurvivorRatio=${SPECJBB_BACKEND_SURVIVOR_RATIO} -XX:MaxTenuringThreshold=15 -XX:InlineSmallCode=10k -verbose:gc 
                -XX:-UseCountedLoopSafepoints -XX:LoopUnrollLimit=20 -XX:MaxGCPauseMillis=500 
                -XX:AdaptiveSizeMajorGCDecayTimeScale=12 -XX:AdaptiveSizeDecrementScaleFactor=2 
                -server -XX:TargetSurvivorRatio=95 -XX:AllocatePrefetchLines=3 
                -XX:AllocateInstancePrefetchLines=2 -XX:AllocatePrefetchStepSize=128 
                -XX:AllocatePrefetchDistance=384 -XX:-PrintGCDetails ${SPECJBB_JAVA_PARAMETERS}" | tr -d "\n" | sed "s/[ ]\{2,\}/ /g")

    echo "$jvm_opts_template"
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
#   $1 resultant template-C.raw location
#   $2 resultant specjbb2015.props location
# Return:
# 	0 if success, non-zero otherwise.
# ######################################
generateConfig() {
    template_c_file=$1
    specjbb2015_file=$2

    # get machine specs for injecting into configuration(s)
    getMachineDetails

    # inject template into configurations
    export CONTROLLER_CMDLINE=${JVM_OPTS_TEMPLATE}

    # replace the {{variables}} with ${VARIABLE} for environment substitution and output to configuration location(s)
    CURRENT_DIR=$(dirname -- "$(readlink -f -- "$0")")
    mkdir -p "$(dirname "$template_c_file")"
    sed -e "s/\([{]\{2,\}\)\([^}}]*\)\([}]\{1\}\)/$\{\U\2/g" "$CURRENT_DIR"/../templates/template-C.raw.j2 | envsubst >"$template_c_file"
    chmod 777 "$template_c_file"
    log "Generated ${template_c_file}"

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

log "Running .... $(basename "$0")"

# Load configuration interface
workload_configuration=$(echo ${SPECJBB_WORKLOAD_CONFIG} | cut -d_ -f3)
. ${USER_WORK_DIR}/configs/${workload_configuration}/calculate.sh

[ "${SPECJBB_PRINT_VARS}" == "true" ] && printVariables >/tmp/input.vars

# Tune defaults that require calculation based on underlying machine's available resources
export SPECJBB_GROUPS=$(get_specjbb_groups)
export SPECJBB_GROUP_COUNT=${SPECJBB_GROUPS}
export SPECJBB_RT_CURVE_START=$(bc <<<"${SPECJBB_RTSTART} / 100")

[ -z "${SPECJBB_SELECTOR_RUNNER_COUNT}" ] && export SPECJBB_SELECTOR_RUNNER_COUNT=${SPECJBB_GROUPS}

cpus_per_group=$((NUM_CPUS / SPECJBB_GROUPS))
[ -z "${SPECJBB_MAPREDUCER_POOL_SIZE}" ] && export SPECJBB_MAPREDUCER_POOL_SIZE=${cpus_per_group}

IFS='|' read -r specjbb_default_t1_mult specjbb_default_t2_mult specjbb_default_t3_mult < <(getDefaultTierThreadMultiplier)

[ -z "${SPECJBB_GC_THREADS}" ] && SPECJBB_GC_THREADS=${cpus_per_group}
[ -z "${SPECJBB_TIER_1_THREADS}" ] && export SPECJBB_TIER_1_THREADS=$(printf '%.0f' $(bc <<<"${specjbb_default_t1_mult} * ${cpus_per_group}"))
[ -z "${SPECJBB_TIER_2_THREADS}" ] && export SPECJBB_TIER_2_THREADS=$(printf '%.0f' $(bc <<<"${specjbb_default_t2_mult} * ${cpus_per_group}"))
[ -z "${SPECJBB_TIER_3_THREADS}" ] && export SPECJBB_TIER_3_THREADS=$(printf '%.0f' $(bc <<<"${specjbb_default_t3_mult} * ${cpus_per_group}"))

# Set base line memory for xmn,xms,xmx
# Set base line memory for xmn,xms,xmx
IFS='|' read -r specjbb_xmx specjbb_xms specjbb_xmn < <(get_specjbb_backend_heap_sizes ${cpus_per_group})
SPECJBB_XMX=$(getHeapValue "${SPECJBB_XMX}" "${specjbb_xmx}")
SPECJBB_XMS=$(getHeapValue "${SPECJBB_XMS}" "${specjbb_xms}")
SPECJBB_XMN=$(getHeapValue "${SPECJBB_XMN}" "${specjbb_xmn}")

# Final run time Options for TI/CT/BE services
JVM_OPTS_TEMPLATE=$(setJVM_OPTS)

# Extra tuning if avs and large pages are requested to be used
has_avx_instruction_set=$([ "$(grep -Po avx /proc/cpuinfo | sort | uniq | wc -l)" = 0 ] && echo false || echo true)
if [[ "${SPECJBB_USE_AVX}" = true && ${has_avx_instruction_set} = false ]]; then
    log "Machine does not have AVX instruction set. Removing option from JVM_OPTS"
else
    [[ ${SPECJBB_USE_AVX} == "true" ]] && JVM_OPTS_TEMPLATE="${JVM_OPTS_TEMPLATE} -XX:UseAVX=0"
fi

[ -z "${SPECJBB_HUGE_PAGE_SIZE}" ] || specjbb_huge_page_size="-XX:LargePageSizeInBytes=${SPECJBB_HUGE_PAGE_SIZE}"
[[ ${SPECJBB_USE_HUGE_PAGES} == "true" ]] && JVM_OPTS_TEMPLATE="${JVM_OPTS_TEMPLATE} -XX:+UseLargePages ${specjbb_huge_page_size}"

# Generate config files based on the variables set above
generateConfig "${SPECJBB_WORK_DIR}/${SPECJBB_KITVERSION}/config/template-C.raw" "${SPECJBB_WORK_DIR}/${SPECJBB_KITVERSION}/config/specjbb2015.props"

# --------------------- print variables ------------------------
CONFIG_RESULT=$?

# Print Variables (before and after)
if [ "${SPECJBB_PRINT_VARS}" == "true" ]; then
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
