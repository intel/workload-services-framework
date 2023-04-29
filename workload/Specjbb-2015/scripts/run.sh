#!/bin/bash

###############################################################################
# This benchmark requires a JDK7 compliant Java VM.  The benchmark runs the SPECjbb benchmark
# in multi or composite mode depending on the CASE type.
#   [multi] mode     > The benchmark runs multiple (jvm's) SPECjbb services BE,TI based on
#      user configuration input variables @see specjbb.env.sh and underlying OS h/w
#   [composite] mode > The benchmark run a single jvm with all the SPECjbb services
#      BE,TI,controller running in that single JVM. Note: variables from
#      specjbb.env.sh are not used in this mode, just default configuration
# Globals:
#   SPECJBB_WORKLOAD_CONFIG    in the format of [mode_pki_customer]. e.g (multijvm_crit_general|composite_max_general) @see CMakeLists.txt @param #3
#   @see specjbb.env.sh
# Arguments:
#   None
# Example:
#   SPECJBB_CLIENT_POOL_SIZE=100
#   ./run_multi_mode.sh
###############################################################################

# ######################################
# Check available resources of system under test before SPECjbb run is kicked off
# Arguments:
#   None
# Output:
# 	 Prints out available Memory and CPU statistics for the underlying machine
# ######################################
sut_resource_pre_check() {
    # get memory info
    read -r mem_total mem_free hugepages_size hugepages_total hugepages_free < <(grep "MemTotal\|MemFree\|Hugepagesize\|HugePages_Total\|HugePages_Free" /proc/meminfo | grep -Po "[0-9]{1,}" | tr "\n" " ")

    # convert to gb
    hugepage_total_gb=$((hugepages_size * hugepages_total / 1024 / 1024))
    hugepage_free_gb=$((hugepages_size * hugepages_free / 1024 / 1024))
    memory_free_gb=$((mem_free / 1024 / 1024))
    mem_total_gb=$((mem_total / 1024 / 1024))

    log "*********SUT Resource Pre-check********"
    log "HugePageSize is ${hugepages_size} kB, HugePageTotalSize is ${hugepage_total_gb} Gb, HugePageFreeSize is ${hugepage_free_gb} Gb"
    log "MemoryFree is ${memory_free_gb} Gb, MemoryTotal is ${mem_total_gb} Gb"

    # CPU Info Statistic
    cores=$(grep -c processor /proc/cpuinfo)
    zones=$(numactl -H | grep cpus | wc -l)
    log "LogicalCores is ${cores} , NumaNodeNum is ${zones}"

    log "********* Java Version *********"
    log "$(java --version | tr '\n' ', ')"

    # verify (transparent hugepage(s) need to switched on in the underlying OS to measure optimal performance)
    [ "$(grep -o '\[.*\]' /sys/kernel/mm/transparent_hugepage/enabled)" != "[always]" ] && printf "%s\n" "\"transparent hugepage(s)\" recommended to be set to [always] for SPECjbb workload!" >&2
    [ "$(grep -o '\[.*\]' /sys/kernel/mm/transparent_hugepage/defrag)" != "[always]" ] && printf "%s\n" "\"direct compaction for hugepage(s)\" recommended to be set to [always] for SPECjbb workload" >&2

    log ""
}

# ######################################
# Log process and machine details to help diagnose any error(s) should they occur
# Arguments:
#   exit_code Exit code
#   diagnosis_file Name of file to output to
# Output:
# 	 Prints out any remaining JVM process details, error count, memory info
# ######################################
workload_diagnosis() {
    exit_code=$1
    diagnosis_file=$2

    echo " "
    echo -e "======= Error Diagnosis =========\n" >>"${diagnosis_file}"
    echo "Exit code:${exit_code}" >>"${diagnosis_file}"

    echo "======= Memory Details =========" >>"${diagnosis_file}"
    free -h >>"${diagnosis_file}"

    echo -e "\n======= JVM Error Count =========" >>"${diagnosis_file}"
    grep -il "error\|exception" --include="*.log" * 2>/dev/null | xargs grep -c "error\|exception" >>"${diagnosis_file}"

    echo -e "\n======= JVM processes still running =========" >>"${diagnosis_file}"
    pgrep java -a >>"${diagnosis_file}"

    echo -e "\n======= JVM File descriptor Count =========" >>"${diagnosis_file}"
    for pid in $(pgrep java); do echo "$(ls /proc/$pid/fd/ 2>/dev/null | wc -l) fds for pid: $pid"; done >>"${diagnosis_file}"

    echo -e "\n======= Resource limits =========" >>"${diagnosis_file}"
    paste <(ulimit -aS) <(ulimit -aH) | expand --tabs=80 >>"${diagnosis_file}"

    echo -e "\n======= Huge Page Info =========" >>"${diagnosis_file}"
    echo "SPECJBB_USE_HUGE_PAGES=${SPECJBB_USE_HUGE_PAGES}" >>"${diagnosis_file}"
    grep -i huge /proc/meminfo >>"${diagnosis_file}"

    echo -e "\n======= Tmp directory details =========" >>"${diagnosis_file}"
    paste <(df -h /tmp) <(df -i /tmp) | expand --tabs=60 >>"${diagnosis_file}"
}

log() {
    printf "%s%b\n" "[$(date +%FT%T)] " "$1"
}

