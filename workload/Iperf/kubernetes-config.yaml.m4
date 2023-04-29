include(config.m4)

---

apiVersion: batch/v1
kind: Job
metadata:
  name: iperf-server
spec:
  template:
    metadata:
      labels:
        app: iperf-server
    spec:
      restartPolicy: Never
      PODANTIAFFINITY(required,app,iperf-client)
      containers:
      - name: iperf-server
        image: IMAGENAME(Dockerfile.1.iperf)
        imagePullPolicy: IMAGEPOLICY(Always)
        ports:
        - containerPort: defn(`SERVER_POD_PORT')
          protocol: defn(`PROTOCOL')
        env:
        - name: `IPERF_VER'
          value: "defn(`IPERF_VER')"
        - name: `PROTOCOL'
          value: "defn(`PROTOCOL')"
        - name: `SERVER_POD_PORT'
          value: "defn(`SERVER_POD_PORT')"
        - name: `SERVER_CORE_COUNT'
          value: "defn(`SERVER_CORE_COUNT')"
        - name: `SERVER_CORE_LIST'
          value: "defn(`SERVER_CORE_LIST')"
        - name: `SERVER_OPTIONS'
          value: "defn(`SERVER_OPTIONS')"
        - name: `ONLY_USE_PHY_CORE'
          value: "defn(`ONLY_USE_PHY_CORE')"
        - name: `CLIENT_OR_SERVER'
          value: "server"
        - name: `PARALLEL_NUM'
          value: "defn(`PARALLEL_NUM')"
      - name: iperf-nginx
        image: IMAGENAME(Dockerfile.2.nginx)
        imagePullPolicy: IMAGEPOLICY(Always)
        ports:
        - containerPort: 80

---

apiVersion: v1
kind: Service
metadata:
  labels:
    app: defn(`IPERF_SERVICE_NAME')
  name: defn(`IPERF_SERVICE_NAME')
spec:
ifelse("defn(`MODE')","pod2pod",`dnl
  clusterIP: None
')dnl
  selector:
    app: iperf-server
  ports:
  - protocol: defn(`PROTOCOL')
    port: defn(`SERVER_POD_PORT')
    targetPort: defn(`SERVER_POD_PORT')
    name: iperf-server-pod-port
  - protocol: TCP
    port: 80
    targetPort: 80
    name: iperf-server-nginx-pod-port
ifelse("defn(`MODE')","ingress",`dnl
  externalIPs:
  - 127.0.0.1
')dnl

ifelse("defn(`MODE')","ingress",,`
---

apiVersion: batch/v1
kind: Job
metadata:
  name: iperf-client
  labels:
    application: "iperf-client"
spec:
  template:
    metadata:
      labels:
        app: iperf-client
    spec:
      PODANTIAFFINITY(required,app,iperf-server)
      initContainers:
        - name: wait-for-iperf-server-service
          image: docker.io/library/busybox:1.28
          command: 
          - "sh"
          - "-c"
          - |
            while [ $(wget --server-response --no-check-certificate http://IPERF_SERVICE_NAME:80 2>&1 | awk "/ HTTP/{print \$2}") -ne 200 ]; do
              echo Waiting...
              sleep 5s
            done
      containers:
      - name: iperf-client
        image: IMAGENAME(Dockerfile.1.iperf)
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
        - name: `IPERF_VER'
          value: "defn(`IPERF_VER')"
        - name: `MODE'
          value: "defn(`MODE')"
        - name: `PROTOCOL'
          value: "defn(`PROTOCOL')"
        - name: `IPERF_SERVICE_NAME'
          value: "defn(`IPERF_SERVICE_NAME')"
        - name: `SERVER_POD_PORT'
          value: "defn(`SERVER_POD_PORT')"
        - name: `CLIENT_CORE_COUNT'
          value: "defn(`CLIENT_CORE_COUNT')"
        - name: `CLIENT_CORE_LIST'
          value: "defn(`CLIENT_CORE_LIST')"
        - name: `CLIENT_OPTIONS'
          value: "defn(`CLIENT_OPTIONS')"
        - name: `ONLY_USE_PHY_CORE'
          value: "defn(`ONLY_USE_PHY_CORE')"
        - name: `PARALLEL_NUM'
          value: "defn(`PARALLEL_NUM')"
        - name: `CLIENT_TRANSMIT_TIME'
          value: "defn(`CLIENT_TRANSMIT_TIME')"
        - name: `BUFFER_SIZE'
          value: "defn(`BUFFER_SIZE')"
        - name: `UDP_BANDWIDTH'
          value: "defn(`UDP_BANDWIDTH')"
        - name: `CLIENT_OR_SERVER'
          value: "client"
      restartPolicy: Never
  backoffLimit: 5
')
