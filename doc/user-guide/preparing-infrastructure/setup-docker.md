
## Introduction

The `docker` validation backend runs any workloads locally on the development host, either through multiple docker sessions or through docker-compose. 

## Execute a Workload

Switch to the docker validation backend as follows:

```
cd build
cmake -DBACKEND=docker ..     # Select the docker backend 
```

Then test any workload as follows:
```
cmake -DBENCHMARK=dummy ..                      # Select the dummy workload
./ctest.sh -N                                   # List all testcases
./ctest.sh -R _pkm -V                           # Run the _pkm testcase
./list-kpi.sh workload/dummy/logs-dummy_pi_pkm  # Show the KPIs
```

## Setup arm64 Emulation

You can setup the development host as an arm64 emulator. To do so, run the `setup.sh` script:

```
script/march/setup.sh
```

## See Also

- [cmake commands](../executing-workload/cmake.md)   
- [ctest commands](../executing-workload/ctest.md)   

