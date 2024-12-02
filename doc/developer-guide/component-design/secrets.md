### Introduction

This document describes how to handle secrets (such as an access token) in the workload development. 

### Configure Secrets

Store user secrets under `$PROJECTDIR/script/csp/.<domain>/config.json` (with mode `600`), where `$PROJECTDIR` is the root of the repository, and `.<domain>/config.json` is a domain specific configuration file. The JSON format is preferred but it can be any convenient format.  

```json
{
   "token": "1234567890"
}
```

### Read Secrets

The workload `validate.sh` can read the workload secrets into environment variables. Special care must be taken not to expose the secret values:

- Declare the secret variable in `WORKLOAD_PARAMS` with a leading `-`. This will ensure that the secret values won't be accidentally shown on the screen, in any of the visible configuration files, or be uploaded to the WSF dashboard in subsequent operations.    

```
WORKLOAD_PARAMS=(-TOKEN)
```

- The WSF assumes a limited set of host-level utilities that can be used in bash scripts. `jq` (a popular utility to access json constructs) is not one of them. You can instead use `sed` to parse the json configuration file. While parsing the secret values, pay attention **not to expose the values directly on the command line**.   

```
TOKEN="$(sed -n '/"token":/{p;q}' "$PROJECTDIR"/script/csp/.mydomain/config.json | cut -f4 -d'"')"
```

### Use Secrets in Docker

To use the workload secrets in a docker execution, declare `DOCKER_OPTIONS` in `validate.sh`:

```
# In validate.sh, you can declare DOCKER_OPTIONS for single container workloads.  
DOCKER_OPTIONS="-e TOKEN" 
```

or use a dedicated `docker-config.yaml`:
```
worker-0:
- image: ...
  options:
  - -e TOKEN
...
```

> **Do not expose the TOKEN value on the command line.** Let docker read from the environment instead. 

### Use Secrets in Docker-Compose

To use workload secrets in a docker-compose file, use the environment variables to access the secret values:

```
# compose-config.yaml
services:
  my-workload-service:
    image: ...
    environment:
      TOKEN: "${TOKEN}"
...
```

### Use Secrets in Kubernetes Scripts/Helm Charts:

Use the `workload-config` secret (auto-generated) to access the workload secrets in a Kubernetes configuration file or in Helm Charts:

```
# kubernetes-config.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: my-workload
spec:
  template:
    spec:
      containers:
      - name: my-workload
        image: ...
        env:
        - name: TOKEN
          valueFrom:
            secretKeyRef:
              name: workload-config
              key: TOKEN
...
```

### Access Secretes in Native Ansible Scripts

Use the following code snippets to use the workload secrets as environment variables. Be careful not to show the secret values in the ansible debugging output or on the command line on a SUT.  

```
# deployment.yaml
- name: Use my secret
  command: curl --header $TOKEN ...
  environment: "{{ workload_secrets }}"
  vars:
    workload_secrets: "{{ lookup('file',wl_logs_dir+'/.workload-secret.yaml) | from_yaml }}"
```
















