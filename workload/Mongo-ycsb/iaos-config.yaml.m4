#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
knobs_definition:
  pkb_THREADS:
    name: "THREADS"
    description: ""
    type: pkb
    values:
      range:
        start: 1
        stop: 96
        step: 4
      default: 10

metrics_definition:
  - name: "throughput"
    goal: "maximize"
    metric: "Sum of \[run phase\] Throughput"
    expected_improvement: 500
    source: workload
    weight: 1.0

pkb_options:
  workload_name: Mongo
  documentation_url: ""
  flags:
    TARGET:
      value: 0
  run_label: mgo

wos_options:
  num_random_generations: 30
  num_bo_generations: 30
