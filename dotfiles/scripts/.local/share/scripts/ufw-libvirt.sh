#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: sudo $(basename "$0")"
    echo "Allow libvirt bridge traffic through UFW."
    exit 0
fi

command -v ufw >/dev/null 2>&1 || { echo "Error: ufw not found." >&2; exit 1; }

sudo ufw allow in on virbr0
sudo ufw allow out on virbr0
sudo ufw reload

echo "Applied basic UFW rules for virbr0."
echo "If guest forwarding still fails, also review /etc/default/ufw and /etc/ufw/sysctl.conf."
