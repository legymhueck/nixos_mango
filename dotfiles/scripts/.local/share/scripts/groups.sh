#!/usr/bin/env bash
set -euo pipefail

DEFAULT_GROUPS=(
  adm audio autologin disk floppy input libvirt sys log network scanner power
  rfkill users video storage optical lp wheel wireshark kvm docker
)

TARGET_USER="${SUDO_USER:-${USER:-$(id -un)}}"
CREATE_MISSING=0
GROUPS_TO_ADD=()

usage() {
  cat <<EOF
Usage: $(basename "$0") [--user USER] [--create-missing] [group ...]

Examples:
  $(basename "$0")
  $(basename "$0") --user m wheel libvirt docker
  $(basename "$0") --create-missing autologin libvirt

Notes:
  - With no group arguments, a built-in default list is used.
  - Missing groups are skipped unless --create-missing is passed.
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --user)
      [[ $# -ge 2 ]] || { echo "Error: --user requires a value." >&2; exit 1; }
      TARGET_USER="$2"
      shift 2
      ;;
    --create-missing)
      CREATE_MISSING=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      GROUPS_TO_ADD+=("$1")
      shift
      ;;
  esac
done

if (( ${#GROUPS_TO_ADD[@]} == 0 )); then
  GROUPS_TO_ADD=("${DEFAULT_GROUPS[@]}")
fi

if ! id "$TARGET_USER" >/dev/null 2>&1; then
  echo "Error: user not found: $TARGET_USER" >&2
  exit 1
fi

for cmd in sudo gpasswd getent groupadd; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Error: required command not found: $cmd" >&2; exit 1; }
done

for group in "${GROUPS_TO_ADD[@]}"; do
  if ! getent group "$group" >/dev/null 2>&1; then
    if (( CREATE_MISSING == 1 )); then
      echo "Creating missing group: $group"
      sudo groupadd "$group"
    else
      echo "Skipping missing group: $group"
      continue
    fi
  fi

  if id -nG "$TARGET_USER" | grep -qw "$group"; then
    echo "User '$TARGET_USER' is already in group '$group'"
    continue
  fi

  sudo gpasswd -a "$TARGET_USER" "$group"
done

echo "Done. You may need to log out and back in for group changes to take effect."
