#!/bin/bash

###############################################################################
# This workload runs Specjbb service(s) in MultiJVM mode i.e Multiple JVMs/Single container|node
# Globals:
# Arguments:
#   --config_runtime_vars Path where runtime environmental variables are stored. Variables include ...
#           SPECJBB_RUN_TYPE,SPECJBB_GROUPS,SPECJBB_KITVERSION,SPECJBB_WORK_DIR,SPECJBB_LOG_DIR,
#           TI_JVM_COUNT,NUMA_NODES, VM_OPTS_CT_TEMPLATE,JVM_OPTS_BE_TEMPLATE,JVM_OPTS_TI_TEMPLATE
# Example:
#   ./run_multi_mode.sh --config_runtime_vars=/tmp/runtime.vars
# Notes:
#   This benchmark requires a JDK7 compliant Java VM.  If such a JVM is not on your path already you must set
#   the JAVA environment variable to point to where the 'java' executable can be found.
###############################################################################

JAVA=java
CONFIG_RUNTIME_VARS=/tmp/runtime.vars

if ! which $JAVA >/dev/null 2>&1; then
    echo "ERROR: Could not find a 'java' executable. Please set the JAVA environment variable or update the PATH."
    exit 1
fi

# ######################################
# Run specjbb BACKEND or TXINJECTOR service(s) as a background process
# Globals:
#   NUMA_NODES
#   SPECJBB_LOG_DIR
# Arguments:
#   $1 group number
#   $2 Jvm Name for the service
#   $3 GC Log prefix
#   $4 service type TXINJECTOR|BACKEND
#   $5 Max. Number of open files jvm can consume
#   $6 extra JAVA_OPTS for running the service
# ######################################
runService() {
    group_index=$1

    jvm_id=$2
    jvm_name=$3
    jvm_type=$4
    open_files=$5
    jvm_opts=$6

    log="${jvm_name}.log"
    group_id="Group${group_index}"

    log "Starting $jvm_type $jvm_name-$group_index ..."
    [[ ${NUMA_NODES:-0} -gt 0 ]] && numa_cmd="numactl --cpunodebind=$((group_index % NUMA_NODES)) --localalloc"

    # Run
    PS4="[\$(date +%FT%T)] "
    set -x
    ulimit -n "${open_files}" && nohup ${numa_cmd} java ${jvm_opts} \
        -Xlog:gc*:file="${SPECJBB_LOG_DIR}"/"${jvm_name}".GC.log -jar specjbb2015.jar \
        -m "${jvm_type}" -G="${group_id}" -J="${jvm_id}" >"${SPECJBB_LOG_DIR}/${log}" 2>&1 &
    set +x
}

log() {
    printf "%s%b\"\n" "[$(date +%FT%T)] " "$1"
}

# ######################################
# Check if specjbb services are running as expected
# Arguments:
#   $1 service type TXINJECTOR|BACKEND
#   $2 expected number of $1 services to be running
# Return:
# 	0 if success, non-zero otherwise.
# ######################################
checkJvmProcesses() {
    jvm_type=$1
    count=$2
    let missing_jvms=0

    pids=$(ps -e -o pid,cmd | grep "[j]ava" | grep "${jvm_type}" | awk '{print $1}' | tr '\n' ' ')
    pids_count=$(ps -e -o pid,cmd | grep "[j]ava" | grep "${jvm_type}" | wc -l)

    if [[ $count -ne $pids_count ]]; then
        log "Expected ${count} JVM(s) of type ${jvm_type}, found ${pids_count} running."
        missing_jvms=1
    fi

    if [[ $missing_jvms -gt 0 ]]; then
        log "Removing remaining processes and copying logs."
        [ -z "${pids}" ] || kill -9 "${pids}"
        return 1
    fi

    return 0
}

# ######################################
# Print help contents to screen
# Output:
# 	Writes out all input arguments to stdout
# ######################################
usage() {
    echo -e "
Usage:
 --config_runtime_vars: Location of output variables file needed for specjbb runtime service. Defaults to /tmp/runtime.vars
	"
}

# ----------------------- read input arguments ----------------------
while [[ $# -gt 0 ]]; do
    opt="$1"
    shift #expose next argument
    case "$opt" in
    "--") break 2 ;;

    "--config_runtime_vars")
        CONFIG_RUNTIME_VARS="$1"
        shift
        ;;

    "--config_runtime_vars="*)
        CONFIG_RUNTIME_VARS="${opt#*=}"
        ;;

    *)
        usage
        echo >&2 "Invalid option: $opt"
        exit 2
        ;;

    esac
done

# ---------------------------- main---------------------------------

log "Running .... $(basename "$0")"

#) load variables
if [ ! -f "${CONFIG_RUNTIME_VARS}" ]; then
    echo "Please run generate_multi_mode_config first!" && exit 3
else
    . "${CONFIG_RUNTIME_VARS}"
fi

