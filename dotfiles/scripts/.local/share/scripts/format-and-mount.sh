#!/usr/bin/env bash
set -euo pipefail

DEVICE=""
MAP_NAME=""
MOUNT_PATH=""
MOUNT_OPTS="${MOUNT_OPTS:-noatime,compress=zstd:3,autodefrag,discard=async}"
ASSUME_YES=0

usage() {
    cat <<EOF
Usage: $(basename "$0") [--yes] [device] [map-name] [mount-path]

Format a block device as LUKS + Btrfs, then mount it.

Examples:
  $(basename "$0")
  $(basename "$0") /dev/sdb1 backup /mnt/backup
  $(basename "$0") --yes /dev/sdc1 archive ~/mount/archive
EOF
}

while (( $# > 0 )); do
    case "$1" in
        --yes)
            ASSUME_YES=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

if (( $# >= 1 )); then
    DEVICE="$1"
else
    echo "Available drives:"
    lsblk -o NAME,SIZE,MODEL,TYPE,MOUNTPOINT | grep -E 'part|disk' || true
    echo
    read -r -p "Enter the device or partition (e.g., /dev/sdb1): " DEVICE
fi

if (( $# >= 2 )); then
    MAP_NAME="$2"
else
    read -r -p "Enter a mapping name (e.g., micleh): " MAP_NAME
fi

if (( $# >= 3 )); then
    MOUNT_PATH="$3"
else
    read -r -p "Enter mount path (e.g., ~/mount): " MOUNT_PATH
fi

[[ "$DEVICE" == /dev/* ]] || DEVICE="/dev/$DEVICE"
MOUNT_PATH="${MOUNT_PATH/#\~/$HOME}"

for cmd in lsblk sudo cryptsetup mkfs.btrfs mount btrfs mkdir; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "Error: required command not found: $cmd" >&2; exit 1; }
done

[[ -b "$DEVICE" ]] || { echo "Error: block device not found: $DEVICE" >&2; exit 1; }
[[ -n "$MAP_NAME" ]] || { echo "Error: mapping name must not be empty." >&2; exit 1; }
[[ -n "$MOUNT_PATH" ]] || { echo "Error: mount path must not be empty." >&2; exit 1; }

mkdir -p "$MOUNT_PATH"

echo "WARNING: This will irreversibly wipe $DEVICE"
echo "  mapper name: $MAP_NAME"
echo "  mount path : $MOUNT_PATH"
if (( ASSUME_YES != 1 )); then
    read -r -p "Type the full device path to continue: " confirm
    [[ "$confirm" == "$DEVICE" ]] || { echo "Confirmation failed. Aborting." >&2; exit 1; }
fi

sudo cryptsetup luksFormat "$DEVICE"
sudo cryptsetup open "$DEVICE" "$MAP_NAME"
sudo mkfs.btrfs -L "$MAP_NAME" "/dev/mapper/$MAP_NAME"
sudo mount -o "$MOUNT_OPTS" "/dev/mapper/$MAP_NAME" "$MOUNT_PATH"

if [[ ! -d "$MOUNT_PATH/data" ]]; then
    sudo btrfs subvolume create "$MOUNT_PATH/data"
fi
sudo chown "$USER:$USER" "$MOUNT_PATH/data"

echo "Optimized encrypted drive ready at $MOUNT_PATH/data"
