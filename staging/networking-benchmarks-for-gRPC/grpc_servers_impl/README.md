# Overview

This directory has the grpc server implementations for Go and C++ runtimes.



**Note:** Do not try to run both servers at the same time with the current configuration, as both use the same port number (i.e., `9030`). Change this in one of the server if you want to have both running at the same time. Also adjust the host port numbers in the `ghz_config` files accordingly if using a different host address/port.