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
| Debian|  [12](https://www.debian.org/releases/bookworm/)   |
| Intel oneAPI HPC Toolkit |  [2023.1.0](https://www.intel.com/content/www/us/en/developer/tools/oneapi/hpc-toolkit-download.html)   |
| OpenFOAM | [11](https://github.com/OpenFOAM/OpenFOAM-11.git) |

# Configuration Snippets
This section contains code snippets on build instructions for software components.

Note: Common Linux utilities, such as docker, git, wget, will not be listed here. Please install on demand if it is not provided in base OS installation.


### Intel oneAPI HPC Toolkit

Install dependencies
```
sudo apt-get -y install gawk g++ gcc make
```

Install oneAPI HPC Toolkit
```
wget https://registrationcenter-download.intel.com/akdlm/IRC_NAS/1ff1b38a-8218-4c53-9956-f0b264de35a4/l_HPCKit_p_2023.1.0.46346_offline.sh
chmod +x l_HPCKit_p_2023.1.0.46346_offline.sh
sudo ./l_HPCKit_p_2023.1.0.46346_offline.sh -a -s --silent --eula accept
source /opt/intel/oneapi/setvars.sh
```

### Zlib
```
wget https://www.zlib.net/fossils/zlib-1.3.tar.gz -O zlib.tar.gz
tar -zxf zlib.tar.gz
cd zlib-* 
./configure
make -j 
sudo make install 
```

### Community OpenFOAM

Set environment variables 
```
export OPENFOAM_VERSION=11
export MPI_ROOT=${I_MPI_ROOT}
```

Install dependencies
```
sudo apt-get -y install git flex  libptscotch-dev
```

clone OpenFOAM
```
git clone https://github.com/OpenFOAM/OpenFOAM-11.git
```

Moddify configuration files
```
#Change Compiler form gcc to icx
sed -i -e '/export WM_COMPILER/s/Gcc/Icx/' ./OpenFOAM-${OPENFOAM_VERSION}/etc/bashrc

#Add compiler flags for c++ compilation on Linux
sed -i -e '/$(LIB_HEADER_DIRS) -fPIC/s/$/ -xCORE-AVX512 -fp-model precise -fp-speculation=safe/' ./OpenFOAM-${OPENFOAM_VERSION}/wmake/rules/linux64Icx/c++

#Change from openMPI to Intel MPI implementation
sed -i -e '/export WM_MPLIB/s/SYSTEMOPENMPI/INTELMPI/' ./OpenFOAM-${OPENFOAM_VERSION}/etc/bashrc

#Set FOAM mpi implementation to Intel implementation
sed -i '235s|^.*$|    export FOAM_MPI="intelmpi"|' ./OpenFOAM-${OPENFOAM_VERSION}/etc/config.sh/mpi
sed -i -e '/PINC/d' ./OpenFOAM-${OPENFOAM_VERSION}/wmake/rules/General/mplibINTELMPI64
sed -i -e '/PLIBS/d' ./OpenFOAM-${OPENFOAM_VERSION}/wmake/rules/General/mplibINTELMPI64
echo 'PINC       = -isystem ${I_MPI_ROOT}/include'  >> ./OpenFOAM-${OPENFOAM_VERSION}/wmake/rules/General/mplibINTELMPI64 
echo 'PLIBS      = -L${I_MPI_ROOT}/lib/release -lmpi'  >> ./OpenFOAM-${OPENFOAM_VERSION}/wmake/rules/General/mplibINTELMPI64 

#Set up OpenFOAM environment and complete build
cd OpenFOAM-${OPENFOAM_VERSION}
source etc/bashrc
./Allwmake -j
```

### Intel OpenFOAM Implementation (includes motorbike benchmark example)

Download Intel modifications
```
git clone https://github.com/do-jason/OpenFOAM-Intel.git
```

See https://github.com/do-jason/OpenFOAM-Intel/blob/master/benchmarks/motorbike/README.org for more motorbike benchmark configuration information.

```
# Sample code to run motorbike with 20M cells and 16 processes
cd OpenFOAM-Intel/benchmarks/motorbike
./Mesh 100 40 40
./Setup 16
./Solve
```


-end of document-
