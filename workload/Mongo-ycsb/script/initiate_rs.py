#!/usr/bin/env python2
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

import time
import os
import pymongo

job_index      = int(os.environ.get('JOB_COMPLETION_INDEX') or 0)
server_address = os.environ.get('MONGODB_SERVER') or 'localhost'
server_port    = 27017+job_index
ssl            = int(os.environ.get('m_tls_flag') or 0)

uri = "%s-%s:%s" % (server_address, server_port, server_port)

options = ""
if ssl == 1:
    options = "?ssl=true"

myclient = pymongo.MongoClient("mongodb://%s/%s" % (uri, options))

config = {
    '_id': 'rs0', 'members': [
        {'_id': 0, 'host': uri, 'priority': 5 }
    ]
}

print("Enabling RS in %s%s\n" % (uri, options))
try:
    print(myclient.admin.command("replSetInitiate", config))
    print("Replica set activated!\n")
except pymongo.errors.OperationFailure as e:
    print(e.message)
    print(e.args)
    print("Replica set failure or existing\n")

print("Waiting for replication status:")
i = 0
while i < 15:
    data = {}
    status = ""
    try:
        data = myclient.admin.command("replSetGetStatus", 1)
        status = data.get('members')[0].get('stateStr')
    except pymongo.errors.OperationFailure:
        status = "NotYetInitialized"

    print(status)
    if status == 'PRIMARY':
        break
    time.sleep(1)
    i += 1
