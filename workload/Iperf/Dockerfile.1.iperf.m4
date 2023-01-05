# iperf2

ARG OS_VER=8.5
ARG OS_IMAGE=rockylinux

FROM ${OS_IMAGE}:${OS_VER} AS build

RUN dnf group -y install "Development Tools"
RUN dnf -y install wget psmisc bind-utils

ARG IPERF_VER="2"

ARG IPERF2_VER="2.1.7"
ARG IPERF2_PACKAGE=https://sourceforge.net/projects/iperf2/files/iperf-${IPERF2_VER}.tar.gz

RUN IPERF_PACKAGE=$(eval echo \$IPERF${IPERF_VER}_PACKAGE) \
    && IPERF_CHOSEN_VERSION=$(eval echo \$IPERF${IPERF_VER}_VER) \
    && wget ${IPERF_PACKAGE} && tar xf iperf-${IPERF_CHOSEN_VERSION}.tar.gz \
    && cd iperf-${IPERF_CHOSEN_VERSION} \
    && ./configure \
    && make -j \
    && make install

COPY script/run_iperf* /
RUN chmod +x /run_iperf*

RUN mkfifo /export-logs
CMD (/run_iperf.sh; echo $? > status) && \
    tar cf /export-logs status output.logs && \
    sleep infinity
