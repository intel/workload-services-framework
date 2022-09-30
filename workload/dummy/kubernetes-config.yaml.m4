include(config.m4)

# You can specify the Kubernetes deployment in the format of a kubernetes-config.yaml.m4
# or helm charts. See WordPress5MT as an example of using helm charts.  

# The IMAGENAME macro extract the docker image name from the Dockerfile and apply 
# REGISTRY and RELEASE tags. 

# The IMAGEPOLICY macro specifies the image pulling policy. If REGISTRY is defined,
# the image pull policy is default to IfNotExist, or else Always. 

apiVersion: batch/v1
kind: Job
metadata:
  name: dummy-benchmark
spec:
  template:
    spec:
      containers:
      - name: dummy-benchmark
        image: IMAGENAME(Dockerfile)
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
        - name: `SCALE'
          value: "SCALE"
      restartPolicy: Never
