## WRF
[WRF](https://www2.mmm.ucar.edu/wrf/users/) (for "Weather Research and Forecasting Model") is open-source code in the public domain, and its use is unrestricted. The Weather Research and Forecasting (WRF) Model is a state of the art mesoscale numerical weather prediction system designed for both atmospheric research and operational forecasting applications. It features two dynamical cores, a data assimilation system, and a software architecture supporting parallel computation and system extensibility. The model serves a wide range of meteorological applications across scales from tens of meters to thousands of kilometers. The effort to develop WRF began in the latter 1990's and was a collaborative partnership of the National Center for Atmospheric Research (NCAR), the National Oceanic and Atmospheric Administration (represented by the National Centers for Environmental Prediction (NCEP) and the Earth System Research Laboratory), the U.S. Air Force, the Naval Research Laboratory, the University of Oklahoma, and the Federal Aviation Administration (FAA).

For researchers, WRF can produce simulations based on actual atmospheric conditions (i.e., from observations and analyses) or idealized conditions. WRF offers operational forecasting a flexible and computationally-efficient platform, while reflecting recent advances in physics, numerics, and data assimilation contributed by developers from the expansive research community. WRF is currently in operational use at NCEP and other national meteorological centers as well as in real-time forecasting configurations at laboratories, universities, and companies.

#computational forecasting, #CFD, #WRF, #Open-source Field Operation And Manipulation, #high performance computing


## Software Components
Table 1 lists the necessary software components. 
The descending row order represents the install sequence. 
The recommended component version and download location are also provided.

Table 1: Software Components
| Component| Version |
| :---        |    :----:   |
| Debian|  [12](https://www.debian.org/releases/bookworm/)   |
| Intel oneAPI HPC Toolkit |  [2024.0.0.49589](https://www.intel.com/content/www/us/en/developer/tools/oneapi/hpc-toolkit-download.html)   |
| Szip | [2.1.1](https://support.hdfgroup.org/ftp/lib-external/szip/2.1.1/src/szip-2.1.1.tar.gz) |
| Zlib | [1.3](https://www.zlib.net/zlib-1.3.tar.gz) |
| HDF5 | [1.14.3](https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.14/hdf5-1.14.3/src/hdf5-1.14.3.tar.gz) |
| NetCDF | [4.9.2](https://github.com/Unidata/netcdf-c/archive/refs/tags/v4.9.2.tar.gz) |
| NetCDF-Fortran | [4.6.1](https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v4.6.1.tar.gz) |
| WRF | [4.5](https://github.com/wrf-model/WRF/releases/download/v4.5/v4.5.tar.gz) |


# Configuration Snippets
This section contains code snippets on build instructions for software components.

Note: Common Linux utilities, such as docker, git, wget, will not be listed here. Please install on demand if it is not provided in base OS installation.


### Intel oneAPI HPC Toolkit

Install dependencies
```
sudo apt-get -y install build-essential libpopt-dev autoconf libtool libxml2-dev libcurl4-gnutls-dev m4 csh
```

Install oneAPI HPC Toolkit
```
wget https://registrationcenter-download.intel.com/akdlm/IRC_NAS/1b2baedd-a757-4a79-8abb-a5bf15adae9a/l_HPCKit_p_2024.0.0.49589_offline.sh
chmod +x l_HPCKit_p_2024.0.0.49589_offline.sh
sudo ./l_HPCKit_p_2024.0.0.49589_offline.sh -a -s --silent --eula accept
source /opt/intel/oneapi/setvars.sh
```

### Szip
```
wget https://support.hdfgroup.org/ftp/lib-external/szip/2.1.1/src/szip-2.1.1.tar.gz -O szip.tar.gz
tar -zxf szip.tar.gz
cd szip-* 
source /opt/intel/oneapi/setvars.sh 
./configure --prefix=/usr/local/szip 
make 
sudo make install
```

### Zlib
```
wget https://www.zlib.net/zlib-1.3.tar.gz -O zlib.tar.gz
tar -zxf zlib.tar.gz 
cd zlib-* 
source /opt/intel/oneapi/setvars.sh 
./configure --prefix=/usr/local/zlib 
make 
sudo make install
```

### HDF5
```
wget "https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.14/hdf5-1.14.3/src/hdf5-1.14.3.tar.gz" -O hdf5.tar.gz 
tar -zxf hdf5.tar.gz 
cd hdf5-*
sudo ldconfig
sudo ln -s $(which ifort) /usr/bin/ifort
sudo ln -s $(which icc) /usr/bin/icc
source /opt/intel/oneapi/setvars.sh 
autoreconf -if
./configure  --prefix=/usr/local/hdf5 --enable-fortran --enable-parallel --enable-hl --enable-shared --with-szip=/usr/local/szip --with-zlib=/usr/local/zlib CXX=$(which mpiicpc) CC=$(which mpiicc)  FC=$(which mpiifort) LDFLAGS="-L/opt/intel/oneapi/mpi/2021.9.0/lib -L/opt/intel/oneapi/mpi/2021.9.0/lib/release/ -L/opt/intel/oneapi/compiler/2023.1.0/linux/compiler/lib/intel64_lin/"
make -j 4
sudo make install
```

### NetCDF
```
export HDF5=/usr/local/hdf5
export ZDIR=/usr/local/zlib
export NETCDF=/usr/local/netcdf
NETCDF_C_REPO=
wget https://github.com/Unidata/netcdf-c/archive/refs/tags/v4.9.2.tar.gz -O netcdf_c.tar.gz 
tar -zxf netcdf_c.tar.gz 
cd netcdf-c-*
source /opt/intel/oneapi/setvars.sh
CPPFLAGS="-I${HDF5}/include -I${ZDIR}/include" LDFLAGS="-L${HDF5}/lib -L${ZDIR}/lib" LIBS=-ldl ./configure --prefix=${NETCDF} --enable-parallel
make -j 4 
sudo make install
```

### NetCDF - Fortran
```
export HDF5=/usr/local/hdf5 ZDIR=/usr/local/zlib NETCDF=/usr/local/netcdf
wget https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v4.6.1.tar.gz -O netcdf_fort.tar.gz 
tar -zxf netcdf_fort.tar.gz 
cd netcdf-fortran-*
source /opt/intel/oneapi/setvars.sh
CPPFLAGS="-I${NETCDF}/include" LDFLAGS="-L${NETCDF}/lib" LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${NETCDF}/lib ./configure --prefix=${NETCDF}
make -j 4 
sudo make install
```

### WRF
```
WRF_VER="4.5"
wget https://github.com/wrf-model/WRF/archive/refs/tags/v4.5.1.tar.gz -O wrf.tar.gz && tar -zxf wrf.tar.gz && sudo mv WRFV${WRF_VER} /WRF
export CC=$(which icx)
export FC=$(which ifx)
export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/netcdf/bin:/usr/local/netcdf/lib
export HDF5=/usr/local/hdf5
export ZDIR=/usr/local/zlib
export NETCDF=/usr/local/netcdf
export WRFIO_NCD_LARGE_FILE_SUPPORT=1
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/hdf5/lib:/usr/local/netcdf/lib
cd /WRF 
source /opt/intel/oneapi/setvars.sh 
echo "67" | ./configure && \
sed -E -i 's/^(SFC[[:blank:]]*=[[:blank:]]*).*/\1 ifx/' ./configure.wrf && sed -E -i 's/^(SCC[[:blank:]]*=[[:blank:]]*).*/\1 icx -Wno-error=implicit-function-declaration -Wno-error=implicit-int/' ./configure.wrf && sed -E -i 's/^(CCOMP[[:blank:]]*=[[:blank:]]*).*/\1 icx -Wno-error=implicit-function-declaration -Wno-error=implicit-int/' ./configure.wrf && sed -E -i 's/^(OMP[[:blank:]]*=[[:blank:]]*).*/\1 -fiopenmp/' ./configure.wrf && sed -E -i 's/^(OMPCC[[:blank:]]*=[[:blank:]]*).*/\1 -fiopenmp/' ./configure.wrf && sed -E -i 's/^(LDFLAGS_LOCAL[[:blank:]]*=[[:blank:]]*).*/\1-fuse-ld=lld/' ./configure.wrf && sed -E -i 's/^(FCOPTIM[[:blank:]]*=[[:blank:]]*).*/\1-Ofast/' ./configure.wrf && sed -E -i 's/^(CFLAGS_LOCAL[[:blank:]]*=[[:blank:]]*).*/\1-Ofast -flto -w -xCORE-AVX512 -qopt-zmm-usage=high/' ./configure.wrf && sed -E -i 's/^(FCBASEOPTS_NO_G[[:blank:]]*=[[:blank:]]*).*/\1-w -flto -xCORE-AVX512 -qopt-zmm-usage=high -ftz -align array64byte -fno-alias $(FORMAT_FREE) $(BYTESWAPIO) -fp-model fast=2 -fimf-use-svml=true -vec-threshold0/' ./configure.wrf && sed -E -i 's/^(FCNOOPT[[:blank:]]*=[[:blank:]]*).*/\1-Ofast/' ./configure.wrf && ./compile -j 8 wrf
echo "<--WRF installed
```
### Run WRF (includes benchmark example)

#### Get benchmark data
```
wget https://www2.mmm.ucar.edu/wrf/users/benchmark/v44/v4.4_bench_conus12km.tar.gz 
tar -zxf v4.4_bench_conus12km.tar.gz 
```
#### Set soft links
```
ln -sf $workdir/v4.4_bench_conus12km/wrfbdy_d* /WRF/run 
ln -sf $workdir/v4.4_bench_conus12km/wrfinput_d* /WRF/run
ln -sf $workdir/v4.4_bench_conus12km/*.dat /WRF/run
ln -sf $workdir/v4.4_bench_conus12km/namelist.input.restart /WRF/run/namelist.input
ln -sf $workdir/v4.4_bench_conus12km/wrfrst_d01_2019-11-26_23:00:00.ifort /WRF/run/wrfrst_d01_2019-11-26_23:00:00
```
#### Set environment variables 
The value of each variable deppends on the HW configuration. The following values are based in the next example:
```
Model name:          Intel(R) Xeon(R) Platinum 8375C CPU @ 2.90GHz
CPU(s):              4
CPU family:          6
Model:               106
Thread(s) per core:  2
Core(s) per socket:  2
```
```
export PROCESS_PER_NODE=4
export OMP_NUM_THREADS= 1
export I_MPI_PIN_DOMAIN=auto
export I_MPI_PIN_ORDER=bunch
export OMP_PROC_BIND=close
export OMP_PLACES=cores
export KMP_BLOCKTIME=10
export KMP_STACKSIZE=512M
export WRF_NUM_TILES=4
```

#### Set up WRF environment and complete build
```
ulimit -s unlimited
cd /WRF/run 
mpiexec.hydra -genvall -n $PROCESS_PER_NODE -ppn $PROCESS_PER_NODE ./wrf.exe
```

-end of document-
