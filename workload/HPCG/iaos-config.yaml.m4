#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
knobs_definition:
  pkb_PROCESS_PER_NODE:
    name: "PROCESS_PER_NODE"
    description: ""
    type: pkb
    values:
      enum:
        - "numa"
        - "socket"
        - "1"
    default: "numa"
  pkb_OMP_NUM_THREADS:
    name: "OMP_NUM_THREADS"
    description: ""
    type: pkb
    values:
      enum:
        - "numa"
        - "socket"
        - "1"
        - "2"
        - "4"
    default: "numa"
  pkb_KMP_AFFINITY:
    name: "KMP_AFFINITY"
    description: ""
    type: pkb
    values:
      enum:
        - "threadcompact1"
        - "compact0"
        - "compact1"
    default: "threadcompact1"

metrics_definition:
  - name: "Throughput"
    goal: "maximize"
    metric: "Throughput (GFlop/s)"
    expected_improvement: 100
    source: workload
    weight: 1.0

pkb_options:
  workload_name: HPCG
  documentation_url: ""
  flags:
    X_DIMENSION:
      value: 192
    Y_DIMENSION:
      value: 192
    Z_DIMENSION:
      value: 192
    RUN_SECONDS:
      value: 30
    MPI_AFFINITY:
      value: "numa"
  vm_groups:
    target:
      needs_volumes: False
  run_label: hpcg

wos_options:
  num_random_generations: 3
  num_bo_generations: 3