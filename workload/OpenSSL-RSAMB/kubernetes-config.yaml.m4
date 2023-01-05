include(config.m4)

apiVersion: batch/v1
kind: Job
metadata:
  name: benchmark
spec:
  template:
    spec:
      containers:
      - name: benchmark
        image: IMAGENAME(Dockerfile.2.patsubst(WORKLOAD,`.*_'))
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
        - name: `CONFIG'
          value: "CONFIG"
        - name: `PROCESSES'
          value: "PROCESSES"
        - name: `BIND_CORE'
          value: "BIND_CORE"
        - name: `BIND'
          value: "BIND"
        - name: `ASYNC_JOBS'
          value: "ASYNC_JOBS"
      restartPolicy: Never
  backoffLimit: 4
