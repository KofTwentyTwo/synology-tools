#!/bin/bash
# create_simple_syno_vm.sh
# usage: sudo ./create_simple_syno_vm.sh <vmid> "<vmname>" <bridge>

set -euo pipefail

if [ $# -lt 3 ]; then
    echo "Usage: $0 <vmid> \"<vmname>\" <bridge>"
    exit 1
fi

VMID="$1"
VMNAME="$2"
BRIDGE="$3"

# --- Proxmox configuration ---
STORAGE="local-vmpool-1"     # your storage pool
ARCPATH="./arc.img"          # ArcLoader image (must exist in current directory)
MEMORY="4096"
CORES="4"

echo "[INFO] Creating basic Synology VM $VMID ($VMNAME)"

# Create VM
qm create "$VMID" --name "$VMNAME" --memory "$MEMORY" --cores "$CORES" \
  --net0 virtio,bridge="$BRIDGE" --bios seabios \
  --serial0 socket --vga serial0 --boot order=sata0

# Import ArcLoader image as boot disk
echo "[INFO] Importing ArcLoader boot disk..."
qm importdisk "$VMID" "$ARCPATH" "$STORAGE"
qm set "$VMID" --sata0 "${STORAGE}:vm-${VMID}-disk-0"

# Optional: add a blank 16GB data disk (for testing only)
echo "[INFO] Adding small blank data disk..."
qm set "$VMID" --sata1 "$STORAGE:16"

# Finish configuration
qm set "$VMID" --boot order=sata0
echo "[INFO] VM created successfully."
echo "----------------------------------------------"
echo "Run 'qm start $VMID' to boot ArcLoader."
echo "Access loader at http://<vm-ip>:7681 to configure DSM."
echo "----------------------------------------------"
