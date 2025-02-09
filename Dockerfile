FROM nvidia/cuda:12.8.0-cudnn-devel-ubuntu22.04 

# Set environment variable for non-interactive installations
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    python3-dev python3-pip python3-setuptools git g++ wget make \
    libprotobuf-dev protobuf-compiler libopencv-dev \
    libgoogle-glog-dev libboost-all-dev libhdf5-dev libatlas-base-dev && \
    rm -rf /var/lib/apt/lists/*

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
# RUN git clone https://github.com/CMU-Perceptual-Computing-Lab/openpose.git .
ARG OPEN_VERSION="v1.7.0"
RUN git clone --depth 1 -b $OPEN_VERSION https://github.com/CMU-Perceptual-Computing-Lab/openpose.git

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
    aws s3 cp s3://fuku-openpose-bucket/models/pose_iter_102000.caffemodel /openpose/models/pose/hand/pose_iter_102000.caffemodel && \
    aws s3 cp s3://fuku-openpose-bucket/models/pose_iter_120000.caffemodel /openpose/models/pose/hand/pose_iter_120000.caffemodel && \
    aws s3 cp s3://fuku-openpose-bucket/models/pose_iter_116000.caffemodel /openpose/models/pose/face/pose_iter_116000.caffemodel

# =========================================== S3 ends ===================================================

# Build OpenPose
WORKDIR /openpose/build
RUN cmake -DBUILD_PYTHON=ON .. && make -j$(nproc)
WORKDIR /openpose
