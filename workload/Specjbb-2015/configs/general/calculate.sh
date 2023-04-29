#!/bin/bash

# ######################################
# Interface Script that configure's Specjbb JVM and threading arguments depending on input configuration
# Globals:
#   None
# Arguments:
#   None
# Example:
#  . ./calculate.sh
# Return:
# 	0 if successfully context'ed
# ######################################

# ######################################
# Generates the JVM Options for each of the Specjbb services
# Globals:
#   SPECJBB_*
#   NUMA_NODES
# Arguments:
#   None
# Return:
# 	 Pipe delimited JVM options for TI|CT|BE
#    Empty use caller values
# ######################################
function get_jvm_options() {
    # Use default (from caller)
    echo ""
}

# ######################################
# Calculate Tier1|2|3 threads for specjbb
# Globals:
#   SPECJBB_*
#   NUMA_NODES
# Arguments:
#    None
# Return:
# 	 Pipe delimited JVM options for [tier_1_threads|tier_2_threads|tier_3_threads]
#    Empty use caller values
# ######################################
function get_specjbb_tier_threads() {
    # Use default (from caller)
    echo ""
}

# ######################################
# Generates specjbb gc threads
# Globals:
#   SPECJBB_*
#   NUMA_NODES
# Arguments:
#   platform                        ICX|SPR ....
#   user_configured_gc_threads      user inputted gc threads
# Return:
# 	gc threads for specjbb
# ######################################
function get_specjbb_gc_threads() {
    platform=$1
    user_configured_gc_threads=$2

    if [[ "${platform}" =~ ^(ICX)$ ]]; then
        cores_per_socket=$(lscpu | grep "Core(s) per socket:" | awk -F ':' '{print $2}')
        threads=$((cores_per_socket / SPECJBB_GROUPS))
        echo "${user_configured_gc_threads:-$threads}"
    elif [[ "${platform}" =~ ^(SPR)$ ]]; then
        vCPUs=$(grep -c ^processor /proc/cpuinfo)
        threads=$((vCPUs / SPECJBB_GROUPS))
        echo "${user_configured_gc_threads:-$threads}"
    else
        vCPUs=$(grep -c ^processor /proc/cpuinfo)
        threads=$((vCPUs / SPECJBB_GROUPS))
        echo "${user_configured_gc_threads:-$threads}"
    fi
}

# ######################################
# Get Specjbb Groups
# Globals:
#   SPECJBB_*
#   NUMA_NODES
# Arguments:
#   platform                        ICX|SPR ....
#   user_configured_gc_threads      user inputted gc threads
# Return:
# 	Number of groups to run specjbb with. Correlation between number of BE services and number of groups
# ######################################
function get_specjbb_groups() {
    echo "${SPECJBB_GROUPS:-${NUMA_NODES}}"
}

# ######################################
# Get Backend Heap configuration
# Globals:
#   SPECJBB_*
#   NUMA_NODES
# Arguments:
#   cpus_per_group
#   user_configured_gc_threads      user inputted gc threads
# Return:
# 	Pipe delimited [xmx|xms|xmn] value to be injected into the backend specjbb service
# ######################################
function get_specjbb_backend_heap_sizes() {
    cpus_per_group=$1

    if [ "${SPECJBB_TUNE_OPTION:-regular}" = "max" ]; then
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
    else
        xmx="${SPECJBB_XMX:-4g}"
        xms="${SPECJBB_XMX:-4g}"

        specjbb_xmx=$(echo "${xmx}" | grep -Po "[0-9]{1,}")
        xmn="${SPECJBB_XMN:-$((specjbb_xmx - 2))g}"

        echo "${xmx}|${xms}|${xmn}"
    fi
}
