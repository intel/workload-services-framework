# ycsb-0.17.0-base

ARG OS_VER=22.04
ARG OS_IMAGE=ubuntu

FROM ${OS_IMAGE}:${OS_VER} as builder

#install basic env
RUN apt update && apt install -y wget build-essential openssl automake autoconf make bzip2 libtool redis netcat numactl libatomic1 sudo

#install java jdk
ARG JDK_VER="jdk-17"
ifelse(IMAGEARCH,linux/arm64,dnl
`ARG JDK_PACKAGE="${JDK_VER}_linux-aarch64_bin.tar.gz"',
`ARG JDK_PACKAGE="${JDK_VER}_linux-x64_bin.tar.gz"
')
RUN mkdir -p /jdk
WORKDIR /jdk
RUN wget https://download.oracle.com/java/17/latest/${JDK_PACKAGE} \
  && tar -xvf ${JDK_PACKAGE} -C /jdk/ \
  && rm -fr ${JDK_PACKAGE} \
  &&  mv jdk-* jdk-version

#install mvn
ARG MAVEN_VER="apache-maven-3.3.9"
ARG MAVEN_PACKAGE="https://archive.apache.org/dist/maven/maven-3/3.3.9/binaries/${MAVEN_VER}-bin.tar.gz"
WORKDIR /usr/local
RUN wget ${MAVEN_PACKAGE} \
  && tar xzvf ${MAVEN_VER}-bin.tar.gz -C /usr/local \
  && rm -rf ${MAVEN_VER}-bin.tar.gz \
  && mv apache-maven-* maven

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

#install ycsb
ARG YCSB_VER="ycsb-0.17.0"
ARG YCSB_PACKAGE="https://github.com/brianfrankcooper/YCSB/releases/download/0.17.0/${YCSB_VER}.tar.gz"
WORKDIR /usr/src
RUN wget --no-check-certificate ${YCSB_PACKAGE} \
  && tar xfvz ${YCSB_VER}*.tar.gz -C /usr/src \
  && rm -rf ${YCSB_VER}*.tar.gz \
  && mv ycsb-0.17.0* ycsb
COPY conf/90Read10Update /usr/src/ycsb/workloads

FROM ${OS_IMAGE}:${OS_VER}
RUN apt update && apt install -y openssl redis netcat numactl wget
COPY --from=builder /usr/local/ /usr/local/
# install jdk
COPY --from=builder /jdk/jdk-version /jdk/jdk-version
ENV JAVA_HOME /jdk/jdk-version/
ENV PATH $JAVA_HOME/bin:$PATH
# install maven
COPY --from=builder /usr/local/maven /usr/local/maven
COPY script/maven.sh /etc/profile.d
RUN chmod 777 /etc/profile.d/maven.sh
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

RUN mkfifo /export-logs
COPY script/run_test.sh script/prepare_ycsb.sh /usr/src/
WORKDIR /usr/src
RUN chmod +x run_test.sh prepare_ycsb.sh
CMD (./run_test.sh; echo $? > status) 2>&1 | tee output.logs \
  && tar cf /export-logs status output.logs \
  && sleep infinity
