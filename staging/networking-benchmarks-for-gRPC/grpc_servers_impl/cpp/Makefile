#
# Copyright 2015 gRPC authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


LDFLAGS += `pkg-config --libs protobuf grpc++` \
           -Wl,--no-as-needed -lgrpc++_reflection -Wl,--as-needed

CXX = g++
CPPFLAGS += `pkg-config --cflags protobuf grpc++ grpc`
CXXFLAGS += -I $(BUILD)

GRPC_CPP_PLUGIN = grpc_cpp_plugin
GRPC_CPP_PLUGIN_PATH ?= `which $(GRPC_CPP_PLUGIN)`

PROTOC = protoc
PROTOS_PATH = ../../protos
BUILD = build
SERVER = $(BUILD)/server

PROTOBUF_OBJECTS = $(BUILD)/echo/echo.pb.o \
                   $(BUILD)/hyper_proto_bench/bench1/benchmark.pb.o \
                   $(BUILD)/main.pb.o $(BUILD)/main.grpc.pb.o
SERVER_OBJECTS = $(BUILD)/server.o

all: system-check build compile_server

$(BUILD)/echo/echo.pb.cc:
	$(PROTOC) -I $(PROTOS_PATH) --cpp_out=$(BUILD) $(PROTOS_PATH)/echo/echo.proto

# Target added to the original code
$(BUILD)/hyper_proto_bench/bench1/benchmark.pb.cc:
	$(PROTOC) -I $(PROTOS_PATH) --cpp_out=$(BUILD) $(PROTOS_PATH)/hyper_proto_bench/bench1/benchmark.proto

$(BUILD)/main.pb.cc:
	$(PROTOC) -I $(PROTOS_PATH) --cpp_out=$(BUILD) $(PROTOS_PATH)/main.proto

$(BUILD)/main.grpc.pb.cc:
	$(PROTOC) -I $(PROTOS_PATH) --grpc_out=$(BUILD) --plugin=protoc-gen-grpc=$(GRPC_CPP_PLUGIN_PATH) $(PROTOS_PATH)/main.proto

$(BUILD)/server.o: src/server.cc
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $^ -o $@

compile_server: $(PROTOBUF_OBJECTS) $(SERVER_OBJECTS)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $(PROTOBUF_OBJECTS) $(SERVER_OBJECTS) $(LDFLAGS) -o $(SERVER)

build:
	@mkdir -p $(BUILD)

clean:
	@rm -rf $(BUILD)


# The following is to test your system and ensure a smoother experience.
# They are by no means necessary to actually compile a grpc-enabled software.

PROTOC_CMD = which $(PROTOC)
PROTOC_CHECK_CMD = $(PROTOC) --version | grep -q libprotoc.3
PLUGIN_CHECK_CMD = which $(GRPC_CPP_PLUGIN)
HAS_PROTOC = $(shell $(PROTOC_CMD) > /dev/null && echo true || echo false)
ifeq ($(HAS_PROTOC),true)
HAS_VALID_PROTOC = $(shell $(PROTOC_CHECK_CMD) 2> /dev/null && echo true || echo false)
endif
HAS_PLUGIN = $(shell $(PLUGIN_CHECK_CMD) > /dev/null && echo true || echo false)

SYSTEM_OK = false
ifeq ($(HAS_VALID_PROTOC),true)
ifeq ($(HAS_PLUGIN),true)
SYSTEM_OK = true
endif
endif


system-check:
ifneq ($(HAS_VALID_PROTOC),true)
	@echo " DEPENDENCY ERROR"
	@echo
	@echo "You don't have protoc 3.0.0 installed in your path."
	@echo "Please install Google protocol buffers 3.0.0 and its compiler."
	@echo "You can find it here:"
	@echo
	@echo "   https://github.com/protocolbuffers/protobuf/releases/tag/v3.0.0"
	@echo
	@echo "Here is what I get when trying to evaluate your version of protoc:"
	@echo
	-$(PROTOC) --version
	@echo
	@echo
endif
ifneq ($(HAS_PLUGIN),true)
	@echo " DEPENDENCY ERROR"
	@echo
	@echo "You don't have the grpc c++ protobuf plugin installed in your path."
	@echo "Please install grpc. You can find it here:"
	@echo
	@echo "   https://github.com/grpc/grpc"
	@echo
	@echo "Here is what I get when trying to detect if you have the plugin:"
	@echo
	-which $(GRPC_CPP_PLUGIN)
	@echo
	@echo
endif
ifneq ($(SYSTEM_OK),true)
	@false
endif
