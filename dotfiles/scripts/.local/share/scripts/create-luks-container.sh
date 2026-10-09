#!/usr/bin/env bash
set -euo pipefail

IMAGE_FILE="${1:-pkg.img}"
SIZE_MB="${2:-20480}"
MAP_NAME="${3:-pkg}"
MOUNT_POINT="${4:-/mnt/$MAP_NAME}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [image-file] [size-mb] [mapper-name] [mount-point]

Creates a LUKS container file, formats it as ext4, and mounts it.

Examples:
  $(basename "$0")
  $(basename "$0") backup.img 4096 backup /mnt/backup
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

for cmd in dd sudo losetup cryptsetup mkfs.ext4 mount mkdir; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "Error: required command not found: $cmd" >&2; exit 1; }
done

[[ "$SIZE_MB" =~ ^[0-9]+$ ]] || { echo "Error: size must be an integer number of MiB." >&2; exit 1; }

if [[ -e "$IMAGE_FILE" ]]; then
    echo "Error: image file already exists: $IMAGE_FILE" >&2
    exit 1
fi

mkdir -p "$(dirname "$IMAGE_FILE")"

echo "Creating image file $IMAGE_FILE (${SIZE_MB} MiB)..."
dd if=/dev/urandom of="$IMAGE_FILE" bs=1M count="$SIZE_MB" status=progress

LOOP_DEV="$(sudo losetup -f --show "$IMAGE_FILE")"
echo "Using loop device: $LOOP_DEV"

echo "Formatting LUKS container..."
sudo cryptsetup luksFormat "$LOOP_DEV"
sudo cryptsetup luksOpen "$LOOP_DEV" "$MAP_NAME"
sudo mkfs.ext4 "/dev/mapper/$MAP_NAME"

sudo mkdir -p "$MOUNT_POINT"
sudo mount "/dev/mapper/$MAP_NAME" "$MOUNT_POINT"

echo "Mounted container at $MOUNT_POINT"
echo
echo "Cleanup when finished:"
echo "  sudo umount '$MOUNT_POINT'"
echo "  sudo cryptsetup luksClose '$MAP_NAME'"
echo "  sudo losetup -d '$LOOP_DEV'"
