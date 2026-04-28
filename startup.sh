#!/bin/bash

set +e

BASE="/workspace/runpod-slim"
COMFY="$BASE/ComfyUI"

PYTHON="/opt/comfy_env/bin/python"
JUPYTER="/opt/comfy_env/bin/jupyter"

echo "==========================================="
echo "CLEAN START (STABLE + TTS + WHISPER READY)"
echo "==========================================="

# DNS FIX
echo "Fixing DNS..."
echo "nameserver 8.8.8.8" > /etc/resolv.conf || true
echo "nameserver 1.1.1.1" >> /etc/resolv.conf || true

echo "Waiting for network..."
for i in {1..20}; do
  ping -c 1 github.com > /dev/null 2>&1 && break
  sleep 2
done

# ============================================
# STEP 1: Setup ComfyUI
# ============================================
mkdir -p $BASE
cd $BASE

if [ ! -d "$COMFY" ]; then
  echo "Cloning ComfyUI..."
  git clone https://github.com/comfyanonymous/ComfyUI.git
else
  echo "ComfyUI already exists, skipping clone"
fi

cd $COMFY

# ============================================
# STEP 2: CRITICAL - Force pinned versions FIRST
# ============================================
echo "=========================================="
echo "STEP 2: Forcing pinned compatible versions"
echo "=========================================="

# Force NumPy 1.24.4
echo "Installing NumPy 1.24.4..."
$PYTHON -m pip uninstall numpy -y 2>/dev/null
$PYTHON -m pip install numpy==1.24.4 --force-reinstall --no-deps

# Force comfy-kitchen 0.2.3 (compatible with PyTorch 2.2.0)
echo "Installing comfy-kitchen 0.2.3..."
$PYTHON -m pip uninstall comfy-kitchen -y 2>/dev/null
$PYTHON -m pip install comfy-kitchen==0.2.3 --force-reinstall --no-deps

# ============================================
# STEP 3: Install base ComfyUI requirements
# ============================================
echo "=========================================="
echo "STEP 3: Installing base requirements"
echo "=========================================="

$PYTHON -m pip install --upgrade pip
$PYTHON -m pip install --no-cache-dir -r requirements.txt || true

# Immediately re-pin after requirements.txt
echo "Re-pinning after requirements.txt..."
$PYTHON -m pip uninstall comfy-kitchen numpy -y 2>/dev/null
$PYTHON -m pip install numpy==1.24.4 --force-reinstall --no-deps
$PYTHON -m pip install comfy-kitchen==0.2.3 --force-reinstall --no-deps

# ============================================
# STEP 4: Install compatible versions
# ============================================
echo "=========================================="
echo "STEP 4: Installing compatible versions"
echo "=========================================="

$PYTHON -m pip install opencv-python==4.8.1.78 scikit-image==0.21.0 blake3 --force-reinstall --no-deps || true

# ============================================
# STEP 5: Install audio/transcription dependencies
# ============================================
echo "=========================================="
echo "STEP 5: Installing audio/transcription"
echo "=========================================="

$PYTHON -m pip install faster-whisper ctranslate2 pydub ffmpeg-python || true

# ============================================
# STEP 6: Setup directories
# ============================================
echo "=========================================="
echo "STEP 6: Setting up directories"
echo "=========================================="

mkdir -p $BASE/{models,input,output,custom_nodes}

ln -sfn $BASE/models $COMFY/models
ln -sfn $BASE/input $COMFY/input
ln -sfn $BASE/output $COMFY/output

rm -rf $COMFY/custom_nodes
ln -sfn $BASE/custom_nodes $COMFY/custom_nodes

# ============================================
# STEP 7: Setup Qwen-TTS
# ============================================
echo "=========================================="
echo "STEP 7: Setting up Qwen-TTS"
echo "=========================================="

cd $BASE/custom_nodes

if [ ! -d "ComfyUI-Qwen-TTS" ]; then
  echo "Cloning Qwen-TTS nodes..."
  git clone https://github.com/flybirdxx/ComfyUI-Qwen-TTS.git
fi

cd ComfyUI-Qwen-TTS

echo "Installing Qwen-TTS requirements..."
$PYTHON -m pip install -r requirements.txt || true

echo "Installing core Qwen-TTS package..."
$PYTHON -m pip install qwen-tts || true

# Re-pin after Qwen-TTS
echo "Re-pinning after Qwen-TTS..."
$PYTHON -m pip uninstall comfy-kitchen numpy -y 2>/dev/null
$PYTHON -m pip install numpy==1.24.4 --force-reinstall --no-deps
$PYTHON -m pip install comfy-kitchen==0.2.3 --force-reinstall --no-deps

# ============================================
# STEP 8: Install Jupyter
# ============================================
echo "=========================================="
echo "STEP 8: Installing Jupyter"
echo "=========================================="

$PYTHON -m pip install --upgrade jupyterlab notebook ipykernel || true

# ============================================
# STEP 9: Start Jupyter
# ============================================
echo "=========================================="
echo "STEP 9: Starting Jupyter"
echo "=========================================="

cd /workspace

if [ -x "$JUPYTER" ]; then
  $JUPYTER lab \
    --notebook-dir=/workspace \
    --ip=0.0.0.0 \
    --port=8888 \
    --no-browser \
    --allow-root \
    --ServerApp.allow_origin='*' \
    --IdentityProvider.token='' &
else
  $PYTHON -m jupyter lab \
    --notebook-dir=/workspace \
    --ip=0.0.0.0 \
    --port=8888 \
    --no-browser \
    --allow-root \
    --ServerApp.allow_origin='*' \
    --IdentityProvider.token='' &
fi

sleep 3

# ============================================
# STEP 10: Environment variables
# ============================================
echo "=========================================="
echo "STEP 10: Setting environment variables"
echo "=========================================="

export SOULX_SINGER_ROOT=/workspace/runpod-slim/ComfyUI/pretrained_models
export PYTHONPATH=/workspace/runpod-slim/ComfyUI/custom_nodes/ComfyUI-SoulX-Singer:$PYTHONPATH

# ============================================
# STEP 11: Install additional packages
# ============================================
echo "=========================================="
echo "STEP 11: Installing additional packages"
echo "=========================================="

$PYTHON -m pip install --upgrade soundfile librosa omegaconf funasr torchcodec || true

# ============================================
# STEP 12: FINAL PIN - Force pinned versions
# ============================================
echo "=========================================="
echo "STEP 12: FINAL - Forcing pinned versions"
echo "=========================================="

$PYTHON -m pip uninstall numpy comfy-kitchen -y 2>/dev/null
$PYTHON -m pip install numpy==1.24.4 --force-reinstall --no-deps
$PYTHON -m pip install comfy-kitchen==0.2.3 --force-reinstall --no-deps

# ============================================
# STEP 13: Verify installations
# ============================================
echo "=========================================="
echo "STEP 13: Verifying installations"
echo "=========================================="

$PYTHON -c "import numpy; print(f'✓ NumPy version: {numpy.__version__}')"
$PYTHON -c "import torch; print(f'✓ PyTorch version: {torch.__version__}'); print(f'✓ CUDA available: {torch.cuda.is_available()}')"
$PYTHON -c "import comfy_kitchen; print('✓ comfy-kitchen loaded successfully')"

echo "=========================================="
echo "All verifications passed!"
echo "=========================================="

# ============================================
# STEP 14: Start ComfyUI
# ============================================
echo "Starting ComfyUI..."
cd $COMFY

$PYTHON main.py --listen 0.0.0.0 --port 8188

echo "ComfyUI exited. Debug mode active."
sleep infinity