# --------------------- main ------------------------
CURRENT_DIR=$(dirname -- "$(readlink -f -- "$0")")

# --------------SUT Resource Pre-check--------------
sut_resource_pre_check

export USER_WORK_DIR="/opt/pkb"
export SPECJBB_WORK_DIR="${USER_WORK_DIR}/SPECjbb2015"
export SPECJBB_LOG_DIR="${USER_WORK_DIR}"
export SPECJBB_KITVERSION=$(find "${SPECJBB_WORK_DIR}" -maxdepth 1 -type d -regextype egrep -regex '.*\/[0-9]{1,2}.[0-9]{2,3}' -exec basename {} \;)

mode=$(echo "${SPECJBB_WORKLOAD_CONFIG}" | cut -d_ -f1)
pki_type=$(echo "${SPECJBB_WORKLOAD_CONFIG}" | cut -d_ -f2)
run_exit_code=0
if [[ "$mode" == "multijvm" ]]; then
    # run [multi] mode

    # #######################
    # read SPECJBB_* env. variables and run ./generate_multi_mode_config.sh for generating
    #   a). SPECjbb configuration @ ${work_dir}/SPECjbb2015/${specjbb_kitversion}/config/
    #   b). runtime variables     @ /tmp/runtime.vars
    # #######################
    # Convert input environmental variables(s) to --[lowercase]key=[unescaped]value
    SPECJBB_ARGS=$(printenv | grep "^SPECJBB_" | perl -lpe "s/^([^=]{1,})([=]{1})(.*)$/\-\-\L\$1=\E\$3/g" | perl -p -e 's/%([a-fA-F0-9][a-fA-F0-9])/chr hex $1/eg')

    # Pass variables as array to script for generating configuration
    readarray -t array_args <<<"$SPECJBB_ARGS"
    "${CURRENT_DIR}"/generate_multi_mode_config.sh "${array_args[@]}" --config_runtime_vars=/tmp/runtime.vars
    if [[ $? != 0 ]]; then
        echo "Problem generating multijvm configuration!" && exit 1
    fi

    # #######################
    # runs SPECjbb in multi-mode based on the newly generated configuration files
    # #######################
    "${CURRENT_DIR}"/run_multi_mode.sh --config_runtime_vars=/tmp/runtime.vars
    run_exit_code=$?
elif [[ "$mode" == "composite" ]]; then
    SPECJBB_ARGS=$(printenv | grep "^SPECJBB_" | perl -lpe "s/^([^=]{1,})([=]{1})(.*)$/\-\-\L\$1=\E\$3/g" | perl -p -e 's/%([a-fA-F0-9][a-fA-F0-9])/chr hex $1/eg')

    # Pass variables as array to script for generating configuration
    readarray -t array_args <<<"$SPECJBB_ARGS"

    "${CURRENT_DIR}"/generate_composite_config.sh "${array_args[@]}" --config_runtime_vars=/tmp/runtime.vars
    if [[ $? != 0 ]]; then
        echo "Problem generating composite configuration!" && exit 2
    fi
    "${CURRENT_DIR}"/run_composite.sh --config_runtime_vars=/tmp/runtime.vars
    run_exit_code=$?
else
    echo "Unknown mode ${mode}"
fi

# Generate workload diagnosis file
file_name="${USER_WORK_DIR}/workload_diagnosis.log"
log "Generating $(basename $file_name)"
workload_diagnosis ${run_exit_code} "${file_name}"

#) download any jvm error logs (if reported)
find "${SPECJBB_WORK_DIR}/${SPECJBB_KITVERSION}" -name "*err*.log" -exec mv {} ${USER_WORK_DIR} \;

#) make report downloadable for more verbose reading
[ -d "${SPECJBB_WORK_DIR}/${SPECJBB_KITVERSION}"/result ] && (cd ${SPECJBB_WORK_DIR} && tar -zcf result.tar.gz --absolute-names ${SPECJBB_WORK_DIR}/"${SPECJBB_KITVERSION}"/result && mv result.tar.gz ${USER_WORK_DIR})

# export key run-time variables for use with kpi
for var in ${!pki_type@}; do echo "$var=${!var}"; done >>${USER_WORK_DIR}/output.run.log
[ -z "$(find ./ -name output.logs)" ] && echo "RUN RESULT:" >${USER_WORK_DIR}/output.logs

# Ensure there are max-JOPs result(s) for load test runs. Controller may have stopped and not produced any jOPS values
if [[ $run_exit_code = 0 && ! $SPECJBB_RUN_TYPE =~ ^(PRESET)$ ]]; then

    jops_result=$(grep "RUN RESULT" -RI --include="output.logs")
    jops_values=$(for i in $(echo "critical max"); do echo "$jops_result" | grep -Po "$i-jOPS[^,]+" | grep -Po "[0-9]+"; done | awk '{sum+=$1;} END{print sum;}')

    if [[ -z "${jops_values}" || ${jops_values} == 0 ]]; then
        log "Workload has stopped but did not produce any jOPS value(s). Something has gone wrong!"
        [ "${SPECJBB_USE_HUGE_PAGES}" = true ] && log "Please ensure you have enough huge pages configured to run the workload by increasing the [HUGEPAGE_MEMORY_NUM] variable"
        run_exit_code=4
    fi
fi

echo "Finished with exit code:${run_exit_code}"
exit ${run_exit_code}
