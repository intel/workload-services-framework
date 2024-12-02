
# Software Stack Elements

A software stack is the underlying software layers that a workload is constructed upon. The software layers include reusable software libraries, ansible scripts, docker images, and microservices.

## Structure

Software stack consists of the following elements, some described in this document and others in the linked document. 

- **[Dockerfiles][dockerfile]**: A software stack may contain one or many Dockerfiles.   
- **[CMakeLists.txt][cmakelists]**: A manifest to configure `cmake`.  
- **[build.sh][build]**: A script for building the workload docker image(s).  

Optionally, software stacks can define unit tests similar to how workloads work to verify software stack functionalities.  

## See Also

- [Dockerfile Requirements][dockerfile]

[dockerfile]: dockerfile.md
[cmakelists]: cmakelists.md
[build]: build.md
