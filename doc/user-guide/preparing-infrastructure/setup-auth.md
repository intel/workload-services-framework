
# Setup Docker Registry

A private docker registry is optional in most of the validation scenarios except if you want to run the workloads on an On-Premises  Kubernetes cluster, or you explicitly setup a docker registry to store any newly built workload images.

This document describes how to authenticate to a docker registry if the registry requires authentication. Skip this document if there is no authentication requirement.

## `REGISTRY_AUTH`

The [`cmake`][cmake] `REGISTRY_AUTH` option specifies how to authenticate to a private docker registry. Currently, `docker` and `pass` are the only supported values, which uses the docker authentication mechanism or docker-credential-pass with pass as password store.

### Docker

Enable the `REGISTRY_AUTH` option:

```
cmake -DREGISTRY=<url> -DREGISTRY_AUTH=docker ..
```

With the above command, the validation scripts will upload the docker authentication information specified in `.docker/config.json` as a Kubernetes `imagePullSecret` to the validation cluster, On-Premises or in Cloud.

> `CredHelpers` or `CredStore` in `.docker/config.json` is not supported.

### Pass

Enable the `REGISTRY_AUTH` option:

```
cmake -DREGISTRY=<url> -DREGISTRY_AUTH=pass ..
```

Version for both pass and docker-credential-pass binaries is read automatically. With the above command, the validation scripts will make the `pass` and `gpg` session available on execution machine.

### Authenticate to Cloud Private Registry

### Amazon Elastic Container Registry

```
make aws
$ aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com
$ exit
```

> Note that the build script will auto-create the image repository namespaces.

### Google Cloud Container Registry

```
make gcp
$ gcloud auth activate-service-account --key-file <key-file>
$ gcloud auth print-access-token | docker login -u oauth2accesstoken --password-stdin <registry-url>
$ exit
```

> Note that the Oauth2 access token will expire in an hour.


### Azure Container Registry:

```
make azure
$ az acr login --name <registry-name> --expose-token --output tsv --query accessToken | docker login -username 00000000-0000-0000-0000-000000000000 --password-stdin <registry-url>
$ exit
```

[cmake]: ../../user-guide/executing-workload/cmake.md