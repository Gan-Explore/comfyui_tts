#!/bin/bash
set -e

BASE="/workspace/runpod-slim"
COMFY="$BASE/ComfyUI"
CUSTOM="$BASE/custom_nodes"
CACHE="$BASE/model_cache"

PYTHON="/opt/comfy_env/bin/python"
PIP="/opt/comfy_env/bin/pip"
JUPYTER="/opt/comfy_env/bin/jupyter"

echo "========================================="
echo "AI CREATION STACK BOOT (STABLE v4)"
echo "========================================="

# -------------------------------------------------
# Fix DNS
# -------------------------------------------------

echo "Fixing DNS..."
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

# -------------------------------------------------
# Wait for internet
# -------------------------------------------------

echo "Checking internet..."
for i in {1..30}; do
    if ping -c 1 github.com &> /dev/null; then
        echo "Internet OK"
        break
    fi
    echo "Waiting for network..."
    sleep 2
done

# -------------------------------------------------
# Create workspace
# -------------------------------------------------

mkdir -p $BASE/{models,input,output,user,custom_nodes}
mkdir -p $CACHE/{huggingface,torch,diffusers}

export HF_HOME=$CACHE/huggingface
export TRANSFORMERS_CACHE=$CACHE/huggingface
export TORCH_HOME=$CACHE/torch
export XDG_CACHE_HOME=$CACHE

# -------------------------------------------------
# Install ComfyUI (only if missing)
# -------------------------------------------------

if [ ! -f "$COMFY/main.py" ]; then
    echo "Installing ComfyUI..."
    cd $BASE
    git clone https://github.com/comfyanonymous/ComfyUI.git || true
else
    echo "ComfyUI exists — skipping install"
fi

# -------------------------------------------------
# 🔥 Patch comfy_aimdo crash (PERMANENT FIX)
# -------------------------------------------------

echo "Patching comfy_aimdo issue..."

MAIN_FILE="$COMFY/main.py"

if grep -q "comfy_aimdo.control.init()" "$MAIN_FILE"; then
    echo "[PATCH] Applying comfy_aimdo fix..."

    sed -i 's/import comfy_aimdo.control/try:\n    import comfy_aimdo.control\n    HAS_AIMDO = True\nexcept ImportError:\n    print("[WARN] comfy_aimdo not found — skipping")\n    HAS_AIMDO = False/' "$MAIN_FILE"

    sed -i 's/comfy_aimdo.control.init()/if HAS_AIMDO:\n    comfy_aimdo.control.init()/' "$MAIN_FILE"

else
    echo "[PATCH] comfy_aimdo already handled or not present"
fi

# -------------------------------------------------
# Link persistent folders
# -------------------------------------------------

echo "Linking persistent storage..."

rm -rf $COMFY/{models,custom_nodes,input,output,user} || true

ln -s $BASE/models $COMFY/models
ln -s $BASE/custom_nodes $COMFY/custom_nodes
ln -s $BASE/input $COMFY/input
ln -s $BASE/output $COMFY/output
ln -s $BASE/user $COMFY/user

# -------------------------------------------------
# Install nodes safely
# -------------------------------------------------

mkdir -p $BASE/scripts

cat << 'EOF' > $BASE/scripts/node_installer.py
import os, subprocess

CUSTOM="/workspace/runpod-slim/custom_nodes"

repos={
"ComfyUI-Qwen-TTS":"https://github.com/flybirdxx/ComfyUI-Qwen-TTS.git",
"ComfyUI-XTTS":"https://github.com/daswer123/ComfyUI-XTTS.git",
"KJNodes":"https://github.com/kijai/ComfyUI-KJNodes.git"
}

for name,repo in repos.items():
    path=os.path.join(CUSTOM,name)
    if not os.path.exists(path):
        try:
            print(f"[INSTALL NODE] {name}")
            subprocess.check_call(["git","clone",repo,path])
        except Exception as e:
            print(f"[FAILED NODE INSTALL] {name}: {e}")
EOF

$PYTHON $BASE/scripts/node_installer.py

# -------------------------------------------------
# Self-heal system (safe)
# -------------------------------------------------

cat << 'EOF' > $BASE/scripts/self_heal.py
import subprocess, sys, re

SAFE = {"einops","sentencepiece","safetensors","soundfile","librosa","scipy","numpy"}

print("Self-heal active (safe mode)")

def install(p):
    if p in SAFE:
        print(f"[AUTO INSTALL] {p}")
        subprocess.call(["/opt/comfy_env/bin/pip","install",p])
    else:
        print(f"[SKIP UNKNOWN] {p}")

while True:
    line=sys.stdin.readline()
    if not line:
        break
    m=re.search(r"No module named '([^']+)'",line)
    if m:
        install(m.group(1))
EOF

# -------------------------------------------------
# Debug info
# -------------------------------------------------

echo "Python:"
which python

python -c "import transformers; print('Transformers:', transformers.__version__)"

# -------------------------------------------------
# Start Jupyter
# -------------------------------------------------

echo "Starting Jupyter..."

cd /workspace

$JUPYTER lab \
--notebook-dir=/workspace \
--ip=0.0.0.0 \
--port=8888 \
--no-browser \
--allow-root \
--ServerApp.allow_origin='*' \
--IdentityProvider.token='' &

sleep 3

# -------------------------------------------------
# Start ComfyUI (safe mode)
# -------------------------------------------------

echo "Starting ComfyUI..."

cd $COMFY

set +e

$PYTHON main.py \
--listen 0.0.0.0 \
--port 8188 \
2>&1 | tee /tmp/comfy.log | $PYTHON $BASE/scripts/self_heal.py

echo "ComfyUI exited. Keeping container alive..."
tail -f /dev/null
