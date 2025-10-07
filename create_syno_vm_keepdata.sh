#!/bin/bash
# create_syno_vm_keepdata.sh
# usage:
#   sudo ./create_syno_vm_keepdata.sh <vmid> "<vmname>" <path_to_export_dir> <bridge_name>
# example:
#   sudo ./create_syno_vm_keepdata.sh 9000 "Queuedl DSM" /volume1/.../Queuedl_DSM vmbr1

set -euo pipefail

if [ $# -lt 4 ]; then
    echo "Usage: $0 <vmid> \"<vmname>\" <export_disk_dir> <bridge_name>"
    exit 1
fi

VMID="$1"
VMNAME="$2"
DISKDIR="$3"
BRIDGE="$4"

# --- Proxmox config ---
STORAGE="local-vmpool-1"   # your storage pool
ARCPATH="./arc.img"        # ArcLoader image must be in current working dir
MEMORY="4096"
CORES="4"

# --- Create base VM ---
echo "[INFO] Creating ArcLoader VM $VMID ($VMNAME)"
qm create "$VMID" --name "$VMNAME" --memory "$MEMORY" --cores "$CORES" \
  --net0 virtio,bridge="$BRIDGE" --bios seabios --bootdisk sata0 \
  --serial0 socket --vga serial0 --boot order=sata0

# --- Import ArcLoader boot image ---
echo "[INFO] Importing ArcLoader boot disk..."
qm importdisk "$VMID" "$ARCPATH" "$STORAGE"
qm set "$VMID" --sata0 "${STORAGE}:vm-${VMID}-disk-0"

# --- Create blank system disk for DSM install ---
echo "[INFO] Creating 8 GB system disk for fresh DSM installation..."
qm set "$VMID" --sata1 "$STORAGE:8"

# --- Attach exported data disks ---
echo "[INFO] Attaching exported data disks (preserve contents)..."
INDEX=2
for FILE in "$DISKDIR"/*.qcow2; do
    echo "  -> Importing $FILE as sata${INDEX}"
    qm importdisk "$VMID" "$FILE" "$STORAGE"
    qm set "$VMID" --sata${INDEX} "${STORAGE}:vm-${VMID}-disk-${INDEX}"
    INDEX=$((INDEX+1))
done

# --- Final settings ---
qm set "$VMID" --boot order=sata0
echo "[INFO] VM created successfully."
echo "----------------------------------------------"
echo "Next steps:"
echo "1. Start VM:  qm start $VMID"
echo "2. In ArcLoader UI, pick the SAME DSM version as the original vDSM."
echo "3. When DSM Web Assistant appears, choose 'Migrate / Keep existing data'."
echo "   DSM installs on the new 8 GB system disk and re-imports your data volumes."
echo "----------------------------------------------"
