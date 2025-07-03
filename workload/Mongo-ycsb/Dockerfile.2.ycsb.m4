changecom(`@')dnl
# ifelse(regexp(PLATFORM, `ARMv[0-9]'), -1, `amd64', `arm64')-ycsb-0.17.0-ifelse(regexp(WORKLOAD, \(iaa\|qat\)), -1, `base', `optimized')
changecom(`#')dnl

#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
ARG OS_VER=24.04
ARG OS_IMAGE=ubuntu

FROM ${OS_IMAGE}:${OS_VER} as builder

#install basic env
RUN apt update && apt install -y wget build-essential openssl automake autoconf make bzip2 libtool redis netcat-openbsd numactl libatomic1 sudo zlib1g-dev libcrypto++-dev libssl-dev

#install java jdk
ARG JDK_RELEASE="OpenJDK17U-jdk"
ARG JDK_VER="17.0.15"
ARG BACKPORT_NUM="6"
ifelse(IMAGEARCH,linux/arm64,dnl
`ARG JDK_PACKAGE="https://github.com/adoptium/temurin17-binaries/releases/download/jdk-${JDK_VER}+${BACKPORT_NUM}/${JDK_RELEASE}_aarch64_linux_hotspot_${JDK_VER}_${BACKPORT_NUM}.tar.gz"',
`ARG JDK_PACKAGE="https://github.com/adoptium/temurin17-binaries/releases/download/jdk-${JDK_VER}+${BACKPORT_NUM}/${JDK_RELEASE}_x64_linux_hotspot_${JDK_VER}_${BACKPORT_NUM}.tar.gz"')
WORKDIR /jdk
RUN wget ${JDK_PACKAGE} \
  && tar -xvf ${JDK_RELEASE}_*_linux_hotspot_${JDK_VER}_${BACKPORT_NUM}.tar.gz -C /jdk/ \
  && rm -fr ${JDK_RELEASE}_*_linux_hotspot_${JDK_VER}_${BACKPORT_NUM}.tar.gz \
  &&  mv jdk-* jdk-version
ENV JAVA_HOME /jdk/jdk-version

#install mvn
ARG MAVEN_VER="apache-maven-3.9.9"
ARG MAVEN_PACKAGE="https://archive.apache.org/dist/maven/maven-3/3.9.9/binaries/${MAVEN_VER}-bin.tar.gz"
WORKDIR /usr/local
RUN wget ${MAVEN_PACKAGE} \
  && tar xzvf ${MAVEN_VER}-bin.tar.gz -C /usr/local \
  && rm -rf ${MAVEN_VER}-bin.tar.gz \
  && mv apache-maven-* maven

#set proxy
RUN export protocol=$(echo $http_proxy | awk -F[/:] '{print $1}') \
  && export host=$(echo $http_proxy | awk -F[/:] '{print $4}') \
  && export port=$(echo $http_proxy | awk -F[/:] '{print $5}') \
  && sed -i "/<proxies>/a<proxy>\n<id>proxy1</id>\n<active>true</active>\n<protocol>${protocol}</protocol>\n<host>${host}</host>\n<port>${port}</port>\n</proxy>" /usr/local/maven/conf/settings.xml

#install python2
ARG PYTHON2_VER="Python-2.7.15"
ARG PYTHON2_PACKAGE="https://www.python.org/ftp/python/2.7.15/${PYTHON2_VER}.tgz"
WORKDIR /usr/src
RUN wget --no-check-certificate ${PYTHON2_PACKAGE} \
  &&  tar -zxvf ${PYTHON2_VER}.tgz -C /usr/src \
  && rm -rf ${PYTHON2_VER}.tgz \
  && mv ${PYTHON2_VER} python2
WORKDIR python2
RUN ./configure --enable-optimizations --prefix=/usr/local/python2
RUN make altinstall 

#install pip
RUN wget --no-check-certificate https://bootstrap.pypa.io/pip/2.7/get-pip.py \
  && /usr/local/python2/bin/python2.7 get-pip.py \
  && /usr/src/python2/python -m pip install pymongo

#install ycsb
WORKDIR /usr/src
ARG YCSB_VER="0.17.0"
ifelse(regexp(WORKLOAD, iaa$),-1,
`ARG YCSB_PACKAGE="https://github.com/brianfrankcooper/YCSB/releases/download/${YCSB_VER}/ycsb-${YCSB_VER}.tar.gz"
RUN wget --no-check-certificate ${YCSB_PACKAGE} \
  && tar xfvz ycsb-${YCSB_VER}*.tar.gz -C /usr/src \
  && rm -rf ycsb-${YCSB_VER}*.tar.gz \
  && mv ycsb* /usr/src/ycsb',
`ARG YCSB_PACKAGE="https://github.com/brianfrankcooper/YCSB/archive/refs/tags/${YCSB_VER}.tar.gz"
RUN wget -O - ${YCSB_PACKAGE} | tar xfz - -C /usr/src \
  && mv YCSB* /usr/src/ycsb-build \
  && sed -i "s/buffer\[base + 5\] = (byte) (((bytes >> 25) \& 95)/buffer\[base + 5\] = (byte) (((bytes >> 20) \& 31)/g" ycsb-build/core/src/main/java/site/ycsb/RandomByteIterator.java \
  && sed -i "s/buffer\[base + 4\] = (byte) (((bytes >> 20) \& 63)/buffer\[base + 4\] = (byte) (((bytes >> 20) \& 23)/g" ycsb-build/core/src/main/java/site/ycsb/RandomByteIterator.java \
  && sed -i "s/buffer\[base + 3\] = (byte) (((bytes >> 15) \& 31)/buffer\[base + 3\] = (byte) (((bytes >> 10) \& 31)/g" ycsb-build/core/src/main/java/site/ycsb/RandomByteIterator.java \
  && sed -i "s/buffer\[base + 2\] = (byte) (((bytes >> 10) \& 95)/buffer\[base + 2\] = (byte) (((bytes >> 10) \& 31)/g" ycsb-build/core/src/main/java/site/ycsb/RandomByteIterator.java \
  && sed -i "s/buffer\[base + 1\] = (byte) (((bytes >> 5) \& 63)/buffer\[base + 1\] = (byte) (((bytes) \& 31)/g" ycsb-build/core/src/main/java/site/ycsb/RandomByteIterator.java
WORKDIR /usr/src/ycsb-build
RUN /usr/local/maven/bin/mvn -pl site.ycsb:mongodb-binding -am clean package \
  && tar xfvz mongodb/target/ycsb-mongodb-binding*.tar.gz -C /usr/src
WORKDIR /usr/src
RUN rm -rf ycsb/ \
  && mv ycsb-mongodb-binding* /usr/src/ycsb
')
COPY conf/90Read10Update conf/workloada_query conf/workloada_combined /usr/src/ycsb/workloads

FROM ${OS_IMAGE}:${OS_VER}
RUN apt update && apt install -y openssl redis netcat-openbsd numactl wget libc6
COPY --from=builder /usr/local/ /usr/local/
# install jdk
COPY --from=builder /jdk/jdk-version /jdk/jdk-version
ENV JAVA_HOME /jdk/jdk-version/
ENV PATH $JAVA_HOME/bin:$PATH
# install maven
COPY --from=builder /usr/local/maven /usr/local/maven
ENV M2_HOME /usr/local/maven
ENV PATH ${M2_HOME}/bin:${PATH}
# install python2
COPY --from=builder /usr/local/python2 /usr/local/python2
RUN ln -s /usr/local/python2/bin/python2.7 /usr/bin/python
# install redis-cli
COPY --from=builder /usr/bin/redis-cli /usr/bin/redis-cli
# install ycsb
COPY --from=builder /usr/src/ycsb /usr/src/ycsb

WORKDIR /usr/src
# remove old version of log4j
RUN rm /usr/src/ycsb/ignite-binding/lib/log4j-core-2.11.0.jar -f \
  && rm /usr/src/ycsb/tablestore-binding/lib/log4j-core-2.0.2.jar -f \
  && rm /usr/src/ycsb/voltdb-binding/lib/log4j-core-2.7.jar -f \
  && rm /usr/src/ycsb/elasticsearch5-binding/lib/log4j-core-2.8.2.jar -f \
  && rm /usr/src/ycsb/geode-binding/lib/log4j-core-2.7.jar -f
RUN python -m pip install pymongo

RUN mkfifo /export-logs
COPY script/run_test.sh /usr/src/
COPY script/initiate_rs.py /usr/src
COPY script/collect_dbtable_info.py /usr/src/
WORKDIR /usr/src
RUN chmod +x run_test.sh initiate_rs.py collect_dbtable_info.py
RUN touch mongodb.log

CMD (./run_test.sh; echo $? > status) 2>&1 | tee output.logs \
  && tar cf /export-logs status output.logs mongodb.log ycsb_output.json \
  && sleep infinity