## XGBoost
XGBoost is an optimized distributed gradient boosting library designed to be highly efficient, flexible and portable. It implements machine learning algorithms under the Gradient Boosting framework. XGBoost provides a parallel tree boosting (also known as GBDT, GBM) that solve many data science problems in a fast and accurate way. The same code runs on major distributed environment (Kubernetes, Hadoop, SGE, Dask, Spark, PySpark) and can solve problems beyond billions of examples.
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
| xgboost | [1.6.1](https://xgboost.readthedocs.io/en/stable/) |
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

### XGBoost
```
pip3 install xgboost==1.6.1
```
### Software components
```
pip3 install scikit-learn pandas==1.3.5 openpyxl tqdm requests scipy
```