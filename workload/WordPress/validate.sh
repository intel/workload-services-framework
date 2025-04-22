#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# DATABASE name, user, password
STRING_LENGTH=$(( RANDOM % 10 + 5 ))
TEMP_STRING="$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w ${STRING_LENGTH} | head -n 1)"

# General parameters
WP_VERSION=$(echo "${TESTCASE}" | awk -F'_' '{ print $4 }' | grep -oE "[0-9.]+") 
PHP_VERSION=$(echo "${TESTCASE}" | awk -F'_' '{ print $5 }' | grep -oE "[0-9.]+")
PHPMODE=$(echo "${TESTCASE}" | awk -F'_' '{ print $6 }')  # nojit or jit
HTTPMODE=$(echo "${TESTCASE}" | awk -F'_' '{ print $7 }')       # http or https
OPENSSL_VERSION=$(echo "${TESTCASE}" | awk -F'_' '{ print $8 }')  # openssl1.1 or openssl3.1
SYNCMODE=$(echo "${TESTCASE}" | awk -F'_' '{ print $9 }')  # sync or async
if [[ "$TESTCASE" == *_gated || "$TESTCASE" == *_pkm ]]; then
    NODE=$(echo "${TESTCASE}" | awk -F'_' '{ print $(NF-1) }')  # 1n or 2n
else
    NODE=$(echo "${TESTCASE}" | awk -F'_' '{ print $NF }')  # 1n or 2n
fi

HUGEPAGE_NUM=${HUGEPAGE_NUM:-2048}
INSTANCE_COUNT=${INSTANCE_COUNT:-1}
VCPUS_PER_INSTANCE=${VCPUS_PER_INSTANCE:-}
ALL_INSTANCE_CPU_STR=""

# Client tunable parameters
NUSERS=${NUSERS:-200}
DURATION=${DURATION:-60}

# FCGI processes for PHP
NSERVERS=${NSERVERS:-auto}                                      # if auto: (NSERVERS * INSTANCE_COUNT) equal to number of cores allocated to wordpress, else each instance's php worker number is NSERVERS

# Nginx parameters
NGINX_WORKER_PROCESSES=${NGINX_WORKER_PROCESSES:-auto}          # equal to number of cores allocated to nginx
CURVE=${CURVE:-X25519}
PROTOCOL=${PROTOCOL:-TLSv1.3}
CIPHER=${CIPHER:-TLS_AES_256_GCM_SHA384}
CERT=${CERT:-rsa2048}
WORDPRESS_HOST=${WORDPRESS_HOST:-127.0.0.1}

# MariaDB parameters
MYSQL_ROOT_PASSWORD=$TEMP_STRING
MYSQL_USER=$TEMP_STRING
MYSQL_PASSWORD=$TEMP_STRING
MYSQL_DATABASE=$TEMP_STRING
MYSQL_DB_HOST=$TEMP_STRING

# WordPress parameters
WORDPRESS_DB_NAME=$TEMP_STRING
WORDPRESS_DB_USER=$TEMP_STRING
WORDPRESS_DB_PASSWORD=$TEMP_STRING

