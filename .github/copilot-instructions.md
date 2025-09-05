# ComfyUI Runpod Ultimate

Production-ready Docker image for ComfyUI with FLUX.1 and Qwen-Image support, optimized for modern GPUs. This is a Docker-based ComfyUI template designed for deployment on Runpod cloud computing platform.

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Critical Timing and Command Guidelines

### NEVER CANCEL Commands - Expected Execution Times
- **Docker builds**: 15-90 minutes depending on build type - ALWAYS wait for completion
- **Model downloads**: 15-45 minutes for complete model sets - NEVER interrupt
- **Container startup**: 2-10 minutes for full initialization including model verification
- **Health check response**: Should respond within 30 seconds once fully started

### Build Command Timeouts
- Use minimum 120-minute timeouts for `docker compose up --build`
- Use minimum 60-minute timeouts for model download operations
- Use minimum 15-minute timeouts for container startup and health checks
- If a command appears stuck, wait at least the full expected time before investigating

## Working Effectively

### Prerequisites and Setup
- Docker and Docker Compose are required for all operations
- NVIDIA GPU with CUDA support (for production use)
- Minimum 16GB RAM, 50GB disk space
- For local development: `cp env.example .env` and edit tokens if needed

### Bootstrap and Build the Repository
- `docker compose up --build` -- NEVER CANCEL: Takes 15-90 minutes depending on build type. Set timeout to 120+ minutes.
- Build variants available:
  - `BUILD_TYPE=minimal` -- ~15-20 minutes, ~5GB image, core ComfyUI only
  - `BUILD_TYPE=standard` -- ~30-45 minutes, ~15GB image, popular nodes + FLUX models  
  - `BUILD_TYPE=full` -- ~60-90 minutes, ~30GB image, all nodes and models
- Set build type: `export BUILD_TYPE=minimal` (or edit .env file)

### CRITICAL Build Issue - CUDA Version Compatibility
- **ISSUE**: The Dockerfile uses CUDA 12.8 images which are not available
- **SOLUTION**: Update base images in Dockerfile from:
  - `nvidia/cuda:12.8-devel-ubuntu22.04` → `nvidia/cuda:12.9.1-devel-ubuntu22.04`
  - `nvidia/cuda:12.8-runtime-ubuntu22.04` → `nvidia/cuda:12.9.1-runtime-ubuntu22.04`
- **PyTorch Version**: May need to update from `torch==2.8.0+cu128` to compatible version like `torch==2.5.1+cu124`
- Always check available CUDA images at https://hub.docker.com/r/nvidia/cuda/tags before building

### Run the Application
- Start: `docker compose up` (after successful build)
- Access ComfyUI web interface: http://localhost:8188
- Health check: `curl http://localhost:8188/system_stats`
- Logs: `docker compose logs -f comfyui`

### Manual Model Download (if needed)
- `docker compose exec comfyui python3 model_downloader.py`
- Alternative: `docker compose exec comfyui python3 /tmp/download_models.py`
- Requires HF_TOKEN environment variable for gated models like FLUX.1-dev
- Models stored in `/workspace/models/` inside container
- Check model status: `docker compose exec comfyui ls -la /workspace/models/`

## Validation and Testing

### NEVER use traditional unit tests - none exist in this repository
### Manual Validation Required After Changes

**Essential validation steps after any changes:**
1. **Build Test**: `docker compose up --build` must complete successfully
2. **Startup Test**: Container must start and ComfyUI server must be accessible at http://localhost:8188
3. **Web Interface Test**: Open http://localhost:8188 in browser, interface should load without errors
4. **API Test**: `curl http://localhost:8188/system_stats` should return JSON response
5. **Model Loading Test**: Check that models load correctly (if HF_TOKEN provided)

**Complete End-to-End Scenario Testing:**
- Load ComfyUI web interface
- Try loading a basic workflow (from `workflows/` directory if BUILD_TYPE includes models)
- If using standard/full builds: Test FLUX.1 model generation workflow
- Verify generated images appear in output directory
- Test different build variants if making changes affecting multiple build types

**Timeout Requirements:**
- Build commands: NEVER CANCEL - Set timeout to 120+ minutes minimum
- Model downloads: NEVER CANCEL - Can take 30+ minutes for large models
- Container startup: Allow 5-10 minutes for full initialization

## File Structure and Navigation

### Key Directories
- `scripts/` - Core installation and runtime scripts
  - `entrypoint.sh` - Main container startup script
  - `install_nodes.sh` - Custom nodes installation (check after modifying node lists)
  - `download_models.py` - Model downloading logic
  - `healthcheck.sh` - Container health checking
