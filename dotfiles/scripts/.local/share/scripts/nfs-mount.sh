#!/usr/bin/env bash
set -euo pipefail

SERVER="${NFS_SERVER:-192.168.2.2}"
DEFAULT_MOUNTS=(
    "/volumeUSB1/usbshare" "/mnt/usbshare1"
    "/volumeUSB2/usbshare" "/mnt/usbshare2"
    "/volumeUSB3/usbshare" "/mnt/usbshare3"
    "/volume1/fotos-privat" "/mnt/fotos"
    "/volume1/homes" "/mnt/homes"
)

usage() {
    cat <<EOF
Usage: $(basename "$0") [REMOTE_PATH MOUNT_POINT]...

Examples:
  $(basename "$0")
  NFS_SERVER=nas.local $(basename "$0") /volume1/data /mnt/data
  $(basename "$0") 192.168.2.2:/volume1/media /mnt/media

Notes:
  - With no arguments, built-in defaults are mounted.
  - REMOTE_PATH may be either /export/path or server:/export/path.
  - Arguments must be supplied in pairs.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

for cmd in sudo mount mountpoint mkdir df; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "Error: required command not found: $cmd" >&2; exit 1; }
done

if (( $# == 0 )); then
    mounts=("${DEFAULT_MOUNTS[@]}")
else
    (( $# % 2 == 0 )) || { echo "Error: arguments must be REMOTE_PATH/MOUNT_POINT pairs." >&2; exit 1; }
    mounts=("$@")
fi

for ((i = 0; i < ${#mounts[@]}; i += 2)); do
    remote="${mounts[i]}"
    target="${mounts[i + 1]}"

    if [[ "$remote" != *:* ]]; then
        remote="$SERVER:$remote"
    fi

    sudo mkdir -p "$target"

    if mountpoint -q "$target"; then
        echo "Already mounted at $target"
        continue
    fi

    echo "Mounting $remote -> $target"
    sudo mount -t nfs "$remote" "$target"
done

df -h -t nfs4 -t nfs || true
