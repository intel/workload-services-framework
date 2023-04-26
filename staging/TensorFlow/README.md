## Tensorflow Software Stack
[TensorFlow](https://www.tensorflow.org/) is an open source software library for numerical computation using data flow graphs. It is used for machine learning applications such as neural networks and is widely used for deep learning and other applications. TensorFlow allows developers to create data flow graphs for numerical computations, which can be executed on various types of hardware such as CPUs and GPUs. It also provides abstractions for building and training models, as well as tools for visualizing them. Typical use cases include image recognition, natural language processing, and recommender systems.

TensorFlow software stack is optimised for building and training of machine learning and deep learning models, e.g. [BERT](https://arxiv.org/abs/1810.04805), ResNet and other such models.

#TensorFlow, #BERT, #ResNet, #deep learning, #maching learning, #image recognition, #natural language processing, #recommender systems

## Software Components
Table 1 lists the necessary software components. 
The descending row order represents the install sequence. 
The recommended component version and download location are also provided.

Table 1: Software Components
| Component| Version |
| :--- | :---: |
| Ubuntu | [20.04](https://hub.docker.com/layers/library/ubuntu/20.04/images/sha256-3626dff0d616e8ee7065a9ac8c7117e904a4178725385910eeecd7f1872fc12d) |
| Python | [3.8.10](https://packages.ubuntu.com/focal/python3) |
| pip | [20.0.2](https://packages.ubuntu.com/focal/python3-pip) |
| TensorFlow | [2.11.0](https://pypi.org/project/intel-tensorflow/) |
| Intel® Extension for TensorFlow | [1.1.0](https://pypi.org/project/intel-extension-for-tensorflow/) |


## Configuration Snippets
This section contains code snippets on build instructions for software components.

Note: Common Linux utilities, such as docker, git, wget, will not be listed here. Please install on demand if it is not provided in base OS installation.

### Ubuntu
```
docker pull ubuntu:20.04
```

### pip
```
apt install -y  python3 python3-pip
```

### TensorFlow
```
pip install intel-tensorflow==2.11.0
```

### Intel® Extension for TensorFlow
```
pip install --upgrade intel-extension-for-tensorflow[cpu]
```

Workload Services Framework

-end of document-