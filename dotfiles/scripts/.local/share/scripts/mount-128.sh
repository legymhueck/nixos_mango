#!/usr/bin/env bash
set -euo pipefail

SOURCE_SPEC="${1:-${TARGET_UUID:-709b4965-5bce-4219-ae11-32da71981f22}}"
MAP_NAME="${2:-${MAP_NAME:-micleh}}"
MOUNT_PATH="${3:-${MOUNT_PATH:-$HOME/mount}}"
MOUNT_OPTS="${MOUNT_OPTS:-noatime,compress=zstd:3,autodefrag,discard=async}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [UUID-or-device] [map-name] [mount-path]

Examples:
  $(basename "$0")
  $(basename "$0") 709b4965-5bce-4219-ae11-32da71981f22 micleh ~/mount
  $(basename "$0") /dev/sdb1 backupdisk /mnt/backup

Environment:
  TARGET_UUID   Default UUID if no first argument is given
  MAP_NAME      Default mapper name
  MOUNT_PATH    Default mount path
  MOUNT_OPTS    Mount options
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

for cmd in blkid cryptsetup mountpoint mount mkdir sudo; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "Error: required command not found: $cmd" >&2; exit 1; }
done

if [[ "$SOURCE_SPEC" == /dev/* ]]; then
    DEVICE="$SOURCE_SPEC"
else
    DEVICE="$(blkid -U "$SOURCE_SPEC" || true)"
fi

[[ -n "$DEVICE" ]] || { echo "Error: device not found for '$SOURCE_SPEC'." >&2; exit 1; }
[[ -e "$DEVICE" ]] || { echo "Error: device path does not exist: $DEVICE" >&2; exit 1; }

if ! sudo cryptsetup isLuks "$DEVICE" >/dev/null 2>&1; then
    echo "Error: $DEVICE is not a LUKS device." >&2
    exit 1
fi

if [[ ! -e "/dev/mapper/$MAP_NAME" ]]; then
    echo "Unlocking $DEVICE as $MAP_NAME..."
    sudo cryptsetup open "$DEVICE" "$MAP_NAME"
else
    echo "Device is already unlocked at /dev/mapper/$MAP_NAME"
fi

mkdir -p "$MOUNT_PATH"

if mountpoint -q "$MOUNT_PATH"; then
    echo "Already mounted at $MOUNT_PATH"
    exit 0
fi

echo "Mounting /dev/mapper/$MAP_NAME to $MOUNT_PATH"
sudo mount -o "$MOUNT_OPTS" "/dev/mapper/$MAP_NAME" "$MOUNT_PATH"

if [[ -d "$MOUNT_PATH/data" ]]; then
    echo "Success! Access your files at $MOUNT_PATH/data"
else
    echo "Success! Mounted at $MOUNT_PATH"
fi
