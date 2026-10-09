#!/usr/bin/env bash
set -euo pipefail

SHARE="${1:-${DISKSTATION_SHARE:-//192.168.2.2/4TB_2}}"
MOUNT_POINT="${2:-${DISKSTATION_MOUNT_POINT:-/mnt/diskstation/4tb_2}}"
CREDENTIALS_FILE="${SMB_CREDENTIALS_FILE:-$HOME/.smbcredentials}"
SMB_VERS="${SMB_VERS:-3.0}"
SMB_IOCHARSET="${SMB_IOCHARSET:-utf8}"
SMB_EXTRA_OPTS="${SMB_EXTRA_OPTS:-}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [//server/share] [mount-point]

Environment:
  DISKSTATION_SHARE         Default share path
  DISKSTATION_MOUNT_POINT   Default mount point
  SMB_CREDENTIALS_FILE      Credentials file (default: ~/.smbcredentials)
  SMB_VERS                  SMB protocol version (default: 3.0)
  SMB_IOCHARSET             Charset (default: utf8)
  SMB_EXTRA_OPTS            Extra comma-separated mount options
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

for cmd in sudo mount mountpoint id mkdir; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "Error: required command not found: $cmd" >&2; exit 1; }
done

[[ -f "$CREDENTIALS_FILE" ]] || { echo "Error: credentials file not found: $CREDENTIALS_FILE" >&2; exit 1; }

sudo mkdir -p "$MOUNT_POINT"

if mountpoint -q "$MOUNT_POINT"; then
    echo "Already mounted at $MOUNT_POINT"
    exit 0
fi

mount_opts="credentials=$CREDENTIALS_FILE,uid=$(id -u),gid=$(id -g),vers=$SMB_VERS,iocharset=$SMB_IOCHARSET"
if [[ -n "$SMB_EXTRA_OPTS" ]]; then
    mount_opts+=",$SMB_EXTRA_OPTS"
fi

sudo mount -t cifs "$SHARE" "$MOUNT_POINT" -o "$mount_opts"
echo "Mounted $SHARE at $MOUNT_POINT"
