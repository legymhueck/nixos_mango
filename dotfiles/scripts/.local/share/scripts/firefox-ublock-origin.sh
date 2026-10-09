#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<EOF
Usage: $(basename "$0")

Download the latest uBlock Origin Firefox add-on XPI and open it with Firefox.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if ! command -v wget >/dev/null 2>&1; then
    echo "Error: wget is not installed." >&2
    exit 1
fi

if ! command -v firefox >/dev/null 2>&1; then
    echo "Error: firefox is not installed." >&2
    exit 1
fi

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/firefox-addon-installs"
TMP_PATH="$CACHE_DIR/ublock-origin.xpi.download"
XPI_PATH="$CACHE_DIR/ublock-origin.xpi"

mkdir -p "$CACHE_DIR"
trap 'rm -f "$TMP_PATH"' EXIT

wget -O "$TMP_PATH" "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi"
mv -f "$TMP_PATH" "$XPI_PATH"

firefox "$XPI_PATH"
