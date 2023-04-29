define(`redisService',`
---
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: smt-redis
spec:
  replicas: 1
  selector:
    matchLabels:
      name: smt-redis
  template:
    metadata:
      labels:
        name: smt-redis
    spec:
      containers:
        - name: smt-redis
          image: IMAGENAME(Dockerfile.3.redis)
          imagePullPolicy: IMAGEPOLICY(Always)
          ports:
            - containerPort: 6379
              name: redis
              protocol: TCP
      nodeSelector:
        HAS-SETUP-STORAGE: "yes"
---
apiVersion: v1
kind: Service
metadata:
  name: smt-redis
  labels:
    name: smt-redis
spec:
  type: NodePort
  ports:
    - name: smt-redis
      port: 6380
      targetPort: 6379
      nodePort: 31380
  selector:
    name: smt-redis
')