# Parameters for numa configuration
PHP_NUMA_OPTIONS=${PHP_NUMA_OPTIONS:-"--interleave=all"}
MARIADB_NUMA_OPTIONS=${MARIADB_NUMA_OPTIONS:-"--interleave=all"}
NGINX_NUMA_OPTIONS=${NGINX_NUMA_OPTIONS:-"--interleave=all"}
SIEGE_NUMA_OPTIONS=${SIEGE_NUMA_OPTIONS:-"--interleave=all"}
# PHP_NUMA_OPTIONS=${PHP_NUMA_OPTIONS:-"-C 0-47,96-143 -m 0"}
# MARIADB_NUMA_OPTIONS=${MARIADB_NUMA_OPTIONS:-"-C 0-47,96-143 -m 0"}
# NGINX_NUMA_OPTIONS=${NGINX_NUMA_OPTIONS:-"-C 0-47,96-143 -m 0"}
# SIEGE_NUMA_OPTIONS=${SIEGE_NUMA_OPTIONS:-"-C 48-95,144-191 -m 1"}
# Replace space to ? for m4 parsing
PHP_NUMA_OPTIONS=${PHP_NUMA_OPTIONS//" "/"?"}
PHP_NUMA_OPTIONS=${PHP_NUMA_OPTIONS//","/"!"}
MARIADB_NUMA_OPTIONS=${MARIADB_NUMA_OPTIONS//" "/"?"}
MARIADB_NUMA_OPTIONS=${MARIADB_NUMA_OPTIONS//","/"!"}
NGINX_NUMA_OPTIONS=${NGINX_NUMA_OPTIONS//" "/"?"}
NGINX_NUMA_OPTIONS=${NGINX_NUMA_OPTIONS//","/"!"}
SIEGE_NUMA_OPTIONS=${SIEGE_NUMA_OPTIONS//" "/"?"}
SIEGE_NUMA_OPTIONS=${SIEGE_NUMA_OPTIONS//","/"!"}

# Logs Setting
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR/../../script/overwrite.sh"

SUTINFO_CSP=""
SUTINFO_WORKER_VCPUS=""
SUTINFO_WORKER_NUMAINFO=""

. "$DIR/../../script/sut-info.sh"

if [[ -n "$VCPUS_PER_INSTANCE" && $SUTINFO_CSP == "static" ]]; then
    # Initialize total instances across all NUMA nodes
    total_instances=0

    # Initialize an empty associative array (we will use indexed arrays directly)
    numa_nodes=()

    # Initialize an array to store the list of CPUs for all instances
    all_instance_cpus=()

    # Clean up input (remove extra spaces)
    cpu_nodes=$(echo "$SUTINFO_WORKER_NUMAINFO" | tr -s ' ')

    # Convert the comma-separated string into an array for easy iteration
    IFS=',' read -r -a cpu_nodes_array <<< "$cpu_nodes"

    # Iterate over the CPU node assignments
    for cpu in "${!cpu_nodes_array[@]}"; do
      # Get NUMA node for the current CPU
      node=${cpu_nodes_array[$cpu]}  # Directly access the NUMA node for the CPU
      if [ $node == "-" ]; then
        continue
      fi
    
      # Append the CPU to its corresponding NUMA node in the array
      numa_nodes[$node]="${numa_nodes[$node]} $cpu"
    done

    for node in "${!numa_nodes[@]}"; do
        # Extract node name
        node_name="NUMA Node$node"

        cpu_list=(${numa_nodes[$node]})
        total_cpus=${#cpu_list[@]} 
        
        # Calculate the number of instances based on vCPUs per instance
        instances=$((total_cpus / VCPUS_PER_INSTANCE))
        # If there's a remainder, increase the instance count by 1
        if (( total_cpus % VCPUS_PER_INSTANCE != 0 )); then
            instances=$((instances + 1))
        fi
        # Output the result for the current node
        echo "$node_name has $total_cpus CPU(s), needs $instances instance(s)"
        # Now we need to assign the CPUs to instances
        echo "CPUs assigned to each instance in $node_name:"
        for ((i=0; i<instances; i++)); do
          start_index=$((i * VCPUS_PER_INSTANCE))
          end_index=$(((i + 1) * VCPUS_PER_INSTANCE - 1))
          # Ensure the end index does not exceed the available CPUs
          if ((end_index >= total_cpus)); then
            end_index=$((total_cpus - 1))
          fi
          # Get the list of CPUs for this instance
          instance_cpus=("${cpu_list[@]:$start_index:$((end_index - start_index + 1))}")
          # Convert the CPU list to a comma-separated string
          instance_cpus_str=$(IFS=,; echo "${instance_cpus[*]}")
          # Output the CPU list as a comma-separated string for this instance
          echo "  Instance $((i+1)): $instance_cpus_str"
          # Add the current instance's CPUs to the global list
          all_instance_cpus+=("${instance_cpus_str}")
        done
        # Add the instances for this node to the total instance count
        total_instances=$((total_instances + instances))
    done
    # Output the total instances across all NUMA nodes
    echo "Total instances across all NUMA nodes: $total_instances"
    ALL_INSTANCE_CPU_STR=$(IFS=_; echo "${all_instance_cpus[*]}")
    INSTANCE_COUNT=$total_instances
    PHP_NUMA_OPTIONS="--interleave=all"
    MARIADB_NUMA_OPTIONS="--interleave=all"
    NGINX_NUMA_OPTIONS="--interleave=all"
fi

# Calculate some params after overwrite
HUGEPAGE_NUM_TOTAL=$((HUGEPAGE_NUM * INSTANCE_COUNT)) 

WP_OS_SUFFIX=""
if [[ $WORKLOAD == wordpress_wp6.7_php8.3 ]]; then
  WP_OS_SUFFIX="-ubuntu2404"
fi

# Workload Setting
WORKLOAD_PARAMS=(
WP_VERSION
PHP_VERSION
PHPMODE
HTTPMODE 
OPENSSL_VERSION
SYNCMODE 
HUGEPAGE_NUM 
INSTANCE_COUNT 
HUGEPAGE_NUM_TOTAL 
NUSERS 
DURATION 
NSERVERS 
ASYNC 
NGINX_WORKER_PROCESSES 
CURVE 
PROTOCOL 
CIPHER 
CERT 
MYSQL_ROOT_PASSWORD 
MYSQL_USER 
MYSQL_PASSWORD 
MYSQL_DATABASE 
MYSQL_DB_HOST 
WORDPRESS_HOST 
WORDPRESS_DB_NAME 
WORDPRESS_DB_USER 
WORDPRESS_DB_PASSWORD 
PHP_NUMA_OPTIONS 
MARIADB_NUMA_OPTIONS 
NGINX_NUMA_OPTIONS 
SIEGE_NUMA_OPTIONS 
NODE
SUTINFO_CSP
VCPUS_PER_INSTANCE
ALL_INSTANCE_CPU_STR
WP_OS_SUFFIX
)

# Kubernetes Setting
RECONFIG_OPTIONS="-DWP_VERSION=$WP_VERSION -DPHP_VERSION=$PHP_VERSION -DPHPMODE=$PHPMODE -DHTTPMODE=$HTTPMODE  -DOPENSSL_VERSION=$OPENSSL_VERSION -DSYNCMODE=$SYNCMODE -DHUGEPAGE_NUM=$HUGEPAGE_NUM -DINSTANCE_COUNT=$INSTANCE_COUNT -DHUGEPAGE_NUM_TOTAL=$HUGEPAGE_NUM_TOTAL -DNUSERS=$NUSERS -DDURATION=$DURATION -DNSERVERS=$NSERVERS -DASYNC=$ASYNC -DNGINX_WORKER_PROCESSES=$NGINX_WORKER_PROCESSES -DCURVE=$CURVE -DPROTOCOL=$PROTOCOL -DCIPHER=$CIPHER -DCERT=$CERT -DMYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD -DMYSQL_USER=$MYSQL_USER -DMYSQL_PASSWORD=$MYSQL_PASSWORD -DMYSQL_DATABASE=$MYSQL_DATABASE -DMYSQL_DB_HOST=$MYSQL_DB_HOST -DWORDPRESS_HOST=$WORDPRESS_HOST -DWORDPRESS_DB_NAME=$WORDPRESS_DB_NAME -DWORDPRESS_DB_USER=$WORDPRESS_DB_USER -DWORDPRESS_DB_PASSWORD=$WORDPRESS_DB_PASSWORD -DPHP_NUMA_OPTIONS=$PHP_NUMA_OPTIONS -DMARIADB_NUMA_OPTIONS=$MARIADB_NUMA_OPTIONS -DNGINX_NUMA_OPTIONS=$NGINX_NUMA_OPTIONS -DSIEGE_NUMA_OPTIONS=$SIEGE_NUMA_OPTIONS -DNODE=$NODE -DSUTINFO_CSP=$SUTINFO_CSP -DVCPUS_PER_INSTANCE=$VCPUS_PER_INSTANCE -DALL_INSTANCE_CPU_STR=$ALL_INSTANCE_CPU_STR -DWP_OS_SUFFIX=$WP_OS_SUFFIX"
JOB_FILTER="job-name=benchmark"

EVENT_TRACE_PARAMS=""

. "$DIR/../../script/validate.sh"