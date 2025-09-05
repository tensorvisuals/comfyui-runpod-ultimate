# syntax=docker/dockerfile:1.7
FROM --platform=linux/amd64 runpod/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04 AS builder

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

# System Dependencies for builder (minimal; runtime deps installed later)
RUN set -eux; \
        retry() { \
            for i in $(seq 1 5); do \
                echo "apt-get update attempt $i"; \
                apt-get update && return 0; \
                echo "apt-get update failed (attempt $i), sleeping 10s"; \
                sleep 10; \
            done; \
            return 1; \
        }; \
        retry; \
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
                git git-lfs curl wget \
        ; \
        git lfs install; \
        apt-get clean; \
        rm -rf /var/lib/apt/lists/*

# Install ComfyUI
WORKDIR /opt
RUN git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git

WORKDIR ${COMFYUI_PATH}

# (Skip Python installs in builder to reduce layer size)

# Install Custom Nodes (clone only; skip per-node pip here)
COPY scripts/install_nodes.sh /tmp/install_nodes.sh
RUN chmod +x /tmp/install_nodes.sh && \
    SKIP_NODE_PIP=1 BUILD_TYPE=${BUILD_TYPE} bash /tmp/install_nodes.sh

# (Skip node requirements in builder)

# Strip VCS metadata to shrink layers before COPY to final
RUN find ${COMFYUI_PATH} -type d -name .git -prune -exec rm -rf {} +

# Copy model download script
COPY scripts/download_models.py /tmp/download_models.py

# Final Stage - auch PyTorch Runtime Image
FROM --platform=linux/amd64 runpod/pytorch:2.8.0-py3.11-cuda12.8.1-cudnn-devel-ubuntu22.04

ARG DEBIAN_FRONTEND=noninteractive

# Runtime Environment
ENV TZ=UTC \
    PIP_NO_CACHE_DIR=1 \
    HF_HUB_ENABLE_HF_TRANSFER=1 \
    PYTHONUNBUFFERED=1 \
    PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True" \
    CUDA_MODULE_LOADING=LAZY \
    COMFYUI_PATH=/opt/ComfyUI

# Install runtime dependencies
RUN set -eux; \
        retry() { \
            for i in $(seq 1 5); do \
                echo "apt-get update attempt $i"; \
                apt-get update && return 0; \
                echo "apt-get update failed (attempt $i), sleeping 10s"; \
                sleep 10; \
            done; \
            return 1; \
        }; \
        retry; \
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
                git git-lfs curl wget \
                libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 libgomp1 \
                libgoogle-perftools-dev libtcmalloc-minimal4 \
                ffmpeg libsndfile1 \
        ; \
        apt-get clean; \
        rm -rf /var/lib/apt/lists/*

# Set LD_PRELOAD only after libtcmalloc is installed to avoid preload warnings during earlier steps
ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4

# Create non-root user
RUN useradd -m -u 1000 -s /bin/bash runpod && \
    mkdir -p /opt/ComfyUI /workspace && \
    chown -R runpod:runpod /opt /workspace

# Copy from builder
COPY --from=builder --chown=runpod:runpod /opt/ComfyUI ${COMFYUI_PATH}

# Install Python dependencies in the runtime image to ensure availability
COPY requirements/base.txt /tmp/base.txt
COPY requirements/nodes.txt /tmp/nodes.txt
RUN set -eux; \
    python3 -m pip install --no-cache-dir -r ${COMFYUI_PATH}/requirements.txt; \
    python3 -m pip install --no-cache-dir -r /tmp/base.txt || true; \
    python3 -m pip install --no-cache-dir -r /tmp/nodes.txt || true; \
    cd ${COMFYUI_PATH}/custom_nodes; \
    for dir in */; do \
        if [ -f "$dir/requirements.txt" ]; then \
            echo "Installing requirements for $dir"; \
            python3 -m pip install --no-cache-dir -r "$dir/requirements.txt" || true; \
        fi; \
        if [ -f "$dir/pyproject.toml" ]; then \
            echo "Installing from pyproject.toml for $dir"; \
            python3 -m pip install --no-cache-dir "$dir" || true; \
        fi; \
    done

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