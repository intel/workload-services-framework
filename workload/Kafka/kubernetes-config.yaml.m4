include(config.m4)

apiVersion: apps/v1
kind: Deployment
metadata:
  name: zookeeper-kafka-server
  labels:
    app: zookeeper-kafka-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: zookeeper-kafka-server
  template:
    metadata:
      labels:
        app: zookeeper-kafka-server
        zoo-producer-consumer: anti
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
      - name: zookeeper-kafka-server-container
        image: IMAGENAME(Dockerfile.1.server)
        imagePullPolicy: IMAGEPOLICY(Always)
        ports:
          - containerPort: 2181
          - containerPort: 9092
          - containerPort: 9093
ifelse(index(TESTCASE,_3n),-1,,`dnl
      PODANTIAFFINITY(required,zoo-producer-consumer,anti)
')dnl

---
apiVersion: v1
kind: Service
metadata:
  name: zookeeper-kafka-server-service
  labels:
    name: zookeeper-kafka-server-service
spec:
  ports:
    - port: 2181
      protocol: TCP
      name: zookeeper-kafka-server-1
    - port: 9092
      protocol: TCP
      name: zookeeper-kafka-server-2
    - port: 9093
      protocol: TCP
      name: zookeeper-kafka-server-3
 
  selector:
    app: zookeeper-kafka-server
  type: ClusterIP

---
apiVersion: batch/v1
kind: Job
metadata:
  name: kafka-topic-creator
spec:
  template:
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      initContainers:
        - name: wait-for-zookeeper-kafka-server-service
          image: busybox:1.28
          command: ['sh', '-c', "until nc -z -w5 zookeeper-kafka-server-service 9092; do echo waiting for kafka service; sleep 2; done"]
        - name: wait-for-zookeeper-server-service
          image: busybox:1.28
          command: ['sh', '-c', "until nc -z -w5 zookeeper-kafka-server-service 2181; do echo waiting for zookeeper service; sleep 2; done"]
      containers:
      - name: kafka-topic-creator-container
        image: IMAGENAME(Dockerfile)
        imagePullPolicy: IMAGEPOLICY(Always)
        command: ["sh", "-c", "run_test.sh && sleep infinity"]
        env:
          - name: IDENTIFIER
            value: "topic"
          - name: ZOOKEEPER_SERVER
            value: "zookeeper-kafka-server-service:2181"
          - name: K_REPLICATION_FACTOR
            value: "defn(`REPLICATION_FACTOR')"
          - name: K_PARTITIONS
            value: "defn(`PARTITIONS')"
          - name: K_KAFKA_BENCHMARK_TOPIC
            value: "defn(`KAFKA_BENCHMARK_TOPIC')"
      PODAFFINITY(required,app,zookeeper-kafka-server)
      restartPolicy: Never
  backoffLimit: 2

---
apiVersion: batch/v1
kind: Job
metadata:
  name: benchmark
spec:
  template:
    metadata:
      labels:
        zoo-producer-consumer: anti
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      initContainers:
        - name: wait-for-topic-created
          image: IMAGENAME(Dockerfile)
          imagePullPolicy: IMAGEPOLICY(Always)
          command: ["sh", "-c", "until kafka-topics.sh --list --zookeeper zookeeper-kafka-server-service:2181 | grep KAFKA_BENCHMARK_TOPIC ; do echo waiting for topic; sleep 10; done"]
      containers:
      - name: benchmark
        image: IMAGENAME(Dockerfile)
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
          - name: IDENTIFIER
            value: "producer"
          - name: KAFKA_SERVER
            value: "zookeeper-kafka-server-service:9092"
          - name: K_KAFKA_BENCHMARK_TOPIC
            value: "defn(`KAFKA_BENCHMARK_TOPIC')"
          - name: K_NUM_RECORDS
            value: "defn(`NUM_RECORDS')"
          - name: K_THROUGHPUT
            value: "defn(`THROUGHPUT')"
          - name: K_RECORD_SIZE
            value: "defn(`RECORD_SIZE')"
          - name: K_COMPRESSION_TYPE
            value: "defn(`COMPRESSION_TYPE')"
          - name: K_MESSAGES
            value: "defn(`MESSAGES')"
          - name: K_PRODUCERS
            value: "defn(`PRODUCERS')"
          - name: K_CONSUMER_TIMEOUT
            value: "defn(`CONSUMER_TIMEOUT')"
      restartPolicy: Never
ifelse(index(TESTCASE,_3n),-1,,`dnl
      PODANTIAFFINITY(required,zoo-producer-consumer,anti)
')dnl
ifelse(index(TESTCASE,_1n),-1,,`dnl
      PODAFFINITY(required,app,zookeeper-kafka-server)
')dnl

---
apiVersion: batch/v1
kind: Job
metadata:
  name: benchmarkconsumer
spec:
  template:
    metadata:
      labels:
        zoo-producer-consumer: anti
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      initContainers:
        - name: wait-for-topic-created
          image: IMAGENAME(Dockerfile)
          imagePullPolicy: IMAGEPOLICY(Always)
          command: ["sh", "-c", "until kafka-topics.sh --list --zookeeper zookeeper-kafka-server-service:2181 | grep KAFKA_BENCHMARK_TOPIC ; do echo waiting for topic; sleep 10; done"]
      containers:
      - name: kafka-consumer-container 
        image: IMAGENAME(Dockerfile)
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
          - name: IDENTIFIER
            value: "consumer"
          - name: KAFKA_SERVER
            value: "zookeeper-kafka-server-service:9092"
          - name: K_KAFKA_BENCHMARK_TOPIC
            value: "defn(`KAFKA_BENCHMARK_TOPIC')"
          - name: K_NUM_RECORDS
            value: "defn(`NUM_RECORDS')"
          - name: K_THROUGHPUT
            value: "defn(`THROUGHPUT')"
          - name: K_RECORD_SIZE
            value: "defn(`RECORD_SIZE')"
          - name: K_COMPRESSION_TYPE
            value: "defn(`COMPRESSION_TYPE')"
          - name: K_MESSAGES
            value: "defn(`MESSAGES')"
          - name: K_CONSUMERS
            value: "defn(`CONSUMERS')"
          - name: K_CONSUMER_TIMEOUT
            value: "defn(`CONSUMER_TIMEOUT')"
      restartPolicy: Never
ifelse(index(TESTCASE,_3n),-1,,`dnl
      PODANTIAFFINITY(required,zoo-producer-consumer,anti)
')dnl
ifelse(index(TESTCASE,_1n),-1,,`dnl
      PODAFFINITY(required,app,zookeeper-kafka-server)
')dnl
