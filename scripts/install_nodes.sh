#!/bin/bash
set -euo pipefail

cd ${COMFYUI_PATH}/custom_nodes

BUILD_TYPE="${BUILD_TYPE:-standard}"
echo "📦 Installing Custom Nodes (Build Type: $BUILD_TYPE)..."

# Core nodes (all builds)
CORE_NODES=(
    "https://github.com/Comfy-Org/ComfyUI-Manager.git|7aec23e"
    "https://github.com/crystian/ComfyUI-Crystools.git|v1.14.0"
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git|9916c13"
)

# Standard nodes (standard + full builds)
STANDARD_NODES=(
    "https://github.com/rgthree/rgthree-comfy.git|v1.5.0"
    "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git|5.0.2"
    "https://github.com/cubiq/ComfyUI_essentials.git|v1.3.0"
    "https://github.com/jags111/efficiency-nodes-comfyui.git|2.0"
    "https://github.com/Comfy-Org/comfyui_controlnet_aux.git|v0.2.0"
    "https://github.com/cubiq/ComfyUI_IPAdapter_plus.git|v2.3.0"
    "https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git|1.0.0"
    "https://github.com/city96/ComfyUI-GGUF.git|1.0.0"
)

# Full nodes (only full build)
FULL_NODES=(
    "https://github.com/ltdrdata/ComfyUI-Inspire-Pack.git|1.0.0"
    "https://github.com/Kosinkadink/ComfyUI-Advanced-ControlNet.git|1.1.0"
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git|1.0.0"
    "https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved.git|1.0.0"
    "https://github.com/kijai/ComfyUI-KJNodes.git|1.0.0"
    "https://github.com/WASasquatch/was-node-suite-comfyui.git|1.0.0"
    "https://github.com/Derfuu/Derfuu_ComfyUI_ModdedNodes.git|1.0.0"
    "https://github.com/Gourieff/comfyui-reactor-node.git|1.0.0"
    "https://github.com/melMass/comfy_mtb.git|1.0.0"
    "https://github.com/Acly/comfyui-inpaint-nodes.git|1.0.0"
)

# Function to clone with specific commit/tag
clone_node() {
    local repo_url="${1%%|*}"
    local commit="${1##*|}"
    local repo_name=$(basename "$repo_url" .git)
    
    echo "Installing $repo_name..."
    if [ -d "$repo_name" ]; then
        echo "  Already exists, skipping..."
    else
        git clone --depth 1 --branch "$commit" "$repo_url" 2>/dev/null || \
        (git clone "$repo_url" && cd "$repo_name" && git checkout "$commit")
    fi
}

# Install based on build type
echo "Installing core nodes..."
for node in "${CORE_NODES[@]}"; do
    clone_node "$node"
done

if [ "$BUILD_TYPE" != "minimal" ]; then
    echo "Installing standard nodes..."
    for node in "${STANDARD_NODES[@]}"; do
        clone_node "$node"
    done
fi

if [ "$BUILD_TYPE" = "full" ]; then
    echo "Installing full nodes..."
    for node in "${FULL_NODES[@]}"; do
        clone_node "$node"
    done
fi

# Install requirements for each node
echo "📚 Installing node requirements..."
for dir in */; do
    if [ -f "$dir/requirements.txt" ]; then
        echo "Installing requirements for $dir"
        python3 -m pip install --no-cache-dir -r "$dir/requirements.txt" 2>/dev/null || true
    fi
    if [ -f "$dir/pyproject.toml" ]; then
        echo "Installing from pyproject.toml for $dir"
        python3 -m pip install --no-cache-dir "$dir" 2>/dev/null || true
    fi
done

echo "✅ Custom nodes installed successfully!"
