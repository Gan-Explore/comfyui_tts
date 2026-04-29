#!/bin/bash

set -e

echo "==========================================="
echo "STARTING TTS LAB (SoulX-Singer Ready)"
echo "==========================================="

BASE="/workspace/runpod-slim"
COMFY="$BASE/ComfyUI"

# Create virtual environment
echo "Setting up Python virtual environment..."
python -m venv /opt/comfy_env
source /opt/comfy_env/bin/activate

# Upgrade pip
pip install --upgrade pip setuptools wheel

# ============================================
# STEP 1: Install PyTorch 2.4.0 with CUDA 12.4
# ============================================
echo "Installing PyTorch 2.4.0 with CUDA 12.4..."
pip install torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 \
    --index-url https://download.pytorch.org/whl/cu124

# ============================================
# STEP 2: Clone ComfyUI
# ============================================
mkdir -p $BASE
if [ ! -d "$COMFY" ]; then
    echo "Cloning ComfyUI..."
    git clone https://github.com/comfyanonymous/ComfyUI.git $COMFY
fi

# ============================================
# STEP 3: Install ComfyUI requirements
# ============================================
echo "Installing ComfyUI requirements..."
pip install -r $COMFY/requirements.txt

# ============================================
# STEP 4: Install SoulX-Singer dependencies
# ============================================
echo "Installing SoulX-Singer dependencies..."
pip install \
    ToJyutping \
    g2p_en \
    g2pM \
    demucs \
    transformers \
    accelerate \
    einops \
    soundfile \
    librosa \
    omegaconf \
    opencv-python \
    scikit-image \
    nltk \
    regex \
    jupyter \
    jupyterlab \
    ipykernel \
    notebook \
    sqlalchemy \
    alembic \
    aiohttp

# ============================================
# STEP 5: Download NLTK data
# ============================================
python -c "import nltk; nltk.download('cmudict', quiet=True); nltk.download('averaged_perceptron_tagger', quiet=True)" 2>/dev/null || true

# ============================================
# STEP 6: Clone SoulX-Singer custom node
# ============================================
mkdir -p $COMFY/custom_nodes
if [ ! -d "$COMFY/custom_nodes/ComfyUI-SoulX-Singer" ]; then
    echo "Cloning SoulX-Singer custom node..."
    cd $COMFY/custom_nodes
    git clone https://github.com/HM-RunningHub/ComfyUI-RH_SoulX-Singer.git || \
        echo "Warning: SoulX-Singer clone failed"
fi

# ============================================
# STEP 7: Setup directory symlinks
# ============================================
echo "Setting up directories..."
# mkdir -p $BASE/{models,input,output}
# ln -sfn $BASE/models $COMFY/models
# ln -sfn $BASE/input $COMFY/input
# ln -sfn $BASE/output $COMFY/output
# ln -sfn $BASE/custom_nodes $COMFY/custom_nodes

# ============================================
# STEP 8: Start Jupyter
# ============================================
echo "Starting Jupyter Lab on port 8888..."
cd /workspace
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root \
    --ServerApp.token='' --ServerApp.allow_origin='*' &

sleep 3

# ============================================
# STEP 9: Start ComfyUI
# ============================================
echo "Starting ComfyUI on port 8188..."
cd $COMFY
export SOULX_SINGER_ROOT=$COMFY/pretrained_models
export PYTHONPATH=$COMFY/custom_nodes/ComfyUI-SoulX-Singer:$PYTHONPATH

python main.py --listen 0.0.0.0 --port 8188

sleep infinity
