#!/usr/bin/env bash
# Instala Godot 4.3 y sus plantillas de exportación en Codespaces.
set -euo pipefail
V=4.3
cd /tmp
sudo apt-get update -y && sudo apt-get install -y unzip wget python3
wget -q https://github.com/godotengine/godot/releases/download/${V}-stable/Godot_v${V}-stable_linux.x86_64.zip
unzip -oq Godot_v${V}-stable_linux.x86_64.zip
sudo mv Godot_v${V}-stable_linux.x86_64 /usr/local/bin/godot
wget -q https://github.com/godotengine/godot/releases/download/${V}-stable/Godot_v${V}-stable_export_templates.tpz
mkdir -p ~/.local/share/godot/export_templates/${V}.stable
unzip -oq Godot_v${V}-stable_export_templates.tpz
mv templates/* ~/.local/share/godot/export_templates/${V}.stable/
rm -rf templates *.zip *.tpz
godot --version
