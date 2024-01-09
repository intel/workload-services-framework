#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(../../template/config.m4)

apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongodb-server
  labels:
    app: mongodb-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mongodb-server
  template:
    metadata:
        labels:
          app: mongodb-server
          name: MONGODB-SERVER
          deployPolicy: standalone
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
      - name: mongodb-server
        image: IMAGENAME(Dockerfile.1.defn(`OPTIONS'))
        imagePullPolicy: IMAGEPOLICY(Always)
        ports:
          - containerPort: 27017
        securityContext:
          privileged: true
        command: ["/bin/bash", "-c", "/tests/mongodb_service.sh | tee -a mongo_server.log && sleep infinity"]
        args:
          - |
            chmod +x /tests/mongodb_service.sh
            /tests/mongodb_service.sh
        volumeMounts:
          - name: mongodb-stack-volume
            mountPath: /tests
      volumes:
      - name: mongodb-stack-volume
        configMap:
          name: mongodb-stack-cm
          defaultMode: 0744
---

apiVersion: v1
kind: Service
metadata:
  name: mongodb-server-service
  labels:
    name: mongodb-server-service
spec:
  ports:
    - port: 27017
      protocol: TCP
      name: mongodb-server
  selector:
    app: mongodb-server
  type: ClusterIP
---

apiVersion: batch/v1
kind: Job
metadata:
  name: unittest
spec:
  template:
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
      - name: unittest
        image: IMAGENAME(Dockerfile.1.defn(`OPTIONS'))
        imagePullPolicy: IMAGEPOLICY(Always)
        securityContext:
          privileged: true
        command: ["/bin/bash", "-c", "/tests/unittest.sh"]
        args:
          - |
            chmod +x /tests/unittest.sh
            /tests/unittest.sh
        volumeMounts:
          - name: unittest-volume
            mountPath: /tests
      volumes:
      - name: unittest-volume
        configMap:
          name: unittest-cm
          defaultMode: 0744
      restartPolicy: Never

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: mongodb-stack-cm
data:
  mongodb_service.sh: |
    #!/bin/bash

    db_path="/var/lib/mongodb"
    log_path="/var/log/mongodb/mongo.log"
    rm -rf $db_path    # Ensure no db files exist from previous runs
    mkdir -p $db_path  # Create DB subfolder
    mkdir -p /var/log/mongodb
    rm -rf /var/log/mongodb/*
    eval "touch $log_path"
    cd /usr/src/mongodb/bin
    ./mongod --port 27017 --bind_ip_all --fork --logpath $log_path --dbpath $db_path

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: unittest-cm
data:
  unittest.sh: |
    #!/bin/bash

    COUNTER=0
    LIMIT=180
    FLAG=1
    nc -z -w5 mongodb-server-service 27017
    FLAG=$?
    until ((FLAG == 0)); do
            ((COUNTER++))
            echo "mongodb-server-service connection are unstable for $COUNTER seconds"
            nc -z -w5 mongodb-server-service 27017
            FLAG=$?
            if [ $COUNTER -ge $LIMIT ]; then
                echo "Connection FAILED after $COUNTER seconds"
                exit 1 ;
            fi
            sleep 1
        done
    echo "SUCCESS"