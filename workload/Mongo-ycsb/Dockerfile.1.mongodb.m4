# ycsb-amd64-mongodb441-base

ARG MONGODB_BASE_IMAGE=amd64-mongodb441-base
FROM ${MONGODB_BASE_IMAGE}RELEASE

WORKDIR /usr/src/mongodb/bin
RUN apt update && apt install -y iproute2 ethtool kmod sudo stress-ng bc numactl

COPY script/mongodb_config.sh conf/mongod.conf script/prepare_mongodb.sh script/stress-ng.sh .

RUN chmod +x prepare_mongodb.sh mongodb_config.sh stress-ng.sh
CMD ./mongodb_config.sh | tee -a mongo_server.log && sleep infinity
