#!/usr/bin/env bash
set -euo pipefail

# Script to set appropriate permissions for .ssh directory and its contents

SSH_DIR="${1:-$HOME/.ssh}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [ssh-dir]

Set standard permissions on an SSH directory.
Default: ~/.ssh
EOF
}

if [[ "$SSH_DIR" == "-h" || "$SSH_DIR" == "--help" ]]; then
    usage
    exit 0
fi

if [ ! -d "$SSH_DIR" ]; then
    echo "Error: $SSH_DIR does not exist." >&2
    exit 1
fi

echo "Setting permissions for $SSH_DIR..."

chmod 700 "$SSH_DIR"
find "$SSH_DIR" -type f -exec chmod 600 {} +
find "$SSH_DIR" -type f -name "*.pub" -exec chmod 644 {} +
[ -f "$SSH_DIR/known_hosts" ] && chmod 644 "$SSH_DIR/known_hosts"
[ -f "$SSH_DIR/known_hosts.old" ] && chmod 644 "$SSH_DIR/known_hosts.old"
find "$SSH_DIR" -mindepth 1 -type d -exec chmod 700 {} +

echo "Permissions updated successfully."
echo "Applied: directories=700, private files=600, public keys/known_hosts=644"
