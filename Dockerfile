FROM nvidia/cuda:8.0-cudnn5-devel-ubuntu16.04
MAINTAINER ttsurumi@nefrock.com

# https://github.com/BVLC/caffe/wiki/Ubuntu-16.04-or-15.10-Installation-Guide#the-gpu-support-prerequisites
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    zip \
    wget \
    curl \
    ffmpeg \
    pkg-config \
    qtbase5-dev \
    libatlas-base-dev \
    libboost-all-dev \
    libgflags-dev \
    libgoogle-glog-dev \
    libhdf5-serial-dev \
    libleveldb-dev \
    liblmdb-dev \
    libopencv-dev \
    libprotobuf-dev \
    libsnappy-dev \
    protobuf-compiler \
    python3-dev \
    python3-scipy \
    python3-numpy \
    python3-tk\
    python3-pip \
    && rm -rf /var/lib/apt/lists/*


RUN apt-get install -y \
    gfortran \
    libatlas-dev \
    libavcodec-dev \
    libavformat-dev \
    libgtk2.0-dev \
    libjpeg-dev \
    libswscale-dev \
    pkg-config \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


# https://github.com/BVLC/caffe/wiki/OpenCV-3.1-Installation-Guide-on-Ubuntu-16.04
RUN apt-get install --assume-yes \
    libdc1394-22 \
    libdc1394-22-dev \
    libpng12-dev \
    libtiff5-dev \
    libjasper-dev

WORKDIR /workspace

# install opencv
RUN cd ~ && \
    mkdir -p ocv-tmp && \
    cd ocv-tmp && \
    curl -L https://github.com/opencv/opencv/archive/3.2.0.tar.gz -o ocv.tgz && \
    tar -zxvf ocv.tgz && \
    cd opencv-3.2.0 && \
    mkdir build && \
    cd build && \
    cmake -D CMAKE_BUILD_TYPE=RELEASE \
          -D CMAKE_INSTALL_PREFIX=/usr/local \
          -D BUILD_opencv_java=OFF \
          -D WITH_IPP=OFF \
          -D WITH_1394=OFF \
          -D WITH_FFMPEG=OFF \
          -D BUILD_EXAMPLES=OFF \
          -D BUILD_TESTS=OFF \
          -D BUILD_PERF_TESTS=OFF \
          -D BUILD_DOCS=OFF  \
          -D CUDA_GENERATION=Kepler \
          -D BUILD_NEW_PYTHON_SUPPORT=ON \
          -D PYTHON_EXECUTABLE=$(which python) \
          .. && \
    make -j8 && \
    make install && \
    /bin/bash -c 'echo "/usr/local/lib" > /etc/ld.so.conf.d/opencv.conf' && \
    ldconfig && \
    apt-get update && \
    rm -rf ~/ocv-tmp


ENV CAFFE_ROOT=/opt/caffe
WORKDIR $CAFFE_ROOT

# FIXME: clone a specific git tag and use ARG instead of ENV once DockerHub supports this.
ENV CLONE_TAG=master

RUN ln -s /usr/bin/pip3 /usr/bin/pip
RUN pip install --upgrade pip

RUN git clone -b ${CLONE_TAG} --depth 1 https://github.com/BVLC/caffe.git . && \
    for req in $(cat python/requirements.txt) pydot; do pip install $req; done

COPY caffeconf/Makefile /opt/caffe/
COPY caffeconf/Makefile.config /opt/caffe/
RUN cd /usr/lib/x86_64-linux-gnu &&  ln -s libboost_python-py35.so libboost_python3.so

RUN make all -j"$(nproc)"
RUN make test -j"$(nproc)"
#RUN make runtest -j"$(nproc)"
RUN make pycaffe -j"$(nproc)"
RUN make distribute

#RUN make all -j"$(nproc)" && \
#    make test -j"$(nproc)" && \
#    make runtest -j"$(nproc)" && \
#    make pycaffe -j"$(nproc)" && \
#    make distribute


RUN ln -s /usr/local/cuda/lib64/stubs/libnvidia-ml.so /usr/local/cuda/lib64/libnvidia-ml.so
RUN ln -s /usr/local/nvidia/lib64/libcuda.so.1 /usr/local/cuda/lib64/libcuda.so
RUN ldconfig

ENV PYCAFFE_ROOT $CAFFE_ROOT/python
ENV PYTHONPATH $PYCAFFE_ROOT:$PYTHONPATH
ENV PATH $CAFFE_ROOT/build/tools:$PYCAFFE_ROOT:$PATH
RUN echo "$CAFFE_ROOT/build/lib" >> /etc/ld.so.conf.d/caffe.conf && ldconfig

RUN apt-get install -y python-setuptools

# install dlib
RUN cd ~ && \
    mkdir -p dlib-tmp && \
    cd dlib-tmp && \
    curl -L \
         https://github.com/davisking/dlib/archive/v19.4.tar.gz -o dlib.tar.gz && \
    tar zxvf dlib.tar.gz && \
    cd dlib-19.4/examples && \
    mkdir build && \
    cd build && \
    cmake .. && \
    cmake --build .  && \
    cd ../../ && \
    python setup.py install

ENV LD_LIBRARY_PATH /usr/local/cuda/lib64

RUN apt-get install -y libopenblas-dev swig

WORKDIR /root
