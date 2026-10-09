#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<EOF
Usage: $(basename "$0") [bin-dir]

Append an export PATH line to ~/.bashrc if it is not already present.

Arguments:
  bin-dir   Directory to prepend to PATH (default: ~/.local/bin)

Environment:
  BASHRC_PATH   Override the target bashrc path
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

bin_dir="${1:-$HOME/.local/bin}"
bashrc="${BASHRC_PATH:-$HOME/.bashrc}"

if [[ -e /etc/NIXOS && -z ${BASHRC_PATH:-} ]]; then
    if [[ "$bin_dir" == "$HOME/.local/bin" ]]; then
        echo "$bin_dir is already on PATH through the managed NixOS shell configuration."
        exit 0
    fi
    echo "NixOS shell paths are managed declaratively; update the Home Manager shell configuration." >&2
    exit 1
fi

if [[ "$bin_dir" == "$HOME/.local/bin" ]]; then
    line='export PATH="$HOME/.local/bin:$PATH"'
else
    line="export PATH=\"$bin_dir:\$PATH\""
fi

mkdir -p "$(dirname "$bashrc")"
touch "$bashrc"

if grep -qF -- "$line" "$bashrc"; then
    echo "PATH line already present in $bashrc, skipping."
else
    printf '%s\n' "$line" >> "$bashrc"
    echo "Added PATH line to $bashrc."
fi

echo "Done. Open a new shell or run: source $bashrc"
