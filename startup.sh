#!/bin/bash
set -e

BASE="/workspace/runpod-slim"
COMFY="$BASE/ComfyUI"

PYTHON="/opt/comfy_env/bin/python"
JUPYTER="/opt/comfy_env/bin/jupyter"

echo "==========================================="
echo "CLEAN START (FINAL FINAL - SAFE + ROBUST)"
echo "==========================================="

# Fix DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

# Wait for internet
for i in {1..20}; do
    ping -c 1 github.com && break
    sleep 2
done

# Fresh install
echo "Installing ComfyUI..."
rm -rf $COMFY
cd $BASE
git clone https://github.com/comfyanonymous/ComfyUI.git

cd $COMFY

# 🔥 SAFE GLOBAL PATCH (NO INDENTATION BREAKS)
echo "Safely removing comfy_aimdo from ALL files..."

$PYTHON - << 'EOF'
import os

root = "."

for subdir, dirs, files in os.walk(root):
    for file in files:
        if file.endswith(".py"):
            path = os.path.join(subdir, file)
            try:
                with open(path, "r", encoding="utf-8") as f:
                    lines = f.readlines()

                new_lines = []
                modified = False

                for line in lines:
                    if "comfy_aimdo" in line:
                        indent = len(line) - len(line.lstrip())
                        new_lines.append(" " * indent + "pass  # comfy_aimdo removed\n")
                        modified = True
                    else:
                        new_lines.append(line)

                if modified:
                    with open(path, "w", encoding="utf-8") as f:
                        f.writelines(new_lines)
                    print(f"Patched: {path}")

            except Exception as e:
                print(f"Skipped {path}: {e}")

print("✅ comfy_aimdo fully neutralized")
EOF

# Install requirements
echo "Installing requirements..."

$PYTHON -m pip install --upgrade pip
$PYTHON -m pip install -r requirements.txt

# Optional deps
$PYTHON -m pip install \
opencv-python \
scikit-image \
blake3

# Persistent folders
mkdir -p $BASE/{models,input,output,custom_nodes}

ln -sfn $BASE/models $COMFY/models
ln -sfn $BASE/custom_nodes $COMFY/custom_nodes
ln -sfn $BASE/input $COMFY/input
ln -sfn $BASE/output $COMFY/output

# Start Jupyter
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

# Start ComfyUI
echo "Starting ComfyUI..."
cd $COMFY

exec $PYTHON main.py --listen 0.0.0.0 --port 8188
