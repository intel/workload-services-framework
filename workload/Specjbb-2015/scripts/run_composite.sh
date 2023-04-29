#!/bin/bash

###############################################################################
# This workload runs Specjbb service(s) in Composite mode
# Globals:
# Arguments:
#   --config_runtime_vars Path where runtime environmental variables are stored. Variables include ...
#           SPECJBB_RUN_TYPE,SPECJBB_GROUPS,SPECJBB_KITVERSION,SPECJBB_WORK_DIR,SPECJBB_LOG_DIR,
#           TI_JVM_COUNT,NUMA_NODES, JVM_OPTS_TEMPLATE
# Example:
#   ./run_composite.sh --config_runtime_vars=/tmp/runtime.vars
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

log() {
    printf "%s%b\"\n" "[$(date +%FT%T)] " "$1"
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
    echo "Please run generate_composite_config first!" && exit 3
else
    . "${CONFIG_RUNTIME_VARS}"
fi

#) ensure required variables that are needed for running the specjbb services, are set
variable_list="SPECJBB_RUN_TYPE SPECJBB_GROUPS \
    SPECJBB_KITVERSION SPECJBB_WORK_DIR SPECJBB_LOG_DIR \
    TI_JVM_COUNT NUMA_NODES \
    JVM_OPTS_TEMPLATE"
IFS=" " read -r -a variable_array <<<"${variable_list}"
for var in "${variable_array[@]}"; do
    [[ -z "${!var}" ]] && echo "variable: ${var} not set, exiting... Please check!" && exit 255
done

jvm_open_files_limit=$(sysctl fs.nr_open | grep -Po "[0-9]+")
jvm_open_files_limit=$([ -z "$jvm_open_files_limit" ] && echo 131072 || echo $((jvm_open_files_limit - 20000)))

#) start controller and wait until complete
controller=COMPOSITE

log "Starting ${controller}"

[[ ${NUMA_NODES:-0} -gt 0 ]] && numa_cmd="numactl --interleave=all"
PS4="[\$(date +%FT%T)] "
set -x
cd "${SPECJBB_WORK_DIR}/${SPECJBB_KITVERSION}" &&
    ulimit -n "${jvm_open_files_limit}" &&
    nohup ${numa_cmd} java ${JVM_OPTS_TEMPLATE} \
        -Xlog:gc*:file="${SPECJBB_LOG_DIR}/Ctrlr.GC.log" \
        -jar specjbb2015.jar -m "${controller}" 2>"${SPECJBB_LOG_DIR}/controller.log" 1>"${SPECJBB_LOG_DIR}/output.logs" 2>&1 &

ctrl_pid=$!
run_exit_code=$?
set +x
sleep 10

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
            echo -n " . "
            log "OpenFiles: $(ls /proc/*/fd | wc -l)" &>>"${diagnosis_file}"
            sleep 120
        done) &
    fi

    huge_page_monitor=$!

    wait $ctrl_pid
    run_exit_code=$?
    (kill -9 $huge_page_monitor &>/dev/null)

    #) complete
    log "${controller} has stopped"
fi

exit ${run_exit_code}
