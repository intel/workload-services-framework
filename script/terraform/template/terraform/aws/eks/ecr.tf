#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

resource "aws_ecr_repository" "default" {
  name = "wsf-${var.job_id}-ecr"
  force_delete = true

  tags = {
    Name  = "wsf-${var.job_id}-ecr"
  }
}

resource "null_resource" "docker_auth" {
  triggers = {
    repository_url = aws_ecr_repository.default.repository_url
  }

  provisioner "local-exec" {
    command = format("mkdir -p /home/.config/containers && aws ecr get-login-password --region %s | REGISTRY_AUTH_FILE=/home/.config/containers/auth.json skopeo login --username AWS --password-stdin %s", local.region, replace(aws_ecr_repository.default.repository_url, "//.*/", ""))
  }

  provisioner "local-exec" {
    command = "rm -f /home/.config/containers/auth.json"
    when = destroy
  }
}

