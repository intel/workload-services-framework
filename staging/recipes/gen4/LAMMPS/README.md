## LAMMPS
[LAMMPS](https://www.lammps.org/) is a classical molecular dynamics code with a focus on materials modeling. It's an acronym for Large-scale Atomic/Molecular Massively Parallel Simulator. It is an open-source molecular dynamics software package designed for simulating the behavior of molecules, atoms, or other particles in a variety of environments. It is highly parallelized and can be used to model systems ranging from individual molecules to large, complex materials. It can also be used to study the behavior of liquids, gases, and solids under a wide range of conditions. LAMMPS is written in C++ and can be run on a variety of platforms, including supercomputers, clusters, and desktop machines.

#lammps, #molecular dynamics, #Large-scale Atomic/Molecular Massively Parallel Simulator, #HPC, #high performance computing

## Software Components
Table 1 lists the necessary software components. 
The descending row order represents the install sequence. 
The recommended component version and download location are also provided.

Table 1: Software Components
| Component| Version |
| :---        |    :----:   |
| UBUNTU | [v22.04](https://ubuntu.com/) |
| HPCKIT | [v2024.0.1](https://hub.docker.com/r/intel/hpckit) |
| LAMMPS | [v28Mar2023](https://download.lammps.org/tars/lammps-28Mar2023.tar.gz) |


## Configuration Snippets
This section contains code snippets on build instructions for software components.

Note: Common Linux utilities, such as docker, git, wget, will not be listed here. Please install on demand if it is not provided in base OS installation.

### UBUNTU
```
docker pull ubuntu:22.04
```

### ONEAPI HPCKIT
```
docker pull intel/hpckit:latest
```

### LAMMPS - MPI
```
BASEDIR=hpc-lammps
LAMMPS_VER="28Mar2023"
ARG LAMMPS_PACKAGE="https://download.lammps.org/tars/lammps-${LAMMPS_VER}.tar.gz"
wget ${LAMMPS_PACKAGE} && \
    gunzip lammps-${LAMMPS_VER}.tar.gz && \
    tar -xf lammps-${LAMMPS_VER}.tar && \
    cd lammps-${LAMMPS_VER} && mkdir build && cd build && \
    cmake -C ../cmake/presets/oneapi.cmake -D BUILD_MPI=on -D PKG_INTEL=yes ../cmake && \
    make -j && make install && ln -s /lammps-${LAMMPS_VER}/build/lmp /usr/bin/lmp
```
### LAMMPS - Serial
```
BASEDIR=hpc-lammps
LAMMPS_VER="28Mar2023"
ARG LAMMPS_PACKAGE="https://download.lammps.org/tars/lammps-${LAMMPS_VER}.tar.gz"
wget ${LAMMPS_PACKAGE} && \
    gunzip lammps-${LAMMPS_VER}.tar.gz && \
    tar -xf lammps-${LAMMPS_VER}.tar && \
    cd lammps-${LAMMPS_VER} && mkdir build && cd build && \
    cmake -C ../cmake/presets/oneapi.cmake -D BUILD_MPI=off  -D PKG_INTEL=yes ../cmake && \
    make -j && make install && ln -s /lammps-${LAMMPS_VER}/build/lmp /usr/bin/lmp
```

Workload Services Framework

-end of document-
