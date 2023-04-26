## FFMPEG
[FFMPEG](https://www.ffmpeg.org/) stands for Fast Forward Moving Picture Experts Group. It is a free and open source software project that offers many tools for video and audio processing. With FFMPEG, you can decode, encode, transcode, mux, demux, stream, filter and play most types of video and audio. 

At its core is the command-line ffmpeg tool itself, designed for processing of video and audio files. It is widely used for format transcoding, basic editing (trimming and concatenation), video scaling, video post-production effects and standards compliance (SMPTE, ITU). 

#ffmpeg, #Fast Forward Moving Picture Experts Group, #video processing, #audio processing, #media processing, #transcode

## Software Components
Table 1 lists the necessary software components. 
The descending row order represents the install sequence. 
The recommended component version and download location are also provided.

Table 1: Software Components

| Component| Version |
| :---        |    :----:   |
| UBUNTU | [v22.04](https://ubuntu.com/) |
| YASM | [v1.3.0](https://github.com/OpenVisualCloud/Dockerfiles-Resources/raw/master/yasm-1.3.0.tar.gz) |
| LIBX264 | [5db6aa6cab1b146e07b60cc1736a01f21da01154](https://code.videolan.org/videolan/x264.git) |
| LIBX265 | [v3.1](https://github.com/videolan/x265/archive/3.1.tar.gz) |
| LIBVPX | [v1.9.0](https://chromium.googlesource.com/webm/libvpx.git) |
| SVT HEVC | [v1.5.1](https://github.com/OpenVisualCloud/SVT-HEVC) |
| DAV1D | [v0.9.0](https://code.videolan.org/videolan/dav1d/-/archive/0.9.0/dav1d-0.9.0.tar.gz) |
| SVT AV1 | [v0.9.1](https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/v0.9.1/SVT-AV1-v0.9.1.tar.gz) |
| FFMPEG | [n4.4](https://github.com/FFmpeg/FFmpeg.git) |

## Configuration Snippets
This section contains code snippets on build instructions for software components.

Note: Common Linux utilities, such as docker, git, wget, will not be listed here. Please install on demand if it is not provided in base OS installation.

### UBUNTU
```
docker pull ubuntu:22.04
```

### YASM
```
YASM_VER=1.3.0
YASM_REPO=https://github.com/OpenVisualCloud/Dockerfiles-Resources/raw/master/yasm-${YASM_VER}.tar.gz
cd /opt/build && \
    wget --no-check-certificate -O - ${YASM_REPO} | tar xz
cd /opt/build/yasm-1.3.0 && \
    ./configure --prefix=/usr/local --libdir=/usr/local/lib64 && \
    make -j $(nproc) && \
    make install
```

### LIBX264
```
LIBX264_VER=5db6aa6cab1b146e07b60cc1736a01f21da01154
LIBX264_REPO=https://code.videolan.org/videolan/x264.git
cd /opt/build && \
    git clone ${LIBX264_REPO} -b stable && \
    cd x264 && \
    git checkout ${LIBX264_VER} && \
    ./configure --prefix=/usr/local --libdir=/usr/local/lib64 --bindir=/usr/local/bin --enable-shared --enable-pic && \
    make -j$(nproc) && \
    make install DESTDIR=/opt/dist && \
    make install
```

### LIBX265
```
LIBX265_VER=3.1
LIBX265_REPO=https://github.com/videolan/x265/archive/${LIBX265_VER}.tar.gz
cd /opt/build && \   
    wget -O - ${LIBX265_REPO} | tar xz && \
    cd x265-${LIBX265_VER}/build/linux && \
    cmake -DBUILD_SHARED_LIBS=ON -DCMAKE_INSTALL_PREFIX=/usr/local -DLIB_INSTALL_DIR=/usr/local/lib64 ../../source && \
    make -j$(nproc) && \
    make install DESTDIR=/opt/dist && \
    make install
```

### LIBVPX
```
LIBVPX_VER=v1.9.0
LIBVPX_REPO=https://chromium.googlesource.com/webm/libvpx.git
cd /opt/build && \
    git clone ${LIBVPX_REPO} -b ${LIBVPX_VER} --depth 1 && \
    cd libvpx && \
    ./configure --prefix=/usr/local --libdir=/usr/local/lib64 --enable-shared --disable-examples --disable-unit-tests --enable-vp9-highbitdepth --as=nasm && \
    make -j$(nproc) && \
    make install DESTDIR=/opt/dist && \
    make install
```

### SVT HEVC
```
SVT_HEVC_VER=v1.5.1
SVT_HEVC_REPO=https://github.com/OpenVisualCloud/SVT-HEVC
cd /opt/build && \
    git clone -b ${SVT_HEVC_VER} --depth 1 ${SVT_HEVC_REPO} && cd SVT-HEVC
cd /opt/build/SVT-HEVC/Build/linux && \
    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_INSTALL_LIBDIR=/usr/local/lib64 -DCMAKE_ASM_NASM_COMPILER=yasm ../.. && \
    make -j $(nproc) && \
    make install DESTDIR=/opt/dist && \
    make install
```

### DAV1D
```
DAV1D_VER=0.9.0
DAV1D_REPO=https://code.videolan.org/videolan/dav1d/-/archive/${DAV1D_VER}/dav1d-${DAV1D_VER}.tar.gz
cd /opt/build && \
  wget -O - ${DAV1D_REPO} | tar xz
cd /opt/build/dav1d-${DAV1D_VER} && \
  meson build --prefix=/usr/local --libdir /usr/local/lib64 --buildtype=plain && \
  cd build && \
  ninja install && \
  DESTDIR=/opt/dist ninja install
```

### SVT AV1
```
SVT_AV1_VER=v0.9.1
SVT_AV1_REPO=https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/${SVT_AV1_VER}/SVT-AV1-${SVT_AV1_VER}.tar.gz
cd /opt/build && \
    wget -O - ${SVT_AV1_REPO} | tar zx && \
    mv SVT-AV1-${SVT_AV1_VER} SVT-AV1 && \
    cd SVT-AV1/Build/linux && \
    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_INSTALL_LIBDIR=/usr/local/lib64 -DCMAKE_ASM_NASM_COMPILER=yasm ../.. && \
    make -j $(nproc) && \
    sed -i "s/SvtAv1dec/SvtAv1Dec/" SvtAv1Dec.pc && \
    make install DESTDIR=/opt/dist && \
    make install
```

### FFMPEG
```
FFMPEG_VER=n4.4
FFMPEG_REPO=https://github.com/FFmpeg/FFmpeg.git
cd /opt/build && \
    git clone ${FFMPEG_REPO} -b ${FFMPEG_VER} ffmpeg 
cd /opt/build/ffmpeg && \
    git apply /opt/build/SVT-HEVC/ffmpeg_plugin/n4.4-0001-lavc-svt_hevc-add-libsvt-hevc-encoder-wrapper.patch && \
    ./configure --prefix=/usr/local --libdir=/usr/local/lib64 --bindir=/usr/local/bin --enable-shared --disable-doc --disable-htmlpages \
    --disable-manpages --disable-podpages --disable-txtpages \
    --extra-cflags=-w --enable-nonfree --enable-libass --enable-libfreetype --disable-xlib --disable-sdl2 --disable-hwaccels --disable-vaapi \
    --enable-libvpx --enable-libx264 --enable-gpl --enable-libx265 --enable-libsvthevc --enable-libsvtav1 --enable-libdav1d --extra-libs="-lpthread -lm" && \
    make -j$(nproc) && \
    make install DESTDIR=/opt/dist && \
    make install
```

Workload Services Framework

-end of document-
