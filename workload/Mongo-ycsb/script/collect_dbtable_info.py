#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
from pymongo import MongoClient
import json
import sys

host = sys.argv[1]
port = int(sys.argv[2])

client = MongoClient(host, port)
db = client['ycsb']
stats = db.command("collstats", "usertable")

with open('/usr/src/ycsb_output.json', 'w') as f:
    json.dump(stats, f)