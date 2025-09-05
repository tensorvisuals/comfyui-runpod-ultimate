#!/bin/bash
set -euo pipefail

echo "🚀 ComfyUI Starting..."
echo "📊 System Info:"
echo "================================"

# Check CUDA & Driver
if command -v nvidia-smi &> /dev/null; then
    echo "GPU Info:"
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
    
    # Enable persistence mode for better performance
    nvidia-smi -pm 1 2>/dev/null || true
    
    # Check CUDA version compatibility
    DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n1)
    echo "Driver Version: $DRIVER_VERSION"
    
    # Check if driver supports CUDA 12.8
    DRIVER_MAJOR=$(echo $DRIVER_VERSION | cut -d. -f1)
    if [ "$DRIVER_MAJOR" -lt "545" ]; then
        echo "⚠️ WARNING: Driver version may be too old for CUDA 12.8"
        echo "⚠️ Recommended: Driver 545+ for optimal performance"
    fi
else
    echo "⚠️ nvidia-smi not available - running in CPU mode"
fi

# Python/PyTorch info
python3 << 'EOF'
import torch
import sys
print(f"Python: {sys.version}")
print(f"PyTorch: {torch.__version__}")
print(f"CUDA Available: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"CUDA Version: {torch.version.cuda}")
    print(f"GPU: {torch.cuda.get_device_name(0)}")
    print(f"GPU Memory: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.1f} GB")
    
    # Quick GPU smoke test
    try:
        print("Running GPU smoke test...")
        x = torch.randn(100, 100).cuda()
        y = torch.randn(100, 100).cuda()
        z = torch.matmul(x, y)
        torch.cuda.synchronize()
        print("✅ GPU smoke test passed")
    except Exception as e:
        print(f"❌ GPU smoke test failed: {e}")
        exit(1)
EOF

echo "================================"

# Create necessary directories
mkdir -p ${COMFYUI_PATH}/temp
mkdir -p ${COMFYUI_PATH}/output
mkdir -p ${COMFYUI_PATH}/input
mkdir -p /workspace/models

# Link workspace models if not exists
if [ ! -L "${COMFYUI_PATH}/models" ] && [ -d "/workspace/models" ]; then
    rm -rf ${COMFYUI_PATH}/models
    ln -s /workspace/models ${COMFYUI_PATH}/models
fi

# Download models on first run (if not in 'full' build)
MODEL_MARKER="/workspace/models/.initialized"
if [ ! -f "$MODEL_MARKER" ] && [ "${BUILD_TYPE:-standard}" != "full" ]; then
    echo "📥 First run detected - downloading essential models..."
    
    # Export tokens for model download
    export HF_TOKEN="${HF_TOKEN:-}"
    export CIVITAI_TOKEN="${CIVITAI_TOKEN:-}"
    
    if [ -z "$HF_TOKEN" ]; then
        echo "⚠️ No HF_TOKEN set - some models may fail to download"
    fi
    
    # Run model download script
    if python3 /tmp/download_models.py; then
        touch "$MODEL_MARKER"
        echo "✅ Models downloaded successfully"
    else
        echo "⚠️ Some models failed to download - will work with available models"
    fi
fi

# Start ComfyUI
cd ${COMFYUI_PATH}
echo "🎨 Starting ComfyUI server..."
exec python3 main.py \
    --listen 0.0.0.0 \
    --port 8188 \
    --enable-cors-header \
    --preview-method auto \
    --use-pytorch-cross-attention \
    ${COMFYUI_EXTRA_ARGS:-}
