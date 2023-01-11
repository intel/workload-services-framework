# Overview

Outlined below are the instructions to setup the gRPC C++ server. 

## Requirements
- grpc v1.49.0
- ghz v0.110.0


## General Setup

These instructions are similar to the ones [described here](https://grpc.io/docs/languages/cpp/quickstart/). 


Choose a directory to hold locally installed packages. 
This setup assumes that the environment variable MY_INSTALL_DIR holds this directory path. Use a specific location to avoid installing gRPC libraries system-wide:

```
$ export MY_INSTALL_DIR=$HOME/.local
$ mkdir -p $MY_INSTALL_DIR
```

Add the local bin folder to your path variable, for example:

```
$ export PATH="$MY_INSTALL_DIR/bin:$PATH"
```

Install support libraries:
```
$ sudo apt install -y build-essential autoconf libtool pkg-config
```

**Note** `openssl` may also be needed to be installed to build and install gRPC.


Clone gRPC repo:

```
$ git clone --recurse-submodules -b v1.49.0 --depth 1 --shallow-submodules https://github.com/grpc/grpc
```

Build and install gRPC and Protocol Buffers:

```
$ cd grpc
$ mkdir -p cmake/build
$ pushd cmake/build
$ cmake -DgRPC_INSTALL=ON \
      -DgRPC_BUILD_TESTS=OFF \
      -DCMAKE_INSTALL_PREFIX=$MY_INSTALL_DIR \
      ../..
$ make -j
$ make install
$ popd
```


Adjust the following environment variable:

```
$ export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:$MY_INSTALL_DIR/lib/pkgconfig 
```


Compile the C++ server:

```
$ cd grpc_servers_impl/cpp
$ make
```

# How to use

1. Start two terminals and navigate to the folder of this project.
2. In one of the terminals, start the server:


```
$ cd grpc_servers_impl/cpp
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
- Do not try to run both servers at the same time with the current configuration, as both use the same port number (i.e., `9030`). Change this in one of the server if you want to have both running at the same time.



# Other notes

- The implementation of this server is based on [greeter_server.cc](https://github.com/grpc/grpc/blob/master/examples/cpp/helloworld/greeter_server.cc).
- Futher usage of ghz can be found at https://ghz.sh/docs/examples
- Any performance claims are based on versions specified in the requirements section.

**IMPORTANT: this material is not to be used for production purposes and is only for evaluation.**
