# syntax=docker/dockerfile:1.7
FROM nvidia/cuda:12.8.0-devel-ubuntu22.04 AS builder

# Build Args (NOT persisted in final image)
ARG DEBIAN_FRONTEND=noninteractive
ARG PYTHON_VERSION=3.11
ARG BUILD_TYPE=standard
ARG HF_TOKEN=""
ARG CIVITAI_TOKEN=""
ARG COMFYUI_COMMIT="6f53c6ba478e19b47e2c6beea284913b4094a25f"

# Environment Setup for Builder
ENV TZ=UTC \
    PIP_NO_CACHE_DIR=1 \
    HF_HUB_ENABLE_HF_TRANSFER=1 \
    PYTHONUNBUFFERED=1 \
    COMFYUI_PATH=/opt/ComfyUI

# System Dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git git-lfs curl wget aria2 rsync unzip p7zip-full \
    build-essential pkg-config cmake ninja-build \
    python${PYTHON_VERSION} python${PYTHON_VERSION}-dev python3-pip python3-venv \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 libgomp1 \
    libgoogle-perftools-dev tcmalloc-minimal4 \
    ffmpeg libsndfile1 \
    && ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python \
    && ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 \
    && git lfs install \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install cuDNN
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcudnn9-dev libcudnn9 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip
RUN python3 -m pip install --upgrade pip wheel setuptools

# Install PyTorch 2.8.0 Stable with CUDA 12.8
RUN python3 -m pip install torch==2.8.0+cu128 torchvision==0.20.0+cu128 torchaudio==2.8.0+cu128 \
    --index-url https://download.pytorch.org/whl/cu128

# Install ComfyUI with specific commit
WORKDIR /opt
RUN git clone https://github.com/comfyanonymous/ComfyUI.git && \
    cd ComfyUI && \
    git checkout ${COMFYUI_COMMIT}

WORKDIR ${COMFYUI_PATH}
RUN python3 -m pip install -r requirements.txt

# Install additional Python packages with pinned versions
COPY requirements/base.txt /tmp/base.txt
RUN python3 -m pip install -r /tmp/base.txt

# Install Custom Nodes based on BUILD_TYPE
COPY scripts/install_nodes.sh /tmp/install_nodes.sh
RUN chmod +x /tmp/install_nodes.sh && \
    BUILD_TYPE=${BUILD_TYPE} bash /tmp/install_nodes.sh

# Install node requirements
COPY requirements/nodes.txt /tmp/nodes.txt
RUN python3 -m pip install -r /tmp/nodes.txt || true

# Optional: Download models during build (only for 'full' build)
COPY scripts/download_models.py /tmp/download_models.py
RUN if [ "${BUILD_TYPE}" = "full" ]; then \
        HF_TOKEN=${HF_TOKEN} CIVITAI_TOKEN=${CIVITAI_TOKEN} python3 /tmp/download_models.py || echo "Model download failed, will retry at runtime"; \
    fi

# Final Stage
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG PYTHON_VERSION=3.11

# Runtime Environment
ENV TZ=UTC \
    PIP_NO_CACHE_DIR=1 \
    HF_HUB_ENABLE_HF_TRANSFER=1 \
    PYTHONUNBUFFERED=1 \
    # Performance Optimizations
    PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True,max_split_size_mb:256" \
    TORCH_ALLOW_TF32_CUBLAS=1 \
    NVIDIA_TF32_OVERRIDE=1 \
    CUDA_DEVICE_MAX_CONNECTIONS=1 \
    TORCH_SDPA_BACKEND=flash \
    # ComfyUI Settings
    COMFYUI_PATH=/opt/ComfyUI \
    # TCMalloc for better memory management
    LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git git-lfs curl wget \
    python${PYTHON_VERSION} python3-pip \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 libgomp1 \
    libgoogle-perftools-dev tcmalloc-minimal4 \
    ffmpeg libsndfile1 \
    libcudnn9 \
    && ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python \
    && ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1000 -s /bin/bash runpod && \
    mkdir -p /opt/ComfyUI && \
    chown -R runpod:runpod /opt

# Copy from builder
COPY --from=builder --chown=runpod:runpod /opt/ComfyUI ${COMFYUI_PATH}
COPY --from=builder --chown=runpod:runpod /usr/local/lib/python${PYTHON_VERSION} /usr/local/lib/python${PYTHON_VERSION}
COPY --from=builder --chown=runpod:runpod /usr/local/bin /usr/local/bin

# Setup configs and workflows
COPY --chown=runpod:runpod configs/server_config.json ${COMFYUI_PATH}/server_config.json
COPY --chown=runpod:runpod configs/extra_model_paths.yaml ${COMFYUI_PATH}/extra_model_paths.yaml
COPY --chown=runpod:runpod workflows ${COMFYUI_PATH}/workflows

# Copy utility scripts
COPY --chown=runpod:runpod scripts/model_downloader.py ${COMFYUI_PATH}/model_downloader.py
COPY --chown=runpod:runpod scripts/download_models.py /tmp/download_models.py
COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/healthcheck.sh /healthcheck.sh
RUN chmod +x /entrypoint.sh /healthcheck.sh

# Switch to non-root user
USER runpod
WORKDIR ${COMFYUI_PATH}

# Ports & Health
EXPOSE 8188
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=5 \
    CMD ["/healthcheck.sh"]

ENTRYPOINT ["/entrypoint.sh"]
