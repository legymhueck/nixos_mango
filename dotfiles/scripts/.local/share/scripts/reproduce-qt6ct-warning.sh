#!/usr/bin/env bash
# Reproduce qt6ct's "The application is not configured correctly" warning.
# Use --offscreen for a non-GUI/headless reproduction.

set -u

SCRIPT_PATH=$(readlink -f -- "${BASH_SOURCE[0]}")
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$SCRIPT_PATH")" && pwd)
DOCTOR="$SCRIPT_DIR/qt6ct-doctor.sh"

case ${1:-} in
    -h|--help|help)
        exec "$DOCTOR" --help
        ;;
esac

exec "$DOCTOR" reproduce "$@"
