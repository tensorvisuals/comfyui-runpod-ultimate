# 🚀 ComfyUI Runpod Ultimate Template

Production-ready Docker image for ComfyUI with FLUX.1 and Qwen-Image support, optimized for modern GPUs with CUDA 12.4 + PyTorch 2.5.1.

## ✨ Features

- **CUDA 12.4 + PyTorch 2.5.1** - Stable production stack
- **Security First** - Non-root user, runtime secrets injection
- **Build Variants** - Minimal, Standard, Full configurations
- **Pre-configured Models** - FLUX.1-dev, Qwen-Image, ControlNet
- **50+ Custom Nodes** - Version-pinned for stability
- **Performance Optimized** - Flash Attention, TF32, tcmalloc
- **Multi-stage Build** - Smaller, cleaner images
- **Automated CI/CD** - GitHub Actions with caching

## 🚀 Quick Start

### Deploy on Runpod

1. Fork this repository
2. Set GitHub Secrets (Settings → Secrets → Actions):
   - `HF_TOKEN` - Your Hugging Face token
   - `CIVITAI_TOKEN` - Your Civitai API token (optional)
3. GitHub Actions will automatically build on push
4. Deploy on Runpod:
   ```
   Image: ghcr.io/YOUR_USERNAME/comfyui-runpod-ultimate:standard
   GPU: RTX 4090 or better
   Disk: 50GB (minimal) / 100GB (standard) / 200GB (full)
   Environment Variables:
     - HF_TOKEN=your_token_here
     - CIVITAI_TOKEN=your_token_here
   ```

### Local Development

```bash
# Clone repository
git clone https://github.com/YOUR_USERNAME/comfyui-runpod-ultimate
cd comfyui-runpod-ultimate

# Setup environment
cp env.example .env
# Edit .env and add your tokens

# Build and run
docker compose up --build

# Access ComfyUI
open http://localhost:8188
```

## 📦 Build Variants

### Minimal
- Core ComfyUI + Manager
- Essential nodes only
- No pre-downloaded models
- ~5GB image size

### Standard (Default)
- ComfyUI + popular nodes
- FLUX.1-dev models
- Basic ControlNet
- ~15GB image size

### Full
- All nodes and models
- FLUX + Qwen-Image
- Complete ControlNet suite
- Upscalers and extras
- ~30GB image size

## 🔒 Security

- **Non-root user** execution
- **Runtime secrets** - Tokens never baked into image
- **Version pinning** - Reproducible builds
- **Multi-stage builds** - Minimal attack surface

## 🎯 Performance

- **PyTorch 2.5.1** with CUDA 12.4
- **Flash Attention** via SDPA
- **TF32 precision** enabled
- **TCMalloc** memory optimization
- **Expandable CUDA segments**

## 📊 System Requirements

### Minimum
- GPU: RTX 4090 (24GB VRAM)
- RAM: 32GB
- Storage: 50GB
- CUDA: 12.1+

### Recommended
- GPU: RTX 5090 / RTX 6000 Ada / H200
- RAM: 64GB+
- Storage: 200GB
- CUDA: 12.4+

## 🔧 Environment Variables

```env
# Required for gated models
HF_TOKEN=hf_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Optional for Civitai
CIVITAI_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Build variant
BUILD_TYPE=standard

# Additional ComfyUI arguments
COMFYUI_EXTRA_ARGS=--lowvram
```

## 🐛 Troubleshooting

### GPU Not Detected
```bash
# Check driver version
nvidia-smi
# Should show 525+ for CUDA 12.4
```

### Out of Memory
- Use `BUILD_TYPE=minimal`
- Add `COMFYUI_EXTRA_ARGS=--lowvram`
- Reduce batch size in workflows

### Models Not Loading
- Ensure HF_TOKEN is set in Runpod environment
- Check /workspace/models/.initialized exists
- Manual download: `python model_downloader.py`

## 📚 Resources

- [ComfyUI Documentation](https://docs.comfy.org)
- [Runpod Documentation](https://docs.runpod.io)
- [FLUX.1 Model Card](https://huggingface.co/black-forest-labs/FLUX.1-dev)

## 🤝 Contributing

Pull requests welcome! Please ensure:
- Version pin new dependencies
- Test builds pass
- Update documentation

## 📄 License

Apache 2.0

---

Built with ❤️ for the ComfyUI community
