## Java Software Platform 
The Java software platform is used for developing and running both enterprise and consumer-level software programs written in the Java programming language. Java OpenJDK and Java Zulu are two Java development kits (JDKs) used for developing Java-based applications.  OpenJDK (Open Java Development Kit) is a free and open-source implementation of the Java Platform, Standard Edition (Java SE).  Zulu JDK is an open-source build of the Java Platform Standard Edition (Java SE) and is based on the OpenJDK project. 

The Java software platform is optimised to support developing and running programs written in the Java programming language e.g. OpenJDK, Zulu JDK, Java enterprise systems, SpecJBB, etc. 

#java, #openjdk, #zulu, #jdk, #java development kit, #java platform, #jvm, #java virtual machine, #SpecJBB

## Software Components
Table 1 & 2 lists the necessary software components. 
The descending row order represents the install sequence. 
The recommended component version and download location are also provided.

Table 1: Software Components - OpenJDK
| Component| Version |
| :---        |    :----:   |
| ROCKY LINUX | [v8.5](https://hub.docker.com/_/rockylinux) |
| OPENJDK     | [v16.0.2](https://download.java.net/java/GA/jdk16.0.2/d4a915d82b4c4fbb9bde534da945d746/7/GPL/openjdk-16.0.2_linux-x64_bin.tar.gz) |
| OPENJDK     | [v17.0.1](https://download.java.net/java/GA/jdk17.0.1/2a2082e5a09d4267845be086888add4f/12/GPL/openjdk-17.0.1_linux-x64_bin.tar.gz) |
| OPENJDK     | [v18.0.2.1](https://download.java.net/java/GA/jdk18.0.2.1/db379da656dc47308e138f21b33976fa/1/GPL/openjdk-18.0.2.1_linux-x64_bin.tar.gz) |

Table 2: Software Components - Zulu
| Component| Version |
| :---        |    :----:   |
| ROCKY LINUX | [v8.5](https://hub.docker.com/_/rockylinux) |
| ZULU        | [v16.32.15](https://cdn.azul.com/zulu/bin/zulu16.32.15-ca-jdk16.0.2-linux_x64.tar.gz) |
| ZULU        | [v17.36.17](https://cdn.azul.com/zulu/bin/zulu17.36.17-ca-jdk17.0.4.1-linux_x64.tar.gz) |
| ZULU        | [v18.32.13](https://cdn.azul.com/zulu/bin/zulu18.32.13-ca-jdk18.0.2.1-linux_x64.tar.gz) |
| ZULU        | [v19.30.11](https://cdn.azul.com/zulu/bin/zulu19.30.11-ca-jdk19.0.1-linux_x64.tar.gz) |

## Configuration Snippets - OpenJDK
This section contains code snippets on build instructions for software components

Note: Common Linux utilities, such as docker, git, wget, curl will not be listed here. Please install on demand if it is not provided in base OS installation.

### ROCKY LINUX
```
docker pull rockylinux:8.5
```

### OPENJDK 16.0.2
```
OPENJDK_VER="jdk-16.0.2"
OPENJDK_PKG="https://download.java.net/java/GA/jdk16.0.2/d4a915d82b4c4fbb9bde534da945d746/7/GPL/openjdk-16.0.2_linux-x64_bin.tar.gz"
OPENJDK_INSTALL_DIR=/opt
curl -L "${OPENJDK_PKG}" -o "${OPENJDK_VER}.tar.gz" && \
  tar -xvf "${OPENJDK_VER}.tar.gz" && \
  rm -f "${OPENJDK_VER}.tar.gz"

cd ${OPENJDK_VER} && \
  update-alternatives --install /usr/bin/java java ${OPENJDK_INSTALL_DIR}/${OPENJDK_VER}/bin/java 2 && \
  update-alternatives --install /usr/bin/jar jar ${OPENJDK_INSTALL_DIR}/${OPENJDK_VER}/bin/jar 2 && \
  update-alternatives --install /usr/bin/javac javac ${OPENJDK_INSTALL_DIR}/${OPENJDK_VER}/bin/javac 2 && \
  update-alternatives --set jar ${OPENJDK_INSTALL_DIR}/${OPENJDK_VER}/bin/jar && \
  update-alternatives --set javac ${OPENJDK_INSTALL_DIR}/${OPENJDK_VER}/bin/javac

JAVA_HOME=${OPENJDK_INSTALL_DIR}/${OPENJDK_VER}/ \
JRE_HOME=${OPENJDK_INSTALL_DIR}/${OPENJDK_VER}/jre/ \
PATH=${OPENJDK_INSTALL_DIR}/${OPENJDK_VER}/bin:$PATH:${OPENJDK_INSTALL_DIR}/${OPENJDK_VER}/jre/bin
```

### OPENJDK 17.0.1
```
OPENJDK_VER="jdk-17.0.1"
OPENJDK_PKG="https://download.java.net/java/GA/jdk17.0.1/2a2082e5a09d4267845be086888add4f/12/GPL/openjdk-17.0.1_linux-x64_bin.tar.gz"
OPENJDK_INSTALL_DIR=/opt
curl -L "${OPENJDK_PKG}" -o "${OPENJDK_VER}.tar.gz" && \
  tar -xvf "${OPENJDK_VER}.tar.gz" && \
  rm -f "${OPENJDK_VER}.tar.gz"

cd ${OPENJDK_VER} && \
  update-alternatives --install /usr/bin/java java ${OPENJDK_INSTALL_DIR}/${OPENJDK_VER}/bin/java 2 && \
  update-alternatives --install /usr/bin/jar jar ${OPENJDK_INSTALL_DIR}/${OPENJDK_VER}/bin/jar 2 && \
  update-alternatives --install /usr/bin/javac javac ${OPENJDK_INSTALL_DIR}/${OPENJDK_VER}/bin/javac 2 && \
  update-alternatives --set jar ${OPENJDK_INSTALL_DIR}/${OPENJDK_VER}/bin/jar && \
  update-alternatives --set javac ${OPENJDK_INSTALL_DIR}/${OPENJDK_VER}/bin/javac

JAVA_HOME=${OPENJDK_INSTALL_DIR}/${OPENJDK_VER}/ \
    JRE_HOME=${OPENJDK_INSTALL_DIR}/${OPENJDK_VER}/jre/ \
    PATH=${OPENJDK_INSTALL_DIR}/${OPENJDK_VER}/bin:$PATH:${OPENJDK_INSTALL_DIR}/${OPENJDK_VER}/jre/bin
```

### OPENJDK 18.0.2.1
```
OPENJDK_VER="jdk-18.0.2.1"
OPENJDK_PKG="https://download.java.net/java/GA/jdk18.0.2.1/db379da656dc47308e138f21b33976fa/1/GPL/openjdk-18.0.2.1_linux-x64_bin.tar.gz"
OPENJDK_INSTALL_DIR=/opt

curl -L "${OPENJDK_PKG}" -o "${OPENJDK_VER}.tar.gz" && \
  tar -xvf "${OPENJDK_VER}.tar.gz" && \
  rm -f "${OPENJDK_VER}.tar.gz"

cd "${OPENJDK_VER}" && \
  update-alternatives --install /usr/bin/java java ${OPENJDK_INSTALL_DIR}/"${OPENJDK_VER}"/bin/java 2 && \
  update-alternatives --install /usr/bin/jar jar ${OPENJDK_INSTALL_DIR}/"${OPENJDK_VER}"/bin/jar 2 && \
  update-alternatives --install /usr/bin/javac javac ${OPENJDK_INSTALL_DIR}/"${OPENJDK_VER}"/bin/javac 2 && \
  update-alternatives --set jar ${OPENJDK_INSTALL_DIR}/"${OPENJDK_VER}"/bin/jar && \
  update-alternatives --set javac ${OPENJDK_INSTALL_DIR}/"${OPENJDK_VER}"/bin/javac

JAVA_HOME=${OPENJDK_INSTALL_DIR}/"${OPENJDK_VER}"/ \
    JRE_HOME=${OPENJDK_INSTALL_DIR}/"${OPENJDK_VER}"/jre/ \
    PATH=${OPENJDK_INSTALL_DIR}/"${OPENJDK_VER}"/bin:$PATH:${OPENJDK_INSTALL_DIR}/"${OPENJDK_VER}"/jre/bin
```

## Configuration Snippets - Zulu
This section contains code snippets on build instructions for key software components

Note: Common Linux utilities, such as docker, git, wget, curl will not be listed here. Please install on demand if it is not provided in base OS installation.

### ROCKY LINUX
```
docker pull rockylinux:8.5
```

### ZULU 16.32.15
```
ZULU_VERSION=zulu16.32.15
ZULU_PACKAGE="https://cdn.azul.com/zulu/bin/zulu16.32.15-ca-jdk16.0.2-linux_x64.tar.gz"
JDK_INSTALL_DIR=/opt

curl -L "${ZULU_PACKAGE}" -o "${ZULU_VERSION}.tar.gz" && \
  tar -xvf "${ZULU_VERSION}.tar.gz" && \
  rm -f "${ZULU_VERSION}.tar.gz"

cd "${ZULU_VERSION}-ca-jdk16.0.2-linux_x64" && \
  update-alternatives --install /usr/bin/java java ${JDK_INSTALL_DIR}/${ZULU_VERSION}/bin/java 2 && \
  update-alternatives --install /usr/bin/jar jar ${JDK_INSTALL_DIR}/${ZULU_VERSION}/bin/jar 2 && \
  update-alternatives --install /usr/bin/javac javac ${JDK_INSTALL_DIR}/${ZULU_VERSION}/bin/javac 2 && \
  update-alternatives --set jar ${JDK_INSTALL_DIR}/${ZULU_VERSION}/bin/jar && \
  update-alternatives --set javac ${JDK_INSTALL_DIR}/${ZULU_VERSION}/bin/javac

JAVA_HOME=${JDK_INSTALL_DIR}/"${ZULU_VERSION}-ca-jdk16.0.2-linux_x64"/ \
    JRE_HOME=${JDK_INSTALL_DIR}/"${ZULU_VERSION}-ca-jdk16.0.2-linux_x64"/jre/ \
    PATH=${JDK_INSTALL_DIR}/"${ZULU_VERSION}-ca-jdk16.0.2-linux_x64"/bin:$PATH:${JDK_INSTALL_DIR}/"${ZULU_VERSION}-ca-jdk17.0.4.1-linux_x64"/jre/bin
```

### ZULU 17.36.17
```
ZULU_VERSION=zulu17.36.17
ZULU_PACKAGE="https://cdn.azul.com/zulu/bin/zulu17.36.17-ca-jdk17.0.4.1-linux_x64.tar.gz"
JDK_INSTALL_DIR=/opt

curl -L "${ZULU_PACKAGE}" -o "${ZULU_VERSION}.tar.gz" && \
  tar -xvf "${ZULU_VERSION}.tar.gz" && \
  rm -f "${ZULU_VERSION}.tar.gz" 

cd "${ZULU_VERSION}-ca-jdk17.0.4.1-linux_x64" && \
  update-alternatives --install /usr/bin/java java ${JDK_INSTALL_DIR}/${ZULU_VERSION}/bin/java 2 && \
  update-alternatives --install /usr/bin/jar jar ${JDK_INSTALL_DIR}/${ZULU_VERSION}/bin/jar 2 && \
  update-alternatives --install /usr/bin/javac javac ${JDK_INSTALL_DIR}/${ZULU_VERSION}/bin/javac 2 && \
  update-alternatives --set jar ${JDK_INSTALL_DIR}/${ZULU_VERSION}/bin/jar && \
  update-alternatives --set javac ${JDK_INSTALL_DIR}/${ZULU_VERSION}/bin/javac
  
JAVA_HOME=${JDK_INSTALL_DIR}/"${ZULU_VERSION}-ca-jdk17.0.4.1-linux_x64"/ \
    JRE_HOME=${JDK_INSTALL_DIR}/"${ZULU_VERSION}-ca-jdk17.0.4.1-linux_x64"/jre/ \
    PATH=${JDK_INSTALL_DIR}/"${ZULU_VERSION}-ca-jdk17.0.4.1-linux_x64"/bin:$PATH:${JDK_INSTALL_DIR}/"${ZULU_VERSION}-ca-jdk17.0.4.1-linux_x64"/jre/bin
```

### ZULU 18.32.13
```
ZULU_VERSION=zulu18.32.13
ZULU_PACKAGE="https://cdn.azul.com/zulu/bin/zulu18.32.13-ca-jdk18.0.2.1-linux_x64.tar.gz"
JDK_INSTALL_DIR=/opt

curl -L "${ZULU_PACKAGE}" -o "${ZULU_VERSION}.tar.gz" && \
  tar -xvf "${ZULU_VERSION}.tar.gz" && \
  rm -f "${ZULU_VERSION}.tar.gz"

cd "${ZULU_VERSION}-ca-jdk18.0.2.1-linux_x64" && \
  update-alternatives --install /usr/bin/java java ${JDK_INSTALL_DIR}/${ZULU_VERSION}/bin/java 2 && \
  update-alternatives --install /usr/bin/jar jar ${JDK_INSTALL_DIR}/${ZULU_VERSION}/bin/jar 2 && \
  update-alternatives --install /usr/bin/javac javac ${JDK_INSTALL_DIR}/${ZULU_VERSION}/bin/javac 2 && \
  update-alternatives --set jar ${JDK_INSTALL_DIR}/${ZULU_VERSION}/bin/jar && \
  update-alternatives --set javac ${JDK_INSTALL_DIR}/${ZULU_VERSION}/bin/javac

JAVA_HOME=${JDK_INSTALL_DIR}/"${ZULU_VERSION}-ca-jdk18.0.2.1-linux_x64"/ \
    JRE_HOME=${JDK_INSTALL_DIR}/"${ZULU_VERSION}-ca-jdk18.0.2.1-linux_x64"/jre/ \
    PATH=${JDK_INSTALL_DIR}/"${ZULU_VERSION}-ca-jdk18.0.2.1-linux_x64"/bin:$PATH:${JDK_INSTALL_DIR}/"${ZULU_VERSION}-ca-jdk17.0.4.1-linux_x64"/jre/bin
```

### ZULU 19.30.11
```
ZULU_VERSION=zulu19.30.11
ZULU_PACKAGE="https://cdn.azul.com/zulu/bin/zulu19.30.11-ca-jdk19.0.1-linux_x64.tar.gz"
JDK_INSTALL_DIR=/opt

curl -L "${ZULU_PACKAGE}" -o "${ZULU_VERSION}.tar.gz" && \
  tar -xvf "${ZULU_VERSION}.tar.gz" && \
  rm -f "${ZULU_VERSION}.tar.gz"

cd "${ZULU_VERSION}-ca-jdk19.0.1-linux_x64" && \
  update-alternatives --install /usr/bin/java java ${JDK_INSTALL_DIR}/${ZULU_VERSION}/bin/java 2 && \
  update-alternatives --install /usr/bin/jar jar ${JDK_INSTALL_DIR}/${ZULU_VERSION}/bin/jar 2 && \
  update-alternatives --install /usr/bin/javac javac ${JDK_INSTALL_DIR}/${ZULU_VERSION}/bin/javac 2 && \
  update-alternatives --set jar ${JDK_INSTALL_DIR}/${ZULU_VERSION}/bin/jar && \
  update-alternatives --set javac ${JDK_INSTALL_DIR}/${ZULU_VERSION}/bin/javac

JAVA_HOME=${JDK_INSTALL_DIR}/"${ZULU_VERSION}-ca-jdk19.0.1-linux_x64"/ \
    JRE_HOME=${JDK_INSTALL_DIR}/"${ZULU_VERSION}-ca-jdk19.0.1-linux_x64"/jre/ \
    PATH=${JDK_INSTALL_DIR}/"${ZULU_VERSION}-ca-jdk19.0.1-linux_x64"/bin:$PATH:${JDK_INSTALL_DIR}/"${ZULU_VERSION}-ca-jdk17.0.4.1-linux_x64"/jre/bin
```

Workload Services Framework

-end of document-
