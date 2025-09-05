#!/usr/bin/env python3
"""
Model downloader utility for ComfyUI
"""
import os
import sys
from pathlib import Path
from huggingface_hub import hf_hub_download

def download_model(repo_id, filename, subdir, token=None):
    """Download a model from Hugging Face"""
    models_path = "/workspace/models"
    target_dir = os.path.join(models_path, subdir)
    Path(target_dir).mkdir(parents=True, exist_ok=True)
    
    try:
        path = hf_hub_download(
            repo_id=repo_id,
            filename=filename,
            token=token,
            local_dir=target_dir,
            resume_download=True
        )
        print(f"✅ Downloaded: {repo_id}/{filename}")
        return True
    except Exception as e:
        print(f"❌ Failed to download {repo_id}/{filename}: {e}")
        return False

if __name__ == "__main__":
    print("🚀 ComfyUI Model Downloader")
    print("Usage: python model_downloader.py")
    print("Set HF_TOKEN environment variable for gated models")
