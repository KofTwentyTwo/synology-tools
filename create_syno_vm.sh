#!/bin/bash
# save as create_syno_vm.sh
# usage: sudo ./create_syno_vm.sh <vmid> "<vmname>" /path/to/export/Queuedl_DSM

set -euo pipefail

# Inputs
if [ $# -lt 4 ]; then
    echo "Usage: $0 <vmid> \"<vmname>\" <bridgename> <path_to_disk_dir>"
    exit 1
fi

VMID="$1"
VMNAME="$2"
BRIDGE="$3"
DISKDIR="$4"

# Configuration
ARCPATH="./arc.img"         # must be in current working directory
STORAGE="local-vmpool-1"    # change if using different storage
MEMORY="4096"
CORES="4"

# --- Create VM ---
echo "[INFO] Creating VM $VMID ($VMNAME)"
qm create "$VMID" --name "$VMNAME" --memory "$MEMORY" --cores "$CORES" \
  --net0 virtio,bridge="$BRIDGE" --bios seabios --bootdisk sata0 --boot order=sata0

# --- Import Arc boot disk ---
echo "[INFO] Importing ArcLoader boot disk..."
qm importdisk "$VMID" "$ARCPATH" "$STORAGE"
BOOTDISK=$(qm config "$VMID" | grep sata0 | cut -d' ' -f2)
if [ -z "$BOOTDISK" ]; then
    qm set "$VMID" --sata0 "${STORAGE}:vm-${VMID}-disk-0"
fi

# --- Import all exported DSM disks ---
echo "[INFO] Importing DSM data disks from $DISKDIR"
INDEX=1
for FILE in "$DISKDIR"/*.qcow2; do
    echo "  -> Adding $FILE as sata${INDEX}"
    qm importdisk "$VMID" "$FILE" "$STORAGE"
    qm set "$VMID" --sata${INDEX} "${STORAGE}:vm-${VMID}-disk-${INDEX}"
    INDEX=$((INDEX+1))
done

# --- Final settings ---
qm set "$VMID" --vga serial0 --serial0 socket --boot order=sata0
echo "[INFO] VM $VMNAME ($VMID) created successfully."
echo "[INFO] Start it with: qm start $VMID"
