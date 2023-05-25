## INC
[Intel Neural Compressor](https://github.com/intel/neural-compressor) Intel® Neural Compressor aims to provide popular model compression techniques such as quantization, pruning (sparsity), distillation, and neural architecture search on mainstream frameworks such as TensorFlow, PyTorch, ONNX Runtime, and MXNet, as well as Intel extensions such as Intel Extension for TensorFlow and Intel Extension for PyTorch.  In particular, the tool provides the key features, typical examples, and open collaborations as below:
    
    Support a wide range of Intel hardware such as Intel Xeon Scalable processor, Intel Xeon CPU Max Series, Intel Data Center GPU Flex Series, and Intel Data Center GPU Max Series with extensive testing; support AMD CPU, ARM CPU, and NVidia GPU through ONNX Runtime with limited testing.  
    
    Validate more than 10,000 models such as Bloom-176B, OPT-6.7B, Stable Diffusion, GPT-J, BERT-Large, and ResNet50 from popular model hubs such as Hugging Face, Torch Vision, and ONNX Model Zoo, by leveraging zero-code optimization solution Neural Coder and automatic accuracy-driven quantization strategies

    Collaborate with cloud marketplace such as Google Cloud Platform, Amazon Web Services, and Azure, software platforms such as Alibaba Cloud and Tencent TACO, and open AI ecosystem such as Hugging Face, PyTorch, ONNX, and Lightning AI

#intel neural compressor, #AI, #ai model compression

## Software Components
Table 1 lists the necessary software components. 
The descending row order represents the install sequence. 
The recommended component version and download location are also provided.

Table 1: Software Components
| Component| Version |
| :---        |    :----:   |
| Debian | [11](https://debian.org/) |
| Python | [3.9.14](https://github.com/python/) |
| Intel Neural Compressor | [1.1.2](https://github.com/intel/neural-compressor) |

## Configuration Snippets
This section contains code snippets on build instructions for software components.

Note: Common Linux utilities, such as docker, git, wget, will not be listed here. Please install on demand if it is not provided in base OS installation.

### DEBIAN
```
docker pull debian:11
```

### PYTHON BASE
```
curl -Ls https://www.python.org/ftp/python/3.10.11/Python-3.10.11.tgz -o Python-3.10.11.tgz 
tar -xzvf Python-3.10.11.tgz 
cd Python-3.10.11 
./configure --enable-optimizations 
make -j8 
make install
```

### INTEL NEURAL-COMPRESSOR
```
python3 -m pip install neural-compressor-full
```

-end of document-
