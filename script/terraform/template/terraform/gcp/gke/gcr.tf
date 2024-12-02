#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

resource "google_artifact_registry_repository" "default" {
  location = local.region
  repository_id = "wsf-${var.job_id}-gcr"
  format = "DOCKER"
  labels = var.common_tags
}

locals {
  repository_url = format("%s-docker.pkg.dev/%s/%s", local.region, local.project_id, google_artifact_registry_repository.default.repository_id)
  repository_prefix = replace(local.repository_url,"//.*/","")
}

resource "local_file" "container_auth" {
  content = jsonencode({
    "credHelpers": {
        (local.repository_prefix) = "gcloud"
    }
  })
  filename = "/home/.config/containers/auth.json"
  file_permission = "0600"
}

