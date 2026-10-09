#!/usr/bin/env bash
set -euo pipefail

MOUNT_PATH="${1:-${MOUNT_PATH:-$HOME/mount}}"
MAP_NAME="${2:-${MAP_NAME:-micleh}}"

if [[ "$MOUNT_PATH" == "-h" || "$MOUNT_PATH" == "--help" ]]; then
    echo "Usage: $(basename "$0") [mount-path] [mapper-name]"
    exit 0
fi

MOUNT_PATH="${MOUNT_PATH/#\~/$HOME}"

if mountpoint -q "$MOUNT_PATH"; then
    sudo umount "$MOUNT_PATH"
else
    echo "Not mounted: $MOUNT_PATH"
fi

if [[ -e "/dev/mapper/$MAP_NAME" ]]; then
    sudo cryptsetup close "$MAP_NAME"
else
    echo "Mapper not open: $MAP_NAME"
fi

echo "Drive unmounted and mapper closed where applicable."
