## Scikitlearn
Machine Learning Benchmarks contains implementations of machine learning algorithms across data analytics frameworks. Scikit-learn_bench can be extended to add new frameworks and algorithms. It currently supports the scikit-learn frameworks with Intel(R) Extension for commonly used machine learning algorithms.


## Software Components
Table 1 lists the necessary software components. 
The descending row order represents the install sequence. 
The recommended component version and download location are also provided.

Table 1: Software Components
| Component| Version |
| :---        |    :----:   |
| Debian | [10](https://www.debian.org/download) |
| Python | [3.10](https://www.python.org/ftp/python/3.10.0/Python-3.10.0.tgz) |
| scikit-learn | [1.1.1](https://scikit-learn.org/stable/) |
| scikit-learn-intelex | [skl-intelx](https://github.com/intel/scikit-learn-intelex) |
| pandas | [pd](https://pandas.pydata.org/) |
| openpyxl | [opxl](https://openpyxl.readthedocs.io/en/stable/) |
| tqdm | [tqdm](https://tqdm.github.io/) |
| requests | [res](https://requests.readthedocs.io/en/latest/) |


## Configuration Snippets
This section contains code snippets on build instructions for software components.

Note: Common Linux utilities, such as docker, git, wget, will not be listed here. Please install on demand if it is not provided in base OS installation.

### DEBIAN
```
docker pull debian:10
```

### PYTHON
```
apt-get update && curl -Ls https://www.python.org/ftp/python/3.10.0/Python-3.10.0.tgz -o Python-3.10.0.tgz && tar -xzvf Python-3.10.0.tgz && cd Python-3.10.0 && ./configure --enable-optimizations && make -j8 && make install
```

### Scikit-learn
```
pip3 install scikit-learn==1.1.1
```
### Software components
```
pip3 install pandas scikit-learn-intelex openpyxl tqdm requests
```