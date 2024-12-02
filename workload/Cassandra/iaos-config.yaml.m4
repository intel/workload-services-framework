#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
knobs_definition:
  pkb_CLIENT_THREADS:
    name: "CLIENT_THREADS"
    description: ""
    type: pkb
    values:
      range:
        start: 128
        stop: 384
        step: 50
      default: 256
  pkb_INSTANCE_NUM:
    name: "INSTANCE_NUM"
    description: ""
    type: pkb
    values:
      range:
        start: 4
        stop: 40
        step: 6
      default: 16
  pkb_CLIENT_REQUEST_CPU:
    name: "CLIENT_REQUEST_CPU"
    description: ""
    type: pkb
    values:
      range:
        start: 64
        stop: 126
        step: 10
      default: 64

metrics_definition:
  - name: "Oprate"
    goal: "maximize"
    metric: "Final Op rate"
    expected_improvement: 100
    source: workload
    weight: 1.0

pkb_options:
  workload_name: Cassandra
  documentation_url: ""
  flags:
    CLIENT_DURATION:
      value: 5m
    CLIENT_REQUEST_CPU_ENABLE:
      value: true
    DATA_COMPRESSION:
      value: LZ4Compressor
    DATA_CHUNK_SIZE:
      value: 64
    DATA_COMPACTION:
      value: SizeTieredCompactionStrategy
    CLIENT_INSERT:
      value: 30
    CLIENT_SIMPLE:
      value: 70
  vm_groups:
    target:
      needs_volumes: False
  run_label: cansa

wos_options:
  num_random_generations: 4
  num_bo_generations: 4
