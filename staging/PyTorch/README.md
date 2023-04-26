## PyTorch Software Stack
[Pytorch](https://pytorch.org/) is an open-source deep learning platform developed by Facebook's artificial intelligence research group. It provides a wide range of algorithms for deep learning, including convolutional neural networks, recurrent neural networks, and reinforcement learning. It also provides efficient tools for data preprocessing, model training, and deployment. PyTorch is often used for natural language processing and computer vision tasks.

Pytorch software stack is optimised for building and training of machine learning and deep learning models, e.g. [DLRM](https://github.com/facebookresearch/dlrm), ResNet and other such models.

#Pytorch, #DLRM, #ResNet, #deep learning, #maching learning, #image recognition, #natural language processing, #recommender systems

## Software Components
Table 1 lists the necessary software components. 
The descending row order represents the install sequence. 
The recommended component version and download location are also provided.

Table 1: Software Components
| Component                          |                           Version                            |
| :--------------------------------- | :----------------------------------------------------------: |
| Ubuntu                             |               [22.04](https://hub.docker.com/)               |
| Python                             |         [3.7](https://repo.anaconda.com/miniconda/)          |
| pip                                |                 [21.0.1](https://pypi.org/)                  |
| PyTorch                            |      [1.13.0+cpu](https://download.pytorch.org/whl/cpu)      |
| Intel® Extension for PyTorch       | [1.13.0](https://pypi.org/project/intel-extension-for-pytorch/) |
| TorchVision                        |      [0.14.0+cpu](https://download.pytorch.org/whl/cpu)      |
| TorchAudio                         |      [0.13.0+cpu](https://download.pytorch.org/whl/cpu)      |
| Intel® oneCCL Bindings for PyTorch | [1.12.0+cpu](https://intel-optimized-pytorch.s3.cn-north-1.amazonaws.com.cn/torch_ccl/cpu/oneccl_bind_pt-1.12.0%2Bcpu-cp37-cp37m-linux_x86_64.whl) |

## Configuration Snippets
This section contains code snippets on build instructions for software components.

Note: Common Linux utilities, such as docker, git, wget, will not be listed here. Please install on demand if it is not provided in base OS installation.

### Ubuntu
```
docker pull ubuntu:22.04
```

### Python (Built-In Miniconda)
```
wget https://repo.anaconda.com/miniconda//Miniconda3-py37_23.1.0-1-Linux-x86_64.sh -O anaconda3.sh
chmod +x anaconda3.sh
./anaconda3.sh -b -p /root/anaconda3
```

### pip
```
pip install pip==21.0.1
```

### PyTorch, TorchVision, TorchAudio
```
pip install --no-cache-dir torch==1.13.0+cpu \
                torchvision==0.14.0+cpu \
                torchaudio==0.13.0+cpu \
                --extra-index-url https://download.pytorch.org/whl/cpu
```

### Intel® Extension for PyTorch
```
pip install --no-cache-dir intel_extension_for_pytorch==1.13.0
```

### Intel® oneCCL Bindings for PyTorch
```
wget https://intel-optimized-pytorch.s3.cn-north-1.amazonaws.com.cn/torch_ccl/cpu/oneccl_bind_pt-1.12.0%2Bcpu-cp37-cp37m-linux_x86_64.whl
pip install --no-cache-dir oneccl_bind_pt-1.12.0+cpu-cp37-cp37m-linux_x86_64.whl
```

Workload Services Framework

-end of document-