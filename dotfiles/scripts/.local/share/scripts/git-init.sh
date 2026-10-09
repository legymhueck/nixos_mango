#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<EOF
Usage: $(basename "$0")

Interactively set global git user.name and user.email.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

read -rp "Enter your Git username: " git_username
read -rp "Enter your Git email: " git_email

git config --global user.name "$git_username"
git config --global user.email "$git_email"

echo "Git configured for $git_username <$git_email>"
