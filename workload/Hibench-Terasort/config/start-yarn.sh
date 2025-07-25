#!/usr/bin/env bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
export HDFS_NAMENODE_USER=root
export HDFS_DATANODE_USER=root
export HDFS_SECONDARYNAMENODE_USER=root
export YARN_RESOURCEMANAGER_USER=root
export YARN_NODEMANAGER_USER=root
## @description  usage info
## @audience     private
## @stability    evolving
## @replaceable  no
function hadoop_usage
{
  hadoop_generate_usage "${MYNAME}" false
}

MYNAME="${BASH_SOURCE-$0}"

bin=$(cd -P -- "$(dirname -- "${MYNAME}")" >/dev/null && pwd -P)

# let's locate libexec...
if [[ -n "${HADOOP_HOME}" ]]; then
  HADOOP_DEFAULT_LIBEXEC_DIR="${HADOOP_HOME}/libexec"
else
  HADOOP_DEFAULT_LIBEXEC_DIR="${bin}/../libexec"
fi

HADOOP_LIBEXEC_DIR="${HADOOP_LIBEXEC_DIR:-$HADOOP_DEFAULT_LIBEXEC_DIR}"
# shellcheck disable=SC2034
HADOOP_NEW_CONFIG=true
if [[ -f "${HADOOP_LIBEXEC_DIR}/yarn-config.sh" ]]; then
  . "${HADOOP_LIBEXEC_DIR}/yarn-config.sh"
else
  echo "ERROR: Cannot execute ${HADOOP_LIBEXEC_DIR}/yarn-config.sh." 2>&1
  exit 1
fi

HADOOP_JUMBO_RETCOUNTER=0

# start resourceManager
HARM=$("${HADOOP_HDFS_HOME}/bin/hdfs" getconf -confKey yarn.resourcemanager.ha.enabled 2>&-)
if [[ ${HARM} = "false" ]]; then
  echo "Starting resourcemanager"
  hadoop_uservar_su yarn resourcemanager "${HADOOP_YARN_HOME}/bin/yarn" \
      --config "${HADOOP_CONF_DIR}" \
      --daemon start \
      resourcemanager
  (( HADOOP_JUMBO_RETCOUNTER=HADOOP_JUMBO_RETCOUNTER + $? ))
else
  logicals=$("${HADOOP_HDFS_HOME}/bin/hdfs" getconf -confKey yarn.resourcemanager.ha.rm-ids 2>&-)
  logicals=${logicals//,/ }
  for id in ${logicals}
  do
      rmhost=$("${HADOOP_HDFS_HOME}/bin/hdfs" getconf -confKey "yarn.resourcemanager.hostname.${id}" 2>&-)
      RMHOSTS="${RMHOSTS} ${rmhost}"
  done
  echo "Starting resourcemanagers on [${RMHOSTS}]"
  hadoop_uservar_su yarn resourcemanager "${HADOOP_YARN_HOME}/bin/yarn" \
      --config "${HADOOP_CONF_DIR}" \
      --daemon start \
      --workers \
      --hostnames "${RMHOSTS}" \
      resourcemanager
  (( HADOOP_JUMBO_RETCOUNTER=HADOOP_JUMBO_RETCOUNTER + $? ))
fi

# start nodemanager
echo "Starting nodemanagers"
hadoop_uservar_su yarn nodemanager "${HADOOP_YARN_HOME}/bin/yarn" \
    --config "${HADOOP_CONF_DIR}" \
    --workers \
    --daemon start \
    nodemanager
(( HADOOP_JUMBO_RETCOUNTER=HADOOP_JUMBO_RETCOUNTER + $? ))


# start proxyserver
PROXYSERVER=$("${HADOOP_HDFS_HOME}/bin/hdfs" getconf -confKey  yarn.web-proxy.address 2>&- | cut -f1 -d:)
if [[ -n ${PROXYSERVER} ]]; then
 hadoop_uservar_su yarn proxyserver "${HADOOP_YARN_HOME}/bin/yarn" \
      --config "${HADOOP_CONF_DIR}" \
      --workers \
      --hostnames "${PROXYSERVER}" \
      --daemon start \
      proxyserver
 (( HADOOP_JUMBO_RETCOUNTER=HADOOP_JUMBO_RETCOUNTER + $? ))
fi

exit ${HADOOP_JUMBO_RETCOUNTER}
