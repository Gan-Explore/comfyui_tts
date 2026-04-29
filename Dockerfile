# Use public NVIDIA CUDA image (compatible with RunPod's RTX 4090)
FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_NO_CACHE_DIR=1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git wget curl ffmpeg sox pkg-config build-essential \
    python3.11 python3.11-venv python3.11-dev python3-pip \
    python-is-python3 \
    libgl1 libglib2.0-0 libsndfile1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set Python 3.11 as default
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1

WORKDIR /workspace

# Copy startup script
COPY startup.sh /opt/startup.sh
RUN chmod +x /opt/startup.sh

EXPOSE 8188 8888

ENTRYPOINT ["/opt/startup.sh"]
