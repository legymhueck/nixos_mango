#!/usr/bin/env bash
set -euo pipefail

# Script to add a user to the i2c group.
# By default it targets the invoking user, not root.

USERNAME="${1:-${SUDO_USER:-$(id -un)}}"

if [[ $(id -u) -eq 0 && -z "${SUDO_USER:-}" && -z "${1:-}" ]]; then
    echo "Error: do not run this script directly as root without specifying a username." >&2
    echo "Usage: $0 [username]" >&2
    exit 1
fi

if [[ ! "$USERNAME" =~ ^[a-z_][a-z0-9_-]*\$?$ ]]; then
    echo "Error: invalid username '$USERNAME'." >&2
    exit 1
fi

if ! id "$USERNAME" >/dev/null 2>&1; then
    echo "Error: user '$USERNAME' does not exist." >&2
    exit 1
fi

if ! command -v usermod >/dev/null 2>&1; then
    echo "Error: usermod is not available on this system." >&2
    exit 1
fi

if ! getent group i2c >/dev/null 2>&1; then
    echo "Error: group 'i2c' does not exist." >&2
    exit 1
fi

if id -nG "$USERNAME" | grep -qw i2c; then
    echo "User '$USERNAME' is already in the i2c group."
    exit 0
fi

echo "Adding user '$USERNAME' to the i2c group..."
sudo usermod -aG i2c "$USERNAME"
echo "Successfully added user '$USERNAME' to the i2c group."
echo "Note: You may need to log out and log back in for changes to take effect."
echo "Or run: newgrp i2c"