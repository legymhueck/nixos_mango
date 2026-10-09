#!/usr/bin/env bash
set -euo pipefail

PORT="${LOCALSEND_PORT:-53317}"

usage() {
    cat <<EOF
Usage: $(basename "$0")

Open the LocalSend port in either firewalld or UFW.
Environment:
  LOCALSEND_PORT   Port to open (default: 53317)
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if command -v firewall-cmd >/dev/null 2>&1; then
    sudo firewall-cmd --zone=public --add-port="${PORT}/tcp"
    sudo firewall-cmd --zone=public --add-port="${PORT}/udp"
    sudo firewall-cmd --runtime-to-permanent
    sudo firewall-cmd --reload
    sudo firewall-cmd --list-ports
    sudo firewall-cmd --list-all
elif command -v ufw >/dev/null 2>&1; then
    sudo ufw allow "${PORT}/tcp"
    sudo ufw allow "${PORT}/udp"
    sudo ufw reload
    sudo ufw status
else
    echo "Error: neither firewall-cmd nor ufw is installed." >&2
    exit 1
fi
