FROM nvidia/cuda:11.8.0-cudnn8-devel-ubuntu18.04

# Set environment variable for non-interactive installations
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    python3-dev python3-pip python3-setuptools git g++ wget make \
    libprotobuf-dev protobuf-compiler libopencv-dev \
    libgoogle-glog-dev libboost-all-dev libcaffe-cuda-dev libhdf5-dev libatlas-base-dev && \
    rm -rf /var/lib/apt/lists/*

# Upgrade pip and install Python packages
RUN pip3 install --upgrade pip
RUN pip3 install numpy opencv-python

#replace cmake as old version has CUDA variable bugs
RUN wget https://github.com/Kitware/CMake/releases/download/v3.16.0/cmake-3.16.0-Linux-x86_64.tar.gz && \
    tar xzf cmake-3.16.0-Linux-x86_64.tar.gz -C /opt && \
    rm cmake-3.16.0-Linux-x86_64.tar.gz
ENV PATH="/opt/cmake-3.16.0-Linux-x86_64/bin:${PATH}"

# Get OpenPose
WORKDIR /openpose
RUN git clone https://github.com/CMU-Perceptual-Computing-Lab/openpose.git .

# =========================================== S3 starts ===================================================
# =========================================== S3 starts  ===================================================
# =========================================== S3 starts  ===================================================
# Install AWS CLI
RUN pip3 install awscli

# Set build arguments for AWS credentials
ARG AWS_ACCESS_KEY_ID
ARG AWS_SECRET_ACCESS_KEY
ARG AWS_DEFAULT_REGION

# Set environment variables for AWS
ENV AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
    AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} \
    AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}

# Download the model file from S3
RUN aws s3 cp s3://fuku-openpose-bucket/models/pose_iter_584000.caffemodel /openpose/models/pose/body_25/pose_iter_584000.caffemodel
RUN aws s3 cp s3://fuku-openpose-bucket/models/pose_iter_102000.caffemodel /openpose/models/pose/hand/pose_iter_102000.caffemodel
RUN aws s3 cp s3://fuku-openpose-bucket/models/pose_iter_120000.caffemodel /openpose/models/pose/hand/pose_iter_120000.caffemodel
RUN aws s3 cp s3://fuku-openpose-bucket/models/pose_iter_116000.caffemodel /openpose/models/pose/face/pose_iter_116000.caffemodel

# Unset AWS credentials to avoid storing them in image layers
RUN unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION

# =========================================== S3 ends ===================================================
# =========================================== S3 ends ===================================================
# =========================================== S3 ends ===================================================

# Build OpenPose
WORKDIR /openpose/build
RUN cmake -DBUILD_PYTHON=ON .. && make -j `nproc`
WORKDIR /openpose
