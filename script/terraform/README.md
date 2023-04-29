
### Use CSP storage 

The Kubernetes deployment uses an internal docker registry to serve docker images to the workers. This registry is controlled by a boolean variable `k8s_enable_registry`. The docker registry is enabled by default on any Cloud deployment and disabled for any on-premeses deployment.

```
# terraform-config.aws.tf
...
   output "options" {
     value = {
       ...
       k8s_enable_registry: true
       ...
     }
   }
...
```

For Cloud deployment, you can choose to use vendor-specific object storage to cache the docker registry content, which can speed up loading docker images to the Cloud workers. The following subsections describe the variables that you need to enable for each Cloud vendor.   

#### Cache to the AWS S3 Storage

Add the following options to the AWS configuration file:

```
# terraform-config.aws.tf
...
  output "options" {
    value = {
      ...
      k8s_registry_storage: "aws",
      k8s_registry_aws_storage_bucket: "registry-content",
      k8s_registry_aws_storage_region: local.region,
      ...
    }
  }
...
```

#### Cache to the GCP Storage

Add the following options to the GCP configuration file:

```
# terraform-config.gcp.tf
...
  output "options" {
    value = {
      ...
      k8s_registry_storage: "gcp",
      k8s_registry_gcp_storage_bucket: "registry-cache",
      k8s_registry_gcp_storage_key_file: "service-account-apikey.json"
      ...
    }
  }
...
```

where the service account key file should be placed under `script/csp/.config/gcloud`.   

#### Cache to the Azure Storage

---
Under development
---

Add the following options to the Azure configuration file:

```
# terraform-config.azure.tf
...
  output "options" {
    value = {
      ...
      k8s_registry_storage: "azure",
      k8s_registry_azure_storage_resource_group: "registry-cache",
      k8s_registry_azure_storage_account_name: "registry-docker",
      k8s_registry_azure_storage_container_name: "docker",
      ...
    }
  }
...
```

#### Cache to the Tencent Storage

---
Under development
---

Add the following options to the Tencent configuration file:

```
# terraform-config.tencent.tf
...
  output "options" {
    value = {
      ...
      k8s_registry_storage: "tencent",
      k8s_registry_tencent_storage_bucket: "registry-content",
      k8s_registry_tencent_storage_region: local.region,
      ...
    }
  }
...
```

