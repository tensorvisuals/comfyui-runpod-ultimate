#!/usr/bin/env python3
import os
import sys
from huggingface_hub import hf_hub_download, snapshot_download
import requests
from pathlib import Path

HF_TOKEN = os.getenv("HF_TOKEN", None)
CIVITAI_TOKEN = os.getenv("CIVITAI_TOKEN", None)
BUILD_TYPE = os.getenv("BUILD_TYPE", "standard")
MODELS_PATH = "/workspace/models"

def ensure_dir(path):
    Path(path).mkdir(parents=True, exist_ok=True)

def download_hf(repo, filename, subdir, repo_type="model"):
    """Download from Hugging Face"""
    target_dir = os.path.join(MODELS_PATH, subdir)
    ensure_dir(target_dir)
    try:
        path = hf_hub_download(
            repo_id=repo, 
            filename=filename, 
            token=HF_TOKEN,
            local_dir=target_dir,
            repo_type=repo_type,
            resume_download=True
        )
        print(f"✅ Downloaded: {repo}/{filename}")
        return True
    except Exception as e:
        print(f"⚠️ Failed to download {repo}/{filename}: {e}")
        return False

def main():
    print(f"🚀 Starting model downloads (Build Type: {BUILD_TYPE})...")
    
    if BUILD_TYPE == "minimal":
        print("ℹ️ Minimal build - skipping model downloads")
        return
    
    # Essential models for standard and full builds
    if BUILD_TYPE in ["standard", "full"]:
        print("\n📥 Downloading FLUX.1-dev models...")
        download_hf("Comfy-Org/flux1-dev", "flux1-dev-fp8.safetensors", "checkpoints")
        download_hf("black-forest-labs/FLUX.1-dev", "ae.safetensors", "vae")
        
        print("\n📥 Downloading FLUX text encoders...")
        download_hf("comfyanonymous/flux_text_encoders", "clip_l.safetensors", "text_encoders")
        download_hf("comfyanonymous/flux_text_encoders", "t5xxl_fp8_e4m3fn.safetensors", "text_encoders")
    
    # Additional models for full build
    if BUILD_TYPE == "full":
        print("\n📥 Downloading Qwen-Image models...")
        download_hf("Comfy-Org/Qwen-Image_ComfyUI", "qwen_image_fp8_e4m3fn.safetensors", "diffusion_models")
        download_hf("Comfy-Org/Qwen-Image_ComfyUI", "qwen_image_vae.safetensors", "vae")
        
        print("\n📥 Downloading ControlNet models...")
        download_hf("Shakker-Labs/FLUX.1-dev-ControlNet-Union-Pro", 
                    "diffusion_pytorch_model_promax_fp8.safetensors", "controlnet")
        
        print("\n📥 Downloading upscale models...")
        download_hf("philz1337x/upscaler", "4x-UltraSharp.pth", "upscale_models")
    
    print("\n✅ Model download complete!")

if __name__ == "__main__":
    main()
