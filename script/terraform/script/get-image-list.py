#!/usr/bin/env python3
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

import os
import yaml

KUBERNETES_CONFIG = "kubernetes-config.yaml"
COMPOSE_CONFIG = "compose-config.yaml"
WORKLOAD_CONFIG = "workload-config.yaml"


def _WalkTo(node, name):
  try:
    if name in node:
      return node
    for item1 in node:
      node1 = _WalkTo(node[item1], name)
      if node1:
        return node1
  except Exception:
    return None
  return None


def _ScanK8sImages(images):
  if os.path.exists(KUBERNETES_CONFIG):
    with open(KUBERNETES_CONFIG) as fd:
      for doc in yaml.safe_load_all(fd):
        if doc:
          spec = _WalkTo(doc, "spec")
          if not spec:
            continue
          for c1 in ["containers", "initContainers"]:
            spec = _WalkTo(doc, c1)
            if spec:
              for c2 in spec[c1]:
                if "image" in c2:
                  images[c2["image"]] = 1


def _ScanComposeImages(images):
  if os.path.exists(COMPOSE_CONFIG):
    with open(COMPOSE_CONFIG) as fd:
      for doc in yaml.safe_load_all(fd):
        if doc:
          if "services" in doc:
            for svc in doc["services"]:
              if "image" in doc["services"][svc]:
                images[doc["services"][svc]["image"]] = 1


def _ScanDockerImage(images):
  workload_config={}
  if os.path.exists(WORKLOAD_CONFIG):
    with open(WORKLOAD_CONFIG) as fd:
      for doc in yaml.safe_load_all(fd):
        if doc:
          workload_config.update(doc)

  image = workload_config.get("docker_image", "")
  if image:
    images[image] = 1


images = {}
_ScanDockerImage(images)
_ScanComposeImages(images)
_ScanK8sImages(images)
for image in images:
  print(image)
