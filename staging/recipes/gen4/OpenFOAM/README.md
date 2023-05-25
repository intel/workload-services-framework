## OPENFOAM
[OpenFOAM](https://openfoam.org/) (for "Open-source Field Operation And Manipulation") is a powerful and popular open-source C++ software toolkit for the simulation of fluid flow, heat transfer and other related physical phenomena. It is an object-oriented, open-source Computational Fluid Dynamics (CFD) toolbox with a range of solvers for different physics, such as incompressible, compressible and turbulent flows, multi-phase flows, solid-fluid coupling, electro-magnetic, and chemical reaction. It is used for modelling and simulation of a wide range of engineering applications, from aerospace and automotive to marine and biomedical.

#computational fluid dynamics, #CFD, #OpenFOAM, #Open-source Field Operation And Manipulation, #HPC, #high performance computing

## Software Components
Table 1 lists the necessary software components. 
The descending row order represents the install sequence. 
The recommended component version and download location are also provided.

Table 1: Software Components
| Component| Version |
| :---        |    :----:   |
| Rocky Linux |  [8.5](https://rockylinux.org/news/rocky-linux-8-5-ga-release/)   |
| Intel oneAPI HPC Toolkit |  [2023.0.0](https://yum.repos.intel.com/oneapi)   |
| OpenFOAM | [8](https://github.com/OpenFOAM/OpenFOAM-8.git) |

# Configuration Snippets
This section contains code snippets on build instructions for software components.

Note: Common Linux utilities, such as docker, git, wget, will not be listed here. Please install on demand if it is not provided in base OS installation.

### Rocky Linux
```
docker pull rockylinux:8.5
```

### Intel oneAPI HPC Toolkit
```
cat <<EOF > /etc/yum.repos.d/oneAPI.repo
[oneAPI]
name=Intel® oneAPI repository
baseurl=https://yum.repos.intel.com/oneapi
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://yum.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB

EOF

yum install -y intel-hpckit
```

### OpenFOAM
```
VER_NUM=8
OPEN_FOAM_REPO=https://github.com/OpenFOAM/OpenFOAM-${VER_NUM}.git
OPEN_FOAM_VER=version-${VER_NUM}
git clone -b ${OPEN_FOAM_VER} ${OPEN_FOAM_REPO}

sed -i -e '/export WM_COMPILER/s/Gcc/Icc/' ./OpenFOAM-${VER_NUM}/etc/bashrc
sed -i -e '/export WM_MPLIB/s/SYSTEMOPENMPI/INTELMPI/' ./OpenFOAM-${VER_NUM}/etc/bashrc
sed -i -e '/$(LIB_HEADER_DIRS) -fPIC/s/$/ -xCORE-AVX512 -fp-model precise -fp-speculation=safe/' ./OpenFOAM-${VER_NUM}/wmake/rules/linux64Icc/c++
sed -i '235s|^.*$|    export FOAM_MPI="intelmpi"|' ./OpenFOAM-${VER_NUM}/etc/config.sh/mpi
sed -i -e '/PINC/d' ./OpenFOAM-${VER_NUM}/wmake/rules/General/mplibINTELMPI64
sed -i -e '/PLIBS/d' ./OpenFOAM-${VER_NUM}/wmake/rules/General/mplibINTELMPI64
echo 'PINC       = -isystem $(MPI_ARCH_PATH)/intel64/include'  >> ./OpenFOAM-${VER_NUM}/wmake/rules/General/mplibINTELMPI64
echo 'PLIBS      = -L$(MPI_ARCH_PATH)/intel64/lib/release -lmpi'  >> ./OpenFOAM-${VER_NUM}/wmake/rules/General/mplibINTELMPI64

cd ./OpenFOAM-${VER_NUM}
I_MPI_ROOT=/opt/intel/oneapi/mpi/latest
MPI_ROOT=$I_MPI_ROOT
source /opt/intel/oneapi/setvars.sh intel64 
source etc/bashrc 
./Allwmake -j 
```

Workload Services Framework

-end of document-
