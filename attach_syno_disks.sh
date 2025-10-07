#!/bin/bash
# attach_syno_disks.sh
# usage:
#   sudo ./attach_syno_disks.sh <vmid> <export_dir>

set -euo pipefail

if [ $# -lt 2 ]; then
    echo "Usage: $0 <vmid> <export_disk_dir>"
    exit 1
fi

VMID="$1"
DISKDIR="$2"
STORAGE="local-vmpool-1"
MAX_WAIT=30

echo "[INFO] Attaching exported Synology disks to VM $VMID"
echo "[INFO] Disk directory: $DISKDIR"
echo

NEXT_INDEX=$(($(qm config "$VMID" | grep -c "sata")))

for FILE in "$DISKDIR"/*.qcow2; do
    INDEX=$((NEXT_INDEX + 1))
    echo "[INFO] Importing $FILE → SATA${INDEX}"
    qm importdisk "$VMID" "$FILE" "$STORAGE"

    # Find the latest zvol created for this VM
    ZVOL_NAME=$(zfs list -t volume -o name | grep "vm-${VMID}-disk-" | sort -V | tail -n 1)
    ZVOL_PATH="/dev/zvol/${ZVOL_NAME}"

    echo -n "[WAIT] Checking for $ZVOL_PATH "
    for ((i=1; i<=MAX_WAIT; i++)); do
        if [ -e "$ZVOL_PATH" ]; then
            echo "→ Found after ${i}s"
            break
        fi
        echo -n "."
        sleep 1
    done
    echo

    if [ ! -e "$ZVOL_PATH" ]; then
        echo "[WARN] Timeout waiting for $ZVOL_PATH (ZFS slow to expose). Continuing anyway..."
    fi

    echo "[INFO] Attaching ${ZVOL_NAME} as sata${INDEX}"
    qm set "$VMID" --sata${INDEX} "${STORAGE}:${ZVOL_NAME##*/}"
    echo "[OK] Attached SATA${INDEX} (${ZVOL_NAME})"
    echo

    NEXT_INDEX=$((INDEX))
done

echo "----------------------------------------------"
echo "[INFO] All exported disks imported and attached."
echo "If DSM is running, reboot it to detect new drives."
echo "----------------------------------------------"
