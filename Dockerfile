FROM nvidia/cuda:12.8.0-cudnn-devel-ubuntu22.04 

# Set environment variable for non-interactive installations
ENV DEBIAN_FRONTEND=noninteractive

# ======================== Install library starts ========================
# Basic
RUN apt-get --assume-yes update
RUN apt-get --assume-yes install build-essential
# OpenCV
RUN apt-get --assume-yes install libopencv-dev
# General dependencies
RUN apt-get --assume-yes install libatlas-base-dev libprotobuf-dev libleveldb-dev libsnappy-dev libhdf5-serial-dev protobuf-compiler
RUN apt-get --assume-yes install --no-install-recommends libboost-all-dev
# Remaining dependencies, 14.04
RUN apt-get --assume-yes install libgflags-dev libgoogle-glog-dev liblmdb-dev
# Python3 libs
RUN apt-get --assume-yes install python3-setuptools python3-dev build-essential
RUN apt-get --assume-yes install python3-pip
RUN pip3 install --upgrade numpy protobuf opencv-python
# OpenCL Generic
RUN apt-get --assume-yes install opencl-headers ocl-icd-opencl-dev
RUN apt-get --assume-yes install libviennacl-dev
# otherwise => wget, git not found
RUN apt-get --assume-yes install wget
RUN apt-get --assume-yes install git
# ======================== Install library ends ========================
# Upgrade pip and install Python packages
RUN pip3 install --upgrade pip
RUN pip3 install numpy opencv-python awscli

# Replace CMake with precompiled binaries to avoid CUDA variable bugs
RUN wget -c "https://github.com/Kitware/CMake/releases/download/v3.19.6/cmake-3.19.6.tar.gz"
RUN tar xf cmake-3.19.6.tar.gz
RUN cd cmake-3.19.6 && ./configure && make && make install

# Verify CMake installation
RUN cmake --version

# Get OpenPose
WORKDIR /openpose
ARG OPEN_VERSION="v1.7.0"
RUN git clone --depth 1 -b $OPEN_VERSION https://github.com/CMU-Perceptual-Computing-Lab/openpose.git .

# =========================================== S3 starts ===================================================
# Set build arguments for AWS credentials
ARG AWS_ACCESS_KEY_ID
ARG AWS_SECRET_ACCESS_KEY
ARG AWS_DEFAULT_REGION

# Set environment variables for AWS
ENV AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
    AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} \
    AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}

# Download the model files from S3
RUN aws s3 cp s3://fuku-openpose-bucket/models/pose_iter_584000.caffemodel /openpose/models/pose/body_25/pose_iter_584000.caffemodel && \
    aws s3 cp s3://fuku-openpose-bucket/models/pose_iter_102000.caffemodel /openpose/models/hand/pose_iter_102000.caffemodel && \
    aws s3 cp s3://fuku-openpose-bucket/models/pose_iter_120000.caffemodel /openpose/models/hand/pose_iter_120000.caffemodel && \
    aws s3 cp s3://fuku-openpose-bucket/models/pose_iter_116000.caffemodel /openpose/models/face/pose_iter_116000.caffemodel
# =========================================== S3 ends ===================================================

RUN rm -rf openpose/build
RUN mkdir build && cd build
RUN cd build && cmake ..

# Patch Caffe to remove unsupported architectures
WORKDIR /openpose/3rdparty/caffe
RUN sed -i 's/sm_35;//g' CMakeLists.txt && \
    sed -i 's/sm_37;//g' CMakeLists.txt

# Build OpenPose with updated CUDA architectures
WORKDIR /openpose/build
RUN make -j$(nproc)
WORKDIR /openpose
