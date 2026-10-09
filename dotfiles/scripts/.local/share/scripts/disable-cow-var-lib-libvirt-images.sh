#!/usr/bin/env bash
set -euo pipefail

TARGET_PATH="${1:-/var/lib/libvirt/images}"
ASSUME_YES=0

usage() {
    cat <<EOF
Usage: $(basename "$0") [--yes] [path]

Disable copy-on-write for a libvirt images directory by applying chattr +C.
Default path: /var/lib/libvirt/images

Warning:
  This only affects newly created files meaningfully on most filesystems.
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
            TARGET_PATH="$1"
            shift
            ;;
    esac
done

[[ -e "$TARGET_PATH" ]] || { echo "Error: path not found: $TARGET_PATH" >&2; exit 1; }
command -v chattr >/dev/null 2>&1 || { echo "Error: chattr not found." >&2; exit 1; }

if (( ASSUME_YES != 1 )); then
    echo "About to run: sudo chattr -RV +C '$TARGET_PATH'"
    read -r -p "Proceed? [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 1; }
fi

sudo chattr -RV +C "$TARGET_PATH"
echo "Applied +C to $TARGET_PATH"
