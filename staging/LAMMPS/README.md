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
| ONEAPI HPCKIT | [v2023.0.0-devel](https://hub.docker.com/r/intel/oneapi-hpckit) |
| LAMMPS | [v29Sep2021](https://github.com/lammps/lammps/archive/refs/tags/stable_29Sep2021.tar.gz) |
| NUMACTL | [2.0.14-3](http://archive.ubuntu.com/ubuntu/pool/main/n/numactl/numactl_2.0.14-3ubuntu2_amd64.deb) |


## Configuration Snippets
This section contains code snippets on build instructions for software components.

Note: Common Linux utilities, such as docker, git, wget, will not be listed here. Please install on demand if it is not provided in base OS installation.

### UBUNTU
```
docker pull ubuntu:22.04
```

### ONEAPI HPCKIT
```
docker pull intel/oneapi-hpckit:2023.0.0-devel-ubuntu22.04
```

### LAMMPS
```
BASEDIR=hpc-lammps
LAMMPS_VER="29Sep2021"
LAMMPS_PACKAGE="https://github.com/lammps/lammps/archive/refs/tags/stable_${LAMMPS_VER}.tar.gz"
wget ${LAMMPS_PACKAGE} && \
    mkdir -p ${BASEDIR} && \
    tar vxf stable_${LAMMPS_VER}.tar.gz -C ${BASEDIR} && \
    rm stable_${LAMMPS_VER}.tar.gz && \
    cd ${BASEDIR} && \
    ln -s lammps-stable_${LAMMPS_VER} lammps
```

### NUMACTL
```
NUMACTL_VER="2.0.14-3ubuntu2"
apt install -y numactl="${NUMACTL_VER}"
```

Workload Services Framework

-end of document-
