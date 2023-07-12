#!/bin/bash -xe
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

APISERVER=https://kubernetes.default.svc
SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount
NAMESPACE=$(cat ${SERVICEACCOUNT}/namespace)
TOKEN=$(cat ${SERVICEACCOUNT}/token)
CACERT=${SERVICEACCOUNT}/ca.crt

delete_topo_objects() {
    for i in contains controls e2cell e2node e2t neighbors
    do
        echo "Deleting kind.topo.onosproject.org/$i..."
        curl --cacert ${CACERT} --header "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/merge-patch+json" -X DELETE ${APISERVER}/apis/topo.onosproject.org/v1beta1/namespaces/${NAMESPACE}/kinds/$i/
    done
}

# Currently not used. Delete is enough because the topo service is still online.
clean_topo_finalizers() {
    for i in contains controls e2cell e2node e2t neighbors
    do
        echo "Cleaning kind.topo.onosproject.org/$i..."
        curl --cacert ${CACERT} --header "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/merge-patch+json" -X PATCH -d '{"metadata":{"finalizers":[]}}' ${APISERVER}/apis/topo.onosproject.org/v1beta1/namespaces/${NAMESPACE}/kinds/$i/
    done
}

echo "Test start, running for $1 seconds..."
timeout $1s taskset -c $2 ./xApp_ONF --logLevel=info --initiationTime=$INITIATIONTIME --cellIndLimit=$CELLINDLIMIT --file= --qValue=$QVALUE --parallelLoop=$PARALLELLOOP --preprocessing=$PREPROCESSING || true
delete_topo_objects
python3 parse_log.py
echo "Test finished"
