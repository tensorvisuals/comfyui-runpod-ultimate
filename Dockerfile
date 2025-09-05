# syntax=docker/dockerfile:1.7
FROM pytorch/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04 AS builder

# Build Args (NOT persisted in final image)
ARG DEBIAN_FRONTEND=noninteractive
ARG BUILD_TYPE=minimal
ARG HF_TOKEN=""
ARG CIVITAI_TOKEN=""

# Environment Setup for Builder
ENV TZ=UTC \
    PIP_NO_CACHE_DIR=1 \
    HF_HUB_ENABLE_HF_TRANSFER=1 \
    PYTHONUNBUFFERED=1 \
    COMFYUI_PATH=/opt/ComfyUI

# System Dependencies (PyTorch image hat schon Python 3.11 und CUDA)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git git-lfs curl wget aria2 rsync unzip p7zip-full \
    build-essential \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 libgomp1 \
    libgoogle-perftools-dev tcmalloc-minimal4 \
    ffmpeg libsndfile1 \
    && git lfs install \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install ComfyUI
WORKDIR /opt
RUN git clone https://github.com/comfyanonymous/ComfyUI.git

WORKDIR ${COMFYUI_PATH}
RUN pip install -r requirements.txt

# Install additional packages
COPY requirements/base.txt /tmp/base.txt
RUN pip install -r /tmp/base.txt || true

# Install Custom Nodes
COPY scripts/install_nodes.sh /tmp/install_nodes.sh
RUN chmod +x /tmp/install_nodes.sh && \
    BUILD_TYPE=${BUILD_TYPE} bash /tmp/install_nodes.sh

# Install node requirements
COPY requirements/nodes.txt /tmp/nodes.txt
RUN pip install -r /tmp/nodes.txt || true

# Copy model download script
COPY scripts/download_models.py /tmp/download_models.py

# Final Stage - auch PyTorch Runtime Image
FROM pytorch/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-runtime-ubuntu22.04

ARG DEBIAN_FRONTEND=noninteractive

# Runtime Environment
ENV TZ=UTC \
    PIP_NO_CACHE_DIR=1 \
    HF_HUB_ENABLE_HF_TRANSFER=1 \
    PYTHONUNBUFFERED=1 \
    PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True" \
    CUDA_MODULE_LOADING=LAZY \
    COMFYUI_PATH=/opt/ComfyUI \
    LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git git-lfs curl wget \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 libgomp1 \
    libgoogle-perftools-dev tcmalloc-minimal4 \
    ffmpeg libsndfile1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1000 -s /bin/bash runpod && \
    mkdir -p /opt/ComfyUI /workspace && \
    chown -R runpod:runpod /opt /workspace

# Copy from builder
COPY --from=builder --chown=runpod:runpod /opt/ComfyUI ${COMFYUI_PATH}
COPY --from=builder --chown=runpod:runpod /opt/conda /opt/conda

# Setup configs and workflows
COPY --chown=runpod:runpod configs/server_config.json ${COMFYUI_PATH}/server_config.json
COPY --chown=runpod:runpod configs/extra_model_paths.yaml ${COMFYUI_PATH}/extra_model_paths.yaml
COPY --chown=runpod:runpod workflows ${COMFYUI_PATH}/workflows

# Copy scripts
COPY --chown=runpod:runpod scripts/model_downloader.py ${COMFYUI_PATH}/model_downloader.py
COPY --chown=runpod:runpod scripts/download_models.py /tmp/download_models.py
COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/healthcheck.sh /healthcheck.sh
RUN chmod +x /entrypoint.sh /healthcheck.sh

# Create required directories
RUN mkdir -p ${COMFYUI_PATH}/web && \
    chown -R runpod:runpod ${COMFYUI_PATH}

USER runpod
WORKDIR ${COMFYUI_PATH}

EXPOSE 8188
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=5 \
    CMD ["/healthcheck.sh"]

ENTRYPOINT ["/entrypoint.sh"]