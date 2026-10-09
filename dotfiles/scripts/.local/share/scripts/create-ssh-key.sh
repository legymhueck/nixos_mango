#!/usr/bin/env bash
set -euo pipefail

# Script to generate a new ed25519 SSH key, asking the relevant questions first

SSH_DIR="$HOME/.ssh"
default_key="$SSH_DIR/id_ed25519"

usage() {
    cat <<EOF
Usage: $(basename "$0")

Interactively create a new ed25519 SSH key.
Default path: $default_key
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

echo "This will create a new ed25519 SSH key."
echo

read -rp "Email or comment to embed in the key [optional]: " key_comment
read -rp "Key file path [$default_key]: " key_path
key_path="${key_path:-$default_key}"

if [[ -e "$key_path" ]]; then
    echo "Error: $key_path already exists." >&2
    exit 1
fi

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

echo
echo "Choose a passphrase when prompted (or press Enter twice for none)."
ssh-keygen -t ed25519 -C "${key_comment:-}" -f "$key_path"

chmod 600 "$key_path"
chmod 644 "$key_path.pub"

echo
echo "Key created:"
ls -l "$key_path" "$key_path.pub"
echo
echo "Public key (add it to GitHub/GitLab/your server):"
cat "$key_path.pub"
