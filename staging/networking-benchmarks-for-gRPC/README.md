# Overview

This project has gRPC server implementations for Go and C++ runtimes.

The two servers were benchmarked on both ICX and SPR.

The project uses [ghz v0.110.0](https://github.com/bojand/ghz/releases/tag/v0.110.0) for load generation.


## Folder Layout

```
├── ghz_configs            # ghzconfigs for echo and HyperProtoBench
├── grpc_servers_impl      # server implementations for grpc 
│   ├── cpp                # cpp implementation 
│   └── go                 # golang implementation
├── protos                 # upper directory of proto files for grpc 
│   ├── echo               # proto files for echo
│   └── hyper_proto_bench  # proto files for hyper_proto_bench  
```


**IMPORTANT: this material is not to be used for production purposes and is only for evaluation.**
