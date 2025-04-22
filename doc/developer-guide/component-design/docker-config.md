
# Scheduling containers

The `docker-config.yaml` script is a manifest that describes how to schedule the workload container(s) on multiple hosts (described by `cluster-config.yaml`.) 

You can choose to write `docker-config.yaml` in any of the following formats:
- `docker-config.yaml.m4`: Use the `.m4` template to add conditional statements in the docker-config script.  
- `docker-config.yaml.j2`: Use the `.j2` template to add conditional statements in the docker-config script.  

# DOCKER-CONFIG Format

The `docker-config.yaml` uses the following syntax:

```
worker-0:
- image: "{{ REGISTRY }}image-name{{ IMAGESUFFIX }}{{ RELEASE }}"
  options:
  - -e VAR1=VALUE1
  - -e VAR2=VALUE2
  command: "/bin/bash -c 'echo hello world'"
  export-logs: true
```
where
- The top level keys are the SUT hostnames. The number of the SUT hosts must match what is specified in `cluster-config.yaml`. The SUT hosts are named against their SUT workgroup. For example, for the workers, the SUT hosts are named as `worker-0`, `worker-1`, etc. For clients, the SUT hosts are named as `client-0`, `client-1`, etc.  
- The value of each SUT host is a list of containers to be scheduled on the SUT host. The list order is not enforced.  
- Each container is described as a dictionary of
  - `image`: Specify the full docker image name
  - `options`: Specify the docker run command line arguments, as a string or a list.
  - `command`: Optional. Specify any startup command. This will overwrite whatever is defined in the docker image.
  - `export-logs` or `service-logs`: Optional. Specify whether logs should be collected on the container.

> The script will first collect logs on containers whose `export-logs` is true, which also signals that the workload execution is completed. Then collect logs on containers whose `service-logs` is `true`. `export-logs` and `service-logs` are exclusive options and can not both be true.

# Test Time Considerations

At test time, the validation script launches the containers described in `docker-config.yaml`, for example, 2 containers on `worker-0` and 1 on `worker-1`. The launch order is not enforced thus the workload must implement alternative locking mechanism if the launch order is important.  

> If `docker-config.yaml` exists, the settings will take precedent over `DOCKER_IMAGE` and `DOCKER_OPTIONS`, specified in `validate.sh`.   

To faciliate SUT-level network communication, the list of all SUT private IP addresses are provided to each container runtime as environment variables, for example, `WORKER_0_HOST=10.20.30.40`, `WORKER_1_HOST=20.30.40.50`, `CLIENT_0_HOST=30.40.50.60`, etc. The workload can then use the IP addresses to setup services and communicate among the SUT hosts.  

