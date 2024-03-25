# Overview

Outlined below are the instructions to setup the gRPC Go server. 

## Requirements
- go v1.22.1 linux/amd64
- grpc v1.62.2
- ghz v0.110.0

## General Setup

These instructions are similar to the ones [described here](https://grpc.io/docs/languages/go/quickstart/). 

1. Install the [go release](https://go.dev/doc/install).

2. Install the [protobuf compiler](https://grpc.io/docs/protoc-installation/).

3. Install the protobuf compiler plugins.

```
$ go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.27
$ go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.2
```

4. Update Path variable.

```
$ export PATH="$PATH:$(go env GOPATH)/bin"
```

5. Update generate the `go.sum` file:

```
$ cd grpc_servers_impl/go
$ go mod tidy
```

Compile the Go server:

```
$ cd grpc_servers_impl/go
$ make
```

# How to use

1. Start two terminals and navigate to the folder of this project.
2. In one of the terminals, start the server:


```
$ cd grpc_servers_impl/go
$ ./build/server
```


3. In the other terminal, run the load generator using the Echo message:

```
$ ghz --config ghz_configs/echo.json
```

To benchmark with B1M1 message, use the following command instead:

```
$ ghz --config ghz_configs/B1M1.json
```

Note: 
- The command above assumes that `ghz` is globally available. Adjust the command as needed if the setup is different.


# Other notes

- The implementation of this server is based on [main.go](https://github.com/grpc/grpc-go/blob/master/examples/helloworld/greeter_server/main.go).
- Futher usage of ghz can be found at https://ghz.sh/docs/examples
- Any performance claims are made with go v1.17.4 linux/amd64. The versions for other used components can be found in the requirements section.

**IMPORTANT: this material is not to be used for production purposes and is only for evaluation.**
