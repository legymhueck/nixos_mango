#!/usr/bin/env bash
set -euo pipefail

yes_all=false
dry_run=false

usage() {
    echo "Usage: $0 [-y|--yes] [-n|--dry-run]"
    echo "  -y, --yes      Delete snapshots without confirmation"
    echo "  -n, --dry-run  Only print what would be deleted"
    echo "  -h, --help     Show this help"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes) yes_all=true ;;
        -n|--dry-run) dry_run=true ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
    shift
done

configs=$(sudo snapper list-configs | awk 'NR>2 {print $1}')

if [[ -z "$configs" ]]; then
    echo "No snapper configurations found."
    exit 0
fi

echo "Snapper configurations: $configs"

for config in $configs; do
    echo
    echo "== Config: $config =="

    if ! numbers=$(sudo snapper -c "$config" list --columns number | awk 'NR>2 && $1 != "0" {print $1}'); then
        echo "Warning: could not list snapshots for '$config', skipping." >&2
        continue
    fi

    if [[ -z "$numbers" ]]; then
        echo "No snapshots to delete."
        continue
    fi

    echo "Snapshots to delete: $numbers"

    if [[ "$dry_run" == true ]]; then
        continue
    fi

    if [[ "$yes_all" != true ]]; then
        read -r -p "Delete these snapshots for '$config'? [y/N] " answer
        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            echo "Skipping '$config'."
            continue
        fi
    fi

    sudo snapper -c "$config" delete --sync $numbers
done
