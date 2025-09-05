#!/bin/bash
set -euo pipefail

# Health check for ComfyUI
curl -f http://localhost:8188/system_stats || exit 1