#) ensure required variables that are needed for running the specjbb services, are set
variable_list="SPECJBB_RUN_TYPE SPECJBB_GROUPS \
    SPECJBB_KITVERSION SPECJBB_WORK_DIR SPECJBB_LOG_DIR \
    TI_JVM_COUNT NUMA_NODES JVM_OPTS_CT_TEMPLATE \
    JVM_OPTS_BE_TEMPLATE JVM_OPTS_TI_TEMPLATE"
IFS=" " read -r -a variable_array <<<"${variable_list}"
for var in "${variable_array[@]}"; do
    [[ -z "${!var}" ]] && echo "variable: ${var} not set, exiting... Please check!" && exit 255
done

jvm_open_files_limit=$(sysctl fs.nr_open | grep -Po "[0-9]+")
jvm_open_files_limit=$([ -z "$jvm_open_files_limit" ] && echo 131072 || echo $((jvm_open_files_limit - 20000)))

#) run BI and TI services
for group in $(seq 0 $((SPECJBB_GROUPS - 1))); do
    group_id="Group${group}"
    cd "${SPECJBB_WORK_DIR}/${SPECJBB_KITVERSION}" || exit 4

    for jvm_num in $(seq 0 $((TI_JVM_COUNT - 1))); do
        runService "$group" "JVM${jvm_num}" "${group_id}.TxInjector.${jvm_num}" "TXINJECTOR" "${jvm_open_files_limit}" "${JVM_OPTS_TI_TEMPLATE}"
    done

    runService "$group" "JVM${TI_JVM_COUNT}" "${group_id}.Backend.${TI_JVM_COUNT}" "BACKEND" "${jvm_open_files_limit}" "${JVM_OPTS_BE_TEMPLATE}"
done

#) verify they're running
WAIT=20 && log "Allowing ${WAIT} seconds for JVMs to start." && for i in $(seq 1 ${WAIT}); do
    echo -n ". "
    sleep 2
done && echo ""

run_exit_code=0
checkJvmProcesses "BACKEND" "${SPECJBB_GROUPS}" && [ $? = 0 ] || run_exit_code=$?
checkJvmProcesses "TXINJECTOR" $((SPECJBB_GROUPS * TI_JVM_COUNT)) && [ $? = 0 ] || run_exit_code=$?

#) start controller and wait until complete
if [ ${run_exit_code} = 0 ]; then
    controller=MULTICONTROLLER
    running_service_count=$(ps -e -o pid,cmd | grep "[j]ava" | wc -l)

    log "Starting ${controller}"

    [[ ${NUMA_NODES:-0} -gt 0 ]] && numa_cmd="numactl --interleave=all"
    PS4="[\$(date +%FT%T)] "
    set -x
    cd "${SPECJBB_WORK_DIR}/${SPECJBB_KITVERSION}" &&
        nohup ${numa_cmd} java ${JVM_OPTS_CT_TEMPLATE} \
            -Xlog:gc*:file="${SPECJBB_LOG_DIR}/Ctrlr.GC.log" \
            -jar specjbb2015.jar -m ${controller} 2>"${SPECJBB_LOG_DIR}/controller.log" 1>"${SPECJBB_LOG_DIR}/output.logs" 2>&1 &

    ctrl_pid=$!
    run_exit_code=$?
    set +x
    sleep 10

    # once controller has started, ensure none of the service have stopped abruptly
    if [ $(ps -e -o pid,cmd | grep "[j]ava" | wc -l) -ne $((running_service_count + 1)) ]; then
        log "BE or TI Service has stopped after starting controller. Please check!"
        run_exit_code=-1
    else
        if [ ${run_exit_code} = 0 ]; then
            log "SPECjbb2015 is running ..."

            # monitor huge page consumption
            diagnosis_file="${USER_WORK_DIR}/workload_diagnosis.log"
            if [[ -n "${SPECJBB_USE_HUGE_PAGES}" && "${SPECJBB_USE_HUGE_PAGES}" = true ]]; then
                (
                    while true; do
                        log "hugepage_consumption:$(grep "HugePages_Total\|HugePages_Free" /proc/meminfo | awk '{print $2}' | tr "\n" " " | awk '{print $1-$2}')"
                        log "OpenFiles: $(ls /proc/*/fd | wc -l)" &>>"${diagnosis_file}"
                        sleep 120
                    done
                ) &
            else
                (while true; do
                    echo -n ' . '
                    log "OpenFiles: $(ls /proc/*/fd | wc -l)" &>>"${diagnosis_file}"
                    sleep 120
                done) &
            fi

            huge_page_monitor=$!

            wait $ctrl_pid
            run_exit_code=$?
            (kill -9 $huge_page_monitor &>/dev/null)

            #) complete
            log "Controller has stopped"
        fi
    fi
else
    log "Something went wrong. Please check SPECJBB_* parameters"
    pkill java >/dev/null
fi

exit ${run_exit_code}
