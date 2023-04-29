changecom(`@')
# tpcc-`mysql'patsubst(WORKLOAD,`[^0-9]')-patsubst(WORKLOAD,`.*_',`')
changecom(`#')

ARG MYSQL_BASE_IMAGE=`mysql'patsubst(WORKLOAD,`[^0-9]')-patsubst(WORKLOAD,`.*_',`')
FROM ${MYSQL_BASE_IMAGE}RELEASE

COPY --chown=mysql:mysql script/prepare_common.sh /
COPY --chown=mysql:mysql script/network_rps_tuning.sh /

# introduce mysqltunner tool
ARG MYSQL_TUNNER_VER="v1.9.9"
ARG MYSQL_TUNNER_REPO="https://github.com/major/MySQLTuner-perl.git"
RUN git clone --depth 1 --branch ${MYSQL_TUNNER_VER} ${MYSQL_TUNNER_REPO} && \
    cp MySQLTuner-perl/mysqltuner.pl ./
ARG TUNING_PRIMER_VER=6aec9c280e06acb7a8b84d0c4f2dcde0cd20e72b
ARG TUNING_PRIMER_REPO="https://github.com/BMDan/tuning-primer.sh.git"
RUN git clone ${TUNING_PRIMER_REPO} tunning && \
    cd tunning && \
    git checkout ${TUNING_PRIMER_VER} && \
    cp tuning-primer.sh ../ && \
    cd / && \
    rm -rf tunning
    
RUN chmod +x mysqltuner.pl
RUN chmod +x tuning-primer.sh
