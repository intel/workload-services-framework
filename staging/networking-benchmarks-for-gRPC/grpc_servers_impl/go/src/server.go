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

// Implementation based on https://github.com/grpc/grpc-go/blob/master/examples/helloworld/greeter_server/main.go

package main

import (
	"context"
	"fmt"
	"log"

	pbBench1 "main/build/hyper_proto_bench/bench1"
	pbEcho "main/build/echo"
	pb "main/build"
	"net"

	"google.golang.org/grpc"
)

type server struct {
	pb.UnimplementedEchoServerServer
}

func (s *server) SayHello(ctx context.Context, in *pbEcho.EchoRequest) (*pbEcho.EchoRequest, error) {
	return in, nil
}

// Message handler function added to the original code
func (s *server) GetM1Bench1(ctx context.Context, in *pbBench1.M1) (*pbBench1.M1, error) {
	return in, nil
}

func main() {
	port := 9030
	lis, err := net.Listen("tcp", fmt.Sprintf(":%d", port))
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}
	grpcServer := grpc.NewServer()
	pb.RegisterEchoServerServer(grpcServer, &server{})
	log.Printf("server listening at %v", lis.Addr())
	if err := grpcServer.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %s", err)
	}
}
