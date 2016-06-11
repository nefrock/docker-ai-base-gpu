FROM nvidia/cuda:7.5-cudnn4-devel-ubuntu14.04
MAINTAINER ttsurumi@nefrock.com

RUN apt-get update

RUN apt-get install -y --no-install-recommends \
    build-essential \
    pkg-config \
    cmake \
    git \
    wget \
    curl \
    software-properties-common \
    liblapack-dev \
    libatlas-base-dev \
    libatlas-dev \
    libboost-all-dev \
    libgflags-dev \
    libgoogle-glog-dev \
    libhdf5-serial-dev \
    libleveldb-dev \
    liblmdb-dev \
    libprotobuf-dev \
    libsnappy-dev \
    protobuf-compiler \
    python-dev \
    python-pip \
    gfortran \
    zip \
    unzip


RUN add-apt-repository main
RUN add-apt-repository universe
RUN add-apt-repository restricted
RUN add-apt-repository multiverse

RUN apt-get install -y --no-install-recommends \
    libgraphicsmagick1-dev \
    libavcodec-dev \
    libavformat-dev \
    libgtk2.0-dev \
    libjpeg-dev \
    libswscale-dev \
    graphicsmagick

RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


ENV CAFFE_ROOT=/opt/caffe
WORKDIR $CAFFE_ROOT

# FIXME: clone a specific git tag and use ARG instead of ENV once DockerHub supports this.
ENV CLONE_TAG=master


ENV PYCAFFE_ROOT $CAFFE_ROOT/python
ENV PYTHONPATH $PYCAFFE_ROOT:$PYTHONPATH
ENV PATH $CAFFE_ROOT/build/tools:$PYCAFFE_ROOT:$PATH
RUN echo "$CAFFE_ROOT/build/lib" >> /etc/ld.so.conf.d/caffe.conf && ldconfig

WORKDIR /workspace

RUN pip install numpy

RUN cd ~ && \
    mkdir -p ocv-tmp && \
    cd ocv-tmp && \
    curl -L https://github.com/Itseez/opencv/archive/2.4.11.zip -o ocv.zip && \
    unzip ocv.zip && \
    cd opencv-2.4.11 && \
    mkdir release && \
    cd release && \
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
    rm -rf ~/ocv-tmp

WORKDIR $CAFFE_ROOT

RUN git clone -b ${CLONE_TAG} --depth 1 https://github.com/BVLC/caffe.git . && \
    for req in $(cat python/requirements.txt) pydot; do pip install $req; done && \
    mkdir build && cd build && \
    cmake -DUSE_CUDNN=1 .. && \
    make -j"$(nproc)"

RUN ln -s /usr/local/cuda/lib64/stubs/libnvidia-ml.so /usr/local/cuda/lib64/libnvidia-ml.so
RUN ln -s /usr/local/nvidia/lib64/libcuda.so.1 /usr/local/cuda/lib64/libcuda.so
RUN ldconfig

RUN cd ~ && \
    mkdir -p dlib-tmp && \
    cd dlib-tmp && \
    curl -L \
         https://github.com/davisking/dlib/releases/download/v18.16/dlib-18.16.tar.bz2 \
         -o dlib.tar.bz2 && \
    tar xf dlib.tar.bz2 && \
    cd dlib-18.16/python_examples && \
    mkdir build && \
    cd build && \
    cmake ../../tools/python && \
    cmake --build . --config Release && \
    cp dlib.so /usr/local/lib/python2.7/dist-packages && \
    rm -rf ~/dlib-tmp

ENV LD_LIBRARY_PATH /usr/local/cuda/lib64