- `configs/` - ComfyUI configuration files
  - `server_config.json` - Server settings (port, CORS, etc.)
  - `extra_model_paths.yaml` - Model directory mappings
- `requirements/` - Python dependency specifications
  - `base.txt` - Core Python packages with pinned versions
  - `nodes.txt` - Custom node dependencies (may fail partially)
- `workflows/` - Example ComfyUI workflow files
- `.github/workflows/` - CI/CD pipeline (GitHub Actions)

### Configuration Files
- `Dockerfile` - Multi-stage build definition (contains CUDA version issue)
- `docker-compose.yml` - Local development orchestration
- `env.example` - Environment variable template
- `.env` - Local environment configuration (created from env.example)

### Environment Variables
Required:
- `BUILD_TYPE` - minimal|standard|full (default: standard)
- `HF_TOKEN` - Hugging Face token for gated models (get from https://huggingface.co/settings/tokens)

Optional:
- `CIVITAI_TOKEN` - Civitai API token for additional models
- `COMFYUI_EXTRA_ARGS` - Additional ComfyUI startup arguments (e.g., --lowvram)

## Common Tasks and Workflows

### Changing Build Configuration
- Edit `BUILD_TYPE` in `.env` file or export as environment variable
- Rebuild: `docker compose up --build` (NEVER CANCEL: 15-90 minutes)
- Always test with minimal build first, then standard/full

### Adding Custom Nodes
- Edit `scripts/install_nodes.sh` to add new nodes to appropriate arrays
- Format: `"https://github.com/user/repo.git|version_tag"`
- Node arrays: CORE_NODES (all builds), STANDARD_NODES (standard+full), FULL_NODES (full only)
- Rebuild required after changes

### Model Management
- Models automatically downloaded on first run (except minimal build)
- Manual download: `python3 /tmp/download_models.py` (inside container)
- Model paths configured in `configs/extra_model_paths.yaml`
- Always check `/workspace/models/.initialized` exists after model download

### Debugging Container Issues
- Check logs: `docker compose logs -f comfyui`
- Shell access: `docker compose exec comfyui bash`
- GPU check: `nvidia-smi` (inside container)
- Disk space: `df -h /workspace`

## CI/CD and GitHub Actions

### Automated Build Pipeline
- Located: `.github/workflows/build-and-push.yml`
- Builds all three variants (minimal, standard, full) on push to main
- Publishes to GitHub Container Registry (ghcr.io)
- Requires secrets: `HF_TOKEN`, `CIVITAI_TOKEN` in repository settings

### Troubleshooting Build Failures
- **CUDA Image Not Found**: Update Dockerfile CUDA versions (see CRITICAL section above)
- **Model Download Failures**: Check HF_TOKEN is valid and model access permissions
- **Out of Disk Space**: Standard builds need 50GB+, full builds need 100GB+
- **Memory Issues**: Use BUILD_TYPE=minimal for testing, add COMFYUI_EXTRA_ARGS=--lowvram

## Performance and Resource Management

### GPU Requirements
- Minimum: RTX 4090 (24GB VRAM) for standard builds
- Recommended: RTX 5090 / H100 for full builds with large models
- Driver Version: 545+ required for CUDA 12.x support

### Memory Management
- RAM: 32GB minimum, 64GB+ recommended for full builds
- VRAM: 24GB+ recommended for FLUX.1 models
- Disk: 50GB (minimal), 100GB (standard), 200GB+ (full)

### Build Time Expectations
- **NEVER CANCEL builds or model downloads**
- Minimal build: 15-20 minutes (core ComfyUI only)
- Standard build: 30-45 minutes (includes popular nodes and FLUX models)
- Full build: 60-90 minutes (all nodes and models)
- First run model download: Additional 15-30 minutes

## Validation Scripts and Commands

### Health Checks
- Container health: `docker compose exec comfyui bash scripts/healthcheck.sh`
- API endpoint: `curl -f http://localhost:8188/system_stats`
- GPU detection: `docker compose exec comfyui nvidia-smi`
- Container status: `docker compose ps`
- View logs: `docker compose logs comfyui --tail=50`

### Development Workflow
1. Make changes to configuration/scripts
2. Test with minimal build first: `BUILD_TYPE=minimal docker compose up --build`
3. Validate web interface works: http://localhost:8188
4. Test API: `curl http://localhost:8188/system_stats`
5. If minimal works, test standard build for full functionality
6. Always test complete user workflow (load interface → run generation → check output)

### No Linting or Formatting Tools
- Repository has no automated linting, formatting, or traditional test suites
- All validation is manual through building and running the application
- Focus validation on Docker build success and ComfyUI functionality
- Changes should be tested across different build types if they affect multiple variants