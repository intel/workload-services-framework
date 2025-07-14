# gemm

#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
ARG OS_IMAGE=intel/oneapi-hpckit
ARG OS_VER=2023.1.0-devel-ubuntu22.04
FROM ${OS_IMAGE}:${OS_VER} AS build

ARG BLIS_VER=0.8.1
ARG BLIS_PACKAGE=https://github.com/flame/blis/archive/refs/tags/${BLIS_VER}.zip
ARG GEMMBENCHMARK_VER=1.0
ARG GEMMBENCHMARK_PACKAGE=https://software.intel.com/content/dam/develop/external/us/en/documents/gemm-benchmark.zip
ENV LD_LIBRARY_PATH=/opt/intel/oneapi/lib/intel64:/opt/intel/oneapi/lib/intel64:/hpc_gemm/blis-${BLIS_VER}/lib/skx:$LD_LIBRARY_PATH
ENV BLISLIB=/hpc_gemm/blis-${BLIS_VER}/lib/skx/

WORKDIR /hpc_gemm

RUN apt-get update && apt-get install -y unzip python3 wget
RUN wget ${BLIS_PACKAGE} && unzip ${BLIS_VER}.zip
RUN no_proxy=$(echo $no_proxy | tr ',' '\n' | grep -v -E '^\.?intel.com$' | tr '\n' ',')  wget -U "Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; GTB5)" ${GEMMBENCHMARK_PACKAGE}  && unzip gemm-benchmark.zip   

WORKDIR /hpc_gemm/blis-${BLIS_VER}/config/skx

ARG SINGLE_BLIS_NC=3072 SINGLE_BLIS_KC=384 SINGLE_BLIS_MC=480 DOUBLE_BLIS_NC=3752 DOUBLE_BLIS_KC=256 DOUBLE_BLIS_MC=240
RUN sed -i '108c bli_blksz_init_easy( &blkszs[ BLIS_MC ], '${SINGLE_BLIS_MC}', '${DOUBLE_BLIS_MC}', -1, -1 );' bli_cntx_init_skx.c && \
    sed -i '109c bli_blksz_init_easy( &blkszs[ BLIS_KC ], '${SINGLE_BLIS_KC}', '${DOUBLE_BLIS_KC}', -1, -1 );' bli_cntx_init_skx.c && \
    sed -i '110d' bli_cntx_init_skx.c  && \
    sed -i '110c bli_blksz_init_easy( &blkszs[ BLIS_NC ], '${SINGLE_BLIS_NC}', '${DOUBLE_BLIS_NC}', -1, -1 );' bli_cntx_init_skx.c; 

WORKDIR /hpc_gemm/blis-${BLIS_VER}
RUN chmod +x configure 
RUN ./configure --enable-threading=omp skx && \
    make

WORKDIR ../GEMM_benchmark/
RUN sed -i '26s/-O2/-O3/g' Makefile && \
    sed -i '80s/rand() \/ RAND_MAX/drand48()/g' gemmbench.c && \
    sed -i '81s/rand() \/ RAND_MAX/drand48()/g' gemmbench.c && \
    sed -i '82s/rand() \/ RAND_MAX/drand48()/g' gemmbench.c

SHELL ["/bin/bash", "-c"]
RUN source /opt/intel/oneapi/setvars.sh --force intel64 && \
    source /opt/intel/oneapi/mkl/latest/env/vars.sh --force intel64 && \
    make all

CMD sleep infinity

ARG OS_IMAGE=ubuntu
ARG OS_VER=22.04
FROM ${OS_IMAGE}:${OS_VER}

ARG BLIS_VER=0.8.1
ENV MATH_LIB=mkl
ENV FLOAT_TYPE=sgemm
ENV BLISLIB=/hpc_gemm
ENV LD_LIBRARY_PATH=/opt/intel/oneapi/lib/intel64:/opt/intel/oneapi/lib/intel64:/hpc_gemm:/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH

WORKDIR hpc_gemm/

COPY --from=build /hpc_gemm/GEMM_benchmark/*.blis ./
COPY --from=build /hpc_gemm/GEMM_benchmark/*.mkl  ./
COPY --from=build /hpc_gemm/blis-${BLIS_VER}/lib/skx/libblis.so .
COPY --from=build /hpc_gemm/blis-${BLIS_VER}/lib/skx/libblis.so.3 .
COPY --from=build /opt/intel/oneapi/compiler/2023.1.0/linux/compiler/lib/intel64_lin/libiomp5.so .
COPY --from=build /usr/lib/x86_64-linux-gnu/libgomp.so.1 .
COPY --from=build /usr/lib/x86_64-linux-gnu/libgomp.so.1.0.0 .

RUN apt-get update && apt-get install -y numactl bc

COPY run.sh .
RUN chmod +x run.sh

RUN mkfifo /export-logs
CMD (./run.sh; echo $? > status) 2>&1 | tee output.log  && \
    tar cf /export-logs status output.log  && sleep infinity