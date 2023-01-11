/*
 *
 * Copyright 2015 gRPC authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

// Implementation based on https://github.com/grpc/grpc/blob/master/examples/cpp/helloworld/greeter_server.cc

#include <iostream>
#include <memory>
#include <string>

#include <grpcpp/ext/proto_server_reflection_plugin.h>
#include <grpcpp/grpcpp.h>
#include <grpcpp/health_check_service_interface.h>


#include "main.grpc.pb.h"
#include "echo/echo.pb.h"
#include "hyper_proto_bench/bench1/benchmark.pb.h"


using grpc::Server;
using grpc::ServerBuilder;
using grpc::ServerContext;
using grpc::Status;
using benchmarks::EchoServer;
using benchmarks::echo::EchoRequest;
using benchmarks::bench1::M1;

// Logic and data behind the server's behavior.
class EchoServerServiceImpl final : public EchoServer::Service {

  Status SayHello(ServerContext* context, const EchoRequest* request, EchoRequest* reply) override {
    reply->set_name(request->name());
    return Status::OK;
  }

  // Message handler function added to the original code
  Status GetM1Bench1(ServerContext* context, const M1* request, M1* reply) override {
    reply->MergeFrom(*request);
    return Status::OK;
  }
};

void RunServer() {
  std::string server_address("0.0.0.0:9030");
  EchoServerServiceImpl service;

  grpc::EnableDefaultHealthCheckService(true);
  grpc::reflection::InitProtoReflectionServerBuilderPlugin();
  ServerBuilder builder;
  // Listen on the given address without any authentication mechanism.
  builder.AddListeningPort(server_address, grpc::InsecureServerCredentials());
  // Register "service" as the instance through which we'll communicate with
  // clients. In this case it corresponds to an *synchronous* service.
  builder.RegisterService(&service);
  // Finally assemble the server.
  std::unique_ptr<Server> server(builder.BuildAndStart());
  std::cout << "Server listening on " << server_address << std::endl;

  // Wait for the server to shutdown. Note that some other thread must be
  // responsible for shutting down the server for this call to ever return.
  server->Wait();
}

int main(int argc, char** argv) {
  RunServer();
  return 0;
}